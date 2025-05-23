=encoding utf8

=head1 NAME

CInet::ManySAT - A collection of SAT solvers

=head1 SYNOPSIS

    # Add clauses to a new solver
    my $solver = CInet::ManySAT->new->read($cnf);

    # Check satisfiability, obtain a witness
    my $model = $solver->model;
    say join(" ", $model->@*) if defined $model;

    # Count satisfying assignments
    say $solver->count(risk => 0.05);   # probably exact count with 5% risk
    say $solver->count([-2]);  # exact count of all models where 2 is false

    # Enumerate all satisfying assignments
    my $all = $solver->all;
    while (defined(my $model = $all->next)) {
        say join(" ", $model->@*);
        $all->cancel and last if ++$count > $caring_for;
    }

=head2 VERSION

This document describes CInet::ManySAT v1.1.0.

=cut

# ABSTRACT: A collection of SAT solvers
package CInet::ManySAT;

our $VERSION = "v1.1.0";

use Modern::Perl 2018;
use List::Util qw(first);
use Carp;

use Role::Tiny::With;
with 'CInet::ManySAT::ClauseStorage';

=head1 DESCRIPTION

C<CInet::ManySAT> provides a common interface to a variety of solvers for
the Boolean satisfiability problem (SAT) and its variants.

The supported SAT-like problems are described in the next sections. They all
operate on a Boolean formula presented in conjunctive normal form (CNF).
The solvers used internally are heterogenous, independent programs. Therefore
this class does the L<CInet::ManySAT::ClauseStorage> role to provide a common
formula storage mechanism for all of them. See the documentation of that role
for how to read a formula into the solver or how to get it back out in the
standard DIMACS CNF format.

=head2 Satisfiability and consistency checking

In its simplest form, SAT is about deciding whether a Boolean formula has
a solution, that is an assignment of true and false to the variables which
I<satisfies> all the clauses of the formula simultaneously. The SAT solver
is available through the L<model|/"model"> method which returns either a
I<model> of the formula or C<undef> if the formula is not satisfiable. In this
documentation, the word "model" is used for "satisfying assignment".
Thus the L<model|/"model"> method is a witnessing SAT solver, in that it
provides you with a witness for the "SAT" answer (but not the "UNSAT" answer).

The L<model|/"model"> method accepts optional I<assumptions>. These come in the
form of an arrayref of non-zero integers, just like the clauses of the formula.
The assumptions fix the truth value of some of the variables and they are
valid only for the current invocation of the solver. In this way, you can
use the solver to check if an assignment is I<consistent> with the formula,
that is whether this partial assignment can be extended to a satisfying one.
It can also be used to simply evaluate the formula, verifying that a full
assignment is actually a model.

=head3 Low-overhead incremental solver

If your problem requires checking the same formula over and over again on
different sets of assumptions (maybe because you want to compute a projection
of the set of satisfying assignments to your formula), the solver contained
in this class will not make you very happy. Since C<CInet::ManySAT> has to
support a range of different solvers, it writes a temporary DIMACS CNF file
for every solver invocation, which slows down any large loop around them.
You should consider using the L<CInet::ManySAT::Incremental> solver, which
is specialized to those tasks.

=head2 Model counting

We provide two B<#SAT solvers>. Such a solver determines the number of
satisfying assignments to a formula, potentially faster than by iterating
over them all. One of the solvers is exact and the other is probabilistically
exact, meaning that it delivers the correct answer only with a configurable
probability. The probabilistic solver is generally faster but it may give
up on the formula entirely if it finds that it cannot guarantee exactness
with the given probability. These solvers are accessible through the L<count|/"count">
method with its optional C<risk> parameter.

=head2 Model enumeration

After producing a single model and counting all models, the last task
supported is to enumerate all models. This problem is known as B<AllSAT>.
This module provides an interface to a solver which lazily produces all
the models of a formula. The solver usually starts outputting models
immediately (if it can find them) but gets put to sleep by the operating
system when the IPC buffer is filled up. This way, a slow application
processing the models does not cause the solver to fill up extraordinary
amounts of memory nor the solver to "run away" but maintain a reasonably
full pool of models for immediate reading. The enumeration is cancelable.

=cut

use Exporter qw(import);
our @EXPORT_OK = qw(
    sat_model sat_count sat_all
);

use IPC::Run qw(run);
use IPC::Open3;
use IO::Null;

use CInet::ManySAT::All;

use CInet::Alien::CaDiCaL qw(cadical);
use CInet::Alien::SharpSAT::TD qw(sharpsat_td);
use CInet::Alien::GANAK qw(ganak);
use CInet::Alien::MiniSAT::All qw(nbc_minisat_all);

=head2 Methods

=head3 new

    my $solver = CInet::ManySAT::Count->new;

Create a new instance of a ManySAT solver. Use C<read> and C<add> of
L<CInet::ManySAT::ClauseStorage> to fill it with clauses.

=cut

sub new {
    my $class = shift;
    bless { @_ }, $class
}

=head3 model

    my $model = $solver->model($assump);
    say join(' ', $model->@*) if defined $model;

    say "consistent" if $solver->model($assignment);

Checks the formula for satisfiability and returns a witness model in case
it is satisfiable. Otherwise returns C<undef>. If the solver gave up or
terminated abnormally, an exception is raised.

The first argument C<$assump> is an optional arrayref defining the values
of some of the variables for the current run only. Therefore this method
can be used for model checking or consistency checking as well.

=cut

sub model {
    my $self = shift;
    my $assump = ref $_[0] eq 'ARRAY' ? shift : [ ];

    my $feed = $self->dimacs($assump);
    # cadical returns 0 on error and 10 or 20 when it terminated.
    run [cadical], $feed, \my $out;
    my $status = $? >> 8;
    die "cadical exited with an error" if $status != 10 and $status != 20;

    return undef unless $out =~ /^s SATISFIABLE/m;
    [ grep { $_ } map { /(-?\d+)/g } grep { /^v / } split /\n/, $out ]
}

=head3 count

    say $solver->count($assump);
    say $solver->count($assump, risk => 0.05); # probably correct

Exactly count the models of the formula stored in the solver.

The first argument C<$assump> is an optional arrayref defining the values
of some of the variables for the current run only.

The remaining arguments are treated as options. The only supported option
currently is C<risk>. If specified with a non-zero probability, it causes
the probabilistically exact solver to be invoked. All other options are
passed to the solver.

This method raises an error if the solver terminated abnormally.

=cut

sub count {
    my $self = shift;
    my $assump = ref $_[0] eq 'ARRAY' ? shift : [ ];

    my %opts = @_;
    my $feed = $self->dimacs($assump);
    my $risk = $opts{risk} // 0;
    delete $opts{risk};
    if ($risk == 0) {
        die "sharpsat_td exited with code @{[ $? >> 8 ]}"
            unless run [sharpsat_td(%opts)], $feed, \my $out;
        my $mc = first { defined $_ } map { /^c s exact arb int (\d+)/g } split /\n/, $out;
        $mc
    }
    elsif (0 < $risk and $risk < 1) {
        die "ganak exited with code @{[ $? >> 8 ]}"
            unless run [ganak, '-delta', $risk, '-'], $feed, \my $out;
        my $mc = first { defined $_ } map { /^s mc (\d+)/g } split /\n/, $out;
        $mc
    }
    else {
        die "risk value '$opts{risk}' is not a probability";
    }
}

=head3 all

    say for $solver->all($assump)->list;
    say for $all->list;

    # Or more memory-friendly:
    while (defined(my $model = $all->next)) {
        say $model;
        $all->cancel and last if had_enough;
    }

Enumerate all models of the formula stored in the solver.

The first argument C<$assump> is an optional arrayref defining the values
of some of the variables for the current run only.

This method returns an object of type L<CInet::ManySAT::All> which can be
used to control the enumeration.

=cut

sub all {
    my $self = shift;
    my $assump = ref $_[0] eq 'ARRAY' ? shift : [ ];

    my $feed = $self->dimacs($assump);
    my ($in, $out);
    my $pid = open3 $in, $out, IO::Null->new, nbc_minisat_all;
    while (defined(my $line = $feed->())) {
        print {$in} $line;
    }
    close $in;

    CInet::ManySAT::All->new($pid => $out)
}

=head3 description

    my $str = $solver->description;

Returns a human-readable description of the object.

=cut

sub description {
    my $self = shift;
    'Multi-purpose SAT solver holding ' . scalar($self->clauses->@*) . ' clauses'
}

=head2 EXPORTS

The following functions are exported on demand:

    my $model = sat_model ($cnf, $assump, %opts);
    my $count = sat_count ($cnf, $assump, %opts);
    my $all   = sat_all   ($cnf, $assump, %opts);

Each C<< sat_$action($cnf, @_) >> is equivalent to C<< CInet::ManySAT->new->read($cnf)->$action(@_) >>.

=cut

sub sat_model {
    my $cnf = shift;
    __PACKAGE__->new->read($cnf)->model(@_)
}

sub sat_count {
    my $cnf = shift;
    __PACKAGE__->new->read($cnf)->count(@_)
}

sub sat_all {
    my $cnf = shift;
    __PACKAGE__->new->read($cnf)->all(@_)
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

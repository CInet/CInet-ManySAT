=encoding utf8

=head1 NAME

CInet::ManySAT - A collection of SAT solvers

=head1 SYNOPSIS

    my $solver = CInet::ManySAT->new;
    $solver->read($cnf);          # add clauses to the solver

    # Check satisfiability, obtain a witness
    say join(" ", $solver->model->@*) if $solver->solve;

    # Count satisfying assignments
    say $solver->count_probably;  # probably exact count with 5% risk
    say $solver->count([-2]);     # exact count of all models where 2 is false

    say $solver->count([-2], -risk => 0.01);  # does what you mean

    # Enumerate all satisfying assignments
    TODO

=cut

# ABSTRACT: A collection of SAT solvers
package CInet::ManySAT;

use Modern::Perl 2018;
use Scalar::Util qw(reftype);
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

TODO



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
satisfying assignments to it, potentially faster than by iterating over
them all. One of the solvers is exact and the other is probabilistically
exact, meaning that it delivers the correct answer only with a configurable
probability. The probabilistic solver is generally faster but it may give
up on the formula entirely if it finds that it cannot guarantee exactness
with the given probability.

=head2 Model enumeration

TODO

=cut

use Exporter qw(import);
our @EXPORT_OK = qw(
    sat_solve sat_witness
    sat_count sat_count_probably
);

use IPC::Run qw(run);
use CInet::Alien::CaDiCaL qw(cadical);
use CInet::Alien::DSHARP qw(dsharp);
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

    my $assump = do {
        no warnings 'uninitialized';
        reftype($_[0]) eq 'ARRAY' ? shift : [ ]
    };

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
    say $solver->count($assump, risk => 0.05);

Exactly count the models of the formula stored in the solver.

The first argument C<$assump> is an optional arrayref defining the values
of some of the variables for the current run only. Therefore this method
can be used for model checking or consistency checking as well.

The remaining arguments are treated as options. The only supported option
currently is C<risk>. If specified with a non-zero probability, it causes
the probabilistically exact solver to be invoked.

=cut

sub count {
    my $self = shift;

    my $assump = do {
        no warnings 'uninitialized';
        reftype($_[0]) eq 'ARRAY' ? shift : [ ]
    };

    my %opts = @_;
    my $feed = $self->dimacs($assump);
    my $risk = $opts{risk} // 0;
    if ($risk == 0) {
        die "dsharp exited with code @{[ $? >> 8 ]}"
            unless run [dsharp], $feed, \my $out;
        my $mc = first { $_ } map { /^#SAT.*?(\d+)$/g } split /\n/, $out;
        $mc
    }
    elsif (0 < $risk and $risk < 1) {
        die "ganak exited with code @{[ $? >> 8 ]}"
            unless run [ganak, '-delta', $risk, '-'], $feed, \my $out;
        my $mc = first { $_ } map { /^s mc (\d+)/g } split /\n/, $out;
        $mc
    }
    else {
        die "risk value '$opts{risk}' is not a probability";
    }
}

=head2 EXPORTS

The following functions are exported on demand:

    sat_model($cnf, $assump);
    sat_count($cnf, $assump, %opts);

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

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

=encoding utf8

=head1 NAME

CInet::ManySAT - A collection of SAT solvers

=head1 SYNOPSIS

    my $solver = CInet::ManySAT->new;
    $solver->read($cnf);          # add clauses to the solver

    # Check satisfiability, obtain a witness
    TODO  # say $solver->model if $solver->solve == 1;

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
Also ref incremental solver.

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

=head3 count

    say $solver->count(%opts);
    say $solver->count($assump, %opts);

Exactly count the models of the formula stored in the solver.

If the first argument C<$assump> is an arrayref, the contained literals
are added as assumptions for this solver invocation. The remaining
arguments are a hash of options. The only supported option currently
is C<-risk> which, when non-zero, causes the solver to call the
probabilistic solver via L<count_probably> instead.

=cut

sub count {
    no warnings 'uninitialized';
    my $self = shift;

    if (reftype($_[0]) eq 'ARRAY') {
        $self->assume(shift->@*);
    }

    my %opts = @_;
    return $self->count_probably(%opts)
        if defined $opts{'-risk'} and $opts{'-risk'} != 0;

    my $feed = $self->dimacs;
    die "dsharp exited with code @{[ $? >> 8 ]}"
        unless run [dsharp], $feed, \my $out;

    my $mc = first { $_ } map { /^#SAT.*?(\d+)$/g } split /\n/, $out;
    $mc
}

=head3 count_probably

    say $solver->count_probably(%opts);
    say $solver->count_probably($assump, %opts);

Probably exactly count the models of the formula stored in the solver.

This method accepts the same arguments as L<count>. If the C<-risk> option
is exactly 0, it switches to L<count> instead. The default risk is 0.05.

=cut

sub count_probably {
    no warnings 'uninitialized';
    my $self = shift;

    if (reftype($_[0]) eq 'ARRAY') {
        $self->assume(shift->@*);
    }

    my %opts = @_;
    my $risk = $opts{'-risk'} // 0.05;
    my $feed = $self->dimacs;
    die "ganak exited with code @{[ $? >> 8 ]}"
        unless run [ganak, '-delta', $risk, '-'], $feed, \my $out;

    my $mc = first { $_ } map { /^s mc (\d+)/g } split /\n/, $out;
    $mc
}

=head2 EXPORTS

The following functions are exported on demand:

=head3 sat_count

    sat_count($cnf, $assump, %opts);
    sat_count($cnf, %opts);

This function is equivalent to

    CInet::ManySAT->new->read($cnf)->count($assump, %opts);

=cut

sub sat_count {
    my $cnf = shift;
    __PACKAGE__->new->read($cnf)->count(@_)
}

=head3 sat_count_probably

    sat_count_probably($cnf, $assump, %opts);
    sat_count_probably($cnf, %opts);

This function is equivalent to

    CInet::ManySAT->new->read($cnf)->count_probably($assump, %opts);

=cut

sub sat_count_probably {
    my $cnf = shift;
    __PACKAGE__->new->read($cnf)->count_probably(@_)
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

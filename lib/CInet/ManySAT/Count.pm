=encoding utf8

=head1 NAME

CInet::ManySAT::Count - An exact and a probabilistic #SAT solver

=head1 SYNOPSIS

    $solver->read($cnf);          # add clauses to the solver

    say $solver->count_probably;  # probably exact count with 5% risk
    say $solver->count([-2]);     # exact count of all models where 2 is false

    say $solver->count([-2], -risk => 0.01);  # does what you mean

=cut

# ABSTRACT: An exact and a probabilistic #SAT solver
package CInet::ManySAT::Count;

use Modern::Perl 2018;
use Scalar::Util qw(reftype);
use List::Util qw(first);
use Carp;

use Role::Tiny::With;
with 'CInet::ManySAT::ClauseStorage';

=head1 DESCRIPTION

C<CInet::ManySAT::Count> provides two B<#SAT solvers>. Such a solver receives
a Boolean formula and determines the number of satisfying assignments to it,
potentially faster than by iterating over them all. One of the solvers is
exact and the other is probabilistically exact, meaning that it delivers the
correct answer only with a configurable probability. The probabilistic solver
is generally faster but has a higher risk of not terminating at all.

Since the two solvers are implemented in external programs at the moment,
this class does the L<CInet::ManySAT::ClauseStorage> role.

=cut

use Exporter qw(import);
our @EXPORT_OK = qw(sat_count sat_count_probably);

use IPC::Run qw(run);
use CInet::Alien::DSHARP qw(dsharp);
use CInet::Alien::GANAK  qw(ganak);

sub new {
    my $class = shift;
    bless { @_ }, $class
}

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

=head3 sat_count

=cut

sub sat_count {
    my $cnf = shift;
    __PACKAGE__->new->read($cnf)->count(@_)
}

=head3 sat_count_probably

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

=encoding utf8

=head1 NAME

CInet::ManySAT::Incremental - An incremental SAT solver

=head1 SYNOPSIS

    my $solver = CInet::ManySAT::Incremental->new;
    $solver->read($cnf);   # add clauses to the solver
    say $solver->solve;    # result is 0, 1 or undef
    say $solver->solve([-2]);  # add assumptions on the fly

=head2 VERSION

This document describes CInet::ManySAT::Incremental v1.0.0.

=cut

# ABSTRACT: An incremental SAT solver
package CInet::ManySAT::Incremental;

our $VERSION = "v1.0.0";

use Modern::Perl 2018;
use List::Util qw(max);
use Scalar::Util qw(reftype);
use Carp;

use Role::Tiny::With;
with 'CInet::ManySAT::Base';

=head1 DESCRIPTION

C<CInet::ManySAT::Incremental> provides only a B<SAT solver>. Such a solver
receives a Boolean formula and determines whether it has a satisfying
assignment. In that case, it provides proof by exhibiting such an assignment,
called a I<witness>, that can be independently verified.

The solver is intended for I<incremental> usage, which means that cycles of
solving the formula, then adding more clauses, solving again, or evaluating
the same formula with many different assumptions, are cheap. The solver does
not have to be reinitialized after solving.

This class does the L<CInet::ManySAT::Base> role. See its documentation for
how to input formulas into the solver.

This package has no exports because incremental usage requires using the
object interface.

=cut

use CInet::ManySAT::Incremental::CaDiCaL;

=head2 Methods

In addition to implementing the C<add> and C<assume> methods required by
L<CInet::ManySAT::Base>, the following methods are provided:

=cut

sub _update_maxvar {
    my $self = shift;
    $self->{maxvar} = max($self->{maxvar}, map { abs } @_);
    $self
}

sub _finish_current {
    my $self = shift;
    if ($self->{last} != 0) {
        $self->{cadical}->add(0);
        $self->{last} = 0;
    }
    $self
}

sub add {
    my $self = shift;
    for (@_) {
        no warnings 'uninitialized';
        if (reftype($_) eq 'ARRAY') {
            $self->_finish_current;
            $self->_update_maxvar(@$_);
            $self->{cadical}->add($_) for @$_;
            $self->{cadical}->add(0) unless $_->[$_->$#*] == 0;
        }
        else {
            $self->_update_maxvar($_);
            $self->{cadical}->add($_);
            $self->{last} = $_;
        }
    }
    $self
}

# Push the assumptions to an internal arrayref. The point is that we need
# to include assumption variables when computing maxvar (which we need in
# order to retrieve the entire model from CaDiCaL), but if the maxvar comes
# from transient assumptions, we don't know how to reduce it afterwards.
#
# So maxvar needs to reflect only the clauses stored permanently in the
# solver and we take assumptions into account for maxvar temporarily right
# before solving, which is when we commit the stored assumptions to the
# solver as well.
sub assume {
    my $self = shift;
    push $self->{assump}->@*, @_;
    $self
}

=head3 new

    my $solver = CInet::ManySAT::Incremental->new;

Create a new instance of a SAT solver. Use C<read> and C<add> to fill it
with clauses.

=cut

sub new {
    my $class = shift;
    my $solver = CInet::ManySAT::Incremental::CaDiCaL->new;
    bless { cadical => $solver, maxvar => 0, last => 0 }, $class
}

=head3 solve

    my $res = $solver->solve;
    say "consistent" if $solver->solve($assump);

Invokes the SAT solver on the current formula and the current set of
assumptions. Additional assumptions can be optionally passed in an
argument arrayref.

This method returns C<1> when the formula is satisfiable, it returns
C<0> when it is unsatisfiable and C<undef> when the solver gave up or
was interrupted. All assumptions are cleared afterwards.

=cut

sub solve {
    no warnings 'uninitialized';
    my $self = shift;

    if (reftype($_[0]) eq 'ARRAY') {
        $self->assume(shift->@*);
    }

    my $vars = max($self->{maxvar}, map { abs } $self->{assump}->@*);
    $self->{cadical}->assume($_) for $self->{assump}->@*;
    $self->{assump} = [];
    $self->{vars} = $vars; # for ->model

    my $code = $self->{cadical}->solve;
    $code == 10 ? 1 :
        $code == 20 ? 0 :
            undef
}

=head3 model

    my $model = $solver->model
        if $solver->solve == 1;

Returns a satisfying assignment if the last run of L<solve> determined
that the formula was satisfiable. The witness is an arrayref of literals
in which the variables appear one after another negated or non-negated,
indicating whether they are false or true, respectively, in the assignment.

Calling this method under any circumstance B<other than> the last L<solve>
returning C<1> is an error and can cause an uncatchable abort from the
solver library internals. It is recommended to use the L<witness> method
instead of combining L<solve> and L<model>.

=cut

sub model {
    my $self = shift;
    my @witness;
    push @witness, $self->{cadical}->val($_) for 1 .. $self->{vars};
    \@witness
}

=head3 witness

    my $model = $solver->witness;
    say "consistent" if defined $solver->witness($assump);

This method combines L<solve> and L<model>. Additional assumptions to
the solver invocation can be passed in an arrayref.

If the formula is satisfiable, this method returns a witness for that.
If the formula is unsatisfiable, it returns C<undef>. If the solver
could not solve the problem, a (Perl) exception is raised that the
caller can catch.

=cut

sub witness {
    my $self = shift;
    my $sat = $self->solve(@_);

    not(defined $sat) ? die "cadical gave up" :
        not($sat) ? undef :
            $self->model
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

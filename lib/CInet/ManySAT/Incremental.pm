=encoding utf8

=head1 NAME

CInet::ManySAT::Incremental - An incremental SAT solver

=head1 SYNOPSIS

    my $solver = CInet::ManySAT::Incremental->new;
    $solver->read($cnf);   # add clauses to the solver
    say $solver->solve;    # result is 0, 1 or undef
    say $solver->model([-2]);  # add assumptions on the fly

=head2 VERSION

This document describes CInet::ManySAT::Incremental v1.0.0.

=cut

# ABSTRACT: An incremental SAT solver
package CInet::ManySAT::Incremental;

our $VERSION = "v1.0.0";

use Modern::Perl 2018;
use List::Util qw(max);
use Carp;

use Role::Tiny::With;
with 'CInet::ManySAT::Base';

=head1 DESCRIPTION

C<CInet::ManySAT::Incremental> provides only a B<SAT solver>. Such a solver
receives a Boolean formula and determines whether it has a satisfying
assignment. In that case, it provides proof by exhibiting such an assignment,
called a I<witness> or a I<model>, that can be independently verified.

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
        if (ref $_ eq 'ARRAY') {
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

Invokes the SAT solver on the current formula. Assumptions (that is a
partial assignment of the variables) can be optionally passed in an
argument arrayref.

This method returns C<1> when the formula is satisfiable, it returns
C<0> when it is unsatisfiable and C<undef> when the solver gave up or
was interrupted. All assumptions are cleared afterwards.

=cut

sub solve {
    my $self = shift;
    my $assump = ref $_[0] eq 'ARRAY' ? shift : [ ];

    my $vars = max($self->{maxvar}, map { abs } $assump->@*);
    $self->{cadical}->assume($_) for $assump->@*;
    $self->{vars} = $vars; # for ->model

    my $code = $self->{cadical}->solve;
    $code == 10 ? 1 :
        $code == 20 ? 0 :
            undef
}

=head3 model

    my $model = $solver->model;
    say "consistent" if $solver->model($assump);

If the formula is satisfiable, this method returns a witness for that.
The witness is an arrayref of literals in which all variables appear
one after another negated or non-negated, indicating whether they are
false or true, respectively, in the assignment.

If the formula is unsatisfiable, it returns C<undef>. If the solver
could not solve the problem, an exception is raised that the caller
can catch.

=cut

sub model {
    my $self = shift;
    my $sat = $self->solve(@_);

    not(defined $sat) ? die "cadical gave up" :
        not($sat) ? undef :
            [ map { $self->{cadical}->val($_) } 1 .. $self->{vars} ]
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

=encoding utf8

=head1 NAME

CInet::ManySAT::ClauseStorage - Storing clauses before calling external solvers

=head1 SYNOPSIS

    $solver->add(@extra_clauses);   # add more clauses to the solver
    $solver->assume(1, -2, 3);      # fix some variable values for next ->dimacs
    my $feed = $solver->dimacs;     # on the fly DIMACS CNF file generation

=cut

# ABSTRACT: Storing clauses before calling external solvers
package CInet::ManySAT::ClauseStorage;

use Modern::Perl 2018;
use List::Util qw(max);
use Scalar::Util qw(reftype);
use Carp;

use Role::Tiny;
use Role::Tiny::With;

with 'CInet::ManySAT::Base';

=head1 DESCRIPTION

C<CInet::ManySAT::ClauseStorage> is a role implements the L<CInet::ManySAT::Base>
interface by storing clauses in an internal arrayref. This is necessary for
wrapping solvers which are only available as external programs which need
to be fed a complete formula in the DIMACS CNF format upon startup.

This role implements the C<add> and C<assume> methods required by
L<CInet::ManySAT::Base> and provides another method on top.

=head2 Implementation of CInet::ManySAT::Base

=head3 add

    $solver->add(4, -2, 0);  # add clause C<2 ⇒ 4>
    $solver->add(1, -2);     # add clause C<2 ⇒ 1 ∨ 3>
    $solver->add(3, 0);

    $solver->add([1, -2]);   # add clause C<2 ⇒ 1>

Clauses are internally stored as an arrayref of arrayrefs in
C<< $self->{clauses} >>. The current clause under construction
is stored in C<< $self->{current} >>.

The field C<< $self->{maxvar} >> is used to maintain the highest
variable number seen in the clauses.

=cut

sub _finish_current {
    my $self = shift;

    my $cur = $self->{current};
    $self->{current} = [];

    if ($cur->$#* > 0) {
        push $self->{clauses}->@*, $cur;
        # Update maximal variable
        $self->{maxvar} = max(
            $self->{maxvar} // 0,
            map { abs } @$cur
        );
    }
    $self
}

sub add {
    my $self = shift;

    for (@_) {
        if (reftype($_) eq 'ARRAY') {
            $self->_finish_current;
            push $self->{clauses}->@*, $_;
        }
        else {
            push $self->{current}->@*, $_;
            $self->_finish_current if $_ == 0;
        }
    }
    $self
}

=head3 assume

    $solver->assume(2, -1);  # assume that 2 is true and 1 is false

Assumptions are stored as an arrayref at C<< $self->{assump} >>.

=cut

sub assume {
    my $self = shift;
    push $self->{assump}->@*, @_;
    $self
}

=head2 Provided methods

=head3 dimacs

    my $feed = $solver->dimacs;

Returns a coderef which lazily generates the lines of a DIMACS CNF file
representing the stored formula, that is the clauses and assumptions.
Call this code reference until it returns C<undef>.

Calling this method closes and adds the current clause to the formula and
clears the array of assumptions.

=cut

sub dimacs {
    my $self = shift;

    my $clauses = $self->_finish_current->{clauses};
    my $assump = $self->{assump};
    $self->{assump} = [];

    my $nvars = max($self->{maxvar} // 0, map { abs } @$assump);
    my $nclauses = @$clauses* + @$assump;
    my $init = 0;
    return sub {
        return "p cnf $nvars $nclauses" unless $init++;

        my $clause = $clauses->();
        return undef if not defined $clause;
        push $clause->@*, 0 unless $clause->[$clause->$#*] == 0;
        return join ' ', @$clause;
    };
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

=encoding utf8

=head1 NAME

CInet::ManySAT::Incremental::CaDiCaL - FFI bindings to libcadical

=head1 SYNOPSIS

    my $solver = CInet::ManySAT::Incremental::CaDiCaL->new;
    $solver->add($lit);  # $lit == 0 terminates a clause

    $solver->assume($lit);
    my $code = $solver->solve;  # 10 is SAT, 20 is UNSAT

    # Query the values of a satisfying assignment
    do { say $solver->val($_) for 1..$vars } if $code == 10;

=head1 DESCRIPTION

This module provides FFI bindings to the IPASIR interface of the
CaDiCaL SAT solver by Armin Biere.

=head2 Methods

=head3 new

    # solver_t* init(void);
    my $solver = CInet::ManySAT::Incremental::CaDiCaL->new;

Creates a new, empty solver instance.

=head3 DESTROY

    # void release(solver_t* solver);
    $solver = undef;

Frees the internal solver object when the Perl object goes out of scope.

=head3 add

    # void add(solver_t* solver, int lit);
    $solver->add($lit);

The formula is made up of clauses which are made up of literals. This function
adds a single literal to the "current clause". Adding the C<0> literal closes
the current clause and starts a new one. Closing the last clause before a
call to L<solve|/"solve"> is optional.

=head3 assume

    # void assume(solver_t* solver, int lit);
    $solver->assume($lit);

Assume that a literal holds for the next call to L<solve|/"solve">.

=head3 solve

    # int solve(solver_t* solver);
    my $code = $solver->solve;

Solves the SAT problem on the stored formula, with the given assumptions.
The assumptions are reset afterwards. The return code is:

=over

=item *

10 if the formula is satisfiable,

=item *

20 if the formula is unsatisfiable,

=item *

0 if the problem could not be solved for some reason.

=back

=head3 val

    # int val(solver_t* solver, int var);
    say $solver->val($var)

This function may only be called if the C<solve> function returned C<SAT>
and the solver's state was not otherwise modified afterwards. Given a
variable C<$var>, it returns C<$var> or C<-$var> depending on whether
the variable is true or false in the satisfiability witness found by
the solver.

=cut

# ABSTRACT: FFI bindings to libcadical
package CInet::ManySAT::Incremental::CaDiCaL;

use Modern::Perl 2018;
use Carp;

use FFI::Platypus;
use CInet::Alien::CaDiCaL;

my $ffi = FFI::Platypus->new(api => 1);
$ffi->lib(CInet::Alien::CaDiCaL->dynamic_libs);
$ffi->mangler(sub { 'ccadical_' . shift });

$ffi->type('object(CInet::ManySAT::Incremental::CaDiCaL)' => 'solver_t');

$ffi->attach(['init'    => 'new'    ] => [                 ] => 'solver_t');
$ffi->attach(['release' => 'DESTROY'] => ['solver_t'       ] => 'void');
$ffi->attach('add'                    => ['solver_t', 'int'] => 'void');
$ffi->attach('solve'                  => ['solver_t'       ] => 'int');
$ffi->attach('assume'                 => ['solver_t', 'int'] => 'void');
$ffi->attach('val'                    => ['solver_t', 'int'] => 'int');

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

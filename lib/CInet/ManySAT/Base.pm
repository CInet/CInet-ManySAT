=encoding utf8

=head1 NAME

CInet::ManySAT::Base - Common role for ManySAT solvers

=head1 SYNOPSIS

    $solver->read($cnf_file);       # read a DIMACS file or string
    $solver->add(@extra_clauses);   # add more clauses to the solver
    $solver->$action;               # implemented elsewhere
    $solver->$action([1, -2, 3]);   # pass assumptions

=cut

# ABSTRACT: Common role for ManySAT solvers
package CInet::ManySAT::Base;

use Modern::Perl 2018;
use Path::Tiny;
use Carp;

use Role::Tiny;

=head1 DESCRIPTION

C<CInet::ManySAT::Base> is a role that all ManySAT solvers implement
for common formula input. Use L<Role::Tiny::With> to compose it into
your class. All methods on solver objects which do not explicitly
query for data should return the invocant to enable method chaining.

The role requires one method to be implemented and provides one
method on top.

=head2 Required method

=head3 add

    $solver->add(4, -2, 0);  # add clause C<2 ⇒ 4>
    $solver->add(1, -2);     # add clause C<2 ⇒ 1 ∨ 3>
    $solver->add(3, 0);

    $solver->add([1, -2]);   # add clause C<2 ⇒ 1>

Adds literals to the current clause or clauses to the formula.
Two types of input are accepted, which can be freely mixed in C<@_>:

=over

=item *

Non-zero integers denote literals (a variable number and a sign) which
are pushed onto the current clause. A zero integer terminates the current
clause, pushes it onto the formula and starts a new current clause.

=item *

An arrayref of integers is treated like an entire clause. The current clause
of the formula is closed and pushed, then the given clause is pushed.
Terminating the arrayref with a zero literal is not required but allowed.

=back

=cut

requires qw(add);

=head2 Provided methods

=head3 read

    $solver->read(\@clauses);
    $solver->read($dimacs);
    $solver->read($path);

Read some representation of a CNF formula and L<add> it to the solver.
The following representations are understood:

=over

=item *

An arrayref is assumed to contain the clauses. Clauses can either be
L<add>-compatible arrayrefs or they are assumed to be strings in the
DIMACS CNF format containing literals.

=item *

A coderef is called repeatedly until C<undef> is returned and the
return values are treated just like the items in the arrayref case.

=item *

Otherwise the argument is stringified. If it points to an existing
file, that file is read as a DIMACS CNF file. If all else fails,
it is assumed that the string itself is the contents of a DIMACS CNF
file.

=back

=cut

sub read {
    my ($self, $cnf) = @_;
    my $reader = _read_cnf($cnf);
    while (defined(my $clause = $reader->())) {
        $self->add($clause);
    }
    $self
}

sub _read_type {
    my $cnf = shift;

    if (ref $cnf eq 'ARRAY') {
        return 'ARRAY';
    }
    elsif (ref $cnf eq 'CODE') {
        return 'CODE';
    }
    elsif (path($cnf)->is_file) {
        return 'FILE';
    }
    else {
        return 'DATA';
    }
}

sub _read_cnf {
    my $cnf = shift;
    my $type = _read_type($cnf);

    if ($type eq 'ARRAY') {
        my $i = 0;
        return sub {
            return undef if $i > $cnf->$#*;
            return _read_clause($cnf->[$i++]);
        };
    }
    elsif ($type eq 'CODE') {
        return sub {
            my $clause = $cnf->();
            return undef if not defined $clause;
            return _read_clause($clause);
        };
    }
    elsif ($type eq 'FILE') {
        my $fh = path($cnf)->openr_raw;
        return sub {
            if (eof $fh) {
                close $fh;
                return undef;
            }
            my $line = readline $fh;
            chomp $line;
            goto __SUB__ if not length($line) or $line =~ /^[pc]/;
            return _read_clause($line);
        };
    }
    else {
        my @lines = split /\n/, $cnf;
        return sub {
            return undef if not @lines;
            my $line = shift @lines;
            goto __SUB__ if not length($line) or $line =~ /^[pc]/;
            return _read_clause($line);
        }
    }
}

sub _read_clause {
    my $clause = shift;
    return $clause if ref $clause eq 'ARRAY';
    return [split / /, $clause];
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"

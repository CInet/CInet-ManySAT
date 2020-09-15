# This test computes the orientable 4-gaussoids in three different ways:
#
#   1. It enumerates the system orientable4.cnf with axioms found
#      by Lnenicka and Matus.
#   2. It enumerates oriented4.cnf and projects to their supports.
#   3. It enumerates gaussoid4 and uses the incremental solver to
#      check consistency of each gaussoid with the orientation
#      formula.
#
# The results must all be the same and their number must be 629.

use strict;
use warnings;
use autodie;

use Test::More;
use Test::Deep;

use Path::Tiny;
use List::Util qw(uniqstr);
use CInet::ManySAT qw(sat_all);
use CInet::ManySAT::Incremental;

sub to_string {
    join '', map { $_ > 0 ? '0' : '1' } shift->@*
}

# The oriented4.cnf formula was adapted from https://gaussoids.de. The original
# encoding of the formula for oriented gaussoids on n=4 does not allow projection
# to orientable gaussoids. The encoding has been changed to
#
#   a_{ij|K} = 0  <==> V_{ij|K} = 1 and V_{ij|K}' = 1
#   a_{ij|K} = +  <==> V_{ij|K} = 0 and V_{ij|K}' = 1
#   a_{ij|K} = -  <==> V_{ij|K} = 0 and V_{ij|K}' = 0
#
# which allows testing for orientability of any given gaussoids by projecting
# to V_{ij|K}. The numbering of the variables is the same.
#
# Each a_{ij|K} variable gets two variables V_{ij|K} and V_{ij|K}'. Since the
# original a-variables are 1-based contiguous numbers, we use 2*$_-1 and 2*$_
# as V-variables. The following functions handle the conversion between the
# two variable systems. There is also a twist in the truth value of variables
# in the files, where a false literal means containment...

# Project a solution in V-variables to something that to_string()ifies
# correctly to the support in a-variables.
sub project {
    [ map { -$_ } grep { abs($_) % 2 == 1 } shift->@* ]
}

# Lift an object in a-variables to a partial assignment of V-variables.
sub lift {
    [ map { $_ > 0 ? -(2*$_-1) : 2*(-$_)-1 } shift->@* ]
}

# 1. Known axioms.
my @O1 = sort map { to_string($_) }
    sat_all(path('t', 'orientable4.cnf'))->list;
is 0+ @O1, 629, 'method 1 has 629 solutions';

# 2. Projection of oriented gaussoids.
my @O2 = uniqstr sort map { to_string($_) }
    map { project($_) }
    sat_all(path('t', 'oriented4.cnf'))->list;
is 0+ @O2, 629, 'method 2 has 629 solutions';

# 3. Orientability test over all gaussoids.
my $orient = CInet::ManySAT::Incremental->new->read(path('t', 'oriented4.cnf'));
my @O3 = sort map { to_string($_) }
    grep { $orient->model(lift($_)) }
    sat_all(path('t', 'gaussoid4.cnf'))->list;
is 0+ @O3, 629, 'method 3 has 629 solutions';

cmp_deeply \@O1, \@O2, 'results of method 1 and method 2 coincide';
cmp_deeply \@O1, \@O3, 'results of method 1 and method 3 coincide';
cmp_deeply \@O2, \@O3, 'results of method 2 and method 3 coincide';

done_testing;

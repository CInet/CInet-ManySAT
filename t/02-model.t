use strict;
use warnings;
use autodie;

use Test::More;
use Path::Tiny;
use CInet::ManySAT qw(sat_model);
use CInet::ManySAT::Incremental;

# AIM test set by Kazuo Iwama, Eiji Miyano and Yuichi Asahiro,
# found through https://www.cs.ubc.ca/~hoos/SATLIB/benchm.html

my $aim = path('t', 'aim');
for my $cnf ($aim->children(qr/cnf$/)) {
    my $expected = !!($cnf =~ /yes/);

    is(defined(sat_model $cnf), $expected, "$cnf ok");
    my $incr = CInet::ManySAT::Incremental->new->read($cnf);
    is(defined($incr->model), $expected, "$cnf ok (incremental)");
}

done_testing;

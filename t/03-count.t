use strict;
use warnings;
use autodie;

use Test::More;
use Path::Tiny;
use CInet::ManySAT qw(sat_count);

my %COUNT = (
    'gaussoid4.cnf'   => 679,
    'orientable4.cnf' => 629,
    'oriented4.cnf'   => 34873,
    'markov4.cnf'     => 64,
    'markov5.cnf'     => 1024,
    'LUBF5.cnf'       => 1166,
    'UBF5.cnf'        => 206,
    'LUB5.cnf'        => 0,
);

for (sort keys %COUNT) {
    my $cnf = path('t', $_);
    is(sat_count($cnf), $COUNT{$_}, "$cnf ok");
    is(sat_count($cnf, risk => 0.01), $COUNT{$_}, "$cnf ok (risky)");
}

done_testing;

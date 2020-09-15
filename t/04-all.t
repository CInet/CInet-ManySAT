use strict;
use warnings;
use autodie;

use Test::More;
use Test::Deep;

use Path::Tiny;
use CInet::ManySAT qw(sat_all);

sub to_string {
    join '', map { $_ > 0 ? '0' : '1' } shift->@*
}

my %COUNT = (
    'gaussoid4.cnf'   => 679,
    'orientable4.cnf' => 629,
    'oriented4.cnf'   => 34873,
    'markov4.cnf'     => 64,
    'markov5.cnf'     => 1024,
    'LUBF5.cnf'       => 1166,
    'UBF5.cnf'        => 206,
);

for (sort keys %COUNT) {
    my $cnf = path('t', $_);
    is scalar(sat_all($cnf)->list), $COUNT{$_}, "$cnf ok";
}

# Markov networks are orientable (because they are realizable).
my $markov = CInet::ManySAT->new->read(path('t', 'markov4.cnf'));
$markov->read(path('t', 'orientable4.cnf'));
is scalar($markov->all->list), $COUNT{'markov4.cnf'}, 'markov is already orientable';

# LUBF intersected with EUBF (Markov) is just UBF.
my $ubf = CInet::ManySAT->new->read(path('t', 'LUBF5.cnf'))->read(path('t', 'markov5.cnf'));
my @UBF1 = sort map { to_string($_) } $ubf->all->list;
my @UBF2 = sort map { to_string($_) } sat_all(path('t', 'UBF5.cnf'))->list;
cmp_deeply \@UBF1, \@UBF2, 'LUBF and EUBF = UBF';

done_testing;

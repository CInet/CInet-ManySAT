use strict;
use warnings;
use autodie;

use Test::More;
use Path::Tiny;
use CInet::ManySAT;

is CInet::ManySAT::_read_type([ [-1, 2], ]), 'ARRAY', 'clauses';
is CInet::ManySAT::_read_type([ path('t', 'markov5.cnf')->lines_raw ]), 'ARRAY', 'clauses';
is CInet::ManySAT::_read_type(sub{ }), 'CODE', 'generator';
is CInet::ManySAT::_read_type(path('t', 'markov5.cnf')), 'FILE', 'existing file';
is CInet::ManySAT::_read_type(path('t', 'foobar.cnf')), 'DATA', 'string (unfortunately)';
is CInet::ManySAT::_read_type(path('t', 'markov5.cnf')->slurp_raw), 'DATA', 'string';

done_testing;

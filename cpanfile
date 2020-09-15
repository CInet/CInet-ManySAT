requires 'Modern::Perl', '>= 1.20180000';
requires 'Carp';
requires 'List::Util';
requires 'Path::Tiny';

requires 'FFI::Platypus';
requires 'IPC::Run';
requires 'IPC::Open3';
requires 'IO::Null';

requires 'Role::Tiny';

requires 'CInet::Alien::CaDiCaL';
requires 'CInet::Alien::DSHARP';
requires 'CInet::Alien::GANAK';
requires 'CInet::Alien::MiniSAT::All';

on 'test' => sub {
    requires 'Test::More';
};

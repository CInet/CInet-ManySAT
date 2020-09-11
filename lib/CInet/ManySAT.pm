package CInet::ManySAT;

use Modern::Perl 2018;
use Import::Into;

sub import {
    #CInet::ManySAT::Solve -> import::into(1);
    CInet::ManySAT::Count -> import::into(1);
    #CInet::ManySAT::All   -> import::into(1);
}

":wq"

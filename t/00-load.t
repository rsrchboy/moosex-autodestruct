#!/usr/bin/env perl

use Test::More tests => 1;

BEGIN {
    use_ok( 'MooseX::AutoDestruct' );
}

diag("Testing MooseX::AutoDestruct $MooseX::AutoDestruct::VERSION, Perl $], $^X");
diag('Moose version: ' . Moose->VERSION);

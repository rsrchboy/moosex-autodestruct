#!/usr/bin/perl

=head1 DESCRIPTION

This test exercises some basic attribute functionality, to make sure things
are working "as advertized" with the AutoDestruct trait.

=cut

use strict;
use warnings;

use Test::More;
use Test::Moose;

{
    package TestClass;
    use Moose;
    use MooseX::AutoDestruct;

    has one => (is => 'ro', isa => 'Str');

    has two => (
        traits => ['AutoDestruct'],
        #is => 'rw', lazy_build => 1, ttl => 10,
        is => 'rw', predicate => 'has_two', ttl => 5, clearer => 'clear_two',
    );
}

my $tc = TestClass->new;

isa_ok $tc, 'TestClass';
meta_ok $tc;

has_attribute_ok $tc, 'one';
has_attribute_ok $tc, 'two';

# basic autodestruct checking
ok !$tc->has_two, 'no value for two yet';
$tc->two('w00t');
ok $tc->has_two, 'two has value';
is $tc->two, 'w00t', 'two value set correctly';
diag 'sleeping';
sleep 8;
ok !$tc->has_two, 'no value for two (autodestruct)';

# check our generated clearer
$tc->two('w00t');
ok $tc->has_two, 'two has value';
is $tc->two, 'w00t', 'two value set correctly';
$tc->clear_two;
ok !$tc->has_two, 'no value for two (clearer method)';

done_testing;

__END__

=head1 AUTHOR

Chris Weyl  <cweyl@alumni.drew.edu>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Chris Weyl <cweyl@alumni.drew.edu>

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the

     Free Software Foundation, Inc.
     59 Temple Place, Suite 330
     Boston, MA  02111-1307  USA

=cut



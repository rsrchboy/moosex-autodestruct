#!/usr/bin/perl

=head1 DESCRIPTION

This test exercises some basic attribute functionality, to make sure things
are working "as advertized" with the AutoDestruct trait.

Note that we're directly accessing the attribute values here via the
metaclass, bypassing any installed accessors.

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
        is => 'rw', predicate => 'has_two', ttl => 5,
    );

}

my $tc = TestClass->new;

isa_ok $tc, 'TestClass';
meta_ok $tc;

has_attribute_ok $tc, 'one';
has_attribute_ok $tc, 'two';

my $two = $tc->meta->get_attribute('two');

isa_ok $two => 'Moose::Meta::Attribute', 'two isan attribute metaclass';

# some basic attribute tests
has_attribute_ok $two, 'ttl';
ok $two->has_ttl, 'two has a ttl';
is $two->ttl => 5, 'ttl value is correct';

# check with our instance
ok !$two->has_value($tc), 'two has no value yet';
$two->set_value($tc => 'w00t');
is $two->get_value($tc), 'w00t', 'two set correctly';
diag 'sleeping';
sleep 8;
ok !$two->has_value($tc), 'no value for two (autodestruct)';


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



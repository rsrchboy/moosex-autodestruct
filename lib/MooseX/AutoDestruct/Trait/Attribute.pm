package MooseX::AutoDestruct::Trait::Attribute;

# ABSTRACT: Clear your attributes after a certain time

use Moose::Role;
use namespace::autoclean;

# debugging
#use Smart::Comments '###', '####';

use MooseX::AutoDestruct ();

my $trait = MooseX::AutoDestruct->implementation() . '::Trait::Attribute';

with $trait;

!!42;

__END__

=head1 DESCRIPTION

Attribute trait for L<MooseX::AutoDestruct>.  This trait will compose itself
with an appropriate version-specific role depending on the version of L<Moose>
you're using.

=head1 SEE ALSO

L<MooseX:AutoDestruct>.

=cut

package MooseX::AutoDestruct;

# ABSTRACT: Clear your attributes after a certain time

use warnings;
use strict;

use namespace::autoclean;

use Moose ();
use Moose::Exporter;

my $implementation;

{
    my $moose_version = Moose->VERSION;
    $implementation
        = $moose_version < 1.99
        ? 'MooseX::AutoDestruct::V1'
        : 'MooseX::AutoDestruct::V2'
        ;

    ($moose_version > 2.99) && warn
        "This is Moose $moose_version, but I only know how to deal with 2.x at most!\n",
        "We're going to try using the v2 AutoDestruct traits, but YMMV.\n",
        ;

    sub implementation { $implementation }
}

Moose::Exporter->setup_import_methods(
    trait_aliases => [
        [ "${implementation}::Trait::Attribute" => 'AutoDestruct' ],
    ],
);

# debugging
#use Smart::Comments '###', '####';

{
    package Moose::Meta::Attribute::Custom::Trait::AutoDestruct;
    sub register_implementation { "${implementation}::Trait::Attribute" }
}

!!42;

__END__

=for Pod::Coverage implementation

=head1 SYNOPSIS

    package Foo;

    use Moose;
    use namespace::autoclean;
    use MooseX::AutoDestruct;

    has foo => (
        traits     => [ AutoDestruct ],
        is         => 'ro',
        isa        => 'Str',
        lazy_build => 1,
        ttl        => 600, # time, in seconds
    );

    sub _build_foo { --some expensive operation-- }

=head1 DESCRIPTION

MooseX::AutoDestruct is an attribute metaclass trait that causes your
attribute value to be cleared after a certain time from when the value has
been set.

This trait will work regardless of how the value is populated or if a clearer
method has been installed; or if the value is accessed via the installed
accessors or by accessing the attribute metaclass itself.

=head1 TRAITS APPLIED

No traits are automatically applied to any metaclasses; however, on use'ing
this package an 'AutoDestruct' attribute trait becomes available.

Moose will properly deduce what trait you're talking about if you pass
AutoDestruct as a string -- e.g.:

    has foo => (traits => [ 'AutoDestruct' ], ...)

However, this is depreciated in favor of the exported trait alias:

    has foo => (traits => [ AutoDestruct ], ...)

=head1 USAGE

Apply the AutoDestruct trait to your attribute metaclass (e.g. "traits =>
[AutoDestruct]") and supply a ttl value.

Typical usage of this could be for an attribute to store a value that is
expensive to calculate, and can be counted on to be valid for a certain amount
of time (e.g. caching).  Builders are your friends :)

=head1 SEE ALSO

L<Moose>.

=head1 BUGS

Please report any bugs or feature requests to
C<bug-moosex-autodestruct at rt.cpan.org>, or through
the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MooseX-AutoDestruct>.

=cut

package MooseX::AutoDestruct;

use warnings;
use strict;

use namespace::autoclean;

# debugging
#use Smart::Comments '###', '####';

our $VERSION = '0.006';

=head1 NAME

MooseX::AutoDestruct - Clear your attributes after a certain time

=head1 SYNOPSIS

    package Foo;

    use Moose;
    use namespace::autoclean;
    use MooseX::AutoDestruct;

    has foo => (
        traits => ['AutoDestruct'],
        is => 'ro', isa => 'Str', lazy_build => 1,
        ttl => 600, # time, in seconds
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

=head1 USAGE

Apply the AutoDestruct trait to your attribute metaclass (e.g. "traits =>
['AutoDestruct']") and supply a ttl value.

Typical usage of this could be for an attribute to store a value that is
expensive to calculate, and can be counted on to be valid for a certain amount
of time (e.g. caching).  Builders are your friends :)

=cut

{
    package Moose::Meta::Attribute::Custom::Trait::AutoDestruct;

    our $VERSION = '0.006';

    require Moose;

    my $moose_version = Moose->VERSION;
    my $implementation
        = $moose_version < 1.99
        ? 'MooseX::AutoDestruct::V1Traits::Attribute'
        : 'MooseX::AutoDestruct::V2Traits::Attribute'
        ;
    require MooseX::AutoDestruct::V1Traits if $moose_version < 1.99;

    ($moose_version > 2.99) && warn
        "This is Moose $moose_version, but I only know how to deal with 2.x at most!\n",
        "We're going to try using the v2 AutoDestruct traits, but YMMV.\n",
        ;

    sub register_implementation { $implementation }
}
{
    package MooseX::AutoDestruct::Trait::Attribute;
    use Moose::Role;
    use namespace::autoclean;
    our $VERSION = '0.006';
}
{
    package MooseX::AutoDestruct::Trait::Method::Accessor;
    use Moose::Role;
    use namespace::autoclean;
    our $VERSION = '0.006';
}
{
    package MooseX::AutoDestruct::V2Traits::Attribute;
    use Moose::Role;
    use namespace::autoclean;
    with 'MooseX::AutoDestruct::Trait::Attribute';

    our $VERSION = '0.006';

    has ttl => (is => 'ro', isa => 'Int', required => 1, predicate => 'has_ttl');

    # generate / store our metaclass
    has _accessor_metaclass => (is => 'rw', isa => 'Str', predicate => '_has_accessor_metaclass');

    around accessor_metaclass => sub {
        my ($orig, $self) = (shift, shift);

        return $self->_accessor_metaclass if $self->_has_accessor_metaclass;

        # get our base metaclass...
        my $base_class = $self->$orig();

        # ...and apply our trait to it
        ### superclasses: $base_class->meta->name
        my $new_class_meta = Moose::Meta::Class->create_anon_class(
            superclasses => [ $base_class->meta->name ],
            roles => [ 'MooseX::AutoDestruct::Trait::Method::Accessor' ],
            cache => 1,
        );

        ### new accessor class: $new_class_meta->name
        $self->_accessor_metaclass($new_class_meta->name);
        return $new_class_meta->name;
    };

    has value_slot => (is => 'ro', isa => 'Str', lazy_build => 1, init_arg => undef);
    has destruct_at_slot => (is => 'ro', isa => 'Str', lazy_build => 1, init_arg => undef);

    sub _build_value_slot       { shift->name }
    sub _build_destruct_at_slot { shift->name . '__DESTRUCT_AT__' }

    around slots => sub {
        my ($orig, $self) = (shift, shift);

        my $base = $self->$orig();
        return ($self->$orig(), $self->destruct_at_slot);
    };

    sub set_doomsday {
        my ($self, $instance) = @_;

        # ...

        # set our destruct_at slot
        my $doomsday = $self->ttl + time;

        ### doomsday set to: $doomsday
        ### time() is: time()
        $self
            ->associated_class
            ->get_meta_instance
            ->set_slot_value($instance, $self->destruct_at_slot, $doomsday)
            ;

        return;
    }

    sub has_doomsday {
        my ($self, $instance) = @_;

        return $self
            ->associated_class
            ->get_meta_instance
            ->is_slot_initialized($instance, $self->destruct_at_slot)
            ;
    }

    # return true if this value has expired
    sub doomsday {
        my ($self, $instance) = @_;

        my $doomsday = $self
            ->associated_class
            ->get_meta_instance
            ->get_slot_value($instance, $self->destruct_at_slot)
            ;
        $doomsday ||= 0;

        ### $doomsday
        ### time > $doomsday: time > $doomsday
        return time > $doomsday;
    }

    sub avert_doomsday {
        my ($self, $instance) = @_;

        ### in avert_doomsday()...
        $self
            ->associated_class
            ->get_meta_instance
            ->deinitialize_slot($instance, $self->destruct_at_slot)
            ;

        return;
    }

    after set_initial_value => sub { shift->set_doomsday(shift) };
    after set_value         => sub { shift->set_doomsday(shift) };
    after clear_value       => sub { shift->avert_doomsday(shift) };

    before get_value => sub { shift->enforce_doomsday(@_) };
    before has_value => sub { shift->enforce_doomsday(@_) };

    sub enforce_doomsday {
        my ($self, $instance, $for_trigger) = @_;

        # if we're not set yet...
        $self->clear_value($instance) if $self->doomsday($instance);
        return;
    }

    # FIXME do we need this?
    after get_value => sub {
        my ($self, $instance, $for_trigger) = @_;

        $self->set_doomsday unless $self->has_doomsday($instance);
    };

    around _inline_clear_value => sub {
        my ($orig, $self) = (shift, shift);
        my ($instance) = @_;

        my $mi = $self->associated_class->get_meta_instance;

        return $self->$orig(@_)
            . $mi->inline_deinitialize_slot($instance, $self->destruct_at_slot)
            . ';'
            ;
    };

    sub _inline_destruct {
        my $self = shift;
        my ($instance) = @_;

        my $slot_exists = $self->_inline_instance_has(@_);
        my $destruct_at_slot_value = $self
            ->associated_class
            ->get_meta_instance
            ->inline_get_slot_value('$_[0]', $self->destruct_at_slot)
            ;

        my $clear_attribute;
        if ($self->has_clearer) {

            # if we have a clearer method, we should call that -- it may have
            # been wrapped in the class

            my $clearer = $self->clearer;
            ($clearer) = keys %$clearer if ref $clearer;

            $clear_attribute = '$_[0]->' . $clearer . '()';
        }
        else {
            # otherwise, just deinit all the slots we use
            $clear_attribute = $self->_inline_clear_value(@_);
        }

        return " if ($slot_exists && time() > $destruct_at_slot_value) { $clear_attribute } ";
    }

    my $destruct_wrapper = sub {
        my $self = shift;
        return ($self->_inline_destruct(@_), super);
    };

    override _inline_has_value => $destruct_wrapper;
    override _inline_get_value => $destruct_wrapper;

    sub _inline_set_doomsday {
        my ($self, $instance) = @_;
        my $mi = $self->associated_class->get_meta_instance;

        my $code = $mi->inline_set_slot_value(
            $instance,
            $self->destruct_at_slot,
            'time() + ' . $self->ttl,
        );

        return "$code;\n";
    }

    override _inline_instance_set => sub {
        my $self = shift;
        return 'do { ' . $self->_inline_set_doomsday(@_) . ';' . super . ' }';
    };
}
{
    package MooseX::AutoDestruct::V2Traits::Method::Accessor;
    use Moose::Role;
    use namespace::autoclean;
    with 'MooseX::AutoDestruct::Trait::Method::Accessor';

    our $VERSION = '0.006';
}

=head1 SEE ALSO

L<Class::MOP>, L<Moose>.

=head1 AUTHOR

Chris Weyl, C<< <cweyl at alumni.drew.edu> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-moosex-autodestruct at rt.cpan.org>, or through
the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MooseX-AutoDestruct>.

=head1 TODO

Additional testing is required!

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MooseX::AutoDestruct


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MooseX-AutoDestruct>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MooseX-AutoDestruct>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MooseX-AutoDestruct>

=item * Search CPAN

L<http://search.cpan.org/dist/MooseX-AutoDestruct/>

=back

=head1 COPYRIGHT & LICENSE

Copyright (c) 2011, Chris Weyl C<< <cweyl@alumni.drew.edu> >>.

This library is free software; you can redistribute it and/or modify it under
the terms of the GNU Lesser General Public License as published by the Free
Software Foundation; either version 2.1 of the License, or (at your option)
any later version.

This library is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
OR A PARTICULAR PURPOSE.

See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this library; if not, write to the

    Free Software Foundation, Inc.,
    59 Temple Place, Suite 330,
    Boston, MA  02111-1307 USA

=cut

1; # End of MooseX::AutoDestruct

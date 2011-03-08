package MooseX::AutoDestruct::V1Traits;

use warnings;
use strict;

use namespace::autoclean;

# debugging
#use Smart::Comments '###', '####';

our $VERSION = '0.005';

=head1 NAME

MooseX::AutoDestruct::V1Traits - Moose 1.x autodestruct traits

=head1 DESCRIPTION

This package provides the traits needed for MooseX::AutoDestruct to work
with Moose v1.  Nothing to see here, no user-serviceable parts inside.

=cut

{
    package MooseX::AutoDestruct::V1Traits::Attribute;
    use Moose::Role;
    use namespace::autoclean;
    with 'MooseX::AutoDestruct::Trait::Attribute';

    our $VERSION = '0.005';

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
            roles => [ 'MooseX::AutoDestruct::V1Traits::Method::Accessor' ],
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

}
{
    package MooseX::AutoDestruct::V1Traits::Method::Accessor;
    use Moose::Role;
    use namespace::autoclean;
    with 'MooseX::AutoDestruct::Trait::Method::Accessor';

    our $VERSION = '0.005';

    # debug!
    #before _eval_closure => sub { print "$_[2]\n" };

    override _inline_pre_body => sub {
        my ($self, $instance) = @_;
        my $attr          = $self->associated_attribute;
        my $attr_name     = $attr->name;
        my $mi            = $attr->associated_class->instance_metaclass;

        my $code = super();
        my $type = $self->accessor_type;

        return $code
            unless $type eq 'accessor' || $type eq 'reader' || $type eq 'predicate';

        my $slot_exists = $self->_inline_has('$_[0]');

        $code .= "\n    if ($slot_exists && time() > "
            . $mi->inline_get_slot_value('$_[0]', $attr->destruct_at_slot)
            . ") {\n"
            ;

        if ($attr->has_clearer) {

            # if we have a clearer method, we should call that -- it may have
            # been wrapped in the class

            my $clearer = $attr->clearer;
            ($clearer) = keys %$clearer if ref $clearer;

            $code .= '$_[0]->' . $clearer . '()';

        }
        else {

            # otherwise, just deinit all the slots we use
            $code .= '    ' .$mi->inline_deinitialize_slot('$_[0]', $_) . ";\n"
                for $attr->slots;
        }

        $code .= "}\n";

        return $code;
    };

    override _generate_predicate_method_inline => sub {
        my $self          = shift;
        my $attr          = $self->associated_attribute;
        my $attr_name     = $attr->name;
        my $meta_instance = $attr->associated_class->instance_metaclass;

        my ( $code, $e ) = $self->_eval_closure(
            {},
           'sub {'
           . $self->_inline_pre_body(@_)
           . $meta_instance->inline_is_slot_initialized('$_[0]', $attr->value_slot)
           . $self->_inline_post_body(@_)
           . '}'
        );
        confess "Could not generate inline predicate because : $e" if $e;

        return $code;
    };

    override _generate_clearer_method_inline => sub {
        my $self      = shift;
        my $attr      = $self->associated_attribute;
        my $attr_name = $attr->name;
        my $mi        = $attr->associated_class->instance_metaclass;

        my $deinit;
        $deinit .= $mi->inline_deinitialize_slot('$_[0]', $_) . ';'
            for $attr->slots;

        my ( $code, $e ) = $self->_eval_closure(
            {},
           'sub {'
           . $self->_inline_pre_body(@_)
           . $deinit
           . $self->_inline_post_body(@_)
           . '}'
        );
        confess "Could not generate inline clearer because : $e" if $e;

        return $code;
    };

    # we need to override/wrap _inline_store() so we can deal with there being
    # two valid slots here that mean two different things: the value and when
    # it autodestructs.

    override _inline_store => sub {
        my ($self, $instance, $value) = @_;
        my $attr = $self->associated_attribute;
        my $mi   = $attr->associated_class->get_meta_instance;

        my $code = $mi->inline_set_slot_value($instance, $attr->value_slot, $value);
        $code   .= ";\n    ";
        $code   .= $self->_inline_set_doomsday($instance);
        $code   .= $mi->inline_weaken_slot_value($instance, $attr->value_slot, $value)
            if $attr->is_weak_ref;

        return $code;
    };

    sub _inline_set_doomsday {
        my ($self, $instance) = @_;
        my $attr = $self->associated_attribute;
        my $mi   = $attr->associated_class->get_meta_instance;

        my $code = $mi->inline_set_slot_value(
            $instance,
            $attr->destruct_at_slot,
            'time() + ' . $attr->ttl,
        );

        return "$code;\n";
    }

}

=head1 SEE ALSO

L<MooseX:AutoDestruct>, L<Moose>.

=head1 AUTHOR

Chris Weyl, C<< <cweyl at alumni.drew.edu> >>

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

1;

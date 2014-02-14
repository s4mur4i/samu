package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;

BEGIN { extends 'SamuRest::ControllerX::REST'; }

=head1 NAME

SamuRest::Controller::Vmware - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub vmwareBase : Chained('/'): PathPart('vmware'): CaptureArgs(0) {
    my ($self, $c) = @_;
    my $user_id = $c->session->{__user};
    return $self->__error($c, "You're not login yet.") unless $user_id;
}

sub test : Chained('vmwareBase') :PathPart('') :Args(0) :ActionClass('REST') {}

sub test_GET {
    my ($self, $c) = @_;

    return $self->__ok($c, { something => "ok" });
}

=head1 AUTHOR

s4mur4i,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

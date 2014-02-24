package SamuRest::Controller::Bugzilla;
use Moose;
use namespace::autoclean;

BEGIN { extends 'SamuRest::ControllerX::REST'; }

=head1 NAME

SamuRest::Controller::Bugzilla - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub bugzillaBase : Chained('/'): PathPart('bugzilla'): CaptureArgs(0) {
        my ($self, $c) = @_;
}

sub test : Chained('bugzillaBase') :PathPart('') :Args(0) :ActionClass('REST') {}

sub test_GET {
    my ($self, $c) = @_;
    return $self->__ok($c, { something => "ok" });
}

=head1 AUTHOR

Krisztian Banhidy,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

package SamuRest::Controller::Kayako;
use Moose;
use namespace::autoclean;

BEGIN { extends 'SamuRest::ControllerX::REST'; }

=head1 NAME

SamuRest::Controller::Kayako - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub kayakoBase : Chained('/'): PathPart('kayako'): CaptureArgs(0) {
        my ($self, $c) = @_;
}

sub test : Chained('kayakoBase') :PathPart('') :Args(0) :ActionClass('REST') {}

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

package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
        default => 'application/json',
        maps => {
                'application/json'   => 'JSON',
                'text/x-json'        => 'JSON',
        }
);


=head1 NAME

SamuRest::Controller::Vmware - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

#sub index :Path :Args(0) {
#    my ( $self, $c ) = @_;
#
#    $c->response->body('Matched SamuRest::Controller::Vmware in Vmware.');
#}

sub vmwareBase : Chained('/'): PathPart('vmware'): CaptureArgs(0) {
    my ($self, $c) = @_;

}



=head1 AUTHOR

s4mur4i,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

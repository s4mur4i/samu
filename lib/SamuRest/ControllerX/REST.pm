package SamuRest::ControllerX::REST;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    maps => {
        'application/json'   => 'JSON',
        'text/x-json'        => 'JSON',
    }
);

sub __ok {
    my ($self, $c, $data) = @_;

    $self->status_ok(
        $c,
        entity => {
            result => 'success',
            %$data
        },
   );
    $c->detach;
}

sub __error {
    my ($self, $c, $error) = @_;

    $self->status_ok(
        $c,
        entity => {
            result => 'error',
            message => $error,
        },
   );
    $c->detach;
}

sub __bad_request {
    my ($self, $c, $error) = @_;

    $self->status_bad_request(
      $c,
      message => $error
    );
    $c->detach;
}

sub __has_session {
    my ($self, $c) = @_;
    my $user_id = $c->session->{__user};
    return $self->__error($c, "You're not login yet.") unless $user_id;
}
1;

=head1 NAME

SamuRest::ControllerX::REST - extends Catalyst::Controller::REST with custom functions

=head1 DESCRIPTION

...

=head1 METHODS

=cut

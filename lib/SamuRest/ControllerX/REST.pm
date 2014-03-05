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

sub __is_logined {
    my ($self, $c) = @_;
    my $user_id = $c->session->{__user};
    return $self->__error($c, "You're not login yet.") unless $user_id;
    return $user_id;
}

sub __is_admin {
    my ($self, $c) = @_;
    my $user_id = $self->__is_logined($c);

    my $cnt = $c->model('Database::UserRole')->count({ user_id => $user_id, role_id => 1 }); # 1 is admin, hardcode for now
    return $self->__error($c, "Permission Denied.") unless $cnt;

    return $user_id;
}

sub __is_admin_or_owner {
    my ($self, $c, $owner_id) = @_;

    my $user_id = $c->session->{__user};
    return $self->__error($c, "Permission Denied.") unless $user_id;
    return $user_id if $owner_id == $user_id;
    return $user_id if $c->model('Database::UserRole')->count({ user_id => $user_id, role_id => 1 }); # 1 is admin, hardcode for now
    return $self->__error($c, "Permission Denied.");
}

sub __exception_to_json {
    my ($self, $c,$ex ) = @_;
    my %return=();
    if ( $ex->isa('ExBase')) {
        for my $key ( keys %$ex ) {
            if ( $key eq "trace" ) {
                next;
            }
            $return{$key} = $ex->{$key};
        }
    } else {
# Handle Fucking VMware exceptions
        for my $key ( keys %$ex ) {
            $return{fault_string} = $ex->{fault_string};
            $return{name} = $ex->{name};
        }
    }
    $self->__error( $c, \%return );
}

1;

=head1 NAME

SamuRest::ControllerX::REST - extends Catalyst::Controller::REST with custom functions

=head1 DESCRIPTION

...

=head1 METHODS

=cut

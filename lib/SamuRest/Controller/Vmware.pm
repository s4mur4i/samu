package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;
use SamuAPI::common;

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
    my $user_id = $self->__is_logined($c);
    return $self->__error($c, "You're not login yet.") unless $user_id;
}

sub test : Chained('vmwareBase') :PathPart('') :Args(0) :ActionClass('REST') {}

sub test_GET {
    my ($self, $c) = @_;
    
    return $self->__ok($c, { something => "ok" });
}

sub connect: Chained('vmwareBase'): PathPart('connect'): Args(0) : ActionClass('REST'){
    my ($self, $c) = @_;
    my $params = $c->req->params;
    my $user_id = $c->session->{__user};
    my $model = $c->model("Database::UserValue");
    my $username = $params->{vcenter_username} || $model->get_user_value($user_id, "vcenter_username");
    my $password = $params->{vcenter_password} || $model->get_user_value($user_id, "vcenter_password");
    my $url = $params->{vcenter_url} || $model->get_user_value($user_id, "vcenter_url");

    my $vim = &connect_vcenter( $url, $username, $password );
#    if ( $c->) {
 #   }
  #  $c->session->{__vim_login} = ;
}

=head1 AUTHOR

s4mur4i,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

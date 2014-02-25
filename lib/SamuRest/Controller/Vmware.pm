package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;

BEGIN { extends 'SamuRest::ControllerX::REST'; }

use SamuAPI::Common;

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

sub connection: Chained('vmwareBase'): PathPart(''): Args(0) : ActionClass('REST'){
}

sub connection_GET {

}

sub connection_POST {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    my $user_id = $c->session->{__user};
    my $model = $c->model("Database::UserConfig");
    my $vcenter_username = $params->{vcenter_username} || $model->get_user_value($user_id, "vcenter_username");
    return $self->__error($c, "Vcenter_username cannot be parsed or found") unless $vcenter_username;
    my $vcenter_password = $params->{vcenter_password} || $model->get_user_value($user_id, "vcenter_password");
    return $self->__error($c, "Vcenter_password cannot be parsed or found") unless $vcenter_password;
    my $vcenter_url = $params->{vcenter_url} || $model->get_user_value($user_id, "vcenter_url");
    return $self->__error($c, "Vcenter_url cannot be parsed or found") unless $vcenter_url;
    # TODO: Maybe later implement proto, servicepath, server, but for me currently not needed
    my $vim = &VCenter::connect_vcenter( $vcenter_url, $vcenter_username, $vcenter_password );
    if ( !$c->session->{__vim_login} ) {
         @{ $c->session->{__vim_login}} = ();       
    }
    use Data::Dumper;
    print Dumper $c->session;
    push ( @{ $c->session->{__vim_login}} , $vim) ;
    return $self->__ok( $c, { vim_login => "success" });
}

sub connection_DELETE {

}

=head1 AUTHOR

s4mur4i,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

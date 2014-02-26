package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;
use Data::Dumper;

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

sub loginBase : Chained('vmwareBase') : PathPart('') : CaptureArgs(0) {
    my ($self, $c) = @_;
    #TODO login to vcenter with active connection
    if ( !$c->session->{__vim_login}->{active}) {
        $self->__error( $c, "Session not created");
    }
}

sub connection: Chained('vmwareBase'): PathPart(''): Args(0) : ActionClass('REST'){
    my ($self, $c) = @_;
    if ( !$c->session->{__vim_login} ) {
         $c->session->{__vim_login} = { active => '0', sessions => [] };
    }
}

sub connection_GET {
    my ( $self, $c ) = @_;
    my %return = ();
    if ( scalar($c->session->{__vim_login}->{sessions}) eq 0) {
        $return{connections} = "none";
    } else {
        print Dumper $c->session;
        for my $num ( 0..$#{ $c->session->{__vim_login}->{sessions} } ) {
            $return{connections}->{$num} = $c->session->{__vim_login}->{sessions}->[$num]->{url};
        }
    }
    return $self->__ok( $c, \%return );
}

sub connection_POST {
    my ($self, $c) = @_;

    # Set options
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
    my $VCenter;
    my $ret = "success";
    eval { 
        $VCenter = VCenter->new(vcenter_url => $vcenter_url, vcenter_username => $vcenter_username, vcenter_password => $vcenter_password);
        $VCenter->connect_vcenter;
    };
    if ($@) {
        my $ex = $@; 
        $ret = $ex->error;
    } else {
        my $sessionfile = $VCenter->savesession_vcenter;
        push( @{ $c->session->{__vim_login}->{sessions} }, { url => $vcenter_url, sessionfile => $sessionfile} );

    }
    $c->stash->{vim} = $VCenter;
    print Dumper $c->stash;
    return $self->__ok( $c, { vim_login => $ret, id => $#{ $c->session->{__vim_login}->{sessions} }});
}

sub connection_DELETE {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    my $id = $params->{id};
    if ( $id < 0 || $id > $#{ $c->session->{__vim_login}->{sessions} } ) {
        return $self->__error( $c, "Session ID out of range" );
    }
    my $vim = &VCenter::loadsession_vcenter( vcenter_url => $c->session->{__vim_login}->{sessions}->[$id]->{url}, sessionfile => $c->session->{__vim_login}->{sessions}->[$id]->{sessionfile} );
    &VCenter::disconnect_vcenter( vim => $vim );
    delete($c->session->{__vim_login}->{sessions}->[$id]);
    # TODO shift the array to remove the undef item
    return $self->__ok( $c, { $id => "deleted" } );
}

sub connection_PUT {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    my $id = $params->{id};
    if ( $id < 0 || $id > $#{ $c->session->{__vim_login}->{sessions} } ) {
        return $self->__error( $c, "Session ID out of range" );
    }
    $c->session->{__vim_login}->{active} = $id;
    return $self->__ok( $c, { active => $id } );
}

=head1 AUTHOR

s4mur4i,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

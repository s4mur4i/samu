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

sub vmwareBase : Chained('/') : PathPart('vmware') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    my $user_id = $self->__is_logined($c);
    return $self->__error( $c, "You're not login yet." ) unless $user_id;
}

sub loginBase : Chained('vmwareBase') : PathPart('') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    if ( !$c->session->{__vim_login} ) {
        $self->__error( $c, "Login to VCenter first" );
    }
    if (
        !defined(
            $c->session->{__vim_login}->{sessions}
              ->[ $c->session->{__vim_login}->{active} ]
        )
      )
    {
        $self->__error( $c, "No active login session to vcenter" );
    }
    my $vim;
    my $active_session;
    if ( $c->req->params->{vim_id} ) {
        $active_session =
          $c->session->{__vim_login}->{sessions}->[ $c->req->params->{vim_id} ];
    }
    else {
        $active_session = $c->session->{__vim_login}->{sessions}->[ $c->session->{__vim_login}->{active} ];
    }
    eval {
        my $VCenter = VCenter->new(
            vcenter_url => $active_session->{vcenter_url},
            sessionfile => $active_session->{vcenter_sessionfile}
        );
        $VCenter->loadsession_vcenter;
        $c->stash->{vim} = $VCenter;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    $active_session->{last_used} = $c->datetime->epoch;
}

sub connection : Chained('vmwareBase') : PathPart('') : Args(0) :
  ActionClass('REST') {
    my ( $self, $c ) = @_;
    if ( !$c->session->{__vim_login} ) {
        $c->session->{__vim_login} = { active => '0', sessions => [] };
    }
}

sub connection_GET {
    my ( $self, $c ) = @_;
    my %return = ();
    if ( !@{ $c->session->{__vim_login}->{sessions} } ) {
        $return{connections} = "";
    }
    else {
        for my $num ( 0 .. $#{ $c->session->{__vim_login}->{sessions} } ) {
            $return{connections}->{$num} = ();
            for my $key ( keys $c->session->{__vim_login}->{sessions}->[$num]) {
                $return{connections}->{$num}->{$key} = $c->session->{__vim_login}->{sessions}->[$num]->{$key};
            }
        }
        $return{active} = $c->session->{__vim_login}->{active};
    }
    return $self->__ok( $c, \%return );
}

sub connection_POST {
    my ( $self, $c ) = @_;

    # Set options
    my $params           = $c->req->params;
    my $user_id          = $c->session->{__user};
    my $model            = $c->model("Database::UserConfig");
    my $vcenter_username = $params->{vcenter_username}
      || $model->get_user_value( $user_id, "vcenter_username" );
    return $self->__error( $c, "Vcenter_username cannot be parsed or found" )
      unless $vcenter_username;
    my $vcenter_password = $params->{vcenter_password}
      || $model->get_user_value( $user_id, "vcenter_password" );
    return $self->__error( $c, "Vcenter_password cannot be parsed or found" )
      unless $vcenter_password;
    my $vcenter_url = $params->{vcenter_url}
      || $model->get_user_value( $user_id, "vcenter_url" );
    return $self->__error( $c, "Vcenter_url cannot be parsed or found" )
      unless $vcenter_url;

# TODO: Maybe later implement proto, servicepath, server, but for me currently not needed
    my $VCenter;
    eval {
        $VCenter = VCenter->new(
            vcenter_url      => $vcenter_url,
            vcenter_username => $vcenter_username,
            vcenter_password => $vcenter_password
        );
        $VCenter->connect_vcenter;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    else {
        my $sessionfile = $VCenter->savesession_vcenter;
        push(
            @{ $c->session->{__vim_login}->{sessions} },
            {
                vcenter_url         => $vcenter_url,
                vcenter_sessionfile => $sessionfile,
                vcenter_username => $vcenter_username,
                last_used =>    $c->datetime->epoch,
            }
        );
    }

    #$c->stash->{vim} = $VCenter;
    $c->session->{__vim_login}->{active} =
      $#{ $c->session->{__vim_login}->{sessions} };
    return $self->__ok(
        $c,
        {
            vim_login => "success",
            id        => $#{ $c->session->{__vim_login}->{sessions} }
        }
    );
}

sub connection_DELETE {
    my ( $self, $c ) = @_;
    my $params = $c->req->params;
    my $id     = $params->{id};
    if ( $id < 0 || $id > $#{ $c->session->{__vim_login}->{sessions} } ) {
        return $self->__error( $c, "Session ID out of range" );
    }
    my $session = $c->session->{__vim_login}->{sessions}->[$id];
    eval {
        my $VCenter = VCenter->new(
            vcenter_url => $session->{vcenter_url},
            sessionfile => $session->{vcenter_sessionfile}
        );
        $VCenter->loadsession_vcenter;
        $VCenter->disconnect_vcenter;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    $c->session->{__vim_login}->{sessions}->[$id] = undef;
    return $self->__ok( $c, { $id => "deleted" } );
}

sub connection_PUT {
    my ( $self, $c ) = @_;
    my $params = $c->req->params;
    my $id     = $params->{id};
    if ( $id < 0 || $id > $#{ $c->session->{__vim_login}->{sessions} } ) {
        return $self->__error( $c, "Session ID out of range" );
    }
    $c->session->{__vim_login}->{active} = $id;
    return $self->__ok( $c, { active => $id } );
}

sub folderBase : Chained('loginBase') : PathPart('folder') : CaptureArgs(0) { }

sub folders : Chained('folderBase') : PathPart('') : Args(0) :
  ActionClass('REST') { }

sub folders_GET {
    my ( $self, $c ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub folders_POST {
    my ( $self, $c ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub folder : Chained('folderBase') : PathPart('') : Args(1) :
  ActionClass('REST') { }

sub folder_GET {
    my ( $self, $c, $name ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub folder_DELETE {
    my ( $self, $c, $name ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub folder_PUT {
    my ( $self, $c, $name ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub resourcepoolBase : Chained('loginBase') : PathPart('resourcepool') :
  CaptureArgs(0) { }

sub resourcepools : Chained('resourcepoolBase') : PathPart('') : Args(0) :
  ActionClass('REST') { }

sub resourcepools_GET {
    my ( $self, $c ) = @_;
#    my @result = $c->stash->{vim}->find_entities( view_type => 'VirtualMachine', begin_entity => 'test', properties => ['test.1', 'test.2'], filter => { name => qr/.*dsa/i, 'runtime.sa'=> 'test'} );
    my @result = $c->stash->{vim}->find_entities( view_type => 'VirtualMachine' );
    print Dumper @result;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub resourcepools_POST {
    my ( $self, $c ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub resourcepool : Chained('resourcepoolBase') : PathPart('') : Args(1) :
  ActionClass('REST') { }

sub resourcepool_GET {
    my ( $self, $c, $name ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub resourcepool_DELETE {
    my ( $self, $c, $name ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub resourcepool_PUT {
    my ( $self, $c, $name ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

=head1 AUTHOR

s4mur4i,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub taskBase: Chained('loginBase'): PathPart('task') : CaptureArgs(0) { }

sub tasks : Chained('taskBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub tasks_GET {
    my ( $self, $c ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub task : Chained(taskBase) : PathPart(''): Args(1) : ActionClass('REST') {}

sub task_GET {
    my ( $self, $c ,$num) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub task_DELETE {
    my ( $self, $c ,$num) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub templateBase: Chained('loginBase'): PathPart('template') : CaptureArgs(0) { }

sub templates : Chained('templateBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub templates_GET {
    my ( $self, $c ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub template : Chained(templateBase) : PathPart(''): Args(1) : ActionClass('REST') {}

sub template_GET {
    my ( $self, $c ,$name) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub template_DELETE {
    my ( $self, $c ,$name) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub user: Chained('loginBase'): PathPart('user'): Args(1) : ActionClass('REST') {}

sub user_GET {
    my ( $self, $c ,$name) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub networkBase: Chained('loginBase'): PathPart('network') : CaptureArgs(0) { }

sub networks : Chained('networkBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub networks_GET {
    my ( $self, $c ) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub network : Chained(networkBase) : PathPart(''): Args(1) : ActionClass('REST') {}

sub network_GET {
    my ( $self, $c ,$name) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

sub network_DELETE {
    my ( $self, $c ,$name) = @_;
    return $self->__ok( $c, { implementing => "yes" } );
}

__PACKAGE__->meta->make_immutable;

1;

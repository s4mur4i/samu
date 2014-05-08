package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'SamuRest::ControllerX::REST'; }

use SamuAPI::Common;

sub begin: Private {
    my ( $self, $c ) = @_;
    my $verbosity = delete($c->req->params->{verbosity}) || 6;
    my $facility = delete($c->req->params->{facility}) || 'LOG_USER';
    my $label = delete($c->req->params->{label}) || 'samu_vmware';
    $c->log( Log2->new( verbosity => $verbosity, facility => $facility, label => $label ) );
}

=head1 NAME

SamuRest::Controller::Vmware - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub vmwareBase : Chained('/') : PathPart('vmware') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    my $user_id = $self->__is_logined($c);
    return $self->__error( $c, "You're not login yet." ) unless $user_id;
    $c->log->debug1("Logged in user_id=>" . $user_id);
}

sub loginBase : Chained('vmwareBase') : PathPart('') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    $c->log->debug('Check if user has logged in previously in session and has an active session');
    if ( !$c->session->{__vim_login} ) {
        $self->__error( $c, "Login to VCenter first" );
    }
    if ( !defined( $c->session->{__vim_login}->{sessions} ->[ $c->session->{__vim_login}->{active} ])) {
        $self->__error( $c, "No active login session to vcenter" );
    }
    my $active_session;
    if ( $c->req->params->{vim_id} ) {
        $active_session = $c->session->{__vim_login}->{sessions}->[ $c->req->params->{vim_id} ];
    } else {
        $active_session = $c->session->{__vim_login}->{sessions}->[ $c->session->{__vim_login}->{active} ];
    }
    $c->log->dumpobj( "active_session", $active_session );
    eval {
        my $VCenter = VCenter->new( vcenter_url => $active_session->{vcenter_url}, sessionfile => $active_session->{vcenter_sessionfile}, logger => $c->log);
        $VCenter->loadsession_vcenter;
        $c->stash->{vim} = $VCenter;
        $active_session->{last_used} = $c->datetime->epoch;
        my %param = ();
        if ( $c->req->params->{computeresource} ) {
            $c->log->debug1('ComputeResource begin_entity requested');
            %param = ( view_type => 'ComputeResource', properties => ['name'], filter => {name => $c->req->params->{computeresource} } );
        } elsif ($c->req->params->{datacenter}) {
            $c->log->debug1('Datacenter begin_entity requested');
            %param = ( view_type => 'Datacenter', properties => ['name'], filter => {name => $c->req->params->{datacenter} } );
        } elsif ( $c->req->params->{hostsystem} ) {
            $c->log->debug1('Hostsystem begin_entity requested');
            %param = ( view_type => 'HostSystem', properties => ['name'], filter => {name => $c->req->params->{hostsystem} } );
        }
        if ( keys %param ) {
            $c->log->debug('Begin_entity was requested adding to find_params');
            my $begin_entity = $c->stash->{vim}->find_entity( %param );
            $c->stash->{vim}->set_find_params( begin_entity => $begin_entity);
        }
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
}

sub connection : Chained('vmwareBase') : PathPart('') : Args(0) : ActionClass('REST') {
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
    } else {
        for my $num ( 0 .. $#{ $c->session->{__vim_login}->{sessions} } ) {
            $return{connections}->{$num} = ();
            for my $key ( keys $c->session->{__vim_login}->{sessions}->[$num]) {
                $return{connections}->{$num}->{$key} = $c->session->{__vim_login}->{sessions}->[$num]->{$key};
            }
        }
        $return{active} = $c->session->{__vim_login}->{active};
    }
    $c->log->dumpobj('return', \%return);
    return $self->__ok( $c, \%return );
}

sub connection_POST {
    my ( $self, $c ) = @_;
    my $params           = $c->req->params;
    my $user_id          = $c->session->{__user};
    my $model            = $c->model("Database::UserConfig");
    my $vcenter_username = $params->{vcenter_username} || $model->get_user_config( $user_id, "vcenter_username" );
    return $self->__error( $c, "Vcenter_username cannot be parsed or found" ) unless $vcenter_username;
    my $vcenter_password = $params->{vcenter_password} || $model->get_user_config( $user_id, "vcenter_password" );
    return $self->__error( $c, "Vcenter_password cannot be parsed or found" ) unless $vcenter_password;
    my $vcenter_url = $params->{vcenter_url} || $model->get_user_config( $user_id, "vcenter_url" );
    return $self->__error( $c, "Vcenter_url cannot be parsed or found" ) unless $vcenter_url;

# TODO: Maybe later implement proto, servicepath, server, but for me currently not needed
    my $VCenter;
    eval {
        $VCenter = VCenter->new( vcenter_url      => $vcenter_url, vcenter_username => $vcenter_username, vcenter_password => $vcenter_password, logger => $c->log);
        $VCenter->connect_vcenter;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    } else {
        my $sessionfile = $VCenter->savesession_vcenter;
        push( @{ $c->session->{__vim_login}->{sessions} }, { vcenter_url         => $vcenter_url, vcenter_sessionfile => $sessionfile, vcenter_username => $vcenter_username, last_used =>    $c->datetime->epoch, });
    }
    $c->session->{__vim_login}->{active} = $#{ $c->session->{__vim_login}->{sessions} };
    $c->log->dumpobj('vcenter', $VCenter);
    return $self->__ok( $c, { vim_login => "success", id        => $#{ $c->session->{__vim_login}->{sessions} } });
}

sub connection_DELETE {
    my ( $self, $c ) = @_;
    my $id     = $c->req->params->{id};
    $c->log->debug1("id=>'$id'");
    if ( $id < 0 || $id > $#{ $c->session->{__vim_login}->{sessions} } ) {
        return $self->__error( $c, "Session ID out of range" );
    }
    my $session = $c->session->{__vim_login}->{sessions}->[$id];
    eval {
        my $VCenter = VCenter->new( vcenter_url => $session->{vcenter_url}, sessionfile => $session->{vcenter_sessionfile}, logger => $c->log);
        $VCenter->loadsession_vcenter;
        $VCenter->disconnect_vcenter;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    $c->session->{__vim_login}->{sessions}->[$id] = undef;
    return $self->__ok( $c, { $id => "deleted" } );
}

sub connection_PUT {
    my ( $self, $c ) = @_;
    my $id     = $c->req->params->{id};
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
    my %result= ();
    eval {
        bless $c->stash->{vim}, 'VCenter_folder';
        %result = %{ $c->stash->{vim}->get_all };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub folders_PUT {
    my ( $self, $c) = @_;
    my $params = $c->req->params;
    my %result= ();
    eval {
        bless $c->stash->{vim}, 'VCenter_folder';
        %result = %{ $c->stash->{vim}->move( %{ $params } ) };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub folders_POST {
    my ( $self, $c ) = @_;
    my $view = $c->stash->{vim}->find_entity( view_type => 'Folder', properties => ['name'], filter => { name => 'vm'} );
    my $parent = SamuAPI_folder->new( view => $view, logger => $c->log);
    $self->folder_POST($c, $parent->get_mo_ref_value);
}

sub folder : Chained('folderBase') : PathPart('') : Args(1) : ActionClass('REST') { }

sub folder_GET {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_folder';
        %result = %{ $c->stash->{vim}->get_single( moref_value => $mo_ref_value) };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result);

}

sub folder_DELETE {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %return = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_folder';
        %return = %{ $c->stash->{vim}->destroy( value => $mo_ref_value, type => 'Folder') };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%return );

}

sub folder_POST {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    my %create_param = ( name => $c->req->params->{name} );
    $create_param{value} = $mo_ref_value;
# TODO if multiple computeresources with same mo_ref how can they be distingueshed
    eval {
        bless $c->stash->{vim}, 'VCenter_folder';
        %result = %{ $c->stash->{vim}->create( %create_param ) };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub resourcepoolBase : Chained('loginBase') : PathPart('resourcepool') :
  CaptureArgs(0) { }

sub resourcepools : Chained('resourcepoolBase') : PathPart('') : Args(0) :
  ActionClass('REST') { }

sub resourcepools_GET {
    my ( $self, $c ) = @_;
    my $params = $c->req->params;
    my $refresh = $params->{refresh} || 0;
    my %result= ();
    eval {
        bless $c->stash->{vim}, 'VCenter_resourcepool';
        %result = %{ $c->stash->{vim}->get_all};
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub resourcepools_POST {
    my ( $self, $c ) = @_;
    my $view = $c->stash->{vim}->find_entity( view_type => 'ResourcePool', properties => ['name'], filter => { name => 'Resources'} );
    my $parent = SamuAPI_resourcepool->new( view => $view, logger => $c->log);
    $self->resourcepool_POST($c, $parent->get_mo_ref_value);
}

sub resourcepools_PUT {
    my ( $self, $c ) = @_;
    my %result = ();
    my $params = $c->req->params;
    eval {
        bless $c->stash->{vim}, 'VCenter_resourcepool';
        %result = %{ $c->stash->{vim}->move( %{ $params } ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result);
}

sub resourcepool : Chained('resourcepoolBase') : PathPart('') : Args(1) : ActionClass('REST') { }

sub resourcepool_GET {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    my $refresh = $c->req->params->{refresh} || 0;
    eval {
        bless $c->stash->{vim}, 'VCenter_resourcepool';
        %result = %{ $c->stash->{vim}->get_single( refresh => $refresh, moref_value => $mo_ref_value) };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result);
}

sub resourcepool_DELETE {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %return = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_resourcepool';
        %return = %{ $c->stash->{vim}->destroy( value => $mo_ref_value, type => 'ResourcePool') };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%return );
}

sub resourcepool_PUT {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    my %param = %{ $c->req->params };
    $param{moref_value} = $mo_ref_value;
    eval {
        bless $c->stash->{vim}, 'VCenter_resourcepool';
        %result = %{ $c->stash->{vim}->update( %param ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub resourcepool_POST {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    my %create_param = %{ $c->req->params };
    $create_param{value} = $mo_ref_value;
# TODO if multiple computeresources with same mo_ref how can they be distingueshed
    eval {
        bless $c->stash->{vim}, 'VCenter_resourcepool';
        %result = %{ $c->stash->{vim}->create( %create_param ) };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub taskBase: Chained('loginBase'): PathPart('task') : CaptureArgs(0) { }

sub tasks : Chained('taskBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub tasks_GET {
    my ( $self, $c ) = @_;
    my %result =();
    eval {
        %result = %{ $c->stash->{vim}->get_tasks };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub task : Chained(taskBase) : PathPart(''): Args(1) : ActionClass('REST') { }

sub task_GET {
    my ( $self, $c ,$mo_ref_value ) = @_;
    my %result =();
    eval {
        %result = %{ $c->stash->{vim}->get_task( value => $mo_ref_value) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub task_DELETE {
    my ( $self, $c ,$mo_ref_value) = @_;
    my %result = ();
    eval {
        %result = %{ $c->stash->{vim}->cancel_task( value => $mo_ref_value) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub templateBase: Chained('loginBase'): PathPart('template') : CaptureArgs(0) { }

sub templates : Chained('templateBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub templates_GET {
    my ( $self, $c ) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_templates };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub template : Chained(templateBase) : PathPart(''): Args(1) : ActionClass('REST') { }

sub template_GET {
    my ( $self, $c ,$mo_ref_value) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_template( value=> $mo_ref_value) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c,\%result );
}

sub template_DELETE {
    my ( $self, $c ,$mo_ref_value) = @_;
    my %result =();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->promote_template(value => $mo_ref_value) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub datastoreBase: Chained('loginBase'): PathPart('datastore') : CaptureArgs(0) { }

sub datastores : Chained('datastoreBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub datastores_GET {
    my ( $self, $c) = @_;
    my %result =();
	eval {
        bless $c->stash->{vim}, 'VCenter_datastore';
        %result = %{ $c->stash->{vim}->get_all( ) };
	};
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub datastore : Chained('datastoreBase'): PathPart(''): Args(1) : ActionClass('REST') {}

sub datastore_GET {
    my ( $self, $c ,$mo_ref_value) = @_;
    my %result =();
	eval {
        bless $c->stash->{vim}, 'VCenter_datastore';
        %result = %{ $c->stash->{vim}->get_single( value=> $mo_ref_value ) };
	};
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub networkBase: Chained('loginBase'): PathPart('network') : CaptureArgs(0) { }

sub networks : Chained('networkBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub networks_GET {
    my ( $self, $c ) = @_;
    my %result = ( dvp => (), switch => (), hostnetwork => () );
    eval {
        bless $c->stash->{vim}, 'VCenter_dvs';
        $result{switch} = $c->stash->{vim}->get_all;
        bless $c->stash->{vim}, 'VCenter_dvp';
        $result{dvp} = $c->stash->{vim}->get_all;
        bless $c->stash->{vim}, 'VCenter_hostnetwork';
        $result{hostnetwork} = $c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    $c->log->dumpobj('result', \%result);
    return $self->__ok( $c, \%result );
}

sub switch_base : Chained(networkBase) : PathPart('switch'): CaptureArgs(0) { }

sub switches : Chained('switch_base'): PathPart(''): Args(0) : ActionClass('REST') {}

sub switches_GET {
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_dvs';
        %result = %{ $c->stash->{vim}->get_all};
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub switches_POST{
    my ($self, $c) = @_;
    my $params = $c->req->params;
    my $ticket = $params->{ticket};
    my $host = $params->{host};
# TODO impelement method to list hosts
    my %result =();
    eval {
        bless $c->stash->{vim}, 'VCenter_dvs';
        %result = %{ $c->stash->{vim}->create( ticket => $ticket, host => $host )};
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub switch : Chained('switch_base'): PathPart(''): Args(1) : ActionClass('REST') { }

sub switch_GET {
    my ( $self, $c, $mo_ref_value) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_dvs';
        %result = %{ $c->stash->{vim}->get_single( value => $mo_ref_value) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub switch_DELETE {
    my ( $self, $c, $mo_ref_value) =@_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_switch';
        %result = %{ $c->stash->{vim}->destroy( value => $mo_ref_value) };
    };
    if ( $@ ) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub switch_PUT {
    my ( $self, $c, $mo_ref_value) =@_;
    my %result = ();
    my $params           = $c->req->params;
    eval {
        bless $c->stash->{vim}, 'VCenter_switch';
        %result = %{ $c->stash->{vim}->update( %{ $params} ) };
    };
    if ( $@ ) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub dvp_base : Chained(networkBase) : PathPart('dvp'): CaptureArgs(0) { }

sub dvps : Chained('dvp_base'): PathPart(''): Args(0) : ActionClass('REST') {}

sub dvps_GET {
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_dvp';
        %result = %{ $c->stash->{vim}->get_all };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub dvps_POST {
    my ($self, $c) = @_;
    my $params = $c->req->params;
    my $ticket = $params->{ticket};
    my $switch = $params->{switch};
    my $func = $params->{func};
    my %result =();
    eval {
        bless $c->stash->{vim}, 'VCenter_dvp';
        %result = %{ $c->stash->{vim}->create( ticket => $ticket, switch => $switch, func => $func )};
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub dvp : Chained('dvp_base'): PathPart(''): Args(1) : ActionClass('REST') { }

sub dvp_GET {
    my ( $self, $c, $mo_ref_value) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_dvp';
        %result = %{ $c->stash->{vim}->get_single( value => $mo_ref_value) };
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub dvp_DELETE {
    my ( $self, $c, $mo_ref_value) =@_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_dvp';
        %result = %{ $c->stash->{vim}->destroy( value => $mo_ref_value) };
    };
    if ( $@ ) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub dvp_PUT {
    my ( $self, $c, $mo_ref_value) =@_;
    my %result = ();
    my $params           = $c->req->params;
    eval {
        bless $c->stash->{vim}, 'VCenter_dvp';
        %result = %{ $c->stash->{vim}->update( %{ $params} ) };
    };
    if ( $@ ) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );

}

sub hostnetwork_base : Chained(networkBase) : PathPart('hostnetwork'): CaptureArgs(0) { }

sub hostnetworks : Chained('hostnetwork_base'): PathPart(''): Args(0) : ActionClass('REST') {}

sub hostnetworks_GET{
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_hostnetwork';
        %result = %{ $c->stash->{vim}->get_all};
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub hostnetwork : Chained('hostnetwork_base'): PathPart(''): Args(1) : ActionClass('REST') { }

sub hostnetwork_GET {
    my ( $self, $c, $mo_ref_value) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_hostnetwork';
        %result = %{ $c->stash->{vim}->get_single( value => $mo_ref_value)};
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub hostBase: Chained('loginBase'): PathPart('host') : CaptureArgs(0) { }

sub hosts : Chained('hostBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub hosts_GET {
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_host';
        %result = %{ $c->stash->{vim}->get_all };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub host : Chained('hostBase'): PathPart(''): Args(1) : ActionClass('REST') {}

sub host_GET {
    my ( $self, $c, $mo_ref_value) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_host';
        %result = %{ $c->stash->{vim}->get_single(value => $mo_ref_value) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub vmsBase: Chained('loginBase'): PathPart('vm') : CaptureArgs(0) { }

sub vms : Chained('vmsBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub vms_GET {
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_all };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub vms_POST {
    my ( $self, $c) = @_;
    my %result = ();
    my $params = $c->req->params;
    eval {
        %result = (Status => "Not implemented");
#        bless $c->stash->{vim}, 'VCenter_vm';
#        %result = %{ $c->stash->{vim}->create_vm( %{$params}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub vmBase: Chained('vmsBase'): PathPart('') : CaptureArgs(1) {
    my ($self, $c, $mo_ref_value) = @_;
    $c->stash->{ mo_ref_value } = $mo_ref_value
}

sub vm : Chained('vmBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub vm_GET{
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_single( moref_value => $c->stash->{mo_ref_value} ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub vm_DELETE {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->destroy( moref_value => $c->stash->{mo_ref_value} ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub vm_POST {
    my ($self, $c) = @_;
    my %result = ();
    my $params = $c->req->params;
    my $user_id          = $c->session->{__user};
    my $model            = $c->model("Database::UserConfig");
    my $users_rs = $c->model('Database::User');
    my $user = $users_rs->find($user_id);
    if ( !defined($params->{mac_base}) ) {
        $params->{mac_base} = $model->get_user_config( $user_id, "mac_base" ) || "02:01:00:";
    }
    $params->{moref_value} = $c->stash->{mo_ref_value};
    $params->{owner} = $user->username;
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->clone_vm( %$params) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub cpu : Chained('vmBase'): PathPart('cpu'): Args(0) : ActionClass('REST') {}

sub cpu_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        my $ret = $c->stash->{vim}->get_single( moref_value => $c->stash->{mo_ref_value});
        %result = (numcpus => $ret->{numCpu});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub cpu_PUT {
    my ($self, $c) = @_;
    my %result = ();
    my $numcpus = $c->req->params->{numcpus};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->update( numcpus => $numcpus, moref_value => $c->stash->{mo_ref_value} ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub process : Chained('vmBase'): PathPart('process'): Args(0) : ActionClass('REST') {}

sub process_GET {
    my ($self, $c) = @_;
    my $result = {};
    my $params = $c->req->params;
    $params->{moref_value} = $c->stash->{mo_ref_value};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        $result = $c->stash->{vim}->get_process( %{$params} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, $result );
}

sub process_POST {
    my ($self, $c) = @_;
    my %result = ();
    my $params = $c->req->params;
    $params->{moref_value} = $c->stash->{mo_ref_value};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        my $ret = $c->stash->{vim}->run( %{$params} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub transfer : Chained('vmBase'): PathPart('transfer'): Args(0) : ActionClass('REST') {}

sub transfer_POST {
    my ($self, $c) = @_;
    my %result = ();
    my $params = $c->req->params;
    $params->{moref_value} = $c->stash->{mo_ref_value};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        my $ret = $c->stash->{vim}->transfer( %{$params} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub memory : Chained('vmBase'): PathPart('memory'): Args(0) : ActionClass('REST') {}

sub memory_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        my $ret = $c->stash->{vim}->get_single( moref_value => $c->stash->{mo_ref_value});
        %result = (memorySizeMB => $ret->{memorySizeMB});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub memory_PUT {
    my ($self, $c) = @_;
    my %result = ();
    my $memorymb = $c->req->params->{memorymb};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->update(memorymb => $memorymb, moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub disks : Chained('vmBase'): PathPart('disk'): Args(0) : ActionClass('REST') {}

sub disks_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_disks(moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub disks_POST {
    my ($self, $c) = @_;
    my %result = ();
    my %params = %{ $c->req->params };
    $params{moref_value} = $c->stash->{mo_ref_value};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->create_disk( %params ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub disk : Chained('vmBase'): PathPart('disk'): Args(1) : ActionClass('REST') {}

sub disk_GET {
    my ($self, $c, $id ) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_disk(moref_value => $c->stash->{mo_ref_value}, id => $id) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub disk_DELETE {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->remove_hw(moref_value => $c->stash->{mo_ref_value}, num => $id, hw => 'VirtualDisk') };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub annotations : Chained('vmBase'): PathPart('annotation'): Args(0) : ActionClass('REST') {}

sub annotations_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_annotations(moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub annotation : Chained('vmBase'): PathPart('annotation'): Args(1) : ActionClass('REST') {}

sub annotation_GET {
    my ($self, $c, $name) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_annotation(moref_value => $c->stash->{mo_ref_value}, name => $name) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub annotation_DELETE {
    my ($self, $c, $name ) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->delete_annotation(moref_value => $c->stash->{mo_ref_value}, name => $name) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub annotation_PUT {
    my ($self, $c, $name) = @_;
    my %result = ();
    my $value = $c->req->params->{value};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->change_annotation(moref_value => $c->stash->{mo_ref_value}, name => $name, value => $value) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub events : Chained('vmBase'): PathPart('event'): Args(0) : ActionClass('REST') {}

sub events_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_events(moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub event : Chained('vmBase'): PathPart('event'): Args(1) : ActionClass('REST') {}

sub event_GET {
    my ($self, $c, $filter) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_event(moref_value => $c->stash->{mo_ref_value},filter=> $filter ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub cdroms : Chained('vmBase'): PathPart('cdrom'): Args(0) : ActionClass('REST') {}

sub cdroms_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_cdroms(moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub cdroms_POST {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->create_cdrom(moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub cdrom : Chained('vmBase'): PathPart('cdrom'): Args(1) : ActionClass('REST') {}

sub cdrom_GET {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_cdrom(moref_value => $c->stash->{mo_ref_value}, id => $id) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub cdrom_PUT {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->change_cdrom(moref_value => $c->stash->{mo_ref_value}, id => $id) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub cdrom_DELETE {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->remove_hw(moref_value => $c->stash->{mo_ref_value}, num => $id, hw => 'VirtualCdrom' ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub interfaces : Chained('vmBase'): PathPart('interface'): Args(0) : ActionClass('REST') {}

sub interfaces_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_interfaces(moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub interfaces_POST {
    my ($self, $c) = @_;
    my %result = ();
    my $user_id          = $c->session->{__user};
    $c->log->debug1("userid=>'$user_id'");
    my $model            = $c->model("Database::UserConfig");
    my $mac_base = $model->get_user_config( $user_id, "mac_base" ) || "02:01:00:";
    my $type = $c->req->params->{type} || 'E1000';
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->create_interface(moref_value => $c->stash->{mo_ref_value}, mac_base => $mac_base, type=> $type ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub interface : Chained('vmBase'): PathPart('interface'): Args(1) : ActionClass('REST') {}

sub interface_GET {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_interface(moref_value => $c->stash->{mo_ref_value}, id => $id) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub interface_PUT {
    my ($self, $c, $id) = @_;
    my %result = ();
    my $network = $c->req->params->{network};
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->change_interface(moref_value => $c->stash->{mo_ref_value}, id => $id, network => $network) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub interface_DELETE {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->remove_hw(moref_value => $c->stash->{mo_ref_value}, num => $id, hw => 'VirtualEthernetCard') };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub powerstatus : Chained('vmBase'): PathPart('powerstatus'): Args(0) : ActionClass('REST') {}

sub powerstatus_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_powerstate(moref_value => $c->stash->{mo_ref_value}, test => 1) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub powerstate : Chained('vmBase'): PathPart('powerstatus'): Args(1) : ActionClass('REST') {}

sub powerstate_PUT {
    my ($self, $c, $state) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->change_powerstate(moref_value => $c->stash->{mo_ref_value}, state => $state) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub snapshots : Chained('vmBase'): PathPart('snapshot'): Args(0) : ActionClass('REST') {}

sub snapshots_GET {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_snapshots(moref_value => $c->stash->{mo_ref_value}) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub snapshots_POST {
    my ($self, $c) = @_;
    my %result = ();
    my $params = $c->req->params;
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->create_snapshot( moref_value => $c->stash->{mo_ref_value}, name => $params->{name}, desc => $params->{desc} ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub snapshots_DELETE {
    my ($self, $c) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->delete_snapshots( moref_value => $c->stash->{mo_ref_value} ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub snapshot : Chained('vmBase'): PathPart('snapshot'): Args(1) : ActionClass('REST') {}

sub snapshot_GET {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->get_snapshot(moref_value => $c->stash->{mo_ref_value}, id => $id) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub snapshot_PUT {
    my ($self, $c, $id ) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->revert_snapshot(moref_value => $c->stash->{mo_ref_value}, id => $id ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub snapshot_DELETE {
    my ($self, $c, $id) = @_;
    my %result = ();
    eval {
        bless $c->stash->{vim}, 'VCenter_vm';
        %result = %{ $c->stash->{vim}->delete_snapshot( moref_value => $c->stash->{mo_ref_value}, id => $id ) };
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

__PACKAGE__->meta->make_immutable;

1;

package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'SamuRest::ControllerX::REST'; }

use SamuAPI::Common;

sub begin: Private {
    my ( $self, $c ) = @_;
    my $verbosity = $c->req->params->{verbosity} || 6;
    my $facility = $c->req->params->{facility} || 'LOG_USER';
    my $label = $c->req->params->{label} || 'samu_vmware';
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
    my $vcenter_username = $params->{vcenter_username} || $model->get_user_value( $user_id, "vcenter_username" );
    return $self->__error( $c, "Vcenter_username cannot be parsed or found" ) unless $vcenter_username;
    my $vcenter_password = $params->{vcenter_password} || $model->get_user_value( $user_id, "vcenter_password" );
    return $self->__error( $c, "Vcenter_password cannot be parsed or found" ) unless $vcenter_password;
    my $vcenter_url = $params->{vcenter_url} || $model->get_user_value( $user_id, "vcenter_url" );
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
    my $result= {};
    eval {
        $result = $c->stash->{vim}->get_folder_list;
    };
    if ($@) {
        print Dumper $@;
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, $result );
}

sub folders_PUT {
    my ( $self, $c) = @_;
    my $params = $c->req->params;
    my $parent_folder_mo_ref_value = $params->{parent_folder};
    my $child_type = $params->{child_type};
    my $child_value = $params->{child_value};
    my %result= ();
    eval {
# TODO test if works
        my $parent_mo_ref = $c->stash->{vim}->create_moref( type => 'Folder', value => $parent_folder_mo_ref_value) ;
        my $parent_view = $c->stash->{vim}->get_view( mo_ref => $parent_mo_ref );
        my $child_mo_ref = $c->stash->{vim}->create_moref( type => $child_type, value => $child_value) ;
        my $child_view = $c->stash->{vim}->get_view( mo_ref => $child_mo_ref );
        my $task = $parent_view->MoveIntoFolder_Task( list => [$child_view] );
        $result{task} = $task->{value};
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub folders_POST {
    my ( $self, $c ) = @_;
    my %result = ();
    my $params = $c->req->params;
    my $folder_name = $params->{name};
    if (defined( $params->{parent_value} )) {
        my $parent_mo_ref = $c->stash->{vim}->create_moref( type => 'Folder', value => $params->{parent_value} );
        $c->stash->{view} = $c->stash->{vim}->get_view( mo_ref => $parent_mo_ref );
    } else {
        $c->stash->{view} = $c->stash->{vim}->find_entity( view_type => 'Folder', properties => ['name'], filter => { name => 'vm'} );
    }
    eval {
        my $folder = SamuAPI_folder->new( view => $c->stash->{view} );
        $folder->create( name => $folder_name );
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub folder : Chained('folderBase') : PathPart('') : Args(1) : ActionClass('REST') { 
    my ( $self, $c, $mo_ref_value ) = @_;
    eval {
        $c->stash->{mo_ref} = $c->stash->{vim}->create_moref( type => 'Folder', value => $mo_ref_value) ;
        my %params = ( mo_ref => $c->stash->{mo_ref});
        $c->stash->{view} = $c->stash->{vim}->get_view( %params);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
}

sub folder_GET {
    my ( $self, $c, $name ) = @_;
    my %result = ();
    eval {
        my $folder = SamuAPI_folder->new( view => $c->stash->{view} );
        %result = %{ $folder->get_info} ;
        if ( $result{parent_name} ) {
            my $parent_view = $c->stash->{vim}->get_view( mo_ref => $result{parent_name}, properties => ['name'] );
            my $parent = SamuAPI_resourcepool->new( view => $parent_view, refresh => 0 );
            $result{parent_name} = $parent->get_name;
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result);

}

sub folder_DELETE {
    my ( $self, $c, $mo_ref_value ) = @_;
    my $task = undef;
    eval {
        my $folder = SamuAPI_folder->new( view => $c->stash->{view} );
        my $task_mo_ref = $folder->destroy;
        my $taskobj = SamuAPI_task->new( mo_ref => $task_mo_ref);
        $task = $taskobj->mo_ref_value;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, { taskid => $task } );

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
        my $taskmanager = $c->stash->{vim}->get_manager("taskManager");
        for ( @{ $taskmanager->{recentTask}}) {
            my $task_view = $c->stash->{vim}->get_view( mo_ref => $_);
            print Dumper $task_view;
            my $task = SamuAPI_task->new( view => $task_view );
            $result{ $task->get_mo_ref_value} = $task->get_info;
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub task : Chained(taskBase) : PathPart(''): Args(1) : ActionClass('REST') {
    my ( $self, $c, $mo_ref_value ) = @_;
    eval {
        $c->stash->{mo_ref} = $c->stash->{vim}->create_moref( type => 'Task', value => $mo_ref_value) ;
        my %params = ( mo_ref => $c->stash->{mo_ref});
        $c->stash->{view} = $c->stash->{vim}->get_view( %params);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }   
}

sub task_GET {
    my ( $self, $c ,$mo_ref_value ) = @_;
    my %result =();
    eval {
        my $task = SamuAPI_task->new( view => $c->stash->{view} );
        $result{$mo_ref_value} = $task->get_info;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub task_DELETE {
    my ( $self, $c ,$num) = @_;
    my %result = ();
    eval {
#Verify functionality
        my $task = SamuAPI_task->new( view => $c->stash->{view} );
        $task->cancel;
    };
    if ($@) {
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
        my $templates = $c->stash->{vim}->get_templates;
        for my $vm (@$templates) {
            my $template = SamuAPI_template->new( view => $vm);
            $result{$template->get_mo_ref_value } = $template->get_name;
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub template : Chained(templateBase) : PathPart(''): Args(1) : ActionClass('REST') {
    my ( $self, $c, $mo_ref_value ) = @_;
    eval {
        $c->stash->{mo_ref} = $c->stash->{vim}->create_moref( type => 'VirtualMachine', value => $mo_ref_value) ;
        my %params = ( mo_ref => $c->stash->{mo_ref});
        $c->stash->{view} = $c->stash->{vim}->get_view( %params);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
}

sub template_GET {
    my ( $self, $c ,$mo_ref_value) = @_;
    my %result = ();
    eval {
        my $template = SamuAPI_template->new( view => $c->stash->{view});
        %result = %{ $template->get_info};
        my $linked = $c->stash->{vim}->linked_clones( view => $c->stash->{view});
        $result{active_linked_clones} = $linked;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c,\%result );
}

sub template_DELETE {
    my ( $self, $c ,$mo_ref) = @_;
    my %result =();
    eval {
        my $vms = $c->stash->{vim}->linked_clones( view => $c->stash->{view});
        for my $vm ( @{ $vms }) {
            my $mo_ref = $c->stash->{vim}->create_moref( type => 'VirtualMachine', value => $vm->{mo_ref} ) ;
            my $vm_view = $c->stash->{vim}->get_view( mo_ref => $mo_ref );
            my $vm = SamuAPI_virtualmachine->new( view => $vm_view);
            my $task = $vm->promote;
            $result{$vm->get_name} = $task->{value};
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub networkBase: Chained('loginBase'): PathPart('network') : CaptureArgs(0) { }

sub networks : Chained('networkBase'): PathPart(''): Args(0) : ActionClass('REST') {}

sub networks_GET {
    my ( $self, $c ) = @_;
    my %result = ( dvp => {}, switch => {}, network => {} );
    eval {
        my $switches = $c->stash->{vim}->get_switches;
        for my $switch ( @{ $switches } ) {
            my $obj = SamuAPI_distributedvirtualswitch->new( view => $switch );
            $result{switch}{$obj->get_mo_ref_value} = $obj->get_mo_ref;
            $result{switch}{$obj->get_mo_ref_value}{name} = $obj->get_name;
        }
        my $dvps = $c->stash->{vim}->get_dvps;
        for my $dvp ( @{ $dvps } ) {
            my $obj = SamuAPI_distributedvirtualportgroup->new( view => $dvp );
            $result{dvp}{$obj->get_mo_ref_value} = $obj->get_mo_ref;
            $result{dvp}{$obj->get_mo_ref_value}{name} = $obj->get_name;
        }
        my $hostnetworks = $c->stash->{vim}->get_host_networks;
        for my $network ( @{ $hostnetworks } ) {
            my $obj = SamuAPI_network->new( view => $network );
            $result{hostnetwork}{$obj->get_mo_ref_value} = $obj->get_mo_ref;
            $result{hostnetwork}{$obj->get_mo_ref_value}{name} = $obj->get_name;
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub switch_base : Chained(networkBase) : PathPart('switch'): CaptureArgs(0) { }

sub switches : Chained('switch_base'): PathPart(''): Args(0) : ActionClass('REST') {}

sub switches_GET {
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        my $switches = $c->stash->{vim}->get_switches;
        for my $switch ( @{ $switches } ) {
            my $obj = SamuAPI_distributedvirtualswitch->new( view => $switch );
            $result{$obj->get_mo_ref_value} = $obj->get_mo_ref;
            $result{$obj->get_mo_ref_value}{name} = $obj->get_name;
        }
    };
    if ($@) {
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
        my $task_mo_ref = $c->stash->{vim}->create_switch( ticket => $ticket, host => $host );
        my $task = SamuAPI_task->new( mo_ref => $task_mo_ref);
        $result{task} = $task->get_mo_ref;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub switch : Chained('switch_base'): PathPart(''): Args(1) : ActionClass('REST') {
    my ( $self, $c, $mo_ref_value ) = @_;
    eval {
        $c->stash->{mo_ref} = $c->stash->{vim}->create_moref( type => 'DistributedVirtualSwitch', value => $mo_ref_value) ;
        my %params = ( mo_ref => $c->stash->{mo_ref});
        $c->stash->{view} = $c->stash->{vim}->get_view( %params);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
}

sub switch_GET {
    my ( $self, $c, $moref_value) = @_;
    my %result = ();
    eval {
        my $switch = SamuAPI_distributedvirtualswitch->new( view => $c->stash->{view});
        %result = %{ $switch->get_info};
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub switch_DELETE {

}

sub switch_PUT {

}

sub dvp_base : Chained(networkBase) : PathPart('dvp'): CaptureArgs(0) { }

sub dvps : Chained('dvp_base'): PathPart(''): Args(0) : ActionClass('REST') {}

sub dvps_GET {
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        my $dvps = $c->stash->{vim}->get_dvps;
        for my $dvp ( @{ $dvps } ) {
            my $obj = SamuAPI_distributedvirtualportgroup->new( view => $dvp );
            $result{$obj->get_mo_ref_value} = $obj->get_mo_ref;
            $result{$obj->get_mo_ref_value}{name} = $obj->get_name;
        }
    };
    if ($@) {
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
        my $task_mo_ref = $c->stash->{vim}->create_dvp( ticket => $ticket, switch => $switch, func => $func);
        my $task = SamuAPI_task->new( mo_ref => $task_mo_ref);
        $result{task} = $task->get_mo_ref;
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub dvp : Chained('dvp_base'): PathPart(''): Args(1) : ActionClass('REST') {
    my ( $self, $c, $mo_ref_value ) = @_;
    eval {
        $c->stash->{mo_ref} = $c->stash->{vim}->create_moref( type => 'DistributedVirtualPortgroup', value => $mo_ref_value) ;
        my %params = ( mo_ref => $c->stash->{mo_ref});
        $c->stash->{view} = $c->stash->{vim}->get_view( %params);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
}

sub dvp_GET {
    my ( $self, $c, $moref_value) = @_;
    my %result = ();
    eval {
        my $dvp = SamuAPI_distributedvirtualportgroup->new( view => $c->stash->{view});
        %result = %{ $dvp->get_info};
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub dvp_DELETE {

}

sub dvp_PUT {

}

sub hostnetwork_base : Chained(networkBase) : PathPart('hostnetwork'): CaptureArgs(0) { }

sub hostnetworks : Chained('hostnetwork_base'): PathPart(''): Args(0) : ActionClass('REST') {}

sub hostnetworks_GET{
    my ( $self, $c) = @_;
    my %result = ();
    eval {
        my $networks = $c->stash->{vim}->get_networks;
        for my $network ( @{ $networks } ) {
            my $obj = SamuAPI_network->new( view => $network );
            print Dumper $obj;
            $result{$obj->get_mo_ref_value} = $obj->get_mo_ref;
            $result{$obj->get_mo_ref_value}{name} = $obj->get_name;
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub hostnetwork : Chained('hostnetwork_base'): PathPart(''): Args(1) : ActionClass('REST') {
    my ( $self, $c, $mo_ref_value ) = @_;
    eval {
        $c->stash->{mo_ref} = $c->stash->{vim}->create_moref( type => 'Network', value => $mo_ref_value) ;
        my %params = ( mo_ref => $c->stash->{mo_ref});
        $c->stash->{view} = $c->stash->{vim}->get_view( %params);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
}

sub hostnetwork_GET {
    my ( $self, $c, $moref_value) = @_;
    my %result = ();
    eval {
        my $network = SamuAPI_network->new( view => $c->stash->{view});
        %result = %{ $network->get_info};
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }    
    return $self->__ok( $c, \%result );
}

sub hostnetwork_DELETE {

}

sub hostnetwork_PUT {

}

__PACKAGE__->meta->make_immutable;

1;

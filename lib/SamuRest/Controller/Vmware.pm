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
# Parse begin_entity if needed
    eval {
        my %param = ();
# TODO maybe rethink, since this params might be used somewhere else aswell
        if ( $c->req->params->{computeresource} ) {
            %param = ( view_type => 'ComputeResource', properties => ['name'], filter => {name => $c->req->params->{computeresource} } );
        } elsif ($c->req->params->{datacenter}) {
            %param = ( view_type => 'Datacenter', properties => ['name'], filter => {name => $c->req->params->{datacenter} } );
        } elsif ( $c->req->params->{hostsystem} ) {
            %param = ( view_type => 'HostSystem', properties => ['name'], filter => {name => $c->req->params->{hostsystem} } );
        }
        if ( keys %param ) {
            my $begin_entity = $c->stash->{vim}->find_entity( %param );
            $c->stash->{vim}->set_find_params( begin_entity => $begin_entity);
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
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
    my $params = $c->req->params;
    my %result= ();
    eval {
# TODO, try to implement properties for faster query
        my $folders = $c->stash->{vim}->find_entities( view_type => 'Folder' );
        for my $folder_view ( @{ $folders } ) {
            my $folder = SamuAPI_folder->new( view => $folder_view);
            $folder->parse_info;
            my $moref_value = $folder_view->{mo_ref}->{value};
            $result{ $moref_value } = $folder->get_info;
            if ( $result{$moref_value}->{parent} ) {
                $result{$moref_value}->{parent} = $c->stash->{vim}->get_view( mo_ref => $result{$moref_value}->{parent}, properties => ['name'] )->name;
            }
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
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
        $folder->parse_info;
        %result = %{ $folder->get_info} ;
        if ( $result{parent} ) {
            $result{parent} = $c->stash->{vim}->get_view( mo_ref => $result{parent}, properties => ['name'] )->name;
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result);

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
    my $params = $c->req->params;
    my $refresh = $params->{refresh} || 0;
    my %result= ();
    eval {
# TODO, try to implement properties for faster query
        my $resourcepools = $c->stash->{vim}->find_entities( view_type => 'ResourcePool' );
        for my $resourcepool_view ( @{ $resourcepools } ) {
            my $resourcepool = SamuAPI_resourcepool->new( view => $resourcepool_view, refresh => $refresh);
            $resourcepool->parse_info;
            my $moref_value = $resourcepool_view->{mo_ref}->{value};
            $result{ $moref_value } = $resourcepool->get_info;
            if ( $result{$moref_value}->{parent} ) {
                $result{$moref_value}->{parent} = $c->stash->{vim}->get_view( mo_ref => $result{$moref_value}->{parent}, properties => ['name'] )->name;
            }
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub resourcepools_POST {
    my ( $self, $c ) = @_;
    my $view = $c->stash->{vim}->find_entity( view_type => 'ResourcePool', properties => ['name'], filter => { name => 'Resources'} );
    $self->resourcepool($c, $view->{mo_ref}->{value});
    $self->resourcepool_POST($c, $view->{mo_ref}->{value});
}

sub resourcepools_PUT {
    my ( $self, $c ) = @_;
    my %result = ();
    my $param = $c->req->params;
    my $child_value = $param->{child_value};
    my $child_type = $param->{child_type};
    my $child_mo_ref = $c->stash->{vim}->create_moref( type => $child_type, value => $child_value) ;
    my $parent_value = $param->{parent_value} || undef;
    eval {
        my $parent_view = undef;
        if (defined($parent_value) ) {
            my $mo_ref = $c->stash->{vim}->create_moref( type => 'ResourcePool', value => $parent_value) ;
            my %params = ( mo_ref => $mo_ref);
            $parent_view = $c->stash->{vim}->get_view( %params);
        } else {
            $parent_view = $c->stash->{vim}->find_entity( view_type => 'ResourcePool', properties => ['name'], filter => { name => 'Resources'} );
        }
        my $resourcepool = SamuAPI_resourcepool->new( view => $parent_view );
        $resourcepool->move( mo_ref => $child_mo_ref);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result);
}

sub resourcepool : Chained('resourcepoolBase') : PathPart('') : Args(1) : ActionClass('REST') { 
    my ( $self, $c, $mo_ref_value ) = @_;      
    eval {
        $c->stash->{mo_ref} = $c->stash->{vim}->create_moref( type => 'ResourcePool', value => $mo_ref_value) ;
        my %params = ( mo_ref => $c->stash->{mo_ref});
        $c->stash->{view} = $c->stash->{vim}->get_view( %params);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
}

sub resourcepool_GET {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    my $refresh = $c->req->params->{refresh} || 0;
    eval {
        my $resourcepool = SamuAPI_resourcepool->new( view => $c->stash->{view}, refresh => $refresh );
        $resourcepool->parse_info;
        %result = %{ $resourcepool->get_info} ;
        if ( $result{parent} ) {
            $result{parent} = $c->stash->{vim}->get_view( mo_ref => $result{parent}, properties => ['name'] )->name;
        }
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result);
}

sub resourcepool_DELETE {
    my ( $self, $c, $mo_ref_value ) = @_;
    my $task = undef;
    eval {
        my $resourcepool = SamuAPI_resourcepool->new( view => $c->stash->{view} );
        my $task_mo_ref = $resourcepool->destroy;
        my $taskobj = SamuAPI_task->new( mo_ref => $task_mo_ref);
        $task = $taskobj->mo_ref_value;   
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, { taskid => $task } );
}

sub resourcepool_PUT {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    my %update_param = %{ $c->req->params };
    eval {
        my $rp = SamuAPI_resourcepool->new( view => $c->stash->{view} );
        $rp->update(%update_param);
    };
    if ($@) {
        $self->__exception_to_json( $c, $@ );
    }
    return $self->__ok( $c, \%result );
}

sub resourcepool_POST {
    my ( $self, $c, $mo_ref_value ) = @_;
    my %result = ();
    my %create_param = %{ $c->req->params };
# TODO if multiple computeresources with same mo_ref how can they be distingueshed
    eval {
        my $parent_rp = SamuAPI_resourcepool->new( view => $c->stash->{view} );
        my $moref = $parent_rp->create( %create_param );
        my $view = $c->stash->{vim}->get_view( mo_ref => $moref);
        my $resourcepool = SamuAPI_resourcepool->new( view => $view );
        $resourcepool->parse_info;
        %result = %{ $resourcepool->get_info} ;
        if ( $result{parent} ) {
            $result{parent} = $c->stash->{vim}->get_view( mo_ref => $result{parent}, properties => ['name'] )->name;
        }
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
            my $task = SamuAPI_task->new( view => $task_view );
            $task->parse_info;
            $result{$_->{value}} = $task->get_info;
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
        $task->parse_info;
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

package VCenter;

use strict;
use warnings;
use File::Temp qw/ tempfile /;
use Carp;

=pod

=head1 VCenter.pm

Subroutines for VmwareAPI/VCenter.pm

=cut

BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
}

our $vim = undef;
our $vcenter_username = undef;
our $vcenter_password = undef;
our $vcenter_url = undef;
our $sessionfile = undef;
our @entities = undef;
our %find_params = ();
our $logger = undef;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->{logger}->dumpobj( "self", $self);
    return $self;
}

sub base_parse {
    my ( $self, %args ) = @_;
    $self->{vcenter_url} = delete($args{vcenter_url});
    $self->{logger} = delete($args{logger});
    if ($args{vcenter_username} && $args{vcenter_password}) {
       $self->{vcenter_username} = delete($args{vcenter_username});
       $self->{logger}->debug1("vcenter_username=>'$self->{vcenter_username}'");
       $self->{vcenter_password} = delete($args{vcenter_password});
       $self->{logger}->debug1("vcenter_password=>'$self->{vcenter_password}'");
    } elsif ( $args{sessionfile} ) {
       $self->{sessionfile} = delete($args{sessionfile});
       $self->{logger}->debug1("sessionfile=>'$self->{sessionfile}'");
    }
    if (keys %args) {
        ExConnection::VCenter->throw( error => 'Could not create VCenter object, unrecognized argument:' . join(', ', sort keys %args), vcenter_url => $self->{vcenter_url} );
    }
    return $self
}

sub connect_vcenter {
    my $self = shift;
    $self->{logger}->start;
    eval {
        $self->{vim} = Vim->new(service_url => $self->{vcenter_url});
        $self->{vim}->login(user_name => $self->{vcenter_username}, password => $self->{vcenter_password});
    };
    if ($@) {
        ExConnection::VCenter->throw( error => 'Could not connect to VCenter', vcenter_url => $self->{vcenter_url} );
    }
    $self->{logger}->dumpobj( "vim", $self->{vim});
    $self->{logger}->finish;
    return $vim;
}

sub savesession_vcenter {
    my $self = shift;
    $self->{logger}->start;
    my $sessionfile = File::Temp->new( DIR => '/tmp', UNLINK => 0, SUFFIX => '.session', TEMPLATE => 'vcenter.XXXXXX' );
    eval {
        $self->{vim}->save_session( session_file => $sessionfile );
        $self->{sessionfile} = $sessionfile->filename;
    };
    if ($@) {
        $self->{logger}->dumpobj('error', $@);
        ExConnection::VCenter->throw( error => 'Could not save session to VCenter', vcenter_url => $self->{vcenter_url} );
    }
    $self->{logger}->debug1("Returning: filename =>'$sessionfile->filename'" );
    $self->{logger}->finish;
    return $sessionfile->filename;
}

sub loadsession_vcenter {
    my $self = shift;
    $self->{logger}->start;
    eval {
        my $vim = Vim->new(service_url => $self->{vcenter_url});
        $self->{vim} = $vim->load_session(session_file => $self->{sessionfile});
    };
    if ($@) {
        # Cannot detect if timeout or session file is missing TODO: fix
        $self->{logger}->dumpobj('error', $@);
        ExConnection::VCenter->throw( error => 'Could not load session to VCenter', vcenter_url => $self->{vcenter_url} );
    }
    $self->{logger}->dumpobj("self", $self );
    $self->{logger}->finish;
    return $self;
}

sub disconnect_vcenter {
    my $self = shift;
    $self->{logger}->start;
    eval {
        $self->{vim}->logout();
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExConnection::VCenter->throw( error => 'Could not disconnect from VCenter', vcenter_url => $self->{vcenter_url} );
    }
    $self->{logger}->dumpobj("self", $self );
    $self->{logger}->finish;
    return $self;
}

sub set_find_params {
    my ($self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->loghash("args", \%args );
    if ($args{view_type}) {
        $self->{find_params}{view_type} = delete($args{view_type});
    }
    if ($args{filter}) {
        $self->{find_params}{filter} = delete($args{filter});
    }
    if ($args{begin_entity}) {
        $self->{find_params}{begin_entity} = delete($args{begin_entity});
    }
    if ($args{properties}) {
        $self->{find_params}{properties} = delete($args{properties});
    }
    if ( keys %args) {
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => (caller(0))[3] );
    }
    $self->{logger}->dumpobj("self", $self );
    $self->{logger}->finish;
    return $self;
}

sub get_find_params {
    my $self = shift;
    $self->{logger}->start;
    my %return =();
    if ( defined $self->{find_params} ) {
        %return = %{ $self->{find_params}};
    }
    $self->{logger}->loghash("find_params", \%return);
    $self->{logger}->finish;
    return \%return;
}

sub entity_exists {
    my ($self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj("args", \%args);
    my $return = 0;
    if ( $args{mo_ref}) {
        my $view = $self->get_view( %args );
        if ( $view ) {
            push(@{$self->{entities} }, $view);
            $return = 1;
        }
    } else {
        ExAPI::Argument->throw( error => 'No required argument give', argument => join(', ', sort keys %args), subroutine => (caller(0))[3] );
    }
    $self->{logger}->debug1("Return is $return");
    $self->{logger}->finish;
    return $return;
}

sub delete_find_params {
    my ($self, %args) = @_;
    $self->{logger}->start;
    $self->{find_params} = ();
    $self->{logger}->finish;
    return $self;
}

sub find_entities {
    my ($self, %args) = @_;
    $self->{logger}->start;
    my %params = %{ $self->get_find_params} ;
    if ($args{view_type} or $params{view_type}) {
        $params{view_type} = delete($args{view_type});
    } else {
        ExAPI::Argument->throw( error => 'Default argument not given', argument => 'view_type', subroutine => (caller(0))[3] );
    }
    if ($args{filter}) {
        $params{filter} = delete($args{filter});
    }
    if ($args{begin_entity}) {
        $params{begin_entity} = delete($args{begin_entity});
    }
    if ($args{properties}) {
        $params{properties} = delete($args{properties});
    }
    if ( keys %args) {
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => (caller(0))[3] );
    }
    my $results = ();
    eval {
        $results = $self->{vim}->find_entity_views(%params);
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExEntity::FindEntityError->throw( error => 'Got error during finding entities', view_type =>  $params{view_type} );
    }
    $self->{logger}->dumpobj('results', $results);
    $self->{logger}->finish;
    return $results;
}

sub find_entity {
    my ($self,%args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj( "args", \%args );
    my %params = %{ $self->get_find_params};
    if ($args{view_type}) {
        $params{view_type} = delete($args{view_type});
    } else {
        ExAPI::Argument->throw( error => 'Default argument not given', argument => 'view_type', subroutine => (caller(0))[3] );
    }
    if ($args{filter}) {
        $params{filter} = delete($args{filter});
    }
    if ($args{begin_entity}) {
        $params{begin_entity} = delete($args{begin_entity});
    }
    if ($args{properties}) {
        $params{properties} = delete($args{properties});
    }
    if ( keys %args) {
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => (caller(0))[3] );
    }
    my $result = ();
    eval {
        $result = $self->{vim}->find_entity_view(%params);
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExEntity::FindEntityError->throw( error => 'Got error during finding entity', view_type =>  $params{view_type} );
    }
    $self->{logger}->dumpobj('result', $result);
    $self->{logger}->finish;
    return $result;
}

sub get_view {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my %params = %{ $self->get_find_params };
    if ($args{properties}) {
        $params{properties} = delete($args{properties});
    }
    if ($args{mo_ref}) {
        $params{mo_ref} = delete($args{mo_ref});
    }
    if ($args{begin_entity}) {
        $params{begin_entity} = delete($args{begin_entity});
    }
    if ( keys %args) {
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => 'get_view' );
    }
    my $view;
    eval {
        $view = $self->{vim}->get_view( %params );
#TODO Exception if nothing found
        push( @{ $self->{entities}}, $view);
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExEntity::FindEntityError->throw( error => 'Could not retrieve view', view_type =>  'mo_ref' );
    }
    $self->{logger}->finish;
    return $view;
}

sub update_view {
    my ( $self, $view ) = @_;
    $self->{logger}->start;
    my $updated_view = ();
    eval {
        $updated_view = $view->update_view_data;
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExEntity::FindEntityError->throw( error => 'Failed to update view', view_type =>  'update' );
    }
    $self->{logger}->finish;
    return $updated_view;

}

sub clear_entities {
    my $self = shift;
    $self->{logger}->start;
    @{ $self->{entities} } = ();
    $self->{logger}->finish;
    return $self;
}

sub create_moref {
    my ($self, %args ) = @_;
    $self->{logger}->start;
    my ($type,$value);
    if ( $args{type}) {
        $type = delete($args{type});
    }
# TODO fail if argument not given
    if ( $args{value}) {
        $value = delete($args{value});
    }
    if ( keys %args) {
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => 'moref2view' );
    }
    my $moref = ManagedObjectReference->new( type => $type, value => $value);
    $self->{logger}->dumpobj( 'moref', $moref);
    $self->{logger}->finish;
    return $moref;
}

sub get_service_content {
    my $self = shift;
    $self->{logger}->start;
    my $sc;
    eval {
        $sc = $self->{vim}->get_service_content();
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExEntity::ServiceContent->throw( error => 'Could not retrieve service content' );
    }
    if ( !defined($sc) ) {
        ExEntity::Empty->throw( error => 'Could not retrieve Service Content', entity => "Service Content" );
    }
    $self->{logger}->dumpobj( 'servicecontent', $sc);
    $self->{logger}->finish;
    return $sc;
}

sub get_manager {
    my ( $self, $type) = @_;
    $self->{logger}->start;
    my $sc = $self->get_service_content;
    my $manager = $self->get_view( mo_ref => $sc->{$type});
    if ( !defined($manager)) {
        ExEntity::Empty->throw( error => 'Could not retrieve manager', entity => "$type" );
    }
    $self->{logger}->dumpobj('manager', $manager);
    $self->{logger}->finish;
    return $manager;
}

sub get_hosts {
    my $self = shift;
    $self->{logger}->start;
    my $result = ();
    $result = $self->find_entities( view_type => 'HostSystem');
    $self->{logger}->dumpobj( 'result', $result);
    $self->{logger}->finish;
    return $result;
}

sub get_host_configmanager{
    my ( $self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj('args', \%args );
    my $host = SamuAPI_host->new( view => $args{view}, logger => $self->{logger} );
    my $mo_ref = $host->get_manager( $args{manager});
    my $return = $self->get_view( mo_ref => $mo_ref);
    $self->{logger}->dumpobj( 'return', $return);
    $self->{logger}->finish;
    return $return;
}

sub values_to_view {
    my ( $self, %args) = @_;
    $self->{logger}->start;
    my $mo_ref = $self->create_moref( type => $args{type}, value => $args{value});
    my $view = $self->get_view( mo_ref => $mo_ref );
    $self->{logger}->dumpobj("view", $view);
    $self->{logger}->finish;
    return $view;
}

sub get_tasks {
    my $self = shift;
    $self->{logger}->start;
    my %result = ();
    my $taskmanager = $self->get_manager("taskManager");
    for ( @{ $taskmanager->{recentTask}}) {
        my $task_view = $self->get_view( mo_ref => $_);
        my $task = SamuAPI_task->new( view => $task_view, logger => $self->{logger} );
        $result{ $task->get_mo_ref_value} = $task->get_info;
    }
    $self->{logger}->dumpobj('result', \%result);
    $self->{logger}->finish;
    return \%result;
}

sub get_task {
    my ($self, %args) = @_;
    $self->{logger}->start;
    my $task_view = $self->values_to_view( value => $args{value}, type => 'Task');
    my $task = SamuAPI_task->new( view => $task_view, logger => $self->{logger} );
    my $result =  $task->get_info ;
    $self->{logger}->finish;
    return $result;
}

sub cancel_task {
    my ($self, %args )= @_;
    $self->{logger}->start;
    my $result = ();
    my $task_view = $self->values_to_view( value => $args{value}, type => 'Task');
    my $task = SamuAPI_task->new( view => $task_view, logger => $self->{logger} );
#TODO Add test to see if cancelable.
    $task->{view}->cancel;
    $result->{status} = "cancelled";
    $self->{logger}->finish;
    return $result;
}

####################################################################

package VCenter_resourcepool;
use base 'VCenter';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    return $self;
}

sub destroy {
    my ($self,%args) = @_;
    $self->{logger}->start;
    my $task = undef;
    my %return= ();
    my $view = $self->values_to_view( %args );
    my $resourcepool = SamuAPI_resourcepool->new( view => $view, logger => $self->{logger} );
    if ( $resourcepool->child_vms ne 0 ) {
        ExEntity::NotEmpty->throw( error => "ResourcePool has child virtual machines", entity => $resourcepool->get_name, count => $resourcepool->child_vms );
    } elsif ( $resourcepool->child_rps ne 0 ) {
        ExEntity::NotEmpty->throw( error => "ResourcePool has child resourcepools", entity => $resourcepool->get_name, count => $resourcepool->child_rps );
    }
    eval {
        $task = $resourcepool->{view}->Destroy_Task;
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExTask::Error->throw( error => 'Error during task', number=> 'unknown', creator => (caller(0))[3] );
    }
    $self->{logger}->dumpobj( 'task', $task);
    my $obj = SamuAPI_task->new( mo_ref => $task, logger => $self->{logger} );
    %return = ( taskid => { value => $obj->get_mo_ref_value, type => $obj->get_mo_ref_type } );
    $self->{logger}->finish;
    return \%return;
}

sub update {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj('args', \%args);
    my %param = ();
    my $view = $self->values_to_view( type => 'ResourcePool', value => delete($args{moref_value}) );
    my $resourcepool = SamuAPI_resourcepool->new( view => $view, logger => $self->{logger} );
    $param{name} = delete($args{name}) if defined($args{name});
    $param{config} = $resourcepool->_resourcepool_resource_config_spec(%args) if ( keys %args);
    $self->{logger}->dumpobj('param', \%param);
    $resourcepool->{view}->UpdateConfig( %param );
    $self->{logger}->finish;
    return { update => 'success'};
}

sub move {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my $child_value = $args{child_value};
    my $child_type = $args{child_type};
    my $mo_ref = $self->create_moref( type => $child_type, value => $child_value) ;
    my $parent_value = $args{parent_value} || undef;
    eval {
        my $parent_view = undef;
        if (defined($parent_value) ) {
            $parent_view = $self->values_to_view( type=> 'ResourcePool', value => $parent_value );
        } else {
            $parent_view = $self->find_entity( view_type => 'ResourcePool', properties => ['name'], filter => { name => 'Resources'} );
        }
        $parent_view->MoveIntoResourcePool( list => [$mo_ref] );
    }; 
    if ($@) {
        $self->{logger}->dumpobj("error", $@);
        ExEntity::Move->throw( error => 'Problem during moving entity', entity => $child_value, parent => $parent_value );
    }
    $self->{logger}->finish;
# TODO nothing to return..maybe return success?
    return { status => "moved" };
}

sub create {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my $name = delete($args{name});
    my $parent_view;
    if ( defined($args{value}) ) {
        $parent_view = $self->values_to_view( value=>$args{value} , type => 'ResourcePool' );
    } else {
        $parent_view = $self->find_entity( view_type => 'ResourcePool', properties => ['name'], filter => { name => 'Resources'} );
    }
    my $parent = SamuAPI_resourcepool->new( view => $parent_view, logger=> $self->{logger} );
    my $spec = $parent->_resourcepool_resource_config_spec(%args);
    my $rp_moref;
    eval {
        $rp_moref = $parent->{view}->CreateResourcePool( name => $name, spec => $spec );
        $self->{logger}->dumpobj('rp_moref', $rp_moref);
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExTask::Error->throw( error => 'Error during Resource pool creation', number=> 'unknown', creator => (caller(0))[3] );
    }
    my $rp = SamuAPI_resourcepool->new( mo_ref => $rp_moref, logger => $self->{logger});
# TODO validate output and make it same as get
    my %return = ( $name => { type => $rp->get_mo_ref_type, value => $rp->get_mo_ref_value} );
    $self->{logger}->dumpobj('return', %return);
    $self->{logger}->finish;
    return \%return;
}

sub get_all {
    my $self = shift;
    $self->{logger}->start;
    my %result = ();
    my $rps = $self->find_entities( view_type => 'ResourcePool', properties => ['name']);
    for my $rp ( @{ $rps }) {
        my $obj = SamuAPI_resourcepool->new( view => $rp, logger => $self->{logger});
        $self->{logger}->dumpobj('obj', $obj);
        $result{$obj->get_mo_ref_value} = { name => $obj->get_name, value => $obj->get_mo_ref_value, type => $obj->get_mo_ref_type};
    }
    $self->{logger}->dumpobj( 'result', %result);
    $self->{logger}->finish;
    return \%result;
}

sub get_single {
    my ( $self, %args) = @_;
    $self->{logger}->start;
    my %result = ();
    my $view = $self->values_to_view( type=> 'ResourcePool', value => $args{moref_value});
    if ( $args{refresh}) {
        $view->RefreshRuntime;
    }
    my $resourcepool = SamuAPI_resourcepool->new( view => $view, logger => $self->{logger} );
    %result = %{ $resourcepool->get_info} ;
    if ( $result{parent_name} ) { 
        my $parent_view = $self->get_view( mo_ref => $result{parent_name}, properties => ['name'] );
        my $parent = SamuAPI_resourcepool->new( view => $parent_view, refresh => 0, logger=> $self->{logger} );
        $result{parent_name} = $parent->get_name; 
    }
    $self->{logger}->dumpobj( 'result', \%result );
    $self->{logger}->finish;
    return \%result;
}

####################################################################

package VCenter_folder;
use base 'VCenter';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    return $self;
}

sub get_all {
    my $self = shift;
    $self->{logger}->start;
    my %return = ();
    my $folders = $self->find_entities( view_type => 'Folder', properties => ['name'] );
    for my $folder_view ( @{ $folders } ) {
        my $obj = SamuAPI_folder->new( view => $folder_view, logger => $self->{logger} );
        $self->{logger}->dumpobj("folder", $obj);
        $return{$obj->get_mo_ref_value} = { name => $obj->get_name, value => $obj->get_mo_ref_value, type => $obj->get_mo_ref_type};
    }
    $self->{logger}->dumpobj("return", \%return);
    $self->{logger}->finish;
    return \%return;
}

sub get_single {
    my ( $self, %args) = @_;
    $self->{logger}->start;
    my %result = ();
    my $view = $self->values_to_view( type=> 'Folder', value => $args{moref_value});
    my $folder = SamuAPI_folder->new( view => $view, logger => $self->{logger} );
    %result = %{ $folder->get_info} ;
    if ( $result{parent_name} ) { 
        my $parent_view = $self->get_view( mo_ref => $result{parent_name}, properties => ['name'] );
        my $parent = SamuAPI_folder->new( view => $parent_view, logger=> $self->{logger} );
        $result{parent_name} = $parent->get_name; 
    }
    $self->{logger}->dumpobj( 'result', \%result );
    $self->{logger}->finish;
    return \%result;
}

sub create {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my $name = delete($args{name});
    my $parent_view;
    if ( defined($args{value}) ) {
        $parent_view = $self->values_to_view( value=>$args{value} , type => 'Folder' );
    } else {
        $parent_view = $self->find_entity( view_type => 'Folder', properties => ['name'], filter => { name => 'vm'} );
    }
    my $parent = SamuAPI_folder->new( view => $parent_view, logger=> $self->{logger} );
    my $folder_moref;
    eval {
        $folder_moref = $parent->{view}->CreateFolder( name => $name);
        $self->{logger}->dumpobj('folder_moref', $folder_moref);
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExTask::Error->throw( error => 'Error during Folder creation', number=> 'unknown', creator => (caller(0))[3] );
    }
    my $folder = SamuAPI_folder->new( mo_ref => $folder_moref, logger => $self->{logger});
# TODO validate output and make it same as get
    my %return = ( $name => { type => $folder->get_mo_ref_type, value => $folder->get_mo_ref_value} );
    $self->{logger}->dumpobj('return', %return);
    $self->{logger}->finish;
    return \%return;
}

sub destroy {
    my ($self,%args) = @_;
    $self->{logger}->start;
    my $task = undef;
    my %return= ();
    my $view = $self->values_to_view( %args );
    my $folder = SamuAPI_folder->new( view => $view, logger => $self->{logger} );
    if ( $folder->child_vms ne 0 ) {
        ExEntity::NotEmpty->throw( error => "Folder has child virtual machines", entity => $folder->get_name, count => $folder->child_vms );
    } elsif ( $folder->child_folders ne 0 ) {
        ExEntity::NotEmpty->throw( error => "Folder has child folders", entity => $folder->get_name, count => $folder->child_folders );
    }
    eval {
        $task = $folder->{view}->Destroy_Task;
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExTask::Error->throw( error => 'Error during task', number=> 'unknown', creator => (caller(0))[3] );
    }
    $self->{logger}->dumpobj( 'task', $task);
    my $obj = SamuAPI_task->new( mo_ref => $task, logger => $self->{logger} );
    %return = ( taskid => { value => $obj->get_mo_ref_value, type => $obj->get_mo_ref_type } );
    $self->{logger}->finish;
    return \%return;
}

sub move {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my $child_value = $args{child_value};
    my $child_type = $args{child_type};
    my $mo_ref = $self->create_moref( type => $child_type, value => $child_value) ;
    my $parent_value = $args{parent_value} || undef;
    eval {
        my $parent_view = undef;
        if (defined($parent_value) ) {
            $parent_view = $self->values_to_view( type=> 'Folder', value => $parent_value );
        } else {
            $parent_view = $self->find_entity( view_type => 'Folder', properties => ['name'], filter => { name => 'vm'} );
        }
        $parent_view->MoveIntoFolder( list => [$mo_ref] );
    }; 
    if ($@) {
        $self->{logger}->dumpobj("error", $@);
        ExEntity::Move->throw( error => 'Problem during moving entity', entity => $child_value, parent => $parent_value );
    }
    $self->{logger}->finish;
# TODO nothing to return..maybe return success?
    return { status => "moved" };
}

####################################################################

package VCenter_hostnetwork;
use base 'VCenter';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    return $self;
}

sub get_all {
    my $self = shift;
    $self->{logger}->start;
    my $result = ();
    my $networks = $self->find_entities( view_type => 'Network', properties => ['summary'] );
    for my $network ( @{ $networks } ) {
        my $obj = SamuAPI_network->new( view => $network, logger => $self->{logger});
        if ( $obj->get_mo_ref_type eq 'Network' ) {
            push( @{ $result }, $network );
        }
    }
    $self->{logger}->dumpobj('result', $result);
    $self->{logger}->finish;
    return $result;
}

####################################################################

package VCenter_dvp;
use base 'VCenter';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    return $self;
}

sub create {
    my ($self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj('args', \%args);
    my $task = ();
    my $ticket = delete($args{ticket});
    my $switch_value = delete($args{switch});
    my $func = delete($args{func});
    my $name_base = $ticket . "-" . $func . "-";
    my $name = $name_base . &Misc::rand_3digit;
    my $view = $self->find_entity( view_type => 'DistributedVirtualPortgroup', properties => ['name'], filter => { name => $name } );
    while ( defined($view) ) {
        $name = $name_base . &Misc::rand_3digit;
        $view = $self->find_entity( view_type => 'DistributedVirtualPortgroup', properties => ['name'], filter => { name => $name } );
    }
    my $switch_mo_ref = $self->create_moref( value => $switch_value, type=> 'DistributedVirtualSwitch' );
    my $switch_view = $self->get_view( mo_ref => $switch_mo_ref);
    my $network_folder = $self->find_entity( view_type => 'Folder', properties => ['name'], filter => { name => 'network' });
    my $spec = DVPortgroupConfigSpec->new( name        => $name, type        => 'earlyBinding', numPorts    => 20, description => "Port group");
    eval {
        $task = $switch_view->AddDVPortgroup_Task( spec => $spec );
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExTask::Error->throw( error => 'Error during task', number=> 'unknown', creator => (caller(0))[3] );
    }
    $self->{logger}->dumpobj('task', $task);
    $self->{logger}->finish;
    return $task;
}

sub get_all {
    my $self = shift;
    $self->{logger}->start;
    my $result = ();
    $result = $self->find_entities( view_type => 'DistributedVirtualPortgroup', properties => ['summary', 'key'] );
    $self->{logger}->dumpobj('result', $result);
    $self->{logger}->finish;
    return $result;
}

####################################################################

package VCenter_dvs;
use base 'VCenter';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    return $self;
}

sub create {
    my ($self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj('args', \%args);
    my $task = ();
    my $ticket = delete($args{ticket});
    my $host_mo_ref_value = delete($args{host});
    my $host = $self->get_view( mo_ref => $self->create_moref( value => $host_mo_ref_value, type => 'HostSystem' ) );
    my $network_folder = $self->find_entity( view_type => 'Folder', properties => ['name'], filter => { name => 'network' });
    my $hostspec = DistributedVirtualSwitchHostMemberConfigSpec->new( operation           => 'add', maxProxySwitchPorts => 99, host                => $host);
    my $dvsconfigspec = DVSConfigSpec->new( name        => $ticket, maxPorts    => 300, description => "DVS for ticket $ticket", host        => [$hostspec]);
    my $spec = DVSCreateSpec->new( configSpec => $dvsconfigspec );
    eval {
        $task = $network_folder->CreateDVS_Task( spec => $spec );
    };
    if ( $@ ) {
        $self->{logger}->dumpobj('error', $@);
        ExTask::Error->throw( error => 'Error during task', number=> 'unknown', creator => (caller(0))[3] );
    }
    $self->{logger}->dumpobj('task', $task);
    $self->{logger}->finish;
    return $task;
}

sub get_all {
    my $self = shift;
    $self->{logger}->start;
    my $result = ();
    $result = $self->find_entities( view_type => 'DistributedVirtualSwitch', properties => ['summary', 'portgroup'] );
    $self->{logger}->dumpobj('result', $result);
    $self->{logger}->finish;
    return $result;
}

####################################################################

package VCenter_vm;
use base 'VCenter';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    return $self;
}

sub _linked_clones {
    my ( $self, %args) = @_;
    $self->{logger}->start;
    my $snapshot = $self->get_view( mo_ref => $args{vm}->last_snapshot_moref );
    my $disk;
    for my $device ( @{ $snapshot->{'config'}->{'hardware'}->{'device'} } ) {
        $self->{logger}->dumpobj('device', $device);
        if ( defined( $device->{'backing'}->{'fileName'} ) ) {
#TODO IF machine has multiple disks and multiple snapshots this will return incorrectly. According to standards it shouldn't be a good practice though
            $disk = $device->{'backing'}->{'fileName'};
            last;
        }
    }
    my @vms = @{ $self->_find_vms_with_disk( disk => $disk, template => $args{vm}->get_name)};
    $self->{logger}->dumpobj( 'vms', \@vms);
    $self->{logger}->finish;
    return \@vms;
}
 
sub _find_vms_with_disk {
    my ( $self, %args) = @_;
    $self->{logger}->start;
# TODO push this to the model
    my @vms           = ();
    my $machine_views = $self->find_entities( view_type  => 'VirtualMachine', properties => [ 'layout.disk', 'name','summary' ]);
    for my $machine_view (@$machine_views) {
        my $machine = SamuAPI_virtualmachine->new( view => $machine_view, logger => $self->{logger});
        if ( $machine->get_name eq $args{template}) {
            next;
        }
# Move this to the Model aswell? TODO
        my $disks = $machine->get_property('layout.disk');
        for my $vdisk (@{ $disks } ) {
            for my $diskfile ( @{ $vdisk->{'diskFile'} } ) {
                if ( $diskfile eq $args{disk} ) {
                    push( @vms, { name => $machine_view->{name}, mo_ref => $machine_view->{mo_ref}->value });
                }
            }
        }
    }
    $self->{logger}->dumpobj( 'vms', \@vms);
    $self->{logger}->finish;
    return \@vms;
}

sub get_templates {
    my $self = shift;
    $self->{logger}->start;
    my $result = {};
    my $vms = $self->find_entities( view_type => 'VirtualMachine', properties => ['summary'], filter => { 'config.template' => 'true'  }  );
    for my $vm (@$vms) {
        my $obj = SamuAPI_template->new( view => $vm, logger=> $self->{logger});
        $result->{$obj->get_mo_ref_value} = { name => $obj->get_name, value => $obj->get_mo_ref_value, type => $obj->get_mo_ref_type};
    }
    $self->{logger}->dumpobj('result', $result);
    $self->{logger}->finish;
    return $result;
}

sub get_template {
    my ($self, %args) = @_;
    $self->{logger}->start;
    my $result = {};
    my $view = $self->values_to_view( value => $args{value}, type => 'VirtualMachine');
    my $obj = SamuAPI_template->new( view => $view, logger=> $self->{logger});
    $result = $obj->get_info;
    $result->{active_linked_clones} = $self->_linked_clones( vm => $obj);
    $self->{logger}->dumpobj('result', $result);
    $self->{logger}->finish;
    return $result;
}
1

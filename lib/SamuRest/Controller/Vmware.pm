package SamuRest::Controller::Vmware;
use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'SamuRest::ControllerX::REST'; }

use SamuAPI::Common;


=pod

=head1 begin

=head2 PURPOSE

The purpose of the begin is to create the logging object used as $c->log

=cut

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

This Controller is responsilbe for the vmware namespace

=head1 vmwareBase

=head2 PURPOSE

Base sub, which checks if the user has a valid session

=cut

sub vmwareBase : Chained('/') : PathPart('vmware') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    my $user_id = $self->__is_logined($c);
    return $self->__error( $c, "You're not login yet." ) unless $user_id;
    $c->log->debug1("Logged in user_id=>'$user_id'");
}

=pod

=head1 loginBase

=head2 PURPOSE

This sub loads the stored session into the stash for the later use
If vim_id is specified as parameter it will load that id session for the request
After each request the last_used timestamp will be updated

=cut

sub loginBase : Chained('vmwareBase') : PathPart('') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    $c->log->start;
    $c->log->debug('Check if user has logged in previously in session and has an active session');
    if ( !$c->session->{__vim_login} ) {
        $self->__error( $c, "Login to VCenter first" );
    }
    if ( !defined( $c->session->{__vim_login}->{sessions}->[ $c->session->{__vim_login}->{active} ])) {
        $self->__error( $c, "No active login session to vcenter" );
    }
    my $vim_id = $c->req->params->{vim_id} || $c->session->{__vim_login}->{active}; 
    my $active_session = $c->session->{__vim_login}->{sessions}->[ $vim_id ];
    $c->log->dumpobj( "active_session", $active_session );
    eval {
        my $epoch = $c->datetime->epoch;
        my $last_used = $active_session->{last_used};
        if ( defined($last_used) and (( $epoch - $last_used) >1599) ) {
            $c->log->debug('Session has expired');
            ExConnection::SessionExpire->throw( error => "Session expired", time => $last_used );
        }
        my $VCenter = VCenter->new( vcenter_url => $active_session->{vcenter_url}, sessionfile => $active_session->{vcenter_sessionfile}, logger => $c->log);
        $VCenter->loadsession_vcenter;
        $c->stash->{vim} = $VCenter;
        $c->session->{__vim_login}->{sessions}->[ $vim_id ]->{last_used} = $epoch;
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
    $c->log->finish;
}

=pod

=head1 connection

=head2 PURPOSE

The ActionClass for connection functions

=cut

sub connection : Chained('vmwareBase') : PathPart('') : Args(0) : ActionClass('REST') {
    my ( $self, $c ) = @_;
    $c->log->start;
    if ( !$c->session->{__vim_login} ) {
        $c->session->{__vim_login} = { active => '0', sessions => [] };
    }
    $c->log->finish;
}

=pod

=head1 connection_GET

=head2 PURPOSE

This function returns all active session and their information

=head2 PARAMETERS

=over

=back

=head2 RETURNS

Return a JSON on success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub connection_GET {
    my ( $self, $c ) = @_;
    $c->log->start;
    my $return = {};
    if ( !@{ $c->session->{__vim_login}->{sessions} } ) {
        $return->{connections} = "";
    } else {
        for my $num ( 0 .. $#{ $c->session->{__vim_login}->{sessions} } ) {
            $return->{connections}->{$num} = ();
            for my $key ( keys $c->session->{__vim_login}->{sessions}->[$num]) {
                $return->{connections}->{$num}->{$key} = $c->session->{__vim_login}->{sessions}->[$num]->{$key};
            }
        }
        $return->{active} = $c->session->{__vim_login}->{active};
    }
    $c->log->dumpobj('return', $return);
    $c->log->finish;
    return $self->__ok( $c, $return );
}

=pod

=head1 connection_POST

=head2 PURPOSE

This subroutine creates new sessions to a VCenter

=head2 PARAMETERS

=over

=item vcenter_username

Username used to connect to VCenter

=item vcenter_password

Password used to connect  to VCenter

=item vcenter_url

Url to VCenter

=back

=head2 RETURNS

Returns logon information: session_id, timestamp

=head2 DESCRIPTION

If no username/password/url is given then the default value from configs table is used. If nothing is given an error is thrown

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.perlsdk.pg.doc_50%2Fviperl_advancedtopics.5.6.html

=cut

sub connection_POST {
    my ( $self, $c ) = @_;
    $c->log->start;
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
    my $epoch = $c->datetime->epoch;
    eval {
        $VCenter = VCenter->new( vcenter_url      => $vcenter_url, vcenter_username => $vcenter_username, vcenter_password => $vcenter_password, logger => $c->log);
        $VCenter->connect_vcenter;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    } else {
        my $sessionfile = $VCenter->savesession_vcenter;
        push( @{ $c->session->{__vim_login}->{sessions} }, { vcenter_url         => $vcenter_url, vcenter_sessionfile => $sessionfile, vcenter_username => $vcenter_username, last_used =>    $epoch, });
    }
# TODO maybe validate if we delete one and recreate a wrong index can be added here
    $c->session->{__vim_login}->{active} = $#{ $c->session->{__vim_login}->{sessions} };
    $c->log->dumpobj('vcenter', $VCenter);
    $c->log->finish;
    my $return = { vim_login => "success", id        => $#{ $c->session->{__vim_login}->{sessions} }, time_stamp => $epoch };
    return $self->__ok( $c, $return);
}

=pod

=head1 connection_DELETE

=head2 PURPOSE

This subroutine logs off a session for closing server side resource, and to mitigate session reuse for unauthorized users

=head2 PARAMETERS

=over

=item id

ID of the session which needs to be delete

=back

=head2 RETURNS

True on success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.perlsdk.pg.doc_50%2Fviperl_advancedtopics.5.6.html

=cut

sub connection_DELETE {
    my ( $self, $c ) = @_;
    $c->log->start;
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
    $c->log->finish;
    return $self->__ok( $c, { $id => "deleted" } );
}

=pod

=head1 connection_PUT

=head2 PURPOSE

This subroutine changes the active session

=head2 PARAMETERS

=over

=item id

The session that should be marked as active

=back

=head2 RETURNS

A JSON with the active sessionid

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub connection_PUT {
    my ( $self, $c ) = @_;
    $c->log->start;
    my $id     = $c->req->params->{id};
    if ( $id < 0 || $id > $#{ $c->session->{__vim_login}->{sessions} } ) {
        return $self->__error( $c, "Session ID out of range" );
    }
    $c->session->{__vim_login}->{active} = $id;
    $c->log->finish;
    return $self->__ok( $c, { active => $id } );
}

=pod

=head1 folderBase

=head2 PURPOSE

Base sub for folder queries

=cut

sub folderBase : Chained('loginBase') : PathPart('folder') : CaptureArgs(0) { }

=pod

=head1 folders

=head2 PURPOSE

The ActionClass for folders functions
We cast the VCenter object to a VCenter_folder object to narrow scope

=cut

sub folders : Chained('folderBase') : PathPart('') : Args(0) : ActionClass('REST') {
    my ( $self, $c ) = @_;
    bless $c->stash->{vim}, 'VCenter_folder';
}

=pod

=head1 folders_GET

=head2 PURPOSE

This subroutine returns a list of the folders on the VCenter

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A list of all folders on the VCenter, each element has information about : moref_value, name, moref_type

=head2 DESCRIPTION

The moref_value can be used to identify the object later uniqely.

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub folders_GET {
    my ( $self, $c ) = @_;
    $c->log->start;
    my $result= {};
    eval {
        $result = $c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    $c->log->dumpobj('result', $result);
    $c->log->start;
    return $self->__ok( $c, $result );
}

=pod

=head1 folders_PUT

=head2 PURPOSE

This subroutine moves an object into the folder

=head2 PARAMETERS

=over

=item child_value

The moref_value of the child object to move

=item child_type

The moref_type of the child object to move

=item parent_value

The moref_value of the parent object that is the destination, if not specified the object is moved to root directory

=back

=head2 RETURNS

Returns JSON of success:
{ status => "moved" }

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.Folder.html#moveInto

=cut

sub folders_PUT {
    my ( $self, $c) = @_;
    $c->log->start;
    my $params = $c->req->params;
    my $result= {};
    eval {
        $result = $c->stash->{vim}->move( %{ $params } );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    $c->log->dumpobj('result', $result);
    $c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 folders_POST

=head2 PURPOSE

This subroutine creates a folder in the root directory
This function is forwarded to folder_POST with moref_value set to the root folder

=cut

sub folders_POST {
    my ( $self, $c ) = @_;
    $c->log->start;
    # This part can be a violation of the MVC model build, since the 2nd Controller should generate this part.
    # If I would copy code here, that would be code duplication, which I want to evade
    my $view = $c->stash->{vim}->find_entity( view_type => 'Folder', properties => ['name'], filter => { name => 'vm'} );
    my $parent = SamuAPI_folder->new( view => $view, logger => $c->log);
    $c->log->finish;
    $self->folder_POST($c, $parent->get_mo_ref_value);
}

=pod

=head1 folder

=head2 PURPOSE

The ActionClass for folder functions

=cut

sub folder : Chained('folderBase') : PathPart('') : Args(1) : ActionClass('REST') { }

=pod

=head1 folder_GET

=head2 PURPOSE

This subroutine returns information about a folder

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

Returns information in JSON: parent_moref_value, parent_moref_type, status, children folder count, children virtualmachine count, moref_value, moref_type

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.Folder.html

=cut

sub folder_GET {
    my ( $self, $c, $mo_ref_value ) = @_;
    $c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_single( moref_value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    $c->log->dumpobj('result', $result);
    $c->log->finish;
    return $self->__ok( $c, $result);
}

=pod

=head1 folder_DELETE

=head2 PURPOSE

Destroy the given folder object

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ManagedEntity.html#destroy

=cut

sub folder_DELETE {
    my ( $self, $c, $mo_ref_value ) = @_;
    $c->log->start;
    my $return = {};
    eval {
        $return = $c->stash->{vim}->destroy( value => $mo_ref_value, type => 'Folder');
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
    $c->log->dumpobj('result', $return);
    $c->log->finish;
    return $self->__ok( $c, $return );

}

=pod

=head1 folder_POST

=head2 PURPOSE

This subroutine creates a folder in the specified parent folder

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI, this is going to be the parent folder

=item name

The requested name of the folder

=back

=head2 RETURNS

A JSON with the moref of the created folder

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.Folder.html#createFolder

=cut

sub folder_POST {
    my ( $self, $c, $mo_ref_value ) = @_;
    $c->log->start;
    my $result = {};
    my %create_param = ( name => $c->req->params->{name} );
    $create_param{value} = $mo_ref_value;
# TODO if multiple computeresources with same mo_ref how can they be distingueshed
    eval {
        $result = $c->stash->{vim}->create( %create_param );
    };
    if ($@) {
		$c->log->dumpobj('error',$@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result',$result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 resourcepoolBase

=head2 PURPOSE

Base sub for resourcepool queries

=cut

sub resourcepoolBase : Chained('loginBase') : PathPart('resourcepool') :
  CaptureArgs(0) { }

=pod

=head1 resourcepools

=head2 PURPOSE

The ActionClass for resourcepools functions
We cast the VCenter object to a VCenter_resourcepool object to narrow scope

=cut

sub resourcepools : Chained('resourcepoolBase') : PathPart('') : Args(0) : ActionClass('REST') {
    my ( $self, $c ) = @_;
    bless $c->stash->{vim}, 'VCenter_resourcepool';
}

=pod

=head1 resourcepools_GET

=head2 PURPOSE

This subroutine returns a list of resource pools

=head2 PARAMETERS

=over

=item refresh

Force refreshes the runtime information of a Resourcepool

=back

=head2 RETURNS

Return a JSON with resourecepool information: moref_value, moref_type, name

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub resourcepools_GET {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $refresh = $c->req->params->{refresh} || 0;
    my $result= {};
    eval {
        $result = $c->stash->{vim}->get_all( refresh => $refresh);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result',$result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 resourcepools_POST

=head2 PURPOSE

This subroutine creates a resourcepool in the root directory
The function is directed to resourcepool_POST with moref_value set to the root directory

=cut

sub resourcepools_POST {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $view = $c->stash->{vim}->find_entity( view_type => 'ResourcePool', properties => ['name'], filter => { name => 'Resources'} );
    my $parent = SamuAPI_resourcepool->new( view => $view, logger => $c->log);
	$c->log->finish;
    $self->resourcepool_POST($c, $parent->get_mo_ref_value);
}

=pod

=head1 resourcepools_PUT

=head2 PURPOSE

This subroutine moves an object into a folder

=head2 PARAMETERS

=over

=item child_value

The moref_value of the object to move

=item child_type

The moref_type of the object to move

=item parent_value

The moref_value of the destination resourcepool

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html#moveInto

=cut

sub resourcepools_PUT {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->move( %{ $c->req->params } );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result',$result);
	$c->log->finish;
    return $self->__ok( $c, $result);
}

=pod

=head1 resourcepool

=head2 PURPOSE

The ActionClass for resourcepool functions

=cut

sub resourcepool : Chained('resourcepoolBase') : PathPart('') : Args(1) : ActionClass('REST') { }

=pod

=head1 resourcepool_GET

=head2 PURPOSE

This subroutine returns information about a resourcepool

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item refresh

Refreshes runtime information of a resourcepool

=back

=head2 RETURNS

Return JSON with resourcepool information: name, parent moref value, parent moref type, child resourcepool count, child virtualmachine count, moref value, moref type
runtime information: status, memory usage, cpu usage

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html

=cut

sub resourcepool_GET {
    my ( $self, $c, $mo_ref_value ) = @_;
	$c->log->start;
    my $result = {};
    my $refresh = $c->req->params->{refresh} || 0;
    eval {
        $result = $c->stash->{vim}->get_single( refresh => $refresh, moref_value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result);
}

=pod

=head1 resourcepool_DELETE

=head2 PURPOSE

Destroy a resourcepool object

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ManagedEntity.html#destroy

=cut

sub resourcepool_DELETE {
    my ( $self, $c, $mo_ref_value ) = @_;
	$c->log->start;
    my $return = {};
    eval {
        $return = $c->stash->{vim}->destroy( value => $mo_ref_value, type => 'ResourcePool');
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $return);
	$c->log->finish;
    return $self->__ok( $c, $return );
}

=pod

=head1 resourcepool_PUT

=head2 PURPOSE

This subroutine changes settings of a resource pool

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item cpu_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item cpu_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item cpu_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MHz for CPU.

=item cpu_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MHz for CPU.

=item memory_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item memory_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MB for memory.

=item memory_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item memory_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MB for memory.

=item shares_level

The allocation level. The level is a simplified view of shares. Values: high, normal low
high => Shares = 2000 * nmumber of virtual CPUs, 20 * virtual machine memory size in megabytes
normal => Shares = 10 * virtual machine memory size in megabytes, 1000 * number of virtual CPUs
low => Shares = 5 * virtual machine memory size in megabytes, 500 * number of virtual CPUs

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html#updateConfig

=cut

sub resourcepool_PUT {
    my ( $self, $c, $mo_ref_value ) = @_;
	$c->log->start;
    my $result = {};
    my %param = %{ $c->req->params };
    $param{moref_value} = $mo_ref_value;
    eval {
        $result = $c->stash->{vim}->update( %param );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 resourcepool_POST

=head2 PURPOSE

This function creates a resourcepool in the specified resourcepool.

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item cpu_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item cpu_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item cpu_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MHz for CPU.

=item cpu_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MHz for CPU.

=item memory_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item memory_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MB for memory.

=item memory_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item memory_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MB for memory.

=item shares_level

The allocation level. The level is a simplified view of shares. Values: high, normal low
high => Shares = 2000 * nmumber of virtual CPUs, 20 * virtual machine memory size in megabytes
normal => Shares = 10 * virtual machine memory size in megabytes, 1000 * number of virtual CPUs
low => Shares = 5 * virtual machine memory size in megabytes, 500 * number of virtual CPUs

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html#createResourcePool

=cut

sub resourcepool_POST {
    my ( $self, $c, $mo_ref_value ) = @_;
	$c->log->start;
    my $result = {};
    my %create_param = %{ $c->req->params };
    $create_param{value} = $mo_ref_value;
    eval {
        $result = $c->stash->{vim}->create( %create_param );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 taskBase

=head2 PURPOSE

Base sub for task queries

=cut

sub taskBase: Chained('loginBase'): PathPart('task') : CaptureArgs(0) { }

=pod

=head1 tasks

=head2 PURPOSE

The ActionClass for tasks functions

=cut

sub tasks : Chained('taskBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 tasks_GET

=head2 PURPOSE

Returns all tasks from recentTasks of the Taskmanager

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON list with all tasks morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.wssdk.apiref.doc_50%2Fvim.TaskManager.html

=cut

sub tasks_GET {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_tasks;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 task

=head2 PURPOSE

The ActionClass for task functions

=cut

sub task : Chained(taskBase) : PathPart(''): Args(1) : ActionClass('REST') { }

=pod

=head1 task_GET

=head2 PURPOSE

This subroutine returns information about a subroutine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON containing information about a task: cancelable, cancelled, startTime, completeTime, entityName, entity moref, queueTime, key, state, description, name, reason, progress

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

Need to implement further detections for reason

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.Task.html

=cut

sub task_GET {
    my ( $self, $c ,$mo_ref_value ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_task( value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 task_DELETE

=head2 PURPOSE

This subroutine cancels a task

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.Task.html#cancel

=cut

sub task_DELETE {
    my ( $self, $c ,$mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->cancel_task( value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 ticketqueryBase

=head2 PURPOSE

Base sub for ticket queries

=cut

sub ticketqueryBase : Chained('loginBase'):PathPart('ticket'): CaptureArgs(0) { }

=pod

=head1 ticketsquery

=head2 PURPOSE

The ActionClass for ticketsquery functions

=cut

sub ticketsquery : Chained('ticketqueryBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 ticketsquery_GET

=head2 PURPOSE

This function returns a list with all active tickets provisioned

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with a list of tickets, and their connected virtualmachines moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub ticketsquery_GET {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_tickets;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 ticketquery

=head2 PURPOSE

The ActionClass for ticketquery functions

=cut

sub ticketquery: Chained('ticketqueryBase') : PathPart(''): Args(1) : ActionClass('REST') { }

=pod

=head1 ticketquery_GET

=head2 PURPOSE

This function returns information about virtualmachines morefs attached to a ticket

=head2 PARAMETERS

=over

=item ticket

This option is part of the URL

=back

=head2 RETURNS

A JSON containing the virtualmachines morefs attached to a ticket

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub ticketquery_GET {
    my ( $self, $c, $ticket ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_ticket( ticket => $ticket);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );

}

=pod

=head1 userqueryBase

=head2 PURPOSE

Base sub for user queries

=cut

sub userqueryBase : Chained('loginBase'):PathPart('user'): CaptureArgs(0) { }

=pod

=head1 usersquery

=head2 PURPOSE

The ActionClass for usersquery functions

=cut

sub usersquery : Chained('userqueryBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 usersquery_GET

=head2 PURPOSE

This function collects all virtualmachines morefs attached to a username

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON containing a list of usernames and their attached vms

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub usersquery_GET {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_users;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 userquery

=head2 PURPOSE

The ActionClass for userquery functions

=cut

sub userquery: Chained('userqueryBase') : PathPart(''): Args(1) : ActionClass('REST') { }

=pod

=head1 userquery_GET

=head2 PURPOSE

This function retrieves all virtualmachine morefs attached to a username

=head2 PARAMETERS

=over

=item username

This is part of the URL

=back

=head2 RETURNS

A JSON containing the virtualmachine morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub userquery_GET {
    my ( $self, $c, $username ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_user( username => $username);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 templateBase

=head2 PURPOSE

Base sub for template queries
We cast the VCenter object to a VCenter_vm object to narrow scope

=cut

sub templateBase: Chained('loginBase'): PathPart('template') : CaptureArgs(0) { 
    my ( $self, $c ) = @_;
    bless $c->stash->{vim}, 'VCenter_vm';
}

=pod

=head1 templates

=head2 PURPOSE

The ActionClass for templates functions

=cut

sub templates : Chained('templateBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 templates_GET

=head2 PURPOSE

This function gets all useable templates on the VCenter

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with morefs to the templates, and their name

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

The find_entity_views returns all virtualmachine objects with template flag on true

=head2 SEE ALSO

=cut

sub templates_GET {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_templates;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 template

=head2 PURPOSE

The ActionClass for template functions

=cut

sub template : Chained(templateBase) : PathPart(''): Args(1) : ActionClass('REST') { }

=pod

=head1 template_GET

=head2 PURPOSE

This function returns information about templates

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with infromation attached to template: all active linked clones, name, vmpath, memory size in MB, number of cpus, status, vm tools status, moref 

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

Linked clone is calculated from last snapshots disk, since that is the base for all snapshots. I do not allow multiple clone bases from different clones since it will cause a huge confusion and diversion

=head2 SEE ALSO

=cut

sub template_GET {
    my ( $self, $c ,$mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_template( value=> $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c,$result );
}

=pod

=head1 template_DELETE

=head2 PURPOSE

This function unlinks all children from a template

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with list of virtualmachines moref_values, and the attached task moref for unlinking task

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#promoteDisks

=cut

sub template_DELETE {
    my ( $self, $c ,$mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->promote_template(value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 datastoreBase

=head2 PURPOSE

Base sub for datastore queries
We cast the VCenter object to a VCenter_datastore object to narrow scope

=cut

sub datastoreBase: Chained('loginBase'): PathPart('datastore') : CaptureArgs(0) { 
    my ( $self, $c) = @_;
    bless $c->stash->{vim}, 'VCenter_datastore';
}

=pod

=head1 datastores

=head2 PURPOSE

The ActionClass for datastores functions

=cut

sub datastores : Chained('datastoreBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 datastores_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub datastores_GET {
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
	eval {
        $result = $c->stash->{vim}->get_all;
	};
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 datastore

=head2 PURPOSE

The ActionClass for datastore functions

=cut

sub datastore : Chained('datastoreBase'): PathPart(''): Args(1) : ActionClass('REST') {}

=pod

=head1 datastore_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub datastore_GET {
    my ( $self, $c ,$mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
	eval {
        $result = $c->stash->{vim}->get_single( value=> $mo_ref_value );
	};
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 networkBase

=head2 PURPOSE

Base sub for network queries

=cut

sub networkBase: Chained('loginBase'): PathPart('network') : CaptureArgs(0) { }

=pod

=head1 networks

=head2 PURPOSE

The ActionClass for networks functions

=cut

sub networks : Chained('networkBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 networks_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

We cast the VCenter object multiple times to always be in the required scope

=head2 SEE ALSO

=cut

sub networks_GET {
    my ( $self, $c ) = @_;
	$c->log->start;
    my $result = { dvp => {}, switch => {}, hostnetwork => {} };
    eval {
        bless $c->stash->{vim}, 'VCenter_dvs';
        $result->{switch} = $c->stash->{vim}->get_all;
        bless $c->stash->{vim}, 'VCenter_dvp';
        $result->{dvp} = $c->stash->{vim}->get_all;
        bless $c->stash->{vim}, 'VCenter_hostnetwork';
        $result->{hostnetwork} = $c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 switch_base

=head2 PURPOSE

Base sub for switch queries
We cast the VCenter object to a VCenter_dvs object to narrow scope

=cut

sub switch_base : Chained(networkBase) : PathPart('switch'): CaptureArgs(0) { 
    my ( $self, $c) = @_;
    bless $c->stash->{vim}, 'VCenter_dvs';
}

=pod

=head1 switches

=head2 PURPOSE

The ActionClass for switches functions

=cut

sub switches : Chained('switch_base'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 switches_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub switches_GET {
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 switches_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub switches_POST{
    my ($self, $c) = @_;
	$c->log->start;
    my $params = $c->req->params;
    my $ticket = $params->{ticket};
    my $host = $params->{host};
    my $result = {};
    eval {
        $result = $c->stash->{vim}->create( ticket => $ticket, host => $host );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 switch

=head2 PURPOSE

The ActionClass for switch functions

=cut

sub switch : Chained('switch_base'): PathPart(''): Args(1) : ActionClass('REST') { }

=pod

=head1 switch_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub switch_GET {
    my ( $self, $c, $mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_single( value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 switch_DELETE

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub switch_DELETE {
    my ( $self, $c, $mo_ref_value) =@_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->destroy( value => $mo_ref_value);
    };
    if ( $@ ) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 switch_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub switch_PUT {
    my ( $self, $c, $mo_ref_value) =@_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->update( %{ $c->req->params} );
    };
    if ( $@ ) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 dvp_base

=head2 PURPOSE

Base sub for dvp queries
We cast the VCenter object to a VCenter_dvp object to narrow scope

=cut

sub dvp_base : Chained(networkBase) : PathPart('dvp'): CaptureArgs(0) { 
    my ( $self, $c) = @_;
    bless $c->stash->{vim}, 'VCenter_dvp';
}

=pod

=head1 dvps

=head2 PURPOSE

The ActionClass for dvps functions

=cut

sub dvps : Chained('dvp_base'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 dvps_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub dvps_GET {
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 dvps_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub dvps_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $params = $c->req->params;
    my $ticket = $params->{ticket};
    my $switch = $params->{switch};
    my $func = $params->{func};
    my $result = {};
    eval {
        $result = $c->stash->{vim}->create( ticket => $ticket, switch => $switch, func => $func );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 dvp

=head2 PURPOSE

The ActionClass for dvp functions

=cut

sub dvp : Chained('dvp_base'): PathPart(''): Args(1) : ActionClass('REST') { }

=pod

=head1 dvp_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub dvp_GET {
    my ( $self, $c, $mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_single( value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 dvp_DELETE

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub dvp_DELETE {
    my ( $self, $c, $mo_ref_value) =@_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->destroy( value => $mo_ref_value);
    };
    if ( $@ ) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 dvp_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub dvp_PUT {
    my ( $self, $c, $mo_ref_value) =@_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->update( %{ $c->req->params} );
    };
    if ( $@ ) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );

}

=pod

=head1 hostnetwork_base

=head2 PURPOSE

Base sub for hostnetwork queries
We cast the VCenter object to a VCenter_hostnetwork object to narrow scope

=cut

sub hostnetwork_base : Chained(networkBase) : PathPart('hostnetwork'): CaptureArgs(0) { 
    my ( $self, $c) = @_;
    bless $c->stash->{vim}, 'VCenter_hostnetwork';
}

=pod

=head1 hostnetworks

=head2 PURPOSE

The ActionClass for hostnetworks functions

=cut

sub hostnetworks : Chained('hostnetwork_base'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 hostnetworks_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub hostnetworks_GET{
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 hostnetwork

=head2 PURPOSE

The ActionClass for hostnetwork functions

=cut

sub hostnetwork : Chained('hostnetwork_base'): PathPart(''): Args(1) : ActionClass('REST') { }

=pod

=head1 hostnetwork_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub hostnetwork_GET {
    my ( $self, $c, $mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_single( value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 hostBase

=head2 PURPOSE

Base sub for host queries
We cast the VCenter object to a VCenter_host object to narrow scope

=cut

sub hostBase: Chained('loginBase'): PathPart('host') : CaptureArgs(0) { 
    my ( $self, $c) = @_;
    bless $c->stash->{vim}, 'VCenter_host';
}

=pod

=head1 hosts

=head2 PURPOSE

The ActionClass for hosts functions

=cut

sub hosts : Chained('hostBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 hosts_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub hosts_GET {
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result =  $c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 host

=head2 PURPOSE

The ActionClass for host functions

=cut

sub host : Chained('hostBase'): PathPart(''): Args(1) : ActionClass('REST') {}

=pod

=head1 host_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub host_GET {
    my ( $self, $c, $mo_ref_value) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_single(value => $mo_ref_value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 vmsBase

=head2 PURPOSE

Base sub for vms queries
We cast the VCenter object to a VCenter_vm object to narrow scope

=cut

sub vmsBase: Chained('loginBase'): PathPart('vm') : CaptureArgs(0) { 
    my ( $self, $c) = @_;
    bless $c->stash->{vim}, 'VCenter_vm';
}

=pod

=head1 vms

=head2 PURPOSE

The ActionClass for vms functions

=cut

sub vms : Chained('vmsBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 vms_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub vms_GET {
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $$c->stash->{vim}->get_all;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 vms_POST

=head2 PURPOSE

This subrotuine would create an empty VM

=head2 PARAMETERS

=over

=back

=head2 RETURNS

=head2 DESCRIPTION

Currently not implemented

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub vms_POST {
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = {Status => "Not implemented"};
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 vmBase

=head2 PURPOSE

Base sub for vm queries
=cut

sub vmBase: Chained('vmsBase'): PathPart('') : CaptureArgs(1) {
    my ($self, $c, $mo_ref_value) = @_;
    $c->stash->{ mo_ref_value } = $mo_ref_value
}

=pod

=head1 vm

=head2 PURPOSE

The ActionClass for vm functions

=cut

sub vm : Chained('vmBase'): PathPart(''): Args(0) : ActionClass('REST') {}

=pod

=head1 vm_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub vm_GET{
    my ( $self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_single( moref_value => $c->stash->{mo_ref_value} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 vm_DELETE

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub vm_DELETE {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->destroy( moref_value => $c->stash->{mo_ref_value} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 vm_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub vm_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
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
        $result = $c->stash->{vim}->clone_vm( %$params);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 cpu

=head2 PURPOSE

The ActionClass for cpu functions

=cut

sub cpu : Chained('vmBase'): PathPart('cpu'): Args(0) : ActionClass('REST') {}

=pod

=head1 cpu_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub cpu_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        my $ret = $c->stash->{vim}->get_single( moref_value => $c->stash->{mo_ref_value});
        $result = {numcpus => $ret->{numCpu}};
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 cpu_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub cpu_PUT {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my $numcpus = $c->req->params->{numcpus};
    eval {
        $result = $c->stash->{vim}->update( numcpus => $numcpus, moref_value => $c->stash->{mo_ref_value} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 process

=head2 PURPOSE

The ActionClass for process functions

=cut

sub process : Chained('vmBase'): PathPart('process'): Args(0) : ActionClass('REST') {}

=pod

=head1 process_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub process_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my $params = $c->req->params;
    $params->{moref_value} = $c->stash->{mo_ref_value};
    eval {
        $result = $c->stash->{vim}->get_process( %{$params} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 process_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub process_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my $params = $c->req->params;
    $params->{moref_value} = $c->stash->{mo_ref_value};
    eval {
        $result = $c->stash->{vim}->run( %{$params} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 transfer

=head2 PURPOSE

The ActionClass for transfer functions

=cut

sub transfer : Chained('vmBase'): PathPart('transfer'): Args(0) : ActionClass('REST') {}

=pod

=head1 transfer_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub transfer_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my $params = $c->req->params;
    $params->{moref_value} = $c->stash->{mo_ref_value};
    eval {
        $result = $c->stash->{vim}->transfer( %{$params} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 memory

=head2 PURPOSE

The ActionClass for memory functions

=cut

sub memory : Chained('vmBase'): PathPart('memory'): Args(0) : ActionClass('REST') {}

=pod

=head1 memory_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub memory_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        my $ret = $c->stash->{vim}->get_single( moref_value => $c->stash->{mo_ref_value});
        $result = {memorySizeMB => $ret->{memorySizeMB}};
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 memory_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub memory_PUT {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my $memorymb = $c->req->params->{memorymb};
    eval {
        $result = $c->stash->{vim}->update(memorymb => $memorymb, moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 disks

=head2 PURPOSE

The ActionClass for disks functions

=cut

sub disks : Chained('vmBase'): PathPart('disk'): Args(0) : ActionClass('REST') {}

=pod

=head1 disks_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub disks_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_disks(moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 disks_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub disks_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my %params = %{ $c->req->params };
    $params{moref_value} = $c->stash->{mo_ref_value};
    eval {
        $result = $c->stash->{vim}->create_disk( %params );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 disk

=head2 PURPOSE

The ActionClass for disk functions

=cut

sub disk : Chained('vmBase'): PathPart('disk'): Args(1) : ActionClass('REST') {}

=pod

=head1 disk_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub disk_GET {
    my ($self, $c, $id ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_disk(moref_value => $c->stash->{mo_ref_value}, id => $id);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 disk_DELETE

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub disk_DELETE {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->remove_hw(moref_value => $c->stash->{mo_ref_value}, num => $id, hw => 'VirtualDisk');
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 annotations

=head2 PURPOSE

The ActionClass for annotations functions

=cut

sub annotations : Chained('vmBase'): PathPart('annotation'): Args(0) : ActionClass('REST') {}

=pod

=head1 annotations_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub annotations_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_annotations(moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 annotation

=head2 PURPOSE

The ActionClass for annotation functions

=cut

sub annotation : Chained('vmBase'): PathPart('annotation'): Args(1) : ActionClass('REST') {}

=pod

=head1 annotation_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub annotation_GET {
    my ($self, $c, $name) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_annotation(moref_value => $c->stash->{mo_ref_value}, name => $name);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 annotation_DELETE

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub annotation_DELETE {
    my ($self, $c, $name ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->delete_annotation(moref_value => $c->stash->{mo_ref_value}, name => $name);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 annotation_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub annotation_PUT {
    my ($self, $c, $name) = @_;
	$c->log->start;
    my $result = {};
    my $value = $c->req->params->{value};
    eval {
        $result = $c->stash->{vim}->change_annotation(moref_value => $c->stash->{mo_ref_value}, name => $name, value => $value);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 events

=head2 PURPOSE

The ActionClass for events functions

=cut

sub events : Chained('vmBase'): PathPart('event'): Args(0) : ActionClass('REST') {}

=pod

=head1 events_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub events_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_events(moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 event

=head2 PURPOSE

The ActionClass for event functions

=cut

sub event : Chained('vmBase'): PathPart('event'): Args(1) : ActionClass('REST') {}

=pod

=head1 event_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub event_GET {
    my ($self, $c, $filter) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_event(moref_value => $c->stash->{mo_ref_value},filter=> $filter );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 cdroms

=head2 PURPOSE

The ActionClass for cdroms functions

=cut

sub cdroms : Chained('vmBase'): PathPart('cdrom'): Args(0) : ActionClass('REST') {}

=pod

=head1 cdroms_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub cdroms_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_cdroms(moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 cdroms_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub cdroms_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->create_cdrom(moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 cdrom

=head2 PURPOSE

The ActionClass for cdrom functions

=cut

sub cdrom : Chained('vmBase'): PathPart('cdrom'): Args(1) : ActionClass('REST') {}

=pod

=head1 cdrom_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub cdrom_GET {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_cdrom(moref_value => $c->stash->{mo_ref_value}, id => $id);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 cdrom_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub cdrom_PUT {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->change_cdrom(moref_value => $c->stash->{mo_ref_value}, id => $id);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 cdrom_DELETE

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub cdrom_DELETE {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->remove_hw(moref_value => $c->stash->{mo_ref_value}, num => $id, hw => 'VirtualCdrom' );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 interfaces

=head2 PURPOSE

The ActionClass for interfaces functions

=cut

sub interfaces : Chained('vmBase'): PathPart('interface'): Args(0) : ActionClass('REST') {}

=pod

=head1 interfaces_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub interfaces_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_interfaces(moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 interfaces_POST

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub interfaces_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my $user_id          = $c->session->{__user};
    $c->log->debug1("userid=>'$user_id'");
    my $model            = $c->model("Database::UserConfig");
    my $mac_base = $model->get_user_config( $user_id, "mac_base" ) || "02:01:00:";
    my $type = $c->req->params->{type} || 'E1000';
    eval {
        $result = $c->stash->{vim}->create_interface(moref_value => $c->stash->{mo_ref_value}, mac_base => $mac_base, type=> $type );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 interface

=head2 PURPOSE

The ActionClass for interface functions

=cut

sub interface : Chained('vmBase'): PathPart('interface'): Args(1) : ActionClass('REST') {}

=pod

=head1 interface_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub interface_GET {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_interface(moref_value => $c->stash->{mo_ref_value}, id => $id);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 interface_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub interface_PUT {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    my $network = $c->req->params->{network};
    eval {
        $result = $c->stash->{vim}->change_interface(moref_value => $c->stash->{mo_ref_value}, id => $id, network => $network);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 interface_DELETE

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub interface_DELETE {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->remove_hw(moref_value => $c->stash->{mo_ref_value}, num => $id, hw => 'VirtualEthernetCard');
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 powerstatus

=head2 PURPOSE

The ActionClass for powerstatus functions

=cut

sub powerstatus : Chained('vmBase'): PathPart('powerstatus'): Args(0) : ActionClass('REST') {}

=pod

=head1 powerstatus_GET

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub powerstatus_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_powerstate(moref_value => $c->stash->{mo_ref_value}, test => 1);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 powerstate

=head2 PURPOSE

The ActionClass for powerstate functions

=cut

sub powerstate : Chained('vmBase'): PathPart('powerstatus'): Args(1) : ActionClass('REST') {}

=pod

=head1 powerstate_PUT

=head2 PURPOSE



=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI


=back

=head2 RETURNS

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=cut

sub powerstate_PUT {
    my ($self, $c, $state) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->change_powerstate(moref_value => $c->stash->{mo_ref_value}, state => $state) ;
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 snapshots

=head2 PURPOSE

The ActionClass for snapshots functions

=cut

sub snapshots : Chained('vmBase'): PathPart('snapshot'): Args(0) : ActionClass('REST') {}

=pod

=head1 snapshots_GET

=head2 PURPOSE

This function returns all snapshots information

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

Returns JSON with all snapshot information, and also current snapshot 

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.ConfigInfo.html

=cut

sub snapshots_GET {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_snapshots(moref_value => $c->stash->{mo_ref_value});
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 snapshots_POST

=head2 PURPOSE

This function create a snapshot of the vm

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item name

This parameter specifies the snapshot name

=item desc

This parameter specifies the snapshots description

=back

=head2 RETURNS

Return JSON on success with mo_ref of snapshot

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#createSnapshot

=cut

sub snapshots_POST {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    my $params = $c->req->params;
	#TODO Configure default values for these
    eval {
        $result = $c->stash->{vim}->create_snapshot( moref_value => $c->stash->{mo_ref_value}, name => $params->{name}, desc => $params->{desc} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 snapshots_DELETE

=head2 PURPOSE

This function removes all snapshots from a virtual machine, and consolidates disks

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

Returns a JSON with success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#removeAllSnapshots

=cut

sub snapshots_DELETE {
    my ($self, $c) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->delete_snapshots( moref_value => $c->stash->{mo_ref_value} );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 snapshot

=head2 PURPOSE

The ActionClass for snapshot functions

=cut

sub snapshot : Chained('vmBase'): PathPart('snapshot'): Args(1) : ActionClass('REST') {}

=pod

=head1 snapshot_GET

=head2 PURPOSE

This subroutine returns information about the snapshot

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

This option is taken from the URI

=back

=head2 RETURNS

Returns JSON containing following data: name, createTime, description, moref_value, id, state 

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.ConfigInfo.html

=cut

sub snapshot_GET {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->get_snapshot(moref_value => $c->stash->{mo_ref_value}, id => $id);
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 snapshot_PUT

=head2 PURPOSE

This subroutine reverts to a snapshot

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

This option is taken from the URI

=back

=head2 RETURNS

A JSON containing success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.Snapshot.html#revert

=cut

sub snapshot_PUT {
    my ($self, $c, $id ) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->revert_snapshot(moref_value => $c->stash->{mo_ref_value}, id => $id );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

=pod

=head1 snapshot_DELETE

=head2 PURPOSE

This subroutine removes a snapshot and concolidates the disks

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

This option is taken from the URI

=back

=head2 RETURNS

A JSON contaning success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.vm.Snapshot.html#remove

=cut

sub snapshot_DELETE {
    my ($self, $c, $id) = @_;
	$c->log->start;
    my $result = {};
    eval {
        $result = $c->stash->{vim}->delete_snapshot( moref_value => $c->stash->{mo_ref_value}, id => $id );
    };
    if ($@) {
        $c->log->dumpobj('error', $@);
        $self->__exception_to_json( $c, $@ );
    }    
	$c->log->dumpobj('result', $result);
	$c->log->finish;
    return $self->__ok( $c, $result );
}

__PACKAGE__->meta->make_immutable;

1;

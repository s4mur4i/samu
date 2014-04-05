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

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    $self->{vcenter_url} = delete($args{vcenter_url});
    
    # The two information should be provided together, or sessionfile should be given
    if ($args{vcenter_username} && $args{vcenter_password}) {
       $self->{vcenter_username} = delete($args{vcenter_username});
       $self->{vcenter_password} = delete($args{vcenter_password});
    } elsif ( $args{sessionfile} ) {
       $self->{sessionfile} = delete($args{sessionfile});
    }
    if (keys %args) {
        ExConnection::VCenter->throw( error => 'Could not create VCenter object, unrecognized argument:' . join(', ', sort keys %args), vcenter_url => $self->{vcenter_url} );
    }
    return $self;
}

=pod

=head2 connect_vcenter

=head3 PURPOSE

Connecting to a VCenter

=head3 PARAMETERS

=over

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

=cut

sub connect_vcenter {
    my $self = shift;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    my $vim;
    eval {
        $vim = Vim->new(service_url => $self->{vcenter_url});
        $vim->login(user_name => $self->{vcenter_username}, password => $self->{vcenter_password});
    };
    if ($@) {
        ExConnection::VCenter->throw( error => 'Could not connect to VCenter', vcenter_url => $self->{vcenter_url} );
    }
    $self->{vim} = $vim;
    &Log::dumpobj("Vim connect object", $vim);
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return $vim;
}

sub savesession_vcenter {
    my $self = shift;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    my $sessionfile = File::Temp->new( DIR => '/tmp', UNLINK => 0, SUFFIX => '.session', TEMPLATE => 'vcenter.XXXXXX' );
    eval {
        $self->{vim}->save_session( session_file => $sessionfile );
        $self->{sessionfile} = $sessionfile->filename;
    };
    if ($@) {
        ExConnection::VCenter->throw( error => 'Could not save session to VCenter', vcenter_url => $self->{vcenter_url} );
    }
    &Log::dumpobj("Sessionfile", $sessionfile->filename);
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return $sessionfile->filename;
}

sub loadsession_vcenter {
    my $self = shift;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    my $vim;
    eval {
        $vim = Vim->new(service_url => $self->{vcenter_url});
        $vim = $vim->load_session(session_file => $self->{sessionfile});
    };
    if ($@) {
        # Cannot detect if timeout or session file is missing TODO: fix
        ExConnection::VCenter->throw( error => 'Could not load session to VCenter', vcenter_url => $self->{vcenter_url} );
    }
    $self->{vim} = $vim;
    &Log::dumpobj("Vim connect object", $vim);
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return $self;
}

sub disconnect_vcenter {
    my $self = shift;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    eval {
        $self->{vim}->logout();
    };
    if ( $@ ) {
        ExConnection::VCenter->throw( error => 'Could not disconnect from VCenter', vcenter_url => $self->{vcenter_url} );
    }
    &Log::dumpobj("Returning self", $self);
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return $self;
}

sub set_find_params {
    my ($self, %args) = @_;
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
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => 'set_find_params' );
    }
    return $self;
}

sub get_find_params {
    my $self = shift;
    my %return =();
    if ( defined $self->{find_params} ) {
        %return = %{ $self->{find_params}};
    }
    return \%return;
}

sub entity_exists {
    my ($self, %args) = @_;
    my $return = 0;
    if ( $args{mo_ref}) {
        my $view = $self->get_view( %args );
        if ( $view ) {
            push(@{$self->{entities} }, $view);
            $return = 1;
        }
    } else {
        ExAPI::Argument->throw( error => 'No required argument give', argument => join(', ', sort keys %args), subroutine => 'entity_exists' );
    }
    return $return;
}

sub delete_find_params {
    my ($self, %args) = @_;
    $self->{find_params} = ();
    return $self;
}

sub find_entities {
    my ($self, %args) = @_;
    my %params = %{ $self->get_find_params} ;
    if ($args{view_type} or $params{view_type}) {
        $params{view_type} = delete($args{view_type});
    } else {
        ExAPI::Argument->throw( error => 'Default argument not given', argument => 'view_type', subroutine => 'find_entities' );
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
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => 'find_entities' );
    }
    my $results = $self->{vim}->find_entity_views(%params);
    push( @{ $self->{entities}}, @$results);
    return $results;
}

sub find_entity {
    my ($self,%args) = @_;
    my %params = %{ $self->get_find_params};
     if ($args{view_type}) {
        $params{view_type} = delete($args{view_type});
    } else {
        ExAPI::Argument->throw( error => 'Default argument not given', argument => 'view_type', subroutine => 'find_entities' );
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
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => 'find_entities' );
    }
    my $result = $self->{vim}->find_entity_view(%params);
    push( @{ $self->{entities}}, $result);
    return $result;
}

sub get_view {
    my ( $self, %args ) = @_;
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
    my $view = $self->{vim}->get_view( %params );
    push( @{ $self->{entities}}, $view);
    return $view;
}

sub update_view {
    my ( $self, $view ) = @_;
    my $updated_view = $view->update_view_data;
    return $updated_view;

}

sub clear_entities {
    my $self = shift;
    @{ $self->{entities} } = ();
    return $self;
}

sub create_moref {
    my ($self, %args ) = @_;
    my ($type,$value);
    if ( $args{type}) {
        $type = delete($args{type});
    }
    if ( $args{value}) {
        $value = delete($args{value});
    }
    if ( keys %args) {
        ExAPI::Argument->throw( error => 'Unrecognized argument given', argument => join(', ', sort keys %args), subroutine => 'moref2view' );
    }
    my $moref = ManagedObjectReference->new( type => $type, value => $value);
    return $moref;
}

sub get_service_content {
    my $self = shift;
    my $sc = $self->{vim}->get_service_content();
    if ( !defined($sc) ) {
        ExEntity::Empty->throw( error => 'Could not retrieve Service Content', entity => "Service Content" );
    }
    return $sc;
}

sub get_manager {
    my ( $self, $type) = @_;
    my $sc = $self->get_service_content;
    my $manager = $self->get_view( mo_ref => $sc->{$type});
    if ( !defined($manager)) {
        ExEntity::Empty->throw( error => 'Could not retrieve manager', entity => "$type" );
    }
    return $manager;
}

sub get_hosts {
    my $self = shift;
    my $result = ();
    $result = $self->find_entities( view_type => 'HostSystem');
    return $result;
}

sub get_host_configmanager{
    my ( $self, %args) = @_;
    my $host = SamuAPI_host->new( view => $args{view});
    my $mo_ref = $host->get_manager( $args{manager});
    my $return = $self->get_view( mo_ref => $mo_ref);
    return $return;
}

sub get_templates {
    my $self = shift;
    my $result = ();
    $result = $self->find_entities( view_type => 'VirtualMachine', properties => ['summary'], filter => { 'config.template' => 'true'  }  );
    return $result;
}

sub linked_clones {
    my ( $self, %args) = @_;
    my $vm = SamuAPI_virtualmachine->new( view => $args{view} );
    my $snapshot = $self->get_view( mo_ref => $vm->last_snapshot_moref );
    my $disk;
    for my $device ( @{ $snapshot->{'config'}->{'hardware'}->{'device'} } ) {
        if ( defined( $device->{'backing'}->{'fileName'} ) ) {
            $disk = $device->{'backing'}->{'fileName'};
            last;
        }
    }
    my @vms = @{ $self->find_vms_with_disk( disk => $disk, template => $vm->get_name)};
    return \@vms;
}
 
sub find_vms_with_disk {
    my ( $self, %args) = @_;
    my @vms           = ();
    my $machine_views = $self->find_entities( view_type  => 'VirtualMachine', properties => [ 'layout.disk', 'name' ]);
    for my $machine_view (@$machine_views) {
        if ( $machine_view->{name} eq $args{template}) {
            next;
        }
        my $disks = $machine_view->get_property('layout.disk');
        for my $vdisk (@{ $disks } ) {
            for my $diskfile ( @{ $vdisk->{'diskFile'} } ) {
                if ( $diskfile eq $args{disk} ) {
                    push( @vms, { name => $machine_view->{name}, mo_ref => $machine_view->{mo_ref}->value });
                }
            }
        }
    }
    return \@vms;
}

sub get_switches {
    my $self = shift;
    my $result = ();
    $result = $self->find_entities( view_type => 'DistributedVirtualSwitch', properties => ['summary', 'portgroup'] );
    return $result;
}

sub get_dvps {
    my $self = shift;
    my $result = ();
    $result = $self->find_entities( view_type => 'DistributedVirtualPortgroup', properties => ['summary', 'key'] );
    return $result;
}

sub get_networks {
    my $self = shift;
    my $result = ();
    my $networks = $self->find_entities( view_type => 'Network', properties => ['summary'] );
    for my $network ( @{ $networks } ) {
        my $obj = SamuAPI_network->new( view => $network);
        if ( $obj->get_mo_ref_type eq 'Network' ) {
            push( @{ $result }, $network );
        }
    }
    return $result;
}

1

package Entity;

use strict;
use warnings;


BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
}

our $view = undef;
our $info = ();
our $mo_ref = undef;
our $logger = undef;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    return $self;
}

sub base_parse {
    my ( $self, %args) = @_;
    $self->{logger} = delete($args{logger});
    if ( $args{view} ) {
        $self->{view} = delete($args{view});
    }
    if ( $args{mo_ref} ) {
        $self->{logger}->debug1('Argument mo_ref given');
        $self->{mo_ref} = delete($args{mo_ref});
    } elsif ( $self->{view} and $self->{view}->{mo_ref}) {
        $self->{logger}->debug1('Returning mo_ref from view');
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    return $self;
}

sub get_info {
    my $self = shift;
    $self->{logger}->start;
    my $return = $self->{info} || undef;
    $self->{logger}->dumpobj('return', $return);
    $self->{logger}->finish;
    return $return;
}

sub get_mo_ref_value {
    my $self = shift;
    $self->{logger}->start;
    my $return = $self->{mo_ref}->{value} || undef;
    $self->{logger}->dumpobj('return', $return);
    $self->{logger}->finish;
    return $return;
}

sub get_mo_ref_type {
    my $self = shift;
    $self->{logger}->start;
    my $return = $self->{mo_ref}->{type} || undef;
    $self->{logger}->dumpobj('return', $return);
    $self->{logger}->finish;
    return $return;
}

sub get_mo_ref {
    my $self = shift;
    $self->{logger}->start;
    my %return = ( value => $self->{mo_ref}->{value}, type => $self->{mo_ref}->{type});
    $self->{logger}->dumpobj('return', %return);
    $self->{logger}->finish;
    return \%return;
}

sub get_name {
    my $self = shift;
    $self->{logger}->start;
    my $return = $self->{info}->{name} || undef;
    $self->{logger}->dumpobj('return', $return);
    $self->{logger}->finish;
    return $return;
}

#####################################################################################

package SamuAPI_resourcepool;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    $self->{logger}->start;
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{logger}->debug1("Need to flush info hash");
        $self->{info} = ();
    }
    if ( defined($self->{view}) ) {
        $self->{logger}->debug1("View has been given parsing it");
        my $view = $self->{view};
        $self->{logger}->dumpobj("view", $view);
        $self->{info}->{name} = $view->{name};
        $self->{info}->{parent_name} = $view->{parent} if defined($view->{parent});
        if ( defined($view->{parent} )) {
            my $parent = Entity->new( mo_ref => $view->{parent}, logger => $self->{logger});
            $self->{info}->{parent_mo_ref} = $parent->get_mo_ref;
        }
        $self->{info}->{virtualmachinecount} = $self->child_vms;
        $self->{info}->{resourcepoolcount} = $self->child_rps;
        my $runtime = $view->{runtime};
        # Only returning some information can be expanded further later
        $self->{info}->{runtime} = { Status => $runtime->{overallStatus}->{val}, memory => { overallUsage => $runtime->{memory}->{overallUsage} }, cpu => { overallUsage => $runtime->{cpu}->{overallUsage} }};
    }
    $self->{info}->{mo_ref} = $self->get_mo_ref_value;
    $self->{logger}->dumpobj("info parsed", $self->{info});
    $self->{logger}->finish;
    return $self;
}

sub child_vms {
    my $self = shift;
    $self->{logger}->start;
    my $value = 0;
    if ( defined($self->{view}->{vm}) ) {
        $value = scalar @{ $self->{view}->{vm}};
    } else {
        $self->{logger}->info("No child vms");
    }
    $self->{logger}->debug2("value=>'$value'");
    $self->{logger}->finish;
    return $value;
}

sub child_rps {
    my $self = shift;
    $self->{logger}->start;
    my $value = 0;
    if ( defined($self->{view}->{resourcePool}) ) {
        $value = scalar @{ $self->{view}->{resourcePool}};
    } else {
        $self->{logger}->info("No child rps");
    }
    $self->{logger}->debug2("value=>'$value'");
    $self->{logger}->finish;
    return $value;
}

sub _resourcepool_resource_config_spec {
    my ( $self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj('args', \%args);

    my $cpu_share = delete($args{cpu_share}) || 4000;
    my $cpu_expandable_reservation = delete($args{cpu_expandable_reservation}) || "true";
    my $cpu_limit = delete($args{cpu_limit}) || -1;
    my $cpu_reservation = delete($args{cpu_reservation}) || 0;

    my $memory_share = delete($args{memory_share}) || 32928;
    my $memory_expandable_reservation = delete($args{memory_expandable_reservation}) || "true";
    my $memory_limit = delete($args{memory_limit}) || -1;
    my $memory_reservation = delete($args{memory_reservation}) || 0;

    my $share_level = delete($args{shares_level}) || "normal";
    my $shareslevel = SharesLevel->new($share_level);

    my $cpushares   = SharesInfo->new( shares => $cpu_share, level => $shareslevel );
    my $cpuallocation = ResourceAllocationInfo->new( expandableReservation => $cpu_expandable_reservation, limit                 => $cpu_limit, reservation           => $cpu_reservation, shares                => $cpushares);

    my $memshares   = SharesInfo->new( shares => $memory_share, level => $shareslevel );
    my $memoryallocation = ResourceAllocationInfo->new( expandableReservation => $memory_expandable_reservation, limit                 => $memory_limit, reservation           => $memory_reservation, shares                => $memshares);

    my $configspec = ResourceConfigSpec->new( cpuAllocation    => $cpuallocation, memoryAllocation => $memoryallocation);
    $self->{logger}->dumpobj('configspec', $configspec);
    $self->{logger}->finish;
    return $configspec;
}

sub get_property {
    my ($self, $property) = @_;
    $self->{logger}->start;
    $self->{logger}->debug1("Requested property=>'$property'");
    my $object = $self->{view}->get_property($property);
    $self->{logger}->dumpobj( 'object', $object);
    $self->{logger}->finish;
    return $object;
}

######################################################################################

package SamuAPI_folder;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    $self->{logger}->start;
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{logger}->debug1("Need to flush info hash");
        $self->{info} = ();
    }
    my $view = $self->{view};
    $self->{info}->{name} = $view->{name};
    $self->{info}->{parent_name} = $view->{parent} if defined($view->{parent});
    if ( defined($view->{parent} )) {
        my $parent = Entity->new( mo_ref => $view->{parent}, logger=> $self->{logger});
        $self->{info}->{parent_mo_ref} = $parent->get_mo_ref;
    }
    $self->{info}->{status} = $view->{overallStatus}->{val};
    $self->{info}->{foldercount} = $self->child_folders;
    $self->{info}->{virtualmachinecount} = $self->child_vms;
    if ( !defined($self->{mo_ref}) ) {
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    $self->{info}->{mo_ref} = $self->get_mo_ref_value;
    $self->{logger}->dumpobj('self', $self);
    $self->{logger}->finish;
    return $self;
}

sub create {
    my ( $self, %args) = @_;
    my $folder_name = delete($args{name});
    my $folder_view = $self->{view}->CreateFolder( name => $folder_name );
# TODO verify if correctly created
    return $folder_view;
}

sub destroy {
    my $self = shift;
    my $task = undef;
    if ( $self->child_vms ne 0 ) {
        ExEntity::NotEmpty->throw( error => "Folder has child virtual machines", entity => $self->{view}->{name}, count => $self->child_vms );
    } elsif ( $self->child_folders ne 0 ) {
        ExEntity::NotEmpty->throw( error => "Folder has child folders", entity => $self->{view}->{name}, count => $self->child_folders );
    }
    $task = $self->{view}->Destroy_Task;
    return $task;
}

sub child_folders {
    my $self = shift;
    my $value = 0;
    if ( defined($self->{view}->{childEntity}) ) {
        for my $moref ( @{ $self->{view}->{childEntity} } ) {
            $value++ if ($moref->{type} eq "Folder");
        }
    }
    return $value;
}

sub child_vms {
    my $self = shift;
    my $value = 0;
    if ( defined($self->{view}->{childEntity}) ) {
        for my $moref ( @{ $self->{view}->{childEntity} }) {
            $value++ if ($moref->{type} eq "VirtualMachine");
        }
    }
    return $value;
}

######################################################################################

package SamuAPI_task;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{logger}->debug1("Need to flush info hash");
        $self->{info} = ();
    }
    if ( defined($self->{view}) ) {
        my $view = $self->{view};
        $self->{info}->{cancelable} = $view->{info}->{cancelable} || 0;
        $self->{info}->{cancelled} = $view->{info}->{cancelled} || 0;
        $self->{info}->{startTime} = $view->{info}->{startTime};
        $self->{info}->{completeTime} = $view->{info}->{completeTime} if defined($view->{info}->{completeTime});
        $self->{info}->{entityName} = $view->{info}->{entityName};
        my $entity = Entity->new( mo_ref => $view->{info}->{entity}, logger => $self->{logger});
        $self->{info}->{entity_moref} = $entity->get_mo_ref;
        $self->{info}->{queueTime} = $view->{info}->{queueTime};
        $self->{info}->{key} = $view->{info}->{key};
        $self->{info}->{state} = $view->{info}->{state}->{val};
        $self->{info}->{description} = { message => $view->{info}->{description}->{message} ,key => $self->{view}->{info}->{description}->{key} };
        $self->{info}->{name} = $view->{info}->{name};
        #Need to implement different reasons TODO
        $self->{info}->{reason} = $view->{info}->{reason}->{userName} || "unimplemented";
        $self->{info}->{progress} = $view->{info}->{progress} ||100;
    }
    if ( !defined($self->{mo_ref}) ) {
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    $self->{info}->{mo_ref} = $self->get_mo_ref_value;
    return $self;
}

sub cancel {
    my $self = shift;
    #verify if cancaleable
    $self->{view}->CancelTask;
    return $self;
}

sub update {
    my $self = shift;
    $self->{view}->update_view_data;
    return $self;
}

sub get_status {
    my $self = shift;
    return $self->{view}->{info}->{state}->{val};
}

sub get_fault {
    my $self = shift;
    return $self->{view}->{info}->{error}->{fault};
}

sub get_localizedmessage {
    my $self = shift;
    return $self->{view}->{info}->{error}->{localizedMessage};
}

sub wait_for_finish {
    my $self = shift;
    while (1) {
        if ( $self->get_status eq 'success' ) {
            last;
        } elsif ( $self->get_status eq 'error' ) {
            ExTask::Error->throw( error  => 'Error happened during task', detail => $self->get_fault, fault  => $self->get_localizedmessage);
        }   
        else {
            sleep 1;
        } 
    }
    return $self;
}

######################################################################################

package SamuAPI_virtualmachine;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    $self->{logger}->start;
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    if ( defined($self->{view}) ) {
        my $view = $self->{view}->{summary};
        $self->{info}->{name} = $view->{config}->{name};
        $self->{info}->{vmpath} = $view->{config}->{vmPathName};
        $self->{info}->{memorySizeMB} = $view->{config}->{memorySizeMB};
        $self->{info}->{numCpu} = $view->{config}->{numCpu};
        $self->{info}->{overallStatus} = $view->{overallStatus}->{val};
        $self->{info}->{toolsVersionStatus} = $view->{guest}->{toolsVersionStatus};
    }
    if ( !defined($self->{mo_ref}) ) {
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    $self->{info}->{mo_ref} = $self->get_mo_ref_value;
    $self->{snapshot} = ();
    $self->{logger}->finish;
    return $self;
}

sub get_property {
    my ($self, $property) = @_;
    my $object = $self->{view}->get_property($property);
    return $object;
}

sub last_snapshot_moref {
    my $self = shift;
    my $snapshot_view;
    if (   defined( $self->{view}->{snapshot} ) && defined( $self->{view}->{snapshot}->{rootSnapshotList} ) ) {
        $snapshot_view = $self->{view}->{snapshot}->{rootSnapshotList};
    } else {
        ExEntity::NoSnapshot->throw( error    => 'VM has no snapshots defined', entity   => $self->get_name );  
    }
    if ( defined( $snapshot_view->[0]->{'childSnapshotList'} ) ) {
        $snapshot_view = &self->_find_last_snapshot( $snapshot_view->[0]->{'childSnapshotList'} );
    }
    return $snapshot_view->[0]->{'snapshot'};
}

sub _find_last_snapshot {
    my ( $self, $snapshot_view) = @_;
    foreach (@$snapshot_view) {
        if ( defined( $_->{'childSnapshotList'} ) ) {
            &self->_find_last_snapshot( $_->{'childSnapshotList'} );
        }
        else {
            return $_;
        }
    }
}

sub promote {
    my $self = shift;
    $self->poweroff;
    my $task_ref = $self->{view}->PromoteDisks_Task( unlink => 1);
    return $task_ref;
}

sub poweroff {
    my $self = shift;
    if ( $self->get_powerstate ne "poweredOff" ) {
        $self->{view}->PowerOffVM;
# TODO maybe impelemnt shutdown or force
    }
    return $self;
}

sub poweron {
    my $self = shift;
    if ( $self->get_powerstate ne "poweredOff" ) {
        $self->{view}->PowerOnVM;
    }
    return $self;
}

sub _virtualmachineconfigspec {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my %params = ();
    if ( $args{numcpus}) {
        $params{numCPUs} = delete($args{numcpus});
        $self->{logger}->debug1("Requested change of CPU num=>'$params{numCPUs}'");
    }
    if ( $args{memorymb}) {
        $params{memoryMB} = delete($args{memorymb});
        $self->{logger}->debug1("Requested change of Memory MB=>'$params{memoryMB}'");
    }
    my $spec = VirtualMachineConfigSpec->new( %params );
    $self->{logger}->dumpobj('spec', $spec);
    $self->{logger}->finish;
    return $spec;
}

sub find_snapshot_by_id {
    my ( $self, $snapshot_view, $id ) = @_;
    $self->{logger}->start;
    my $return;
    if ( $snapshot_view->id == $id ) {
        $return = $snapshot_view;
    } elsif ( defined( $snapshot_view->childSnapshotList ) ) {
        foreach ( @{ $snapshot_view->childSnapshotList } ) {
            if ( !defined($return) ) { 
                $return = $self->find_snapshot_by_id( $_, $id );
            }
        }       
    }           
    $self->{logger}->finish;
    return $return;
}

sub parse_snapshot {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my $view = $args{snapshot};
    $self->{snapshot}->{ $view->{id} } = { name => $view->{name}, createTime => $view->{createTime}, description => $view->{description}, moref_value => $view->{snapshot}->{value}, id => $view->{id}, state => $view->{state}->{val} };
    if ( defined( $view->{childSnapshotList} ) ) {
        foreach ( @{ $view->{childSnapshotList} } ) {
            $self->parse_snapshot( snapshot => $_ );
        }
    }
    $self->{logger}->finish;
    return $self->get_snapshot;
}

sub get_snapshot {
    my $self = shift;
    $self->{logger}->start;
    my $return = $self->{snapshot} || undef;
    $self->{logger}->dumpobj('return', $return);
    $self->{logger}->finish;
    return $return;
}

sub get_powerstate {
    my $self = shift;
    $self->{logger}->start;
    my $return = $self->{view}->{runtime}->{powerState}->{val} || undef;
    $self->{logger}->dumpobj('return', $return);
    $self->{logger}->finish;
    return $return;
}

sub poweroff_task {
    my $self = shift;
    my $task = $self->{view}->PowerOffVM_Task;
    my $obj = SamuAPI_task->new( view => $task, logger => $self->{logger} );
    my %result = $obj->get_mo_ref;
    return \%result;
}

sub poweron_task {
    my $self = shift;
    my $task = $self->{view}->PowerOnVM_Task;
    my $obj = SamuAPI_task->new( view => $task, logger => $self->{logger} );
    my %result = $obj->get_mo_ref;
    return \%result;
}

sub suspend_task {
    my $self = shift;
    my $task = $self->{view}->SuspendVM_Task;
    my $obj = SamuAPI_task->new( view => $task, logger => $self->{logger} );
    my %result = $obj->get_mo_ref;
    return \%result;
}

sub standby {
    my $self = shift;
    $self->{view}->StandbyGuest;
    return $self;
}

sub reboot {
    my $self = shift;
    $self->{view}->RebootGuest;
    return $self;
}

sub shutdown {
    my $self = shift;
    $self->{view}->ShutdownGuest;
    return $self;
}

sub get_cdroms {
    my $self = shift;
    $self->{logger}->start;
    my %result = ();
    my @cdrom_hw = @{ $self->get_hw( 'VirtualCdrom' ) };
    for ( my $i = 0 ; $i < scalar(@cdrom_hw) ; $i++ ) {
        my $backing = "Unknown";
        if ( $cdrom_hw[$i]->{backing}->isa('VirtualCdromIsoBackingInfo') ) {
            $backing = $cdrom_hw[$i]->{backing}->fileName;
        } elsif ( $cdrom_hw[$i]->{backing} ->isa('VirtualCdromRemotePassthroughBackingInfo') or $cdrom_hw[$i]->{backing}->isa('VirtualCdromRemoteAtapiBackingInfo')) {
            $backing = "Client_Device";
        } elsif ( $cdrom_hw[$i]->{backing}->isa('VirtualCdromAtapiBackingInfo') ) {
            $backing = $cdrom_hw[$i]->{backing}->{deviceName};
        }
        my $label = $cdrom_hw[$i]->{deviceInfo}->{label} || "None";
        $result{$i} = { id => $i, key => $cdrom_hw[$i]->{key}, backing => "$backing", label => "$label"};
    }
    $self->{logger}->dumpobj('result', \%result);
    $self->{logger}->finish;
    return \%result;
}

sub get_hw {
    my ( $self, $hw ) = @_;
    $self->{logger}->start;
    my @hw   = ();
    foreach ( @{$self->{view}->{config}->{hardware}->{device}} ) {
        if ( $_->isa($hw) ) {
            push( @hw, $_ );
        }
    }
    $self->{logger}->dumpobj('hw', \@hw);
    $self->{logger}->finish;
    return \@hw
}

sub get_interfaces {
    my $self = shift;
    $self->{logger}->start;
    my %result = ();
    my @ethernet_hw = @{ $self->get_hw( 'VirtualEthernetCard' ) };
    for ( my $i = 0 ; $i < scalar(@ethernet_hw) ; $i++ ) {
        my $type = "Unknown";
        if ( $ethernet_hw[$i]->isa('VirtualE1000') ) {
            $type = "E1000";
        } elsif ( $ethernet_hw[$i]->isa('VirtualE1000e') ) {
            $type = "E1000e";
        } elsif ( $ethernet_hw[$i]->isa('VirtualPCNet32') ) {
            $type = "PCNet32";
        } elsif ( $ethernet_hw[$i]->isa('VirtualVmxnet2') ) {
            $type = "Vmxnet2";
        } elsif ( $ethernet_hw[$i]->isa('VirtualVmxnet3') ) {
            $type = "Vmxnet3";
        }
        $result{$i} = { id => $i, key => $ethernet_hw[$i]->{key}, mac=> $ethernet_hw[$i]->{macAddress}, label => $ethernet_hw[$i]->{deviceInfo}->{label}, summary => $ethernet_hw[$i]->{deviceInfo}->{summary}, type => $type };
    }
    $self->{logger}->dumpobj('result', \%result);
    $self->{logger}->finish;
    return \%result;

}

sub get_disks {
    my $self = shift;
    $self->{logger}->start;
    my %result = ();
    my @disk_hw = @{ $self->get_hw( 'VirtualDisk' ) };
    for ( my $i = 0 ; $i < scalar(@disk_hw) ; $i++ ) {
        $result{$i} = { id => $i, key => $disk_hw[$i]->{key}, capacity => $disk_hw[$i]->{capacityInKB}, filename => $disk_hw[$i]->{backing}->{fileName} };
    }
    $self->{logger}->dumpobj('result', \%result);
    $self->{logger}->finish;
    return \%result;

}

sub get_annotation_key {
    my ( $self, %args ) = @_;
    $self->{logger}->start;
    my $key = 0;
    foreach ( @{ $self->{view}->{availableField} } ) {
        if ( $_->name eq $args{name} ) {
            $key = $_->{key};
        }
    }
    $self->{logger}->finish;
    return $key;
}

######################################################################################

package SamuAPI_template;

use base 'SamuAPI_virtualmachine';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    if ( defined($self->{view}) ) {
        my $view = $self->{view}->{summary};
        $self->{info}->{name} = $view->{config}->{name};
        $self->{info}->{vmpath} = $view->{config}->{vmPathName};
        $self->{info}->{memorySizeMB} = $view->{config}->{memorySizeMB};
        $self->{info}->{numCpu} = $view->{config}->{numCpu};
        $self->{info}->{overallStatus} = $view->{overallStatus}->{val};
        $self->{info}->{toolsVersionStatus} = $view->{guest}->{toolsVersionStatus};
    }
    if ( !defined($self->{mo_ref}) ) {
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    $self->{info}->{mo_ref} = $self->get_mo_ref_value;
    return $self;
}

sub get_property {
    my ($self, $property) = @_;
    my $object = $self->{view}->get_property($property);
    return $object;
}

######################################################################################

package SamuAPI_distributedvirtualswitch;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    my $view = $self->{view}->{summary};
    $self->{info}->{name} = $view->{name};
    $self->{info}->{numports} = $view->{numPorts} || 0;
    $self->{info}->{uuid} = $view->{uuid};
    $self->{info}->{connected_vms} = $self->connected_vms;
    if ( !defined($self->{mo_ref}) ) {
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    $self->{info}->{mo_ref_value} = $self->get_mo_ref_value;
    $self->{info}->{mo_ref} = $self->get_mo_ref;
    return $self;
}

sub connected_vms {
    my $self = shift;
    my @vm= ();
    for my $vm ( @{$self->{view}->{vm}}) {
        my $obj = Entity->new( mo_ref => $vm, logger => $self->{logger} );
        push( @vm, $obj->get_mo_ref);
    }
    return \@vm;
}

sub _dvsconfigspec {
    my ( $self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj('args', \%args);
    my $spec = DVSConfigSpec->new();
    if ( $args{name} ) {
        $spec->{name} = delete($args{name});
    }
    $self->{logger}->dumpobj('configspec', $spec);
    $self->{logger}->finish;
    return $spec;
}

######################################################################################

package SamuAPI_distributedvirtualportgroup;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    my $view = $self->{view};
    $self->{info}->{name} = $view->{summary}->{name};
    $self->{info}->{key} = $view->{key};
    $self->{info}->{status} = $view->{overallStatus}->{val};
    $self->{info}->{connected_vms} = $self->connected_vms;
    if ( !defined($self->{mo_ref}) ) {
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    $self->{info}->{mo_ref_value} = $self->get_mo_ref_value;
    $self->{info}->{mo_ref} = $self->get_mo_ref;
    return $self;
}

sub connected_vms {
    my $self = shift;
    my @vm= ();
    for my $vm ( @{ $self->{view}->{vm} }) {
        my $obj = Entity->new( mo_ref => $vm, logger => $self->{logger} );
        push( @vm, $obj->get_mo_ref);
    }
    return \@vm;
}

sub _dvportgroupconfigspec {
    my ( $self, %args) = @_;
    $self->{logger}->start;
    $self->{logger}->dumpobj('args', \%args);
    my $type = delete($args{type}) || 'earlyBinding';
    my $numport = delete($args{numport}) || '16';
    my $desc = delete($args{desc}) || 'DVP desc';
    my $autoexpand = delete($args{autoexpand}) || "true";
    my $configspec = DVPortgroupConfigSpec->new( type => $type, numPorts => $numport, autoExpand => $autoexpand );
    if ( $args{name} ) {
        $configspec->{name} = delete($args{name});
    }
    $self->{logger}->dumpobj('configspec', $configspec);
    $self->{logger}->finish;
    return $configspec;
}

######################################################################################

package SamuAPI_network;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    my $view = $self->{view};
    $self->{info}->{connected_vms} = $self->connected_vms;
    $self->{info}->{name} = $view->{summary}->{name};
    if ( !defined($self->{mo_ref}) ) {
        $self->{mo_ref} = $self->{view}->{mo_ref};
    }
    $self->{info}->{mo_ref_value} = $self->get_mo_ref_value;
    $self->{info}->{mo_ref} = $self->get_mo_ref;
    return $self;
}

sub connected_vms {
    my $self = shift;
    my @vm= ();
    for my $vm ( @{ $self->{view}->{vm} }) {
        my $obj = Entity->new( mo_ref => $vm, logger => $self->{logger} );
        push( @vm, $obj->get_mo_ref);
    }
    return \@vm;
}

######################################################################################

package SamuAPI_host;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    my $view = $self->{view};
    $self->{info}->{name} = $view->{name};
    $self->{info}->{rebootrequired} = $view->{summary}->{rebootRequired};
    my $hw = $view->{summary}->{hardware};
    $self->{info}->{hw} = { cpuMhz => $hw->{cpuMhz}, cpuModel => $hw->{cpuModel}, memorySize => $hw->{memorySize}, model => $hw->{model}, numCpuThreads => $hw->{numCpuThreads}, vendor => $hw->{vendor}, numNics => $hw->{numNics}, numHBA => $hw->{numHBAs}, numCpuCores => $hw->{numCpuCores} };
    $self->{info}->{status} = $view->{summary}->{overallStatus}->{val};
    $self->{info}->{vms} = $self->connected_vms;
    return $self;
}

sub connected_vms {
    my $self = shift;
    my @vm= ();
    for my $vm ( @{$self->{view}->{vm}}) {
        my $obj = Entity->new( mo_ref => $vm, logger => $self->{logger} );
        push( @vm, $obj->get_mo_ref);
    }
    return \@vm;
}

######################################################################################

package SamuAPI_event;

use base 'Entity';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->base_parse(%args);
    $self->info_parse;
    return $self;
}

sub info_parse {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    my $view = $self->{view};
    $self->{info}->{username} = $view->{userName} || "system";
    $self->{info}->{createdTime} = $view->{createdTime};
    $self->{info}->{datacenter} = $view->{datacenter}->{name};
    $self->{info}->{key} = $view->{key};
    $self->{info}->{fullFormattedMessage} = $view->{fullFormattedMessage};
    return $self;
}

sub get_key {
    my $self = shift;
    return $self->{info}->{key};
}

1

package Entity;

use strict;
use warnings;


BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
}


sub new {
    my ($class, %args) = @_;
    my $obj=undef;
    if ( $args{view}->isa('ResourcePool')) {
        $obj = SamuAPI_resourcepool->new( %args );
    } elsif ( $args{view}->isa('Folder')) {
        $obj = SamuAPI_folder->new( %args );
    } else {
        ExAPI::ObjectType->throw( error => "Unknown object type", type => ref($args{view}));
    }
    return $obj;
}

#####################################################################################
package SamuAPI_resourcepool;

our $view = undef;
our $info = ();
our $refresh = 0;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->{view} = delete$args{view};
    if ( $args{refresh}) {
        $self->{refresh} = delete($args{refresh});
    }
    return $self;
}

sub parse_info {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    my $view = $self->{view};
    $self->{info} = {virtualmachinecount => 0, parent => "", resourcepoolcount => 0, runtime => {}, name => "", parent_id => 0, mo_ref_value => "" };
    $self->{info}->{name} = $view->{name};
    $self->{info}->{parent} = $view->{parent} if defined($view->{parent});
    $self->{info}->{parent_id} = $view->{parent}->{value} if defined($view->{parent});
    $self->{info}->{virtualmachinecount} = $self->child_vms;
    $self->{info}->{resourcepoolcount} = $self->child_rps;
    $self->{info}->{mo_ref_value} = $view->{mo_ref}->{value};
    if ($self->{refresh}) {
        $view->RefreshRuntime;
    }
    my $runtime = $view->{runtime};
    # Only returning some information can be expanded further later
    $self->{info}->{runtime} = { Status => $runtime->{overallStatus}->{val}, memory => { overallUsage => $runtime->{memory}->{overallUsage} }, cpu => { overallUsage => $runtime->{cpu}->{overallUsage} }};

    return $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
}

sub child_vms {
    my $self = shift;
    my $value = 0;
    if ( defined($self->{view}->{vm}) ) {
        $value = scalar @{ $self->{view}->{vm}};
    }
    return $value;
}

sub child_rps {
    my $self = shift;
    my $value = 0;
    if ( defined($self->{view}->{resourcePool}) ) {
        $value = scalar @{ $self->{view}->{resourcePool}};
    }
    return $value;
}

sub destroy {
    my $self = shift;
    my $task = undef;
    if ( $self->child_vms ne 0 ) {
        ExEntity::NotEmpty->throw( error => "ResourcePool has child virtual machines", entity => $self->{view}->{name}, count => $self->child_vms );
    } elsif ( $self->child_rps ne 0 ) {
        ExEntity::NotEmpty->throw( error => "ResourcePool has child resourcepools", entity => $self->{view}->{name}, count => $self->child_rps );
    }
    $task = $self->{view}->Destroy_Task;
    return $task;
}

sub update {
    my ( $self, %args) = @_;
    my %param = ();
    if ( defined($args{name}) ) {
        $param{name} = delete($args{name});
    }
    my $rp_view = $self->{view};
    if ( keys %args ) {
        $param{spec} = $self->_resourcepool_resource_config_spec(%args);
    }
    $self->{view}->UpdateConfig( %param );
    return $self;
}

sub create {
    my ( $self, %args) = @_;
    my $rp_name = delete($args{name});
    my $rp_spec = $self->_resourcepool_resource_config_spec(%args);
    my $rp_view = $self->{view}->CreateResourcePool( name => $rp_name, spec => $rp_spec );
    return $rp_view;
}

sub move {
    my ( $self, %args ) = @_;
    my @list = ();
    if ( defined($args{list}) ) {
        @list = @{$args{list}}
    } else {
        ExAPI_Argument->throw( error => "Missing list argument", argument => "list", subroutine => "move");
    }
    $self->{view}->MoveIntoResourcePool( list => @list );
    return $self;
}

sub _resourcepool_resource_config_spec {
    my ( $self, %args) = @_;
    my $share_level = delete($args{shares_level}) || "normal";
    my $cpu_share = delete($args{cpu_share}) || 4000;
    my $memory_share = delete($args{memory_share}) || 32928;
    my $cpu_expandable_reservation = delete($args{cpu_expandable_reservation}) || "true";
    my $cpu_limit = delete($args{cpu_limit}) || -1;
    my $cpu_reservation = delete($args{cpu_reservation}) || 0;
    my $memory_expandable_reservation = delete($args{memory_expandable_reservation}) || "true";
    my $memory_limit = delete($args{memory_limit}) || -1;
    my $memory_reservation = delete($args{memory_reservation}) || 0;
    my $shareslevel = SharesLevel->new($share_level);
    my $cpushares   = SharesInfo->new( shares => $cpu_share, level => $shareslevel );
    my $memshares   = SharesInfo->new( shares => $memory_share, level => $shareslevel );
    my $cpuallocation = ResourceAllocationInfo->new( expandableReservation => $cpu_expandable_reservation, limit                 => $cpu_limit, reservation           => $cpu_reservation, shares                => $cpushares);
    my $memoryallocation = ResourceAllocationInfo->new( expandableReservation => $memory_expandable_reservation, limit                 => $memory_limit, reservation           => $memory_reservation, shares                => $memshares);
    my $configspec = ResourceConfigSpec->new( cpuAllocation    => $cpuallocation, memoryAllocation => $memoryallocation);
    return $configspec;
}

######################################################################################
package SamuAPI_folder;

our $view = undef;
our $info = ();

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->{view} = $args{view};
    return $self;
}

sub parse_info {
    my $self = shift;
    # If info has been parsed once then flush previous info
    if ( defined( $self->{info} ) && keys $self->{info} ) {
        $self->{info} = ();
    }
    my $view = $self->{view};
    $self->{info}->{name} = $view->{name};
    $self->{info}->{parent} = $view->{parent} if defined($view->{parent});
    $self->{info}->{parent_id} = $view->{parent}->{value} if defined($view->{parent});
    $self->{info}->{Status} = $view->{overallStatus}->{val};
    $self->{info}->{foldercount} = $self->child_folders;
    $self->{info}->{virtualmachinecount} = $self->child_vms;
    return $self;
}

sub get_info {
    my $self = shift;
    return $self->{info};
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

our $view = undef;
our $mo_ref = undef;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    if ( $args{view}) {
        $self->{view} = $args{view};
    } elsif ( $args{mo_ref}) { 
        $self->{mo_ref} = $args{mo_ref};
    } else {
        ExAPI::Argument->throw( error => "missing view or mo_ref argument ", argument => , subroutine => "SamuAPI_task");
    }
    return $self;
}

sub mo_ref_value {
    my ( $self ) = shift;
    return $self->{mo_ref}->{value};
}

1

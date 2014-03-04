package Entity;

use strict;
use warnings;


BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
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
    $self->{info}->{virtualmachinecount} = scalar @{ $view->{vm}} if defined($view->{vm});
    $self->{info}->{resourcepoolcount} = scalar @{ $view->{resourcePool}} if defined($view->{resourcePool});
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

######################################################################################
package SamuAPI_folder;

our $view = undef;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->{view} = $args{view};
    return $self;
}
1

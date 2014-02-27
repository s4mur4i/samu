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
    return $vim;
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

1

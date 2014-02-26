package VCenter;

use strict;
use warnings;
use File::Temp qw/ tempfile /;

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
   my $vcenter_username = delete($args{vcenter_username});
   my $vcenter_password = delete($args{vcenter_password});
   my $vcenter_url = delete($args{vcenter_url});
   if (keys %args) {
#      croak "Unrecognized arg(s) " .  join(', ', sort keys %args) . " to 'Samu::new'";
# TODO Throw an error
   }
   $self->{vcenter_username} = $vcenter_username;
   $self->{vcenter_password} = $vcenter_password;
   $self->{vcenter_url} = $vcenter_url;
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
    #    print Dumper $@;
    # maybe use carp
    }
    $self->{vim} = $vim;
    &Log::dumpobj("Vim connect object", $vim);
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return $vim;
}

sub savesession_vcenter {
    my $self = shift;
    my $sessionfile = File::Temp->new( DIR => '/tmp', UNLINK => 0, SUFFIX => '.session', TEMPLATE => 'vcenter.XXXXXX' );
    $self->{vim}->save_session( session_file => $sessionfile );
    $self->{sessionfile} = $sessionfile->filename;
    return $sessionfile->filename;
}

sub loadsession_vcenter {
    my %args = @_;
    my $vim = Vim->new(service_url => $args{url});
    $vim = $vim->load_session(session_file => $args{sessionfile});
    return $vim;
}

sub disconnect_vcenter {
    my %args = @_;
    $args{vim}->logout();
}

1

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
    my %args = @_;
    my ( $url, $username, $password ) = @_;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    my $vim;
    eval {
        $vim = Vim->new(service_url => $args{vcenter_url});
        $vim->login(user_name => $args{vcenter_username}, password => $args{vcenter_password});
    };
    if ($@) {
    #    print Dumper $@;
    }
    &Log::dumpobj("Vim connect object", $vim);
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return $vim;
}

sub savesession_vcenter {
    my %args = @_;
    use Data::Dumper;
    print Dumper %args;
    my $sessionfile = File::Temp->new( DIR => '/tmp', UNLINK => 0, SUFFIX => '.session', TEMPLATE => 'vcenterXXXXXX' );
    $args{vim}->save_session( session_file => $sessionfile );
    return $sessionfile;
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

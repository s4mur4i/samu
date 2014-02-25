package VCenter;

use strict;
use warnings;

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
    my ( $url, $username, $password ) = @_;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    my $vim;
        use Data::Dumper;
    eval {
        $vim = Vim->new(service_url => $url);
        $vim->login(user_name => $username, password => $password);
    };
    if ($@) {
        print Dumper $@;
    }
    print Dumper $vim;
    &Log::dumpobj("Vim connect object", $vim);
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return $vim;
}

1

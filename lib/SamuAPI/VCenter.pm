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

True on success

=head3 DESCRIPTION

=head3 THROWS

Connection::Connect if connection to VCenter fails

=head3 COMMENTS

=head3 TEST COVERAGE

=cut

sub connect_vcenter {
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    eval {
        Util::connect(
            Opts::get_option('url'),
            Opts::get_option('username'),
            Opts::get_option('password')
        );
    };
    if ($@) {
        Connection::Connect->throw(
            error => 'Failed to connect to VCenter',
            type  => 'SDK',
            dest  => 'VCenter'
        );
    }
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return 1;
}

1

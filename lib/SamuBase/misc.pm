package misc;

use strict;
use warnings;
use Getopt::Long qw(:config bundling pass_through require_order);
use Pod::Usage;
use FindBin;
use Module::Load;

=pod

=head1 misc.pm

Subroutines from SamuBase/misc.pm

=cut

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );

    @ISA    = qw(Exporter);
    @EXPORT = qw(&option_parser);
}

our $help;

=pod

=head2 call_pod2usage

=head3 PURPOSE



=head3 PARAMETERS

=over

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

=cut

sub call_pod2usage {
    my $helper = shift;
    pod2usage(
        -verbose   => 99,
        -noperldoc => 1,
        -input     => $FindBin::Bin . "/doc/main.pod",
        -output    => \*STDOUT,
        -sections  => $helper
    );
}

=pod

=head2 option_parser

=head3 PURPOSE



=head3 PARAMETERS

=over

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

=cut

sub option_parser {
    &log::debug("Starting " . (caller(0))[3] . " sub");
    my $opts        = shift;
    my $module_name = shift;
    if ( exists( $opts->{helper} ) ) {
        GetOptions( 'help|h' => \$help, );
        $help && &misc::call_pod2usage( $opts->{helper} );
    }
    if ( exists $opts->{module} ) {
        my $module = 'Base::' . $opts->{module};
        &log::debug("loading module $module");
        eval { load $module; };
        $module->import();
    }
    if ( exists $opts->{prereq_module} ) {
        for my $module ( @{ $opts->{prereq_module} } ) {
            &log::debug("loading prereq module $module");
            eval { load $module; };
            $module->import();
        }
    }
    if ( exists $opts->{function} ) {
        if ( exists $opts->{opts} ) {
            &log::debug("Parsing options to VMware SDK");
            &VCenter::SDK_options( $opts->{opts} );
            if ( $opts->{vcenter_connect} ) {
                eval {
                    &log::debug("Connecting to VCenter");
                    &VCenter::connect_vcenter();
                };
                if ($@) { &Error::catch_ex($@) }
            }
            else {
                &log::debug("No connection is required to VCenter");
            }
        }
        &log::debug("Invoking handler function of $module_name");
        &{ $opts->{function} };
        if ( $opts->{vcenter_connect} ) {
            &log::debug("Disconnecting from VCenter");
            &VCenter::disconnect_vcenter();
        }
    }
    else {
        my $arg = shift @ARGV;
        if ( defined $arg and exists $opts->{functions}->{$arg} ) {
            &log::debug("Forwarding parsing to subfunction parser $arg");
            &misc::option_parser( $opts->{functions}->{$arg}, $arg );
        }
        else {
            &log::debug("Calling helper");
            call_pod2usage( $opts->{helper} );
        }
    }
    &log::debug("Finishing " . (caller(0))[3] . " sub");
    return 1;
}

1

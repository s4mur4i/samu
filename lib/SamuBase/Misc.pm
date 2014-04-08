package Misc;

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
    my $opts        = shift;
    my $module_name = shift;
    if ( exists( $opts->{helper} ) ) {
        GetOptions( 'help|h' => \$help, );
        $help && &misc::call_pod2usage( $opts->{helper} );
    }
    if ( exists $opts->{module} ) {
        my $module = 'Base::' . $opts->{module};
        eval { load $module; };
        $module->import();
    }
    if ( exists $opts->{prereq_module} ) {
        for my $module ( @{ $opts->{prereq_module} } ) {
            eval { load $module; };
            $module->import();
        }
    }
    if ( exists $opts->{function} ) {
        if ( exists $opts->{opts} ) {
            &VCenter::SDK_options( $opts->{opts} );
            if ( $opts->{vcenter_connect} ) {
                eval {
                    &VCenter::connect_vcenter();
                };
                if ($@) { &Error::catch_ex($@) }
            }
            else {
            }
        }
        &{ $opts->{function} };
        if ( $opts->{vcenter_connect} ) {
            &VCenter::disconnect_vcenter();
        }
    }
    else {
        my $arg = shift @ARGV;
        if ( defined $arg and exists $opts->{functions}->{$arg} ) {
            &misc::option_parser( $opts->{functions}->{$arg}, $arg );
        }
        else {
            call_pod2usage( $opts->{helper} );
        }
    }
    return 1;
}

1

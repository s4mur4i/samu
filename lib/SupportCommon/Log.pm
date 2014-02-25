package Log;

use strict;
use warnings;

use Getopt::Long qw(:config bundling pass_through);
use Sys::Syslog qw(:standard :macros);
use File::Basename;
use Data::Dumper;

=pod

=head1 log.pm

Subroutines from SupportCommon/log.pm

=cut

my $verbose;
my $quiet;
my $verbosity;

=pod

=head2 verbostiy

=head3 PURPOSE

Returns verbosity level

=head3 PARAMETERS

=over

=back

=head3 RETURNS

Returns verbosity level

=head3 DESCRIPTION

Getter sub for verbosity

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested for each verbosity level to see if it returns a value from 0-10

=cut

sub verbosity {
    return $verbosity;
}

=pod

=head2 log2line

=head3 PURPOSE

Formats a log message

=head3 PARAMETERS

=over

=item level

Level of information

=item msg

The requested log information

=back

=head3 RETURNS

The formatted log message

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Output is tested if it is as expected

=cut

sub log2line {
    $0 =~ s/.*\///g;    # strip off the leading . from the program name
    my $level = shift;
    my $msg   = shift;
    my %args  = @_;
    my $sep   = '';
    my (
        $package, $filename,  $line,     $subroutine,
        $hasargs, $wantarray, $evaltext, $is_require
    ) = caller(1);
    my $prefix =
        $0 . "["
      . $$ . "]: ("
      . basename($filename) . ") "
      . getpwuid($<)
      . " [$level]";
    my $prefix_stderr = basename($filename) . " [$level]";
    closelog();
    openlog( $prefix, "", LOG_USER );
    $msg .= ';';

    for my $k ( sort keys %args ) {
        my $v = $args{$k};

        defined($v) or $v = '(undef)';
        $v =~ s/\\/\\\\/g;
        $v =~ s/'/\\'/g;
        $v =~ s/\t/\\t/g;
        $v =~ s/\r/\\r/g;
        $v =~ s/\n/\\n/g;
        $v =~ s/\0/\\0/g;
        $msg .= "$sep $k='$v'";
        $sep = ',';
    }
    print STDERR "$prefix_stderr: $msg\n";
    return "$msg\n";
}

=pod

=head2 debug2

=head3 PURPOSE

debug 2 for printing information at log level 10

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub debug2 {
    ( verbosity() >= 10 ) and syslog( LOG_DEBUG, log2line( 'DEBUG2', @_ ) );
}

=pod

=head2 debug1

=head3 PURPOSE

debug 1 for printing information at log level 9

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub debug1 {
    ( verbosity() >= 9 ) and syslog( LOG_DEBUG, log2line( 'DEBUG1', @_ ) );
}

=pod

=head2 debug

=head3 PURPOSE

debug for printing information at log level 8

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub debug {
    ( verbosity() >= 8 ) and syslog( LOG_DEBUG, log2line( 'DEBUG', @_ ) );
}

=pod

=head2 info

=head3 PURPOSE

info for printing information at log level 7

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub info {
    ( verbosity() >= 7 ) and syslog( LOG_INFO, log2line( 'INFO', @_ ) );
}

=pod

=head2 notice

=head3 PURPOSE

notice for printing information at log level 6

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub notice {
    ( verbosity() >= 6 ) and syslog( LOG_NOTICE, log2line( 'NOTICE', @_ ) );
}

=pod

=head2 warning

=head3 PURPOSE

warning for printing information at log level 5

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub warning {
    ( verbosity() >= 5 ) and syslog( LOG_WARNING, log2line( 'WARNING', @_ ) );
}

=pod

=head2 error

=head3 PURPOSE

error for printing information at log level 4

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub error {
    ( verbosity() >= 4 ) and syslog( LOG_ERR, log2line( 'ERROR', @_ ) );
}

=pod

=head2 ciritical

=head3 PURPOSE

Critical for printing information at log level 3

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub critical {
    ( verbosity() >= 3 ) and syslog( LOG_CRIT, log2line( 'CRITICAL', @_ ) );
}

=pod

=head2 alert

=head3 PURPOSE

alert for printing information at log level 2

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub alert {
    ( verbosity() >= 2 ) and syslog( LOG_ALERT, log2line( 'ALERT', @_ ) );
}

=pod

=head2 emergency

=head3 PURPOSE

emergency for printing information at log level 1

=head3 PARAMETERS

=over

=item msg

Message to print

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Tested if output from 0 to 10 is as expected

=cut

sub emergency {
    ( verbosity() >= 1 ) and syslog( LOG_EMERG, log2line( 'EMERGENCY', @_ ) );
}

=pod

=head2 dumpobj

=head3 PURPOSE

Dumps an object for debugging

=head3 PARAMETERS

=over

=item name

Name of object for better identification

=item obj

Object to dump

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

Output is tested at normal log level and log level 10

=cut

sub dumpobj {
    my ( $name, $obj ) = @_;
    ( verbosity() >= 10 ) and debug2( "Dumping object $name:" . Dumper($obj) );
}

=pod

=head2 loghash

=head3 PURPOSE

Logs a hash to readable format

=head3 PARAMETERS

=over

=item msg

Message to log to hash

=item hash

Hashref to log

=back

=head3 RETURNS

=head3 DESCRIPTION

=head3 THROWS

=head3 COMMENTS

=head3 TEST COVERAGE

No output at log level 7 but standard output at log level 8 is tested

=cut

sub loghash {
    my ( $msg, $hash ) = @_;
    ( verbosity() >= 8 ) and debug(
        $msg
          . (
            join ',', ( map { "$_=>'" . $hash->{$_} . "'" } sort keys %{$hash} )
          )
    );
}

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );

    @ISA    = qw(Exporter);
    @EXPORT = qw( );

    GetOptions(
        "v+" => \$verbose,    # occurence counter
        "q+" => \$quiet,      # occurence counter
    );
    $quiet   ||= 0;
    $verbose ||= 0;
    $verbosity = ( 6 + $verbose ) - $quiet;
    if ( $verbosity < 0 ) {
        $verbosity = 0;
    }
    elsif ( $verbosity > 10 ) {
        $verbosity = 10;
    }

    debug("==== Log started");
    debug("Verbosity level verbosity=>'$verbosity'");
}

1;

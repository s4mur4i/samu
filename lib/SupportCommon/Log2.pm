package Log2;

use strict;
use warnings;
use Sys::Syslog qw(:standard :macros);
use File::Basename;
use Data::Dumper;
BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
}

our $verbosity = 6;
our $facility = 'LOG_USER';
our $label = 'samu';
our $logger = undef;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->{verbosity} = delete( $args{verbosity} ) || $verbosity;
    $self->{facility} = delete( $args{facility} ) || $facility;
    $self->{label} = delete( $args{label} ) || $label;
    return $self;
}

sub get_verbosity {
    my $self = shift;
    return $self->{verbosity};
}

sub set_verbosity {
    my ($self, $verb) = shift;
    $self->{verbosity} = $verb;
    return $self;
}

sub get_label {
    my $self = shift;
    return $self->{label};
}

sub get_facility {
    my $self = shift;
    return $self->{facility};
}

sub log2line {
    $0 =~ s/.*\///g;    # strip off the leading . from the program name
    my ($self, $level, $msg, %args) = @_;
    my $sep   = '';
    my ( $package, $filename,  $line,     $subroutine, $hasargs, $wantarray, $evaltext, $is_require ) = caller(1);
    my $prefix = $0 . "[" . $$ . "]: (" . basename($filename) . ") " . getpwuid($<) . " [$level]";
#    print Dumper $prefix;
    openlog( $prefix, "", LOG_USER );
    my $prefix_stderr = basename($filename) . " [$level]";
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
    if ( *stderr ) {
        print STDERR "$prefix_stderr: $msg\n";
    }
    return "$msg\n";
}

sub debug2 {
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 10 ) and syslog( LOG_DEBUG, $self->log2line( 'DEBUG2', @msg ) );
}

sub debug1 {
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 9 ) and syslog( LOG_DEBUG, $self->log2line( 'DEBUG1', @msg ) );
}

sub debug {
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 8 ) and syslog( LOG_DEBUG, $self->log2line( 'DEBUG', @msg ) );
}

sub info {
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 7 ) and syslog( LOG_INFO, $self->log2line( 'INFO', @msg ) );
}

sub notice {
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 6 ) and syslog( LOG_NOTICE, $self->log2line( 'NOTICE', @msg ) );
}
    
sub warning { 
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 5 ) and syslog( LOG_WARNING, $self->log2line( 'WARNING', @msg ) );
}   
        
sub error {
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 4 ) and syslog( LOG_ERR, $self->log2line( 'ERROR', @msg ) );
}   
    
sub critical { 
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 3 ) and syslog( LOG_CRIT, $self->log2line( 'CRITICAL', @msg ) );
}       
    
sub alert { 
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 2 ) and syslog( LOG_ALERT, $self->log2line( 'ALERT', @msg ) );
}

sub emergency {
    my ($self, @msg) = @_;
    ( $self->get_verbosity >= 1 ) and syslog( LOG_EMERG, $self->log2line( 'EMERGENCY', @msg ) );
}

sub dumpobj {
    my ( $self, $name, $obj ) = @_;
    ( $self->get_verbosity >= 10 ) and $self->debug2( "Dumping object $name:" . Dumper($obj) );
}

sub loghash {
    my ($self, $msg, $hash ) = @_;
    ( $self->get_verbosity >= 8 ) and $self->debug( $msg . ( join ',', ( map { "$_=>'" . $hash->{$_} . "'" } sort keys %{$hash} )));
}

sub start {
    my $self = shift;
    $self->debug( "Starting " . (caller(1))[3] . " sub" );
    return $self;
}

sub finish {
    my $self = shift;
    $self->debug( "Finishing " . (caller(1))[3] . " sub" );
    return $self;
}

1;

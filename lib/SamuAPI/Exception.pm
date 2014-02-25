package Exception;

use strict;
use warnings;

=pod

=head1 Exception.pm

Subroutines from VmwareAPI/Exception.pm

=cut

use Exception::Class (
    'BaseException' => {},

    ## Base Classes
    'Entity' => {
        isa    => 'BaseException',
        fields => ['entity'],
    },
    'Template' => {
        isa    => 'BaseException',
        fields => ['template'],
    },
    'TaskEr'     => { isa => 'BaseException', },
    'Connection' => { isa => 'BaseException', },
    'Vcenter'    => { isa => 'BaseException', },
    'Vmware'     => { isa => 'BaseException' },
);

BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
}

use overload
  '""'     => sub { $_[0]->as_string },
  'bool'   => sub { 1 },
  fallback => 1;

sub catch_ex {
    my ($ex) = @_;
    &Log::debug(
        "Starting " . ( caller(0) )[3] . " sub" );
    &Log::dumpobj( "ex", $ex );
    &Log::debug(
        "Finishing " . ( caller(0) )[3] . " sub" );
    return 1;
}
1

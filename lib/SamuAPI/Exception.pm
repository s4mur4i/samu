package Exception;

use strict;
use warnings;

=pod

=head1 Exception.pm

Subroutines from VmwareAPI/Exception.pm

=cut

use Exception::Class (
    'ExBase' => {},

    ## Base Classes
    'ExEntity' => {
        isa    => 'ExBase',
        fields => ['entity'],
    },
    'ExTemplate' => {
        isa    => 'ExBase',
        fields => ['template'],
    },
    'ExTask'     => { isa => 'ExBase', fields => ['number'] },
    'ExConnection' => { isa => 'ExBase', },
    'ExConnection::VCenter' => { isa => 'ExConnection', fields => ['vcenter_url'] },
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

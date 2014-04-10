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
    'ExAPI' => { isa => 'ExBase' },

    'ExConnection::VCenter' => { isa => 'ExConnection', fields => ['vcenter_url'] },
    'ExAPI::Argument' => { isa => 'ExAPI', fields => ['argument','subroutine']},
    'ExAPI::ObjectType' => { isa => 'ExAPI', fields => ['type'] },
    'ExEntity::Empty' => { isa => 'ExEntity' },
    'ExEntity::NotEmpty' => { isa => 'ExEntity', fields => ['count'] },
    'ExEntity::NoSnapshot' => { isa => 'ExEntity' },
    'ExEntity::FindEntityError' => { isa => 'ExEntity', fields => ['view_type']},
    'ExEntity::ServiceContent' => { isa => 'ExEntity'},
    'ExTask::Error' => { isa => 'ExTask', fields => ['creator'] },
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
#    &Log::debug( "Starting " . ( caller(0) )[3] . " sub" );
#    &Log::dumpobj( "ex", $ex );
#    &Log::debug( "Finishing " . ( caller(0) )[3] . " sub" );
    return 1;
}

sub parse_ex {
    my $ex = shift;
    my $info = {};
    if ( $ex->isa('SoapFault')) {
        # We have a vmware exception
        $info = &object2hash($ex);
    } elsif ( $ex->isa('ExBase') ) {
        # We have  SamuAPI exception
        for my $key ( keys %$ex ) {
            if ( $key eq "trace" ) {
                next;
            }
            $info->{$key} = $ex->{$key};
        }
    } else {
        $info->{error} = $ex;
        $info->{unknow} = "else";
    }
    return $info;
}

sub _object2hash {
    my $obj = shift;
    my $hash = {};
    for my $key ( keys $obj ) {
        if ( ref($obj->{$key} eq "HASH")) {
            $hash->{$key} = &_object2hash($obj->{$key});
        } else {
            $hash->{$key} = $obj->{$key};
        }
    }
    return $hash;
}
1

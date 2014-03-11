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
    'ExEntity::NotEmpty' => { isa => 'ExEntity', fields => ['count'] },
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

sub parse_ex {
    my $ex = shift;
    my $info = {};
    if ( $ex->isa('SoapFault')) {
        # We have a vmware exception
        if ( $ex->{name} eq "DuplicateNameFault") {
            $info = &vmwareDuplicateName($ex);
        } elsif ( $ex->{name} eq "InsufficientResourcesFault" ) {
            $info = &vmwareInsufficientResourcesFault($ex);
        } elsif ( $ex->{name} eq "InvalidArgumentFault" ) {
            $info = &vmwareInvalidArgument($ex);
        } elsif ( $ex->{name} eq 'InvalidRequestFault' ) {
            $info = &vmwareInvalidRequest($ex);
        } elsif ( $ex->{name} eq "InvalidNameFault" ) {
            $info = &vmwareInvalidName($ex);
        } elsif ($ex->{name} eq "NotSupportedFault") {
            $info = &vmwareNotSupported($ex);
        } elsif ( $ex->{name} eq "RuntimeFaultFault") {
            $info = &vmwareRuntimeFault($ex);
        } else {
            $info = { unknown => "unknown_vmware"};
            print Dumper $ex;
        }
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

sub vmwareDuplicateName {
    my $ex = shift;
    my $return = {};
    $return->{name} = $ex->{name};
    $return->{fault_string} = $ex->{fault_string};
    $return->{detail} = { name => $ex->{detail}->{name} };
    $return->{detail}->{object} = { value => $ex->{detail}->{object}->{value}, type => $ex->{detail}->{object}->{type}};
    return $return;
}

sub vmwareInsufficientResourcesFault {
    my $ex = shift;
    my $return = {};
    $return->{fault_string} = $ex->{fault_string};
    $return->{name} = $ex->{name};
    return $return;
}

sub vmwareInvalidArgument {
    my $ex = shift;
    my $return = {};
    $return->{fault_string} = $ex->{fault_string};
    $return->{name} = $ex->{name};
    $return->{invalidProperty} = $ex->{invalidProperty};
    return $return;
}

sub vmwareInvalidRequest {
    my $ex = shift;
    my $return = {};
    $return->{fault_string} = $ex->{fault_string};
    $return->{name} = $ex->{name};
    return $return;
}


sub vmwareInvalidName {
    my $ex = shift;
    my $return = {};
    $return->{fault_string} = $ex->{fault_string};
    $return->{name} = $ex->{name};
    $return->{entity} = $ex->{entity};
    return $return;
}

sub vmwareNotSupported {
    my $ex = shift;
    my $return = {};
    $return->{fault_string} = $ex->{fault_string};
    $return->{name} = $ex->{name};
    return $return;
}

sub vmwareRuntimeFault {
    my $ex = shift;
    my $return = {};
    $return->{fault_string} = $ex->{fault_string};
    $return->{name} = $ex->{name};
    return $return;
}
1

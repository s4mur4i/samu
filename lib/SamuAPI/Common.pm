use strict;
use warnings;

package Common;
use FindBin;
use SupportCommon::Common;
use VMware::VIRuntime;

=pod

=head1 Common.pm

Collector sub for VmwareAPI modules

=cut

BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
}

use SamuAPI::Exception;
use SamuAPI::VCenter;
use SamuAPI::Entity;

&Log::debug("Loaded module common");

our $VERSION = '1.0.0';

1

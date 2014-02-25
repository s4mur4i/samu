use strict;
use warnings;

package Common;
use FindBin;

=pod

=head1 Common.pm

Collector sub for SupportCommon modules

=cut

use SupportCommon::Log;
use SupportCommon::Table_csv;

&Log::debug("Loaded module common");

our $VERSION = '1.0.0';

1

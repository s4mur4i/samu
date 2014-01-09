use strict;
use warnings;

package common;
use FindBin;

=pod

=head1 common.pm

Collector sub for SupportCommon modules

=cut

use SupportCommon::log;
use SupportCommon::table_csv;

&log::debug("Loaded module common");

our $VERSION = '1.0.0';

1

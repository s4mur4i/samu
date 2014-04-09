package Misc;

use strict;
use warnings;

=pod

=head1 Misc.pm

Subroutines for Misc.pm

=cut

BEGIN {
    use Exporter;
    our @ISA    = qw( Exporter );
    our @EXPORT = qw( );
}

sub rand_3digit {
    return int( rand(999) );
}

1

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

sub increment_disk_name {
    my ($name) = @_;
    my ( $pre, $num, $post );
    if ( $name =~ /(.*_\d+)_(\d+)(\.vmdk)/ ) {
        ( $pre, $num, $post ) = ( $1, $2, $3 );
        $num++;
        # FIXME need better detection here
        if ( $num == 7 ) {
            $num++;
        } elsif ( $num > 15 ) {
            ExEntity::Range->throw( error  => 'Cannot increment further. Last disk used', entity => $name, count  => '15');
        }   
    }   
    else {
        # we will never enter here with current naming
        ( $pre, $post ) = $name =~ /(.*)(\.vmdk)/;
        $num = 1;
    }   
    return "${pre}_$num$post";
} 

1

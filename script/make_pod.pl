#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Pod::Select;

my @relevant = ("SamuAPI", "SamuRest/Controller", "SupportCommon");
my $docdir = "$Bin/../doc/";

for my $dir ( @relevant ) {
    my $fulldir = "$Bin/../lib/" . $dir;
    opendir( my $dirfh, $fulldir);
    while ( my $file =readdir( $dirfh ) ) {
        next if ($file =~ m/^\./);
        podselect({-output => "${docdir}$file"}, "$fulldir/$file");
    }
    closedir $dirfh;
}
1;

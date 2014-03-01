package Test::SamuRest;

use strict;
use warnings;
use DBI;
use File::Spec;

my ( undef, $path ) = File::Spec->splitpath(__FILE__);

sub init {

    $ENV{TEST_SAMUREST_DB} = 'dbi:SQLite:dbname=:memory:';

    my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:");
    my $sql_file = "$path/../../../db/samu.sql";
    open(my $fh, '<', $sql_file) or die "Can't open $sql_file\n";
    my $sql = do { local $/; <$fh>; };
    close($fh);

    my @parts = split(';', $sql);
    foreach my $part (@parts) {
        next unless $part =~ /\S/;
        $dbh->do($part) or die $dbh->errstr;
    }
}

1;
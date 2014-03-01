package Test::SamuRest;

use strict;
use warnings;
use DBI;
use File::Spec;
use File::Temp qw/tempfile/;

my ( undef, $path ) = File::Spec->splitpath(__FILE__);

sub init {

    my ($fh, $filename) = tempfile(EXLOCK => 0);
    $ENV{TEST_SAMUREST_DB} = 'dbi:SQLite:dbname=' . $filename;

    my $dbh = DBI->connect($ENV{TEST_SAMUREST_DB}, '', '', { AutoCommit => 1, PrintError => 1, RaiseError => 1});
    my $sql_file = "$path/../../../db/samu.sql";
    open($fh, '<', $sql_file) or die "Can't open $sql_file\n";
    my $sql = do { local $/; <$fh>; };
    close($fh);

    my @parts = split(';', $sql);
    foreach my $part (@parts) {
        next unless $part =~ /\S/;
        $dbh->do($part . ';') or die $dbh->errstr;
    }
}

1;
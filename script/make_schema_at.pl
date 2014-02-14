#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use DBIx::Class::Schema::Loader qw/ make_schema_at /;

make_schema_at(
    'DB::Schema',
    {   debug => 1,
        dump_directory => "$Bin/../lib",
    },
    [   'dbi:SQLite:db/samu.db'    ]
);

1;
package Table_csv;

use strict;
use warnings;
use Text::Table;
use Class::CSV;

=pod

=head1 table_csv.pm

Subroutines from SupportCommon/table_csv.pm

=cut

my $csv;
my $tbh;

=pod

=head1 create_table

=head2 PURPOSE

Creates main table object

=head2 PARAMETERS

=over

=back

=head2 RETURNS

True on success

=head2 DESCRIPTION

=head2 THROWS

Connection::Connect if object already exists

=head2 COMMENTS

=head2 TEST COVERAGE

Tested if table object is create correclty and is Text::Table as required
Tested if exception is thrown after second create

=cut

sub create_table {
    &Log::debug("Starting  " . (caller(0))[3] . " sub");
    if ( !defined($tbh) ) {
        &Log::debug("Creating table object");
        $tbh = Text::Table->new();
    }
    else {
        Connection::Connect->throw(
            error => "Backend object alreday exists",
            type  => 'Output',
            dest  => 'tbh'
        );
    }
    &Log::debug("Finishing " .(caller(0))[3] . " sub");
    return 1;
}

=pod

=head1 create_csv

=head2 PURPOSE

Create CSV main object

=head2 PARAMETERS

=over

=item header

array ref to title names

=back

=head2 RETURNS

True on success

=head2 DESCRIPTION

=head2 THROWS

Connection::Connect if object already exists

=head2 COMMENTS

=head2 TEST COVERAGE

Tested if csv object is created as expected as a Class::CSV object
Tested if exception is thrown after second create

=cut

sub create_csv {
    my ($header) = @_;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    if ( !defined($csv) ) {
        &Log::debug("Creating csv object");
        $csv = Class::CSV->new( fields => $header );
    }
    else {
        Connection::Connect->throw(
            error => "Backend object alreday exists",
            type  => 'Output',
            dest  => 'csv'
        );
    }
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return 1;
}

=pod

=head1 add_row

=head2 PURPOSE

Adds a row to the table/csv main object

=head2 PARAMETERS

=over

=item row

Array ref with the information

=back

=head2 RETURNS

True on success

=head2 DESCRIPTION

=head2 THROWS

Connection::Connect if no global objects exists

=head2 COMMENTS

=head2 TEST COVERAGE

Test if true is returned after success
Tested if exception is thrown if no objects are defined

=cut

sub add_row {
    my ($row) = @_;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    &Log::dumpobj( "row", $row );
    if ( defined($tbh) ) {
        &Log::debug("Adding row to table");
        $tbh->add(@$row);
    }
    elsif ( defined $csv ) {
        &Log::debug("Adding row to csv");
        $csv->add_line($row);
    }
    else {
        Connection::Connect->throw(
            error => "No backend object defined",
            type  => 'Output',
            dest  => 'tbh/csv'
        );
    }
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return 1;
}

=pod

=head1 print

=head2 PURPOSE

Prints the information of the handler object

=head2 PARAMETERS

=over

=back

=head2 RETURNS

True on success

=head2 DESCRIPTION

=head2 THROWS

Connection::Connect if no global objects exists

=head2 COMMENTS

=head2 TEST COVERAGE

Tested if table and csv output is as expected, also tested if undefines the global objects
Tested if exception is thrown if no objects are defined

=cut

sub print {
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    if ( defined($tbh) ) {
        &Log::debug("Printing from table");
        $tbh->load;
        print $tbh;
        undef $tbh;
    }
    elsif ( defined $csv ) {
        &Log::debug("Printing from csv");
        $csv->print;
        undef $csv;
    }
    else {
        Connection::Connect->throw(
            error => "No backend object defined",
            type  => 'Output',
            dest  => 'tbh/csv'
        );
    }
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return 1;
}

=pod

=head1 option_parser

=head2 PURPOSE

Parses option to decide if table or csv should be used

=head2 PARAMETERS

=over

=item titles

Array ref to use for headers

=back

=head2 RETURNS

True on success

=head2 DESCRIPTION

=head2 THROWS

Vcenter::Opts if unknown opts is requested for output

=head2 COMMENTS

We need to add test to see if we can create a mock option hash for vmware to use and to add requested options

=head2 TEST COVERAGE

=cut

sub option_parser {
    my ($titles) = @_;
    &Log::debug("Starting " . (caller(0))[3] . " sub");
    &Log::dumpobj( "titles", $titles );
    my $output = &Opts::get_option('output');
    if ( $output eq 'table' ) {
        &Output::create_table;
    }
    elsif ( $output eq 'csv' ) {
        &Output::create_csv($titles);
    }
    else {
        Vcenter::Opts->throw(
            error => "Unknwon option requested",
            opt   => $output
        );
    }
    if ( !&Opts::get_option('noheader') ) {
        &Output::add_row($titles);
    }
    else {
        &Log::info("Skipping header adding");
    }
    &Log::debug("Finishing " . (caller(0))[3] . " sub");
    return 1;
}

sub return_csv {
    return $csv;
}

sub return_tbh {
    return $tbh;
}

1

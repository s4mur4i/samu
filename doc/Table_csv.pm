=pod

=head1 table_csv.pm

Subroutines from SupportCommon/table_csv.pm

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


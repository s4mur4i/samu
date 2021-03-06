package SamuRest::Model::Database;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'DB::Schema',

    connect_info => {
        dsn => $ENV{TEST_SAMUREST_DB} ? $ENV{TEST_SAMUREST_DB} : 'dbi:SQLite:db/samu.db',
        user => '',
        password => '',
    }
);

=head1 NAME

SamuRest::Model::Database - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<SamuRest>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Auth::Schema>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.6

=head1 AUTHOR

s4mur4i

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

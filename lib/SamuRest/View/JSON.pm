package SamuRest::View::JSON;
use Moose;
use namespace::autoclean;
#use base qw( Catalyst::View::JSON )

extends 'Catalyst::View::JSON';

=head1 NAME

SamuRest::View::JSON - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=head1 AUTHOR

Krisztian Banhidy,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

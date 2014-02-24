use utf8;
package DB::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

DB::Schema::Result::User

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 username

  data_type: 'text'
  is_nullable: 1

=head2 email

  data_type: 'text'
  is_nullable: 1

=head2 last_modified

  data_type: 'datetime'
  is_nullable: 1

=head2 password

  data_type: 'char'
  is_nullable: 1
  size: 40

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "text", is_nullable => 1 },
  "email",
  { data_type => "text", is_nullable => 1 },
  "last_modified",
  { data_type => "datetime", is_nullable => 1 },
  "password",
  { data_type => "char", is_nullable => 1, size => 40 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<username_unique>

=over 4

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("username_unique", ["username"]);

=head1 RELATIONS

=head2 user_roles

Type: has_many

Related object: L<DB::Schema::Result::UserRole>

=cut

__PACKAGE__->has_many(
  "user_roles",
  "DB::Schema::Result::UserRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_values

Type: has_many

Related object: L<DB::Schema::Result::UserValue>

=cut

__PACKAGE__->has_many(
  "user_values",
  "DB::Schema::Result::UserValue",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 roles

Type: many_to_many

Composing rels: L</user_roles> -> role

=cut

__PACKAGE__->many_to_many("roles", "user_roles", "role");


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2014-02-24 20:32:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:49EPbtAUghjYp4L+G0fS0Q

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");
__PACKAGE__->add_columns('last_modified', { %{__PACKAGE__->column_info('last_modified')}, set_on_create => 1, set_on_update => 1 });

sub set_all_roles {
	my ($self,@roleids) = @_;
	$self->user_roles->delete;
	foreach my $role_id ( @roleids) {
		$self->user_roles->create({role_id=> $role_id});
	}
	return $self;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

package DB::Schema::ResultSet::UserValue;

use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

sub get_user_values {
    my ($self, $user_id) = @_;

    my %data;
    my $rs = $self->search({ user_id => $user_id });
    while (my $r = $rs->next) {
        $data{ $r->value->name } = $r->data;
    }

    return wantarray ? %data : \%data;
}

sub set_user_value {
    my ($self, $user_id, $name, $value) = @_;

    my $schema = $self->result_source->schema;

    my $vr = $schema->resultset('Value')->find({ name => $name });
    return unless $vr; # or create it on the fly? TODO

    my $r = $self->find({ user_id => $user_id, value_id => $vr->id });
    if ($r) {
        $r->data($value);
        $r->update();
    } else {
        $r = $self->create({
            user_id => $user_id,
            value_id => $vr->id,
            data => $value
        });
    }
    return $r;
}

sub delete_user_value {
    my ($self, $user_id, $name) = @_;

    my $schema = $self->result_source->schema;

    my $vr = $schema->resultset('Value')->find({ name => $name });
    return unless $vr; # or create it on the fly? TODO

    $self->search({ user_id => $user_id, value_id => $vr->id })->delete;
    return 1;
}

1;
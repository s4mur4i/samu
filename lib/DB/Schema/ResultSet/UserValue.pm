package DB::Schema::ResultSet::UserValue;

use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use Crypt::CBC;

our $SECRET_KEY = 'somethinghardtoguess';
sub __get_crypt {
    return Crypt::CBC->new(
        -key    => 'my secret key',
        -cipher => 'Blowfish'
    );
}

sub get_user_values {
    my ($self, $user_id) = @_;

    my %data;
    my $rs = $self->search({ user_id => $user_id });
    while (my $r = $rs->next) {
        my $name = $r->value->name;
        next if $name =~ /password/; # skip password?
        $data{ $name } = $r->data;
    }

    return wantarray ? %data : \%data;
}

sub get_user_value {
    my ($self, $user_id, $name) = @_;

    my $schema = $self->result_source->schema;

    my $vr = $schema->resultset('Value')->find({ name => $name });
    return unless $vr;

    my $r = $self->find({ user_id => $user_id, value_id => $vr->id });
    return unless $r;

    if ($name =~ /password/) {
        return __get_crypt()->decrypt($r->data);
    } else {
        return $r->data;
    }
}

sub set_user_value {
    my ($self, $user_id, $name, $value) = @_;

    my $schema = $self->result_source->schema;

    my $vr = $schema->resultset('Value')->find({ name => $name });
    return unless $vr; # or create it on the fly? TODO

    if ($name =~ /password/) { # or use eq
        $value = __get_crypt()->encrypt($value);
    }

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
    return unless $vr;

    $self->search({ user_id => $user_id, value_id => $vr->id })->delete;
    return 1;
}

1;
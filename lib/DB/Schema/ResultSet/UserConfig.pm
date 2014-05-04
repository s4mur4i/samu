package DB::Schema::ResultSet::UserConfig;

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

sub get_user_configs {
    my ($self, $user_id) = @_;
    my %data;
# Search if config display is true
    my $rs = $self->search({
        user_id => $user_id,
        'config.display' => 1
    }, {
        join => 'config',
        prefetch => 'config'
    });
    while (my $r = $rs->next) {
        my $name = $r->config->name;
        $data{ $name } = $r->data;
    }

    return wantarray ? %data : \%data;
}

sub get_user_config {
    my ($self, $user_id, $name) = @_;

    my $schema = $self->result_source->schema;

    my $vr = $schema->resultset('Config')->find({ name => $name });
    return unless $vr;

    my $r = $self->find({ user_id => $user_id, config_id => $vr->id });
    return unless $r;
    if ($vr->encrypt) {
        return __get_crypt()->decrypt($r->data);
    } else {
        return $r->data;
    }
}

sub set_user_config {
    my ($self, $user_id, $name, $value) = @_;

    my $schema = $self->result_source->schema;

    my $vr = $schema->resultset('Config')->find({ name => $name });
    return unless $vr;

    if ($vr->encrypt) {
        $value = __get_crypt()->encrypt($value);
    }

    my $r = $self->find({ user_id => $user_id, config_id => $vr->id });
    if ($r) {
        $r->data($value);
        $r->update();
    } else {
        $r = $self->create({
            user_id => $user_id,
            config_id => $vr->id,
            data => $value
        });
    }
    return $r;
}

sub delete_user_config {
    my ($self, $user_id, $name) = @_;

    my $schema = $self->result_source->schema;

    my $vr = $schema->resultset('Config')->find({ name => $name });
    return unless $vr;

    $self->search({ user_id => $user_id, config_id => $vr->id })->delete;
    return 1;
}

1;

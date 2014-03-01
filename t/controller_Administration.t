use strict;
use warnings;
use Test::More;

use Catalyst::Test 'SamuRest';
use SamuRest::Controller::Administration;
use HTTP::Request::Common;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::SamuRest;
use Data::Dumper;
use JSON;

Test::SamuRest->init();

my $base_url = '/admin';

## register
diag("test register");

my $resp = request POST $base_url, [
    username => 'testuser',
    password => 'testpass',
];
ok($resp->is_success, 'register POST OK.');
ok($resp->header('Content-Type') =~ /json/, 'return json');
my $data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Email/, 'email is required.');

$resp = request POST $base_url, [
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Username/i, 'username is required.');

$resp = request POST $base_url, [
    username => 'testuser',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Password/i, 'password is required.');

$resp = request POST $base_url, [
    username => 'testuser',
    password => 'testpass',
    email => 'test',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Email/i, 'Email is invalid.');

$resp = request POST $base_url, [
    username => 'testuser',
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
diag(Dumper(\$data));

ok( request('/admin/roles')->is_success, 'Request should succeed' );
done_testing();

use strict;
use warnings;
use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::SamuRest;
use vars qw/$dbh/;
BEGIN { $dbh = Test::SamuRest->init(); } # before Catalyst::Test

use Catalyst::Test 'SamuRest';
use SamuRest::Controller::Administration;
use HTTP::Request;
use HTTP::Request::Common qw/POST DELETE GET PUT/;
use Data::Dumper;
use JSON;

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
is($data->{result}, 'success', 'register OK');
my $user_id = $data->{id};
ok($data->{id}, 'register id');

$resp = request POST $base_url, [
    username => 'testuser',
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Username/i, 'Username is already signed up.');

$resp = request POST $base_url, [
    username => 'testuser2',
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Email/i, 'Email is already signed up.');

diag("test profile");
$data = decode_json( get("$base_url/profile/$user_id") );
is($data->{result}, 'success', 'profile OK');
is($data->{username}, 'testuser', 'username ok');
is($data->{email}, 'test@example.com', 'email ok');

$resp = request("$base_url/profile/XXX");
is($resp->code, 400, 'Bad Request');

diag("test list");
$data = decode_json( get("$base_url/list") );
is($data->{1}, 'testuser', 'get list OK');

diag("test list/testuser");
$data = decode_json( get("$base_url/list/testuser") );
is($data->{id}, $user_id, 'get list/testuser OK');

$data = decode_json( get("$base_url/list/testuserXXX") );
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /find user/i, 'failed to find user testuserXXX.');

diag("test login");
$resp = request POST "$base_url/login", [
    username => 'testuser',
    password => 'testpass',
];
$data = decode_json($resp->content);
is($data->{result}, 'success', 'login OK');
my $sessionid = $data->{sessionid};

$resp = request POST "$base_url/login";
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Username/i, 'Username is required for login');

$resp = request POST "$base_url/login", [
    username => 'testuser',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /Password/i, 'Password is required for login');

$resp = request POST "$base_url/login", [
    username => 'testuserZZz',
    password => 'testpass',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /find user/i, 'wrong username');

$resp = request POST "$base_url/login", [
    username => 'testuser',
    password => 'testpassZzz',
];
$data = decode_json($resp->content);
is($data->{result}, 'error', 'return error');
ok($data->{message} =~ /password/i, 'wrong password');

diag("test profile me");
$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{result}, 'success', 'profile me OK');
is($data->{username}, 'testuser', 'username ok');
is($data->{email}, 'test@example.com', 'email ok');
ok( scalar(@{$data->{roles}}) == 0, 'no roles');

diag("test profile update");
$resp = request POST "$base_url/profile/-/$sessionid", [
    username => 'testuser2',
    password => 'testpass2',
    email => 'test2@example.com'
];
is($data->{result}, 'success', 'update profile OK');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{result}, 'success', 'profile get after update OK');
is($data->{username}, 'testuser2', 'username ok');
is($data->{email}, 'test2@example.com', 'email ok');

diag("test logoff");
$data = decode_json( get("$base_url/logoff/-/$sessionid") );
is($data->{result}, 'success', 'logoff OK');

diag("test profile me after logout");
$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{result}, 'error', 'return error after logout');
ok($data->{message} =~ /login/, 'not login yet');

$resp = request POST "$base_url/login", [
    username => 'testuser2',
    password => 'testpass2',
];
$data = decode_json($resp->content);
is($data->{result}, 'success', 'login after password changes OK');
$sessionid = $data->{sessionid};

#### TEST ROLE
$data = decode_json( get("$base_url/roles") );
is($data->{result}, 'error', 'return error'); # requires Permission

$dbh->do(qq~INSERT INTO "roles" VALUES(1,'admin');~);
$dbh->do(qq~INSERT INTO "roles" VALUES(2,'guest');~);
$dbh->do(qq~INSERT INTO "roles" VALUES(3,'registered');~);
$dbh->do(qq~INSERT INTO "roles" VALUES(4,'privilege');")~);
$dbh->do(qq~INSERT INTO "user_roles" VALUES($user_id,1);~); # requires admin

$data = decode_json( get("$base_url/roles/-/$sessionid") );
is($data->{1}, 'admin');
is($data->{2}, 'guest');
is($data->{3}, 'registered');
is($data->{4}, 'privilege');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is_deeply($data->{roles}, ['admin'], 'get user roles ok');

$resp = request POST "$base_url/roles/privilege/-/$sessionid", [
    user_id => $user_id
];
$data = decode_json($resp->content);
is($data->{result}, 'success', 'set roles OK');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is_deeply($data->{roles}, ['admin', 'privilege'], 'get user roles ok');

$data = decode_json( get("$base_url/roles/privilege") );
ok(grep { $_ eq 'testuser2' } @{$data->{privilege}}, 'get testuser2 in privilege');

my $req = HTTP::Request->new('DELETE' => "$base_url/roles/privilege/-/$sessionid");
$req->content("user_id=$user_id"); $req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{result}, 'success', 'delete roles OK');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is_deeply($data->{roles}, ['admin'], 'get user roles ok');

### Config

$dbh->do(qq~INSERT INTO "config" VALUES(1,'vcenter_url',1,0);~);
$dbh->do(qq~INSERT INTO "config" VALUES(2,'vcenter_username',1,0);~);
$dbh->do(qq~INSERT INTO "config" VALUES(3,'vcenter_password',0,1);~);

$resp = request POST "$base_url/profile/$user_id/configs/-/$sessionid", [
    user_id => $user_id,
    name => 'vcenter_url',
    value => 'http://localhost/'
];
$data = decode_json($resp->content);
is($data->{result}, 'success', 'set configs OK');

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
is($data->{vcenter_url}, 'http://localhost/');
ok(not exists $data->{vcenter_password});
ok(not exists $data->{vcenter_username});

$resp = request POST "$base_url/profile/$user_id/configs/-/$sessionid", [
    user_id => $user_id,
    name => 'vcenter_password',
    value => 'testpass'
];
$data = decode_json($resp->content);

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
is($data->{vcenter_url}, 'http://localhost/');
ok(not exists $data->{vcenter_password});
ok(not exists $data->{vcenter_username});

$resp = request POST "$base_url/profile/$user_id/configs/-/$sessionid", [
    user_id => $user_id,
    name => 'vcenter_username',
    value => 'vuser'
];
$data = decode_json($resp->content);

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
is($data->{vcenter_url}, 'http://localhost/');
ok(not exists $data->{vcenter_password});
is($data->{vcenter_username}, 'vuser');

$req = HTTP::Request->new('DELETE' => "$base_url/profile/$user_id/configs/-/$sessionid");
$req->content("user_id=$user_id&name=vcenter_url"); $req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{result}, 'success', 'delete configs OK');

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
ok( (not exists $data->{vcenter_url}), 'delete vcenter_url OK');
ok(not exists $data->{vcenter_password});
is($data->{vcenter_username}, 'vuser');

### REST of user related functions
diag("test delete user");

$data = decode_json( get("$base_url/profile/$user_id") );
is($data->{result}, 'success', 'profile OK');
is($data->{username}, 'testuser2', 'username ok');
is($data->{email}, 'test2@example.com', 'email ok');

$resp = request DELETE "$base_url/profile/$user_id/-/$sessionid";
$data = decode_json($resp->content);
is($data->{result}, 'success', 'delete USER OK');

$data = decode_json( get("$base_url/profile/$user_id") );
is($data->{result}, 'error', 'return error');

$resp = request POST $base_url, [
    username => 'testuser2',
    password => 'testpass2',
    email => 'test2@example.com',
];
$data = decode_json($resp->content);
is($data->{result}, 'success', 'register OK');
$user_id = $data->{id};
ok($data->{id}, 'register id');

$resp = request POST "$base_url/login", [
    username => 'testuser2',
    password => 'testpass2',
];
$data = decode_json($resp->content);
is($data->{result}, 'success', 'login OK');
$sessionid = $data->{sessionid};

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{result}, 'success', 'profile OK');
is($data->{username}, 'testuser2', 'username ok');
is($data->{email}, 'test2@example.com', 'email ok');

$resp = request DELETE "$base_url/profile/-/$sessionid";
$data = decode_json($resp->content);
is($data->{result}, 'success', 'delete profile_me OK');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{result}, 'error', 'return error');

done_testing();

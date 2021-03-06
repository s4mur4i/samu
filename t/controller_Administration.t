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
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Email/, 'email is required.');

$resp = request POST $base_url, [
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Username/i, 'username is required.');

$resp = request POST $base_url, [
    username => 'testuser',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Password/i, 'password is required.');

$resp = request POST $base_url, [
    username => 'testuser',
    password => 'testpass',
    email => 'test',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Email/i, 'Email is invalid.');

$resp = request POST $base_url, [
    username => 'testuser',
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'register OK');
my $user_id = $data->{result}->[0]->{id};
ok($data->{result}->[0]->{id}, 'register id');

$resp = request POST $base_url, [
    username => 'testuser',
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Username/i, 'Username is already signed up.');

$resp = request POST $base_url, [
    username => 'testuser2',
    password => 'testpass',
    email => 'test@example.com',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Email/i, 'Email is already signed up.');

diag("test profile");
$data = decode_json( get("$base_url/profile/$user_id") );
is($data->{status}, 'success', 'profile OK');
is($data->{result}->[0]->{username}, 'testuser', 'username ok');
is($data->{result}->[0]->{email}, 'test@example.com', 'email ok');

$resp = request("$base_url/profile/XXX");
is($resp->code, 400, 'Bad Request');

diag("test list");
$data = decode_json( get("$base_url/list") );
is($data->{result}->[0]->{1}, 'testuser', 'get list OK');

diag("test list/testuser");
$data = decode_json( get("$base_url/list/testuser") );
is($data->{result}->[0]->{id}, $user_id, 'get list/testuser OK');

$data = decode_json( get("$base_url/list/testuserXXX") );
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /find user/i, 'failed to find user testuserXXX.');

diag("test login");
$resp = request POST "$base_url/login", [
    username => 'testuser',
    password => 'testpass',
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'login OK');
my $sessionid = $data->{result}->[0]->{sessionid};

$resp = request POST "$base_url/login";
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Username/i, 'Username is required for login');

$resp = request POST "$base_url/login", [
    username => 'testuser',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Password/i, 'Password is required for login');

$resp = request POST "$base_url/login", [
    username => 'testuserZZz',
    password => 'testpass',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /find user/i, 'wrong username');

$resp = request POST "$base_url/login", [
    username => 'testuser',
    password => 'testpassZzz',
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /password/i, 'wrong password');

diag("test profile me");
$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{status}, 'success', 'profile me OK');
is($data->{result}->[0]->{username}, 'testuser', 'username ok');
is($data->{result}->[0]->{email}, 'test@example.com', 'email ok');
ok( scalar(@{$data->{result}->[0]->{roles}}) == 0, 'no roles');

diag("test profile update");
$resp = request POST "$base_url/profile/-/$sessionid", [
    username => 'testuser3',
    password => 'testpass3',
    email => 'test3@example.com'
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'update profile OK');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{status}, 'success', 'profile get after update OK');
is($data->{result}->[0]->{username}, 'testuser3', 'username ok');
is($data->{result}->[0]->{email}, 'test3@example.com', 'email ok');

$resp = request POST "$base_url/profile/-/$sessionid", [
    email => 'test2.example.com'
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Email/i, 'invalid Email');

$resp = request POST "$base_url/profile/-/$sessionid", [
    email => 'test2@example.com'
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'update profile OK');
$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{status}, 'success', 'profile get after update OK');
is($data->{result}->[0]->{email}, 'test2@example.com', 'email ok');

$resp = request POST "$base_url/profile/-/$sessionid", [
    password => 'testpass2', # login later
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'update profile OK');

$resp = request POST "$base_url/profile/-/$sessionid", [
    username => 'testuser2',
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'update profile OK');
$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{status}, 'success', 'profile get after update OK');
is($data->{result}->[0]->{username}, 'testuser2', 'username ok');

diag("test logoff");
$data = decode_json( get("$base_url/logoff/-/$sessionid") );
is($data->{status}, 'success', 'logoff OK');

diag("test profile me after logout");
$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{status}, 'error', 'return error after logout');
ok($data->{message} =~ /login/, 'not login yet');

$resp = request POST "$base_url/login", [
    username => 'testuser2',
    password => 'testpass2',
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'login after password changes OK');
$sessionid = $data->{result}->[0]->{sessionid};

#### TEST ROLE
$data = decode_json( get("$base_url/roles") );
is($data->{status}, 'error', 'return error'); # requires Permission

$dbh->do(qq~INSERT INTO "roles" VALUES(1,'admin');~);
$dbh->do(qq~INSERT INTO "roles" VALUES(2,'guest');~);
$dbh->do(qq~INSERT INTO "roles" VALUES(3,'registered');~);
$dbh->do(qq~INSERT INTO "roles" VALUES(4,'privilege');")~);
$dbh->do(qq~INSERT INTO "user_roles" VALUES($user_id,1);~); # requires admin

$data = decode_json( get("$base_url/roles/-/$sessionid") );
is($data->{result}->[0]->{1}, 'admin');
is($data->{result}->[1]->{2}, 'guest');
is($data->{result}->[2]->{3}, 'registered');
is($data->{result}->[3]->{4}, 'privilege');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is_deeply($data->{result}->[0]->{roles}, ['admin'], 'get user roles ok');

$resp = request POST "$base_url/roles/privilege/-/$sessionid", [
    user_id => $user_id
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'set roles OK');

$resp = request POST "$base_url/roles/unknownROLE/-/$sessionid", [
    user_id => $user_id
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /role/i, 'set unknown role failed.');

$resp = request POST "$base_url/roles/privilege/-/$sessionid";
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /user_id/i, 'user_id required.');

$resp = request POST "$base_url/roles/privilege/-/$sessionid", [
    user_id => 'ZZzzz'
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Unknown user/i, 'Unknown user');

$resp = request POST "$base_url/roles/privilege/-/$sessionid", [
    user_id => $user_id
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Role already granted/i, 'Role already granted.');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is_deeply($data->{result}->[0]->{roles}, ['admin', 'privilege'], 'get user roles ok');

$data = decode_json( get("$base_url/roles/privilege") );
is($data->{result}->[0]->{privilege}, 'testuser2', 'get testuser2 in privilege');

my $req = HTTP::Request->new('DELETE' => "$base_url/roles/privilege/-/$sessionid");
$req->content("user_id=$user_id"); $req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{status}, 'success', 'delete roles OK');

$req = HTTP::Request->new('DELETE' => "$base_url/roles/privilege/-/$sessionid");
$req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /user_id/i, 'user_id required');

$req = HTTP::Request->new('DELETE' => "$base_url/roles/privilege/-/$sessionid");
$req->content("user_id=Zzzz"); $req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Unknown user/i, 'Unknown user');

$req = HTTP::Request->new('DELETE' => "$base_url/roles/privilege/-/$sessionid");
$req->content("user_id=$user_id"); $req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Role already deleted/i, 'Role already deleted');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is_deeply($data->{result}->[0]->{roles}, ['admin'], 'get user roles ok');

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
is($data->{status}, 'success', 'set configs OK');

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
is($data->{result}->[0]->{vcenter_url}, 'http://localhost/');
ok(not exists $data->{vcenter_password});
ok(not exists $data->{vcenter_username});

$resp = request POST "$base_url/profile/$user_id/configs/-/$sessionid", [
    user_id => $user_id,
    name => 'vcenter_password',
    value => 'testpass'
];
$data = decode_json($resp->content);

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
is($data->{result}->[0]->{vcenter_url}, 'http://localhost/');
ok(not exists $data->{vcenter_password});
ok(not exists $data->{vcenter_username});

$resp = request POST "$base_url/profile/$user_id/configs/-/$sessionid", [
    user_id => $user_id,
    name => 'vcenter_username',
    value => 'vuser'
];
$data = decode_json($resp->content);

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
is($data->{result}->[0]->{vcenter_url}, 'http://localhost/');
ok(not exists $data->{result}->[0]->{vcenter_password});
is($data->{result}->[0]->{vcenter_username}, 'vuser');

$resp = request POST "$base_url/profile/$user_id/configs/-/$sessionid", [
    user_id => $user_id,
    name => 'unknown_CONFIG',
    value => 'http://localhost/'
];
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Unknown config/i, 'Unknown config');

$req = HTTP::Request->new('DELETE' => "$base_url/profile/$user_id/configs/-/$sessionid");
$req->content("user_id=$user_id&name=vcenter_url"); $req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{status}, 'success', 'delete configs OK');

$data = decode_json( get("$base_url/profile/$user_id/configs/-/$sessionid") );
ok( (not exists $data->{vcenter_url}), 'delete vcenter_url OK');
ok(not exists $data->{vcenter_password});
is($data->{result}->[0]->{vcenter_username}, 'vuser');

$req = HTTP::Request->new('DELETE' => "$base_url/profile/$user_id/configs/-/$sessionid");
$req->content("user_id=$user_id&name=unknown_CONFIG"); $req->content_type('application/x-www-form-urlencoded');
$resp = request($req);
$data = decode_json($resp->content);
is($data->{status}, 'error', 'return error');
ok($data->{message} =~ /Unknown config/i, 'Unknown config');

### REST of user related functions
diag("test delete user");

$data = decode_json( get("$base_url/profile/$user_id") );
is($data->{status}, 'success', 'profile OK');
is($data->{result}->[0]->{username}, 'testuser2', 'username ok');
is($data->{result}->[0]->{email}, 'test2@example.com', 'email ok');

$resp = request DELETE "$base_url/profile/$user_id/-/$sessionid";
$data = decode_json($resp->content);
is($data->{status}, 'success', 'delete USER OK');

$data = decode_json( get("$base_url/profile/$user_id") );
is($data->{status}, 'error', 'return error');

$resp = request POST $base_url, [
    username => 'testuser2',
    password => 'testpass2',
    email => 'test2@example.com',
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'register OK');
$user_id = $data->{result}->[0]->{id};
ok($data->{result}->[0]->{id}, 'register id');

$resp = request POST "$base_url/login", [
    username => 'testuser2',
    password => 'testpass2',
];
$data = decode_json($resp->content);
is($data->{status}, 'success', 'login OK');
$sessionid = $data->{result}->[0]->{sessionid};

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{status}, 'success', 'profile OK');
is($data->{result}->[0]->{username}, 'testuser2', 'username ok');
is($data->{result}->[0]->{email}, 'test2@example.com', 'email ok');

$resp = request DELETE "$base_url/profile/-/$sessionid";
$data = decode_json($resp->content);
is($data->{status}, 'success', 'delete profile_me OK');

$data = decode_json( get("$base_url/profile/-/$sessionid") );
is($data->{status}, 'error', 'return error');

done_testing();

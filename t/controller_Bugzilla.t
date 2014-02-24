use strict;
use warnings;
use Test::More;


use Catalyst::Test 'SamuRest';
use SamuRest::Controller::Bugzilla;

ok( request('/bugzilla')->is_success, 'Request should succeed' );
done_testing();

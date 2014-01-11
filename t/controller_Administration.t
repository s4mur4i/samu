use strict;
use warnings;
use Test::More;


use Catalyst::Test 'SamuRest';
use SamuRest::Controller::Administration;

ok( request('/administration')->is_success, 'Request should succeed' );
done_testing();

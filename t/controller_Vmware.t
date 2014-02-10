use strict;
use warnings;
use Test::More;


use Catalyst::Test 'SamuRest';
use SamuRest::Controller::Vmware;

ok( request('/vmware')->is_success, 'Request should succeed' );
done_testing();

use strict;
use warnings;
use Test::More;


use Catalyst::Test 'SamuRest';
use SamuRest::Controller::Kayako;

ok( request('/kayako')->is_success, 'Request should succeed' );
done_testing();

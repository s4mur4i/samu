use strict;
use warnings;
use Test::More;


use Catalyst::Test 'SamuRest';
use SamuRest::Controller::Ticket;

ok( request('/ticket')->is_success, 'Request should succeed' );
done_testing();

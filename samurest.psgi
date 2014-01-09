use strict;
use warnings;

use SamuRest;

my $app = SamuRest->apply_default_middlewares(SamuRest->psgi_app);
$app;


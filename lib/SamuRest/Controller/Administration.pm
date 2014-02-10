package SamuRest::Controller::Administration;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
	default => 'application/json',
	maps => {
		'application/json'   => 'JSON',
		'text/x-json'        => 'JSON',
	}
);

sub adminBase : Chained('/'): PathPart('admin'): CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash(users_rs => $c->model('Database::User'));
}

sub user : Chained('adminBase') :PathPart('') :Args(0) :ActionClass('REST') {}

sub user_POST {
	my ( $self, $c ) = @_;

	## Retrieve the users_rs stashed by the base action:
	my $users_rs = $c->stash->{users_rs};

	my $params = $c->req->params;
	my $id 		 = $params->{id};
	my $username = $params->{username};
	my $email    = $params->{email};

	return $self->__error($c, "Email is required.") unless $email;

	if ($id) { # update
		my $user = $users_rs->find($id);
		return $self->__error($c, "Can't find user: $id") unless $user;
		$user->email($email);
		$user->update;
		return $self->__ok($c, { id => $user->id });
	}

	# create
	return $self->__error($c, "Username is required.") unless $username;

	## Create the user:
	my $user = $users_rs->create({
		username => $username,
		email    => $email
	});
	return $self->__ok($c, { id => $user->id });
}

sub __ok {
	my ($self, $c, $data) = @_;

	$self->status_ok(
        $c,
        entity => {
        	result => 'success',
            %$data
        },
   );
}

sub __error {
	my ($self, $c, $error) = @_;

	$self->status_ok(
        $c,
        entity => {
        	result => 'error',
            message => $error,
        },
   );
}


# sub list: Chained('adminBase'): PathPart('list'):Args(0) {
#     my ($self,$c) = @_;
# }

# sub user : Chained('adminBase'): Pathpart(''): CaptureArgs(1) {
# 	my ($self, $c, $userid) = @_;
# 	if ($userid =~/\D/){
# 		die "Misue of URL, userid mot only digits";
# 	}
# 	my $users_rs = $c->stash->{users_rs};
# 	my $user = $c->stash->{users_rs}->find({id => $userid},{key =>'primary'});
# 	die "No such user" if (!$user);
# 	## Fixme: return some error;
# 	$c->stash(user=>$user);
# }

# sub userLogin : Chained('user'): PathPart('login'): Args(0) {
# 	my ($self, $c) = @_;
# }

# sub userLogoff : Chained('user'): PathPart('logoff'): Args(0) {
# 	my ($self, $c) = @_;
# }

# sub userDelete: Chained('user'): PathPart('delete'): Args() {
# 	my ($self, $c) = @_;
# 	my $user = $c->stash->{user};
# 	$user->delete();

# 	#FIXME return success
# }

# sub userSetRoles: Chained('user'): PathPart('set_roles'): Args() {
# 	my ($self, $c) = @_;
# 	my $user = $c->stash->{user};
# 	if ( lc $c->req->method eq 'post') {
# 		my @roles = $c->req->param('role');
# 		$user->set_all_roles(@roles);
# 	}
# 	## Fixme return success
# }


# sub profile: Chained('user'): PathPart('profile'):Args(0) {
# 	my ($self, $c) = @_;
# }

__PACKAGE__->meta->make_immutable;

1;

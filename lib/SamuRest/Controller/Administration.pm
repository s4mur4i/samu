package SamuRest::Controller::Administration;

use Moose;
use namespace::autoclean;
use Email::Valid;
use Digest::SHA1 qw/sha1_hex/;

BEGIN { extends 'SamuRest::ControllerX::REST' }

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
	my $password = $params->{password};
	my $email    = $params->{email};

	if ($id) { # update
		my $user = $users_rs->find($id);
		return $self->__error($c, "Can't find user: $id") unless $user;
		if ($email) {
			return $self->__error($c, "Email is invalid.") unless Email::Valid->address($email);
			$user->email($email);
		}
		if ($password) {
			$user->password( sha1_hex($password) );
		}

		$user->update;
		return $self->__ok($c, { id => $user->id });
	}

	# validate
	return $self->__error($c, "Username is required.") unless $username;
	my $cnt = $users_rs->count({ username => $username });
	return $self->__error($c, "Username is already signed up.") if $cnt;
	return $self->__error($c, "Password is required.") unless $password;
	return $self->__error($c, "Email is required.") unless $email;
	return $self->__error($c, "Email is invalid.") unless Email::Valid->address($email);
	$cnt = $users_rs->count({ email => $email });
	return $self->__error($c, "Email is already signed up.") if $cnt;

	## Create the user:
	my $user = $users_rs->create({
		username => $username,
		password => sha1_hex($password),
		email    => $email
	});
	return $self->__ok($c, { id => $user->id });
}

sub profile :Chained('adminBase') :PathPart('profile') :Args(1) :ActionClass('REST') {
	my ($self, $c, $id) = @_;

	return $self->__bad_request($c, "Unknown id") unless $id and $id =~ /^\d+$/;

	my $users_rs = $c->stash->{users_rs};
	my $user = $users_rs->find($id);
	return $self->__error($c, "Can't find user: $id") unless $user;

	$c->stash(user => $user);
}

sub profile_GET {
	my ($self, $c, $id) = @_;

	my $user = $c->stash->{user};
	return $self->__ok($c, { id => $user->id, username => $user->username, email => $user->email });
}

sub profile_DELETE {
	my ($self, $c, $id) = @_;

	# check permission?

	my $user = $c->stash->{user};
	$user->delete;

	return $self->__ok($c, { message => 'deleted.' });
}

sub userlist :Chained('adminBase') :PathPart('list') :Args(0) :ActionClass('REST') {}
sub userlist_GET {
	my ($self, $c) = @_;
	my $users_rs = $c->stash->{users_rs};
	my @users = $c->model('Database::User')->search( undef, { order_by => 'id' } )->all;
	my %result=();
	foreach my $user (@users) {
		$result{$user->id} = $user->username;
	}
	return $self->__ok($c, \%result);
}

sub infouser :Chained('adminBase') :PathPart('list') :Args(1) :ActionClass('REST') {}
sub infouser_GET {
	my ($self, $c, $username) = @_;
	my $users_rs = $c->stash->{users_rs};
	my $user = $users_rs->find( {username => $username} );
	return $self->__error($c, "Can't find user: $username") unless $user;
	return $self->__ok($c, { id => $user->id, username => $user->username });
}

sub userLogin :Chained('adminBase') :PathPart('login') :Args(0) :ActionClass('REST') {
	my ($self, $c) = @_;

	my $params = $c->req->params;
	my $username = $params->{username};
	my $password = $params->{password};

	return $self->__error($c, "Username is required.") unless $username;
	return $self->__error($c, "Password is required.") unless $password;

	my $users_rs = $c->stash->{users_rs};
	my $user = $users_rs->find({ username => $username });
	return $self->__error($c, "Can't find user: $username") unless $user;

	return $self->__error($c, "Incorrect password") unless $user->password eq sha1_hex($password);
	$c->session->{__user} = $user->id;

	return $self->__ok($c, { id => $user->id, username => $user->username, email => $user->email, sessionid => $c->sessionid });
}

sub userLogoff :Chained('adminBase') :PathPart('logoff') :ActionClass('REST') {
	my ($self, $c) = @_;

	delete $c->session->{__user};
	return $self->__ok($c, { sessionid => $c->sessionid });
}

sub me :Chained('adminBase') :PathPart('me') :ActionClass('REST') {
	my ($self, $c) = @_;

	my $user_id = $c->session->{__user};
	return $self->__error($c, "You're not login yet.") unless $user_id;

	my $users_rs = $c->stash->{users_rs};
	my $user = $users_rs->find($user_id);
	return $self->__error($c, "Can't find user: $user_id") unless $user;

	return $self->__ok($c, { id => $user->id, username => $user->username, email => $user->email });
}


# sub userSetRoles: Chained('user'): PathPart('set_roles'): Args() {
# 	my ($self, $c) = @_;
# 	my $user = $c->stash->{user};
# 	if ( lc $c->req->method eq 'post') {
# 		my @roles = $c->req->param('role');
# 		$user->set_all_roles(@roles);
# 	}
# 	## Fixme return success
# }


__PACKAGE__->meta->make_immutable;

1;

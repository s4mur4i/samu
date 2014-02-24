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

sub register : Chained('adminBase') :PathPart('') :Args(0) :ActionClass('REST') {}

sub register_POST {
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

sub profile_me :Chained('adminBase') :PathPart('profile') :Args(0) :ActionClass('REST') {
	my ($self, $c) = @_;
	my $user_id = $self->__is_logined($c);
    $c->stash(user_id=> $user_id);
}

sub profile_me_GET {
    my ($self,$c) = @_;
    my $user_id = $c->stash->{user_id};
    $c->detach("profile", [$user_id]);
}

sub profile_me_POST{
    my ($self,$c) = @_;
    my $user_id = $c->stash->{user_id};
    $c->detach("profile", [$user_id]);
}

sub profile_me_DELETE {
    my ($self,$c) = @_;
    my $user_id = $c->stash->{user_id};
    $c->detach("profile", [$user_id]);
}

sub profile :Chained('adminBase') :PathPart('profile') :Args(1) :ActionClass('REST') {
	my ($self, $c, $id) = @_;
	return $self->__bad_request($c, "Unknown id") unless $id and $id =~ /^\d+$/;
    #Checkek logedin here?
	my $users_rs = $c->stash->{users_rs};
	my $user = $users_rs->find($id);
	return $self->__error($c, "Can't find user: $id") unless $user;
	$c->stash(user => $user);
}

sub profile_GET {
	my ($self, $c, $id) = @_;
	my $user = $c->stash->{user};
    # roles
    my @roles = ();
    my $schema = $c->model('Database');
    my @ret = $c->model('Database::UserRole')->search({user_id => $user->id},undef)->all;
    foreach my $userrole( @ret) {
        my $role = $schema->resultset('Role')->find({id=>$userrole->role_id});
        push(@roles, $role->role);
    }
	return $self->__ok($c, { id => $user->id, username => $user->username, email => $user->email , roles=> \@roles});
}

sub profile_DELETE {
	my ($self, $c, $id) = @_;

	# check permission?
    # admin or self can delete
	my $user = $c->stash->{user};
	$user->delete;

	return $self->__ok($c, { message => 'deleted.' });
}

sub profile_POST {
    my ($self,$c,$id) = @_;
    my $params = $c->req->params;
# Security, only admin or own profiles
# Is there a more friendly way to find the param and update the database?
	my $user = $c->stash->{users_rs}->find({id=>$id});
    if ( $params->{username} ) {
        $user->update( {username=> $params->{username}});    
    }
    if ( $params->{password}) {
        $user->update( {password=> sha1_hex($params->{password})});
    }
    if ( $params->{email}) {
        return $self->__error($c, "Email is invalid.") unless Email::Valid->address($params->{email});
        $user->update( { email => $params->{email}});
    }
	return $self->__ok($c, { username => $user->username });
}

sub listBase: Chained('adminBase') : PathPart('list'): CaptureArgs(0) {}

sub userlist :Chained('listBase') :PathPart('') :Args(0) :ActionClass('REST') {}

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

sub infouser :Chained('listBase') :PathPart('') :Args(1) :ActionClass('REST') {}

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

sub rolesBase: Chained('adminBase'): PathPart('roles') : CaptureArgs(0) {}

sub roles :Chained('rolesBase') :PathPart(''): Args(0) :ActionClass('REST') {
	my ($self, $c) = @_;

	my $user_id = $self->__is_admin($c); # requires admin
}

sub roleslist :Chained('rolesBase') :PathPart(''): Args(1) :ActionClass('REST') {
	my ($self, $c) = @_;
}

sub roleslist_GET {
    my ($self, $c,$type) = @_;
    my %result =();
    my $schema = $c->model('Database');
    my $role_rs = $schema->resultset('Role')->find({ role => $type });
    return $self->__error($c, "Unknown role: $type") unless $role_rs;
    my @users = $c->model('Database::UserRole')->search({role_id => $role_rs->id},undef)->all;
    $result{$type}= [];
    foreach my $user (@users) {
        my $userobj = $schema->resultset('User')->find($user->user_id);
        push($result{$type}, $userobj->username);
    }
    return $self->__ok( $c, \%result);
}

sub roles_GET {
    my ($self, $c) = @_;
    my %result =();
    my @roles = $c->model('Database::Role')->search( undef, { order_by => 'id' } )->all;
    foreach my $role (@roles) {
        $result{$role->id} = $role->role;
    }
    return $self->__ok( $c, \%result);
}

sub roles_POST {
	my ($self, $c) = @_;

	my $params = $c->req->params;
	my $to_user_id = $params->{user_id};
	my $role = $params->{role};

	## validate
	my $schema = $c->model('Database');
	my $role_rs = $schema->resultset('Role')->find({ role => $role });
	return $self->__error($c, "Unknown role: $role") unless $role_rs;

	my $to_user = $schema->resultset('User')->find($to_user_id);
	return $self->__error($c, "Unknown user: $to_user_id") unless $to_user;

	my $cnt = $schema->resultset('UserRole')->count({ user_id => $to_user->id, role_id => $role_rs->id });
	return $self->__error($c, "Role already granted.") if $cnt;

	$schema->resultset('UserRole')->create({ user_id => $to_user->id, role_id => $role_rs->id });
	return $self->__ok($c, { id => $to_user->id });
}

sub roles_DELETE {
	my ($self, $c) = @_;

	my $params = $c->req->params;
	my $to_user_id = $params->{user_id};
	my $role = $params->{role};

	## validate
	my $schema = $c->model('Database');
	my $role_rs = $schema->resultset('Role')->find({ role => $role });
	return $self->__error($c, "Unknown role: $role") unless $role_rs;

	my $to_user = $schema->resultset('User')->find($to_user_id);
	return $self->__error($c, "Unknown user: $to_user_id") unless $to_user;

	my $cnt = $schema->resultset('UserRole')->count({ user_id => $to_user->id, role_id => $role_rs->id });
	return $self->__error($c, "Role already deleted.") unless $cnt;

	$schema->resultset('UserRole')->search({ user_id => $to_user->id, role_id => $role_rs->id })->delete;
	return $self->__ok($c, { id => $to_user->id });
}

__PACKAGE__->meta->make_immutable;

1;

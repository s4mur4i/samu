package SamuRest::Controller::Administration;

use Moose;
use namespace::autoclean;
use Email::Valid;
use Digest::SHA1 qw/sha1_hex/;

BEGIN { extends 'SamuRest::ControllerX::REST' }

=head1 NAME

SamuRest::Controller::Administration - Administration API

=head1 DESCRIPTION

REST API of /admin

=head1 METHODS

=head2 adminBase

base chain for url /admin

=cut

sub adminBase : Chained('/') PathPart('admin') CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash(users_rs => $c->model('Database::User'));
}

=pod

=head2 register

=head2 register_POST

    curl -X POST -d 'username=X&password=P&email=test@email.com' http://localhost:3000/admin/

register user with params of B<username>, B<password>, B<email>

=cut

sub register : Chained('adminBase') PathPart('') Args(0) ActionClass('REST') {}

sub register_POST {
	my ( $self, $c ) = @_;

	## Retrieve the users_rs stashed by the base action:
	my $users_rs = $c->stash->{users_rs};

	my $params = $c->req->params;
	my $username = $params->{username};
	my $password = $params->{password};
	my $email    = $params->{email};

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

=pod

=head2 profile_me, profile_me_GET, profile_me_POST, profile_me_DELETE

    curl http://localhost:3000/admin/profile/-/$sessionid_from_login

get current user info, refer B<profile> below for more details

=cut

sub profile_me : Chained('adminBase') PathPart('profile') Args(0) ActionClass('REST') {
	my ($self, $c) = @_;
	my $user_id = $self->__is_logined($c);
    $c->stash(user_id => $user_id);
    $self->profile_base($c, $user_id);
}

sub profile_me_GET {
    my ($self, $c) = @_;
    $self->profile_GET($c, $c->stash->{user_id});
}

sub profile_me_POST {
    my ($self, $c) = @_;
	$self->profile_POST($c, $c->stash->{user_id});
}

sub profile_me_DELETE {
    my ($self, $c) = @_;
    $self->profile_DELETE($c, $c->stash->{user_id});
}

=pod

=head2 profile

=head2 profile_GET

    curl http://localhost:3000/admin/profile/2/-/$sessionid_from_login

get user basic info with roles etc.

=head2 profile_DELETE

    curl -X DELETE http://localhost:3000/admin/profile/2/-/$sessionid_from_login

delete user, admin or owner only

=head2 profile_POST

    curl -X POST -d 'username=X&password=P&email=test@email.com' http://localhost:3000/admin/profile/2/-/$sessionid_from_login

update user info

=cut

sub profile_base : Chained('adminBase') PathPart('profile') CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    $c->stash(user_id => $id);
    return $self->__bad_request($c, "Unknown id") unless $id and $id =~ /^\d+$/;
    my $users_rs = $c->stash->{users_rs};
    my $user = $users_rs->find($id);
    return $self->__error($c, "Can't find user: $id") unless $user;
    $c->stash(user => $user);
}

sub profile : Chained('profile_base') PathPart('') Args(0) ActionClass('REST') {}

sub profile_GET {
	my ($self, $c) = @_;
    my $id = $c->stash->{user_id};
	my $user = $c->stash->{user};
    my @roles = ();
    my $schema = $c->model('Database');
    my @ret = $c->model('Database::UserRole')->search({user_id => $user->id},undef)->all;
    foreach my $userrole( @ret) {
        my $role = $schema->resultset('Role')->find({id=>$userrole->role_id});
        push(@roles, $role->role);
    }
    my %extend =();
    if ( $id == $c->session->{__user}) {
        #add all user_value stored in table for user
        $extend{self} = "yes";
    } else {
        $extend{self} = "no";
    }
	return $self->__ok($c, { id => $user->id, username => $user->username, email => $user->email , roles=> \@roles, extended => \%extend});
}

sub profile_DELETE {
	my ($self, $c) = @_;

    $self->__is_admin_or_owner($c, $c->stash->{user_id});

	my $user = $c->stash->{user};
	$user->delete;

	return $self->__ok($c, { message => 'deleted.' });
}

sub profile_POST {
    my ($self, $c) = @_;

    my $id = $c->stash->{user_id};
    $self->__is_admin_or_owner($c, $id);

    my $params = $c->req->params;
	my $user = $c->stash->{users_rs}->find({id=>$id});
    if ( $params->{username} ) {
        $user->username($params->{username});
    }
    if ( $params->{password}) {
    	$user->password( sha1_hex($params->{password}) );
    }
    if ( $params->{email}) {
        return $self->__error($c, "Email is invalid.") unless Email::Valid->address($params->{email});
        $user->email($params->{email});
    }
    $user->update();

	return $self->__ok($c, { username => $user->username });
}

=pod

=head2 listBase

for /admin/list chain

=head2 userlist, userlist_GET

    curl http://localhost:3000/admin/list

list users

=cut

sub listBase : Chained('adminBase') PathPart('list') CaptureArgs(0) {}

sub userlist : Chained('listBase') PathPart('') Args(0) ActionClass('REST') {}

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

=pod

=head2 infouser, infouser_GET

    curl http://localhost:3000/admin/list/$username

show one user

=cut

sub infouser : Chained('listBase') PathPart('') Args(1) ActionClass('REST') {}

sub infouser_GET {
	my ($self, $c, $username) = @_;
	my $users_rs = $c->stash->{users_rs};
	my $user = $users_rs->find( {username => $username} );
	return $self->__error($c, "Can't find user: $username") unless $user;
	return $self->__ok($c, { id => $user->id, username => $user->username });
}

=pod

=head2 userLogin

    curl -X POST -d 'username=X&password=P' http://localhost:3000/admin/login

login user, will return sessionid

=cut

sub userLogin : Chained('adminBase') PathPart('login') Args(0) ActionClass('REST') {
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

=pod

=head2 userLogin

    curl http://localhost:3000/admin/logoff

logout user

=cut

sub userLogoff : Chained('adminBase') PathPart('logoff') ActionClass('REST') {
	my ($self, $c) = @_;

	delete $c->session->{__user};
	return $self->__ok($c, { sessionid => $c->sessionid });
}

=pod

=head2 rolesBase

chain for /admin/roles

=head2 roles, roles_GET

show all roles

=head2 roles_POST

    curl -X POST -d 'user_id=$user_id&role=$role' http://localhost:3000/admin/roles

assign $user_id for $role

=head2 roles_POST

    curl -X DELETE -d 'user_id=$user_id&role=$role' http://localhost:3000/admin/roles

unassign $user_id for $role

=cut

sub rolesBase : Chained('adminBase') PathPart('roles') CaptureArgs(0) {}

sub roles : Chained('rolesBase') PathPart('') Args(0) ActionClass('REST') {
	my ($self, $c) = @_;

	my $user_id = $self->__is_admin($c); # requires admin
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

=pod

=head2 roleslist, roleslist_GET

    curl http://localhost:3000/admin/roles/$role

show users for the $role

=cut

sub role : Chained('rolesBase') PathPart('') Args(1) ActionClass('REST') { }

sub role_GET {
    my ($self, $c,$role) = @_;
    my %result =();
    my $schema = $c->model('Database');
    my $role_rs = $schema->resultset('Role')->find({ role => $role });
    return $self->__error($c, "Unknown role: $role") unless $role_rs;
    my @users = $c->model('Database::UserRole')->search({role_id => $role_rs->id},undef)->all;
    $result{$role}= [];
    foreach my $user (@users) {
        my $userobj = $schema->resultset('User')->find($user->user_id);
        push($result{$role}, $userobj->username);
    }
    return $self->__ok( $c, \%result);
}

sub role_DELETE {
    my ($self, $c, $role) = @_;

    my $params = $c->req->params;
    my $to_user_id = $params->{user_id};

    ## validate
    my $schema = $c->model('Database');
    my $role_rs = $schema->resultset('Role')->find({ role => $role });
    return $self->__error($c, "Unknown role: $role") unless $role_rs;

    return $self->__error($c, "param user_id is required.") unless $to_user_id;
    my $to_user = $schema->resultset('User')->find($to_user_id);
    return $self->__error($c, "Unknown user: $to_user_id") unless $to_user;

    my $cnt = $schema->resultset('UserRole')->count({ user_id => $to_user->id, role_id => $role_rs->id });
    return $self->__error($c, "Role already deleted.") unless $cnt;

    $schema->resultset('UserRole')->search({ user_id => $to_user->id, role_id => $role_rs->id })->delete;
    return $self->__ok($c, { id => $to_user->id });
}

sub role_POST {
    my ($self, $c, $role ) = @_;

    my $params = $c->req->params;
    my $to_user_id = $params->{user_id};

    ## validate
    my $schema = $c->model('Database');
    my $role_rs = $schema->resultset('Role')->find({ role => $role });
    return $self->__error($c, "Unknown role: $role") unless $role_rs;

    return $self->__error($c, "param user_id is required.") unless $to_user_id;
    my $to_user = $schema->resultset('User')->find($to_user_id);
    return $self->__error($c, "Unknown user: $to_user_id") unless $to_user;

    my $cnt = $schema->resultset('UserRole')->count({ user_id => $to_user->id, role_id => $role_rs->id });
    return $self->__error($c, "Role already granted.") if $cnt;

    $schema->resultset('UserRole')->create({ user_id => $to_user->id, role_id => $role_rs->id });
    return $self->__ok($c, { id => $to_user->id });
}

=pod

=head2 configs, configs_GET

    curl http://localhost:3000/admin/profile/$userid/configs/-/$sessionid

get user configs

=head2 configs_POST

    curl -X POST -d "name=vcenter_username&config=test2" http://localhost:3000/admin/profile/$userid/configs/-/$sessionid

set user config

=head2 configs_DELETE

    curl -X DELETE -d "name=vcenter_username" http://localhost:3000/admin/profile/$userid/configs/-/$sessionid

delete user configs

=cut

sub configs :Chained('profile_base') PathPart('configs') Args(0) ActionClass('REST') {}

sub configs_GET {
    my ($self, $c) = @_;

    my $id = $c->stash->{user_id};
    $self->__is_admin_or_owner($c, $id);

    my %data = $c->model('Database::UserConfig')->get_user_configs($id);
    return $self->__ok( $c, \%data);
}

sub configs_POST {
    my ($self, $c) = @_;

    my $id = $c->stash->{user_id};
    $self->__is_admin_or_owner($c, $id);

    my $params = $c->req->params;
    my $name  = $params->{name};
    my $value = $params->{value};

    my $r = $c->model("Database::UserConfig")->set_user_config($id, $name, $value);
    return $self->__error($c, "Unknown config name: $name") unless $r;

    return $self->__ok($c, { config_id => $r->config_id, data => $value });
}

sub configs_DELETE {
    my ($self, $c) = @_;

    my $id = $c->stash->{user_id};
    $self->__is_admin_or_owner($c, $id);

    my $params = $c->req->params;
    my $name  = $params->{name};

    my $st = $c->model("Database::UserConfig")->delete_user_config($id, $name);
    return $self->__error($c, "Unknown config name: $name") unless $st;

    return $self->__ok($c, {});
}

__PACKAGE__->meta->make_immutable;

1;

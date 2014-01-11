package SamuRest::Controller::Administration;
use Moose;
use namespace::autoclean;
use strict;
use warnings;
use parent 'Catalyst::Controller';

sub adminBase : Chained('/'): PathPart('admin'): CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash(users_rs => $c->model('Database::User'));
}

sub userRegister : Chained('adminBase'): PathPart('register'): Args(0) {
	my ($self, $c) =@_;
	if(lc $c->req->method eq 'post') {
		my $params = $c->req->params;

		## Retrieve the users_rs stashed by the base action:
		my $users_rs = $c->stash->{users_rs};

		## Create the user:
		my $newuser = $users_rs->create({
		username => $params->{username},
		email    => $params->{email},
		});

		## FIXME return success
	}
}

sub user : Chained('adminBase'): Pathpart(''): CaptureArgs(1) {
	my ($self, $c, $userid) = @_;
	if ($userid =~/\D/){
		die "Misue of URL, userid mot only digits";
	}
	my $user = $c->stash>{user_rs}->find({id => $userid},{key =>'primary'});
	die "No such user" if (!$user);
	## Fixme: return some error;
	$c->stash(user=>$user);
}

sub userLogin : Chained('user'): PathPart('login'): Args(0) {
	my ($self, $c) = @_;
}

sub userLogoff : Chained('user'): PathPart('logoff'): Args(0) {
	my ($self, $c) = @_;
}

sub userDelete: Chained('user'): PathPart('delete'): Args() {
	my ($self, $c) = @_;
	my $user = $c->stash->{user};
	$user->delete();

	#FIXME return success
}

sub userSetRoles: Chained('user'): PathPart('set_roles'): Args() {
	my ($self, $c) = @_;
	my $user = $c->stash->{user};
	if ( lc $c->req->method eq 'post') {
		my @roles = $c->req->param('role');
		$user->set_all_roles(@roles);
	}
	## Fixme return success
}
 
sub userEdit: Chained('user'): PathPart('edit'): Args(0) {
	my ($self, $c) = @_;
	if ( $c $c->req->method eq 'post') {
		my $params = $c->req->params;
		my $user = $c->stash->{user};
		$user->update({email => $params->{email}});
	}
	# FIXME return information
}

sub profile: Chained('user'): PathPart('profile'):Args(0) {
	my ($self, $c) = @_;
}
__PACKAGE__->meta->make_immutable;

1;

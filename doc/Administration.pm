=head1 NAME

SamuRest::Controller::Administration - Administration API

=head1 DESCRIPTION

REST API of /admin

=head1 METHODS

=head2 adminBase

base chain for url /admin

=pod

=head2 register

=head2 register_POST

    curl -X POST -d 'username=X&password=P&email=test@email.com' http://localhost:3000/admin/

register user with params of B<username>, B<password>, B<email>

=pod

=head2 profile_me, profile_me_GET, profile_me_POST, profile_me_DELETE

    curl http://localhost:3000/admin/profile/-/$sessionid_from_login

get current user info, refer B<profile> below for more details

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

=pod

=head2 listBase

for /admin/list chain

=head2 userlist, userlist_GET

    curl http://localhost:3000/admin/list

list users

=pod

=head2 infouser, infouser_GET

    curl http://localhost:3000/admin/list/$username

show one user

=pod

=head2 userLogin

    curl -X POST -d 'username=X&password=P' http://localhost:3000/admin/login

login user, will return sessionid

=pod

=head2 userLogin

    curl http://localhost:3000/admin/logoff

logout user

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

=pod

=head2 roleslist, roleslist_GET

    curl http://localhost:3000/admin/roles/$role

show users for the $role

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


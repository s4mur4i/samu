=pod

=head1 begin

=head2 PURPOSE

The purpose of the begin is to create the logging object used as $c->log

=head1 NAME

SamuRest::Controller::Vmware - Catalyst Controller

=head1 DESCRIPTION

This Controller is responsilbe for the vmware namespace

=head1 vmwareBase

=head2 PURPOSE

Base sub, which checks if the user has a valid session

=pod

=head1 loginBase

=head2 PURPOSE

This sub loads the stored session into the stash for the later use
If vim_id is specified as parameter it will load that id session for the request
After each request the last_used timestamp will be updated

=pod

=head1 connection

=head2 PURPOSE

The ActionClass for connection functions

=pod

=head1 connection_GET

=head2 PURPOSE

This function returns all active session and their information

=head2 PARAMETERS

=over

=back

=head2 RETURNS

Return a JSON on success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 connection_POST

=head2 PURPOSE

This subroutine creates new sessions to a VCenter

=head2 PARAMETERS

=over

=item vcenter_username

Username used to connect to VCenter

=item vcenter_password

Password used to connect  to VCenter

=item vcenter_url

Url to VCenter

=back

=head2 RETURNS

Returns logon information: session_id, timestamp

=head2 DESCRIPTION

If no username/password/url is given then the default value from configs table is used. If nothing is given an error is thrown

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.perlsdk.pg.doc_50%2Fviperl_advancedtopics.5.6.html

=pod

=head1 connection_DELETE

=head2 PURPOSE

This subroutine logs off a session for closing server side resource, and to mitigate session reuse for unauthorized users

=head2 PARAMETERS

=over

=item id

ID of the session which needs to be delete

=back

=head2 RETURNS

True on success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.perlsdk.pg.doc_50%2Fviperl_advancedtopics.5.6.html

=pod

=head1 connection_PUT

=head2 PURPOSE

This subroutine changes the active session

=head2 PARAMETERS

=over

=item id

The session that should be marked as active

=back

=head2 RETURNS

A JSON with the active sessionid

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 folderBase

=head2 PURPOSE

Base sub for folder queries

=pod

=head1 folders

=head2 PURPOSE

The ActionClass for folders functions
We cast the VCenter object to a VCenter_folder object to narrow scope

=pod

=head1 folders_GET

=head2 PURPOSE

This subroutine returns a list of the folders on the VCenter

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A list of all folders on the VCenter, each element has information about : moref_value, name, moref_type

=head2 DESCRIPTION

The moref_value can be used to identify the object later uniqely.

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 folders_PUT

=head2 PURPOSE

This subroutine moves an object into the folder

=head2 PARAMETERS

=over

=item child_value

The moref_value of the child object to move

=item child_type

The moref_type of the child object to move

=item parent_value

The moref_value of the parent object that is the destination, if not specified the object is moved to root directory

=back

=head2 RETURNS

Returns JSON of success:
{ status => "moved" }

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.Folder.html#moveInto

=pod

=head1 folders_POST

=head2 PURPOSE

This subroutine creates a folder in the root directory
This function is forwarded to folder_POST with moref_value set to the root folder

=pod

=head1 folder

=head2 PURPOSE

The ActionClass for folder functions

=pod

=head1 folder_GET

=head2 PURPOSE

This subroutine returns information about a folder

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

Returns information in JSON: parent_moref_value, parent_moref_type, status, children folder count, children virtualmachine count, moref_value, moref_type

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.Folder.html

=pod

=head1 folder_DELETE

=head2 PURPOSE

Destroy the given folder object

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ManagedEntity.html#destroy

=pod

=head1 folder_POST

=head2 PURPOSE

This subroutine creates a folder in the specified parent folder

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI, this is going to be the parent folder

=item name

The requested name of the folder

=back

=head2 RETURNS

A JSON with the moref of the created folder

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.Folder.html#createFolder

=pod

=head1 resourcepoolBase

=head2 PURPOSE

Base sub for resourcepool queries

=pod

=head1 resourcepools

=head2 PURPOSE

The ActionClass for resourcepools functions
We cast the VCenter object to a VCenter_resourcepool object to narrow scope

=pod

=head1 resourcepools_GET

=head2 PURPOSE

This subroutine returns a list of resource pools

=head2 PARAMETERS

=over

=item refresh

Force refreshes the runtime information of a Resourcepool

=back

=head2 RETURNS

Return a JSON with resourecepool information: moref_value, moref_type, name

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 resourcepools_POST

=head2 PURPOSE

This subroutine creates a resourcepool in the root directory
The function is directed to resourcepool_POST with moref_value set to the root directory

=pod

=head1 resourcepools_PUT

=head2 PURPOSE

This subroutine moves an object into a folder

=head2 PARAMETERS

=over

=item child_value

The moref_value of the object to move

=item child_type

The moref_type of the object to move

=item parent_value

The moref_value of the destination resourcepool

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html#moveInto

=pod

=head1 resourcepool

=head2 PURPOSE

The ActionClass for resourcepool functions

=pod

=head1 resourcepool_GET

=head2 PURPOSE

This subroutine returns information about a resourcepool

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item refresh

Refreshes runtime information of a resourcepool

=back

=head2 RETURNS

Return JSON with resourcepool information: name, parent moref value, parent moref type, child resourcepool count, child virtualmachine count, moref value, moref type
runtime information: status, memory usage, cpu usage

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html

=pod

=head1 resourcepool_DELETE

=head2 PURPOSE

Destroy a resourcepool object

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ManagedEntity.html#destroy

=pod

=head1 resourcepool_PUT

=head2 PURPOSE

This subroutine changes settings of a resource pool

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item cpu_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item cpu_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item cpu_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MHz for CPU.

=item cpu_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MHz for CPU.

=item memory_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item memory_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MB for memory.

=item memory_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item memory_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MB for memory.

=item shares_level

The allocation level. The level is a simplified view of shares. Values: high, normal low
high => Shares = 2000 * nmumber of virtual CPUs, 20 * virtual machine memory size in megabytes
normal => Shares = 10 * virtual machine memory size in megabytes, 1000 * number of virtual CPUs
low => Shares = 5 * virtual machine memory size in megabytes, 500 * number of virtual CPUs

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html#updateConfig

=pod

=head1 resourcepool_POST

=head2 PURPOSE

This function creates a resourcepool in the specified resourcepool.

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item cpu_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item cpu_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item cpu_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MHz for CPU.

=item cpu_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MHz for CPU.

=item memory_share

The number of shares allocated. Used to determine resource allocation in case of resource contention.

=item memory_limit

The utilization of a virtual machine/resource pool will not exceed this limit, even if there are available resources.  If set to -1, then there is no fixed limit on resource usage.
Units are MB for memory.

=item memory_expandable_reservation

In a resource pool with an expandable reservation, the reservation on a resource pool can grow beyond the specified value.

=item memory_reservation

Amount of resource that is guaranteed available to the virtual machine or resource pool. Reserved resources are not wasted if they are not used. If the utilization is less than the reservation, 
the resources can be utilized by other running virtual machines. Units are MB for memory.

=item shares_level

The allocation level. The level is a simplified view of shares. Values: high, normal low
high => Shares = 2000 * nmumber of virtual CPUs, 20 * virtual machine memory size in megabytes
normal => Shares = 10 * virtual machine memory size in megabytes, 1000 * number of virtual CPUs
low => Shares = 5 * virtual machine memory size in megabytes, 500 * number of virtual CPUs

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ResourcePool.html#createResourcePool

=pod

=head1 taskBase

=head2 PURPOSE

Base sub for task queries

=pod

=head1 tasks

=head2 PURPOSE

The ActionClass for tasks functions

=pod

=head1 tasks_GET

=head2 PURPOSE

Returns all tasks from recentTasks of the Taskmanager

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON list with all tasks morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.wssdk.apiref.doc_50%2Fvim.TaskManager.html

=pod

=head1 task

=head2 PURPOSE

The ActionClass for task functions

=pod

=head1 task_GET

=head2 PURPOSE

This subroutine returns information about a subroutine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON containing information about a task: cancelable, cancelled, startTime, completeTime, entityName, entity moref, queueTime, key, state, description, name, reason, progress

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

Need to implement further detections for reason

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.Task.html

=pod

=head1 task_DELETE

=head2 PURPOSE

This subroutine cancels a task

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.Task.html#cancel

=pod

=head1 ticketqueryBase

=head2 PURPOSE

Base sub for ticket queries

=pod

=head1 ticketsquery

=head2 PURPOSE

The ActionClass for ticketsquery functions

=pod

=head1 ticketsquery_GET

=head2 PURPOSE

This function returns a list with all active tickets provisioned

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with a list of tickets, and their connected virtualmachines moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 ticketquery

=head2 PURPOSE

The ActionClass for ticketquery functions

=pod

=head1 ticketquery_GET

=head2 PURPOSE

This function returns information about virtualmachines morefs attached to a ticket

=head2 PARAMETERS

=over

=item ticket

This option is part of the URL

=back

=head2 RETURNS

A JSON containing the virtualmachines morefs attached to a ticket

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 userqueryBase

=head2 PURPOSE

Base sub for user queries

=pod

=head1 usersquery

=head2 PURPOSE

The ActionClass for usersquery functions

=pod

=head1 usersquery_GET

=head2 PURPOSE

This function collects all virtualmachines morefs attached to a username

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON containing a list of usernames and their attached vms

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 userquery

=head2 PURPOSE

The ActionClass for userquery functions

=pod

=head1 userquery_GET

=head2 PURPOSE

This function retrieves all virtualmachine morefs attached to a username

=head2 PARAMETERS

=over

=item username

This is part of the URL

=back

=head2 RETURNS

A JSON containing the virtualmachine morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 templateBase

=head2 PURPOSE

Base sub for template queries
We cast the VCenter object to a VCenter_vm object to narrow scope

=pod

=head1 templates

=head2 PURPOSE

The ActionClass for templates functions

=pod

=head1 templates_GET

=head2 PURPOSE

This function gets all useable templates on the VCenter

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with morefs to the templates, and their name

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

The find_entity_views returns all virtualmachine objects with template flag on true

=head2 SEE ALSO

=pod

=head1 template

=head2 PURPOSE

The ActionClass for template functions

=pod

=head1 template_GET

=head2 PURPOSE

This function returns information about templates

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with infromation attached to template: all active linked clones, name, vmpath, memory size in MB, number of cpus, status, vm tools status, moref 

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

Linked clone is calculated from last snapshots disk, since that is the base for all snapshots. I do not allow multiple clone bases from different clones since it will cause a huge confusion and diversion

=head2 SEE ALSO

=pod

=head1 template_DELETE

=head2 PURPOSE

This function unlinks all children from a template

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with list of virtualmachines moref_values, and the attached task moref for unlinking task

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#promoteDisks

=pod

=head1 datastoreBase

=head2 PURPOSE

Base sub for datastore queries
We cast the VCenter object to a VCenter_datastore object to narrow scope

=pod

=head1 datastores

=head2 PURPOSE

The ActionClass for datastores functions

=pod

=head1 datastores_GET

=head2 PURPOSE

This function returns a list of datastore morefs

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON containg all datastore morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 datastore

=head2 PURPOSE

The ActionClass for datastore functions

=pod

=head1 datastore_GET

=head2 PURPOSE

This function returns information about one datastore

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON containing the datastores information: accessibility, capacity, free space, maintance mode, multiple host access, name, type, uncommited data, url, 
max file size, timestamp, SIOC, connected virtualmachine morefs, moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.Datastore.html

=pod

=head1 networkBase

=head2 PURPOSE

Base sub for network queries

=pod

=head1 networks

=head2 PURPOSE

The ActionClass for networks functions

=pod

=head1 networks_GET

=head2 PURPOSE

This function returns information about dvps, switchs and host networks. It is a primary collector for quick topology graph

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with all network objects

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

We cast the VCenter object multiple times to always be in the required scope

=head2 SEE ALSO

=pod

=head1 switch_base

=head2 PURPOSE

Base sub for switch queries
We cast the VCenter object to a VCenter_dvs object to narrow scope

=pod

=head1 switches

=head2 PURPOSE

The ActionClass for switches functions

=pod

=head1 switches_GET

=head2 PURPOSE

This function returns all distributed virtual switch morefs

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with all distributed virtual switch morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 switches_POST

=head2 PURPOSE

This function creates a distributed virtual switch

=head2 PARAMETERS

=over

=item ticket

The ticket id of the environment

=item host

The ESXi host moref to attach the DVS to

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.Folder.html#createDistributedVirtualSwitch

=pod

=head1 switch

=head2 PURPOSE

The ActionClass for switch functions

=pod

=head1 switch_GET

=head2 PURPOSE

This function retrieves information about a switch

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with following information: name, number of ports, uuid, connected virtualmachine morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.DistributedVirtualSwitch.html

=pod

=head1 switch_DELETE

=head2 PURPOSE

This function destoys a DVS

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ManagedEntity.html#destroy

=pod

=head1 switch_PUT

=head2 PURPOSE

This function can change parameters of the DVS

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item name

The requested new name of the DVS

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.DistributedVirtualSwitch.html#reconfigure

=pod

=head1 dvp_base

=head2 PURPOSE

Base sub for dvp queries
We cast the VCenter object to a VCenter_dvp object to narrow scope

=pod

=head1 dvps

=head2 PURPOSE

The ActionClass for dvps functions

=pod

=head1 dvps_GET

=head2 PURPOSE

This function returns a list of distributed virtual portgroup morefs

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with a list of distributed virtual portgroup morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 dvps_POST

=head2 PURPOSE

This function creates a new DVP

=head2 PARAMETERS

=over

=item ticket

The ticket id that the switch will be attached to

=item switch

The switch moref value we attach the DVP to

=item func

The function of the DVP, for generating the name

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.DistributedVirtualSwitch.html#addPortgroups

=pod

=head1 dvp

=head2 PURPOSE

The ActionClass for dvp functions

=pod

=head1 dvp_GET

=head2 PURPOSE

This function retrieves information about a distributed virtual portgroup

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with following information: name, key, status, connected virtualmachine morefs, moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.dvs.DistributedVirtualPortgroup.html

=pod

=head1 dvp_DELETE

=head2 PURPOSE

This function destroys a distributed virtual portgroup

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ManagedEntity.html#destroy

=pod

=head1 dvp_PUT

=head2 PURPOSE

This function update distributed virtual portgroup configuration

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item type

Type of postgroup. Possible values: earlybinding, ephemeral, lateBinding

=item numport

Number of ports in the portgroup

=item desc

A description string of the portgroup

=item autoexpand

Automaticly expands the portgroup above the port number limit

=item name

The new name of the port group

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.dvs.DistributedVirtualPortgroup.html#reconfigure

=pod

=head1 hostnetwork_base

=head2 PURPOSE

Base sub for hostnetwork queries
We cast the VCenter object to a VCenter_hostnetwork object to narrow scope

=pod

=head1 hostnetworks

=head2 PURPOSE

The ActionClass for hostnetworks functions

=pod

=head1 hostnetworks_GET

=head2 PURPOSE

This function retrieves a list of host only network morefs

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with a list of host only network morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 hostnetwork

=head2 PURPOSE

The ActionClass for hostnetwork functions

=pod

=head1 hostnetwork_GET

=head2 PURPOSE

This function retrieves information about a host only network

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with following information: name, connected virtualmachine morefs, moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

It is not possible to query host only networks. DVPS are also a subclass of the Network object, so we need to inspect the object in the Controller if it is a host only network

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.Network.html

=pod

=head1 hostBase

=head2 PURPOSE

Base sub for host queries
We cast the VCenter object to a VCenter_host object to narrow scope

=pod

=head1 hosts

=head2 PURPOSE

The ActionClass for hosts functions

=pod

=head1 hosts_GET

=head2 PURPOSE

This function retrieves a list of Hostsystems morefs

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with a list of hostsystems morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 host

=head2 PURPOSE

The ActionClass for host functions

=pod

=head1 host_GET

=head2 PURPOSE

This function retrieves information about a hostsystem

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with following information: name, reboot required, hw information (cpu speed, cpu model, memory size, model, number of CPU threads, vendor, number of NICs, number of HBAs, number of CPU cores), 
status, connected virtualmachine morefs, moref 

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.HostSystem.html

=pod

=head1 vmsBase

=head2 PURPOSE

Base sub for vms queries
We cast the VCenter object to a VCenter_vm object to narrow scope

=pod

=head1 vms

=head2 PURPOSE

The ActionClass for vms functions

=pod

=head1 vms_GET

=head2 PURPOSE

This function retrieves a list of virtualmachine morefs

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON with a list of virtualmachine morefs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 vms_POST

=head2 PURPOSE

This subrotuine would create an empty VM

=head2 PARAMETERS

=over

=back

=head2 RETURNS

A JSON messages saying not implemented

=head2 DESCRIPTION

Currently not implemented

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 vmBase

=head2 PURPOSE

Base sub for vm queries
=cut

sub vmBase: Chained('vmsBase'): PathPart('') : CaptureArgs(1) {
    my ($self, $c, $mo_ref_value) = @_;
    $c->stash->{ mo_ref_value } = $mo_ref_value
}

=pod

=head1 vm

=head2 PURPOSE

The ActionClass for vm functions

=pod

=head1 vm_GET

=head2 PURPOSE

This function retrieves information about a virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with following information: name, vmpath, memory size in MB, number of CPU, status, vm tools status

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html

=pod

=head1 vm_DELETE

=head2 PURPOSE

This function destroy a virtual machine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.ManagedEntity.html#destroy

=pod

=head1 vm_POST

=head2 PURPOSE

This function clones a virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item ticket

The ticket id

=item parent_folder

The parent folder moref value where the machine should be created, by default in the linked clone folder

=item altername

The new requested alternate name for the machine, not mandatory

=item numcpus

The requested CPU number

=item memorymb

The requested memory amount in MB

=item alternateGuestName

Full name for guest, if guestId is specified as other or other-64.

=item cpuHotAddEnabled

Should it be allowed to add cpu without reboot

=item cpuHotRemoveEnabled

Should it be allowed to remove cpu without reboot

=item memoryHotAddEnabled

Should it be allowed to add memory without reboot

=item enterBIOSSetup

At next boot should the bios be entered, not mandatory

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

Full clone possibility has been removed, since the annotations configuration would talk to long to wait for it to complete

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#clone

=pod

=head1 cpu

=head2 PURPOSE

The ActionClass for cpu functions

=pod

=head1 cpu_GET

=head2 PURPOSE

This function retrieves the CPU core amount

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with number of CPUs

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 cpu_PUT

=head2 PURPOSE

This function changes the CPU core amount

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item numcpus

The requested CPU core amount

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#reconfigure

=pod

=head1 process

=head2 PURPOSE

The ActionClass for process functions

=pod

=head1 process_GET

=head2 PURPOSE

This function retrieves a list of processes in virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a list of processes

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

This function requires vmware tools to be installed and running

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.guest.ProcessManager.html#listProcesses

=pod

=head1 process_POST

=head2 PURPOSE

This function runs a command in the virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item username

The username used to log into the virtualmachine. Defaults to the annotation

=item password

The password used to log into the virtualmachine. Default to the annotation

=item workdir

The working directory for the program

=item prog

The full path of the program

=item prog_arg

The arguments for the program

=item env

Environmental variables for the program

=back

=head2 RETURNS

A JSON with a pid of the process

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.vm.guest.ProcessManager.html#startProgram

=pod

=head1 transfer

=head2 PURPOSE

The ActionClass for transfer functions

=pod

=head1 transfer_POST

=head2 PURPOSE

This function transfers files between a virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item dest

The path on virtual machine the file should be uploaded to

=item source

The file on virtual machine that should be downloaded

=item username

The username to authenticate with on virtualmachine. Defaults to the annotation

=item password

The password to authenticate with on virtualmachine. Defaults to the annotation

=item overwrite

Boolean if destination file should be overwritten

=item size

The size of the file that is going to be uploaded

=back

=head2 RETURNS

In case dest is selected:
Transferinformation where a PUT request should be done to upload file

In case source is selected:
Transferinformation where the file can be downloaded from

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.guest.FileManager.html#initiateFileTransferFromGuest
http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.vm.guest.FileManager.html#initiateFileTransferToGuest

=pod

=head1 memory

=head2 PURPOSE

The ActionClass for memory functions

=pod

=head1 memory_GET

=head2 PURPOSE

This function retrieves the memory ammount in MB

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with memory ammount in MB

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 memory_PUT

=head2 PURPOSE

This function changes memory ammount

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item memorymb

The requested memory size in MB

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 disks

=head2 PURPOSE

The ActionClass for disks functions

=pod

=head1 disks_GET

=head2 PURPOSE

This function retrieves a list of disk attached to the virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a list of disk

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 disks_POST

=head2 PURPOSE

This function creates a disk

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item size

The requested size of the disk
FIXME Unit

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 disk

=head2 PURPOSE

The ActionClass for disk functions

=pod

=head1 disk_GET

=head2 PURPOSE

This function retrieves information about a disk

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

The id of the disk

=back

=head2 RETURNS

A JSON with information about the disk: key, capacity in KB, disk filename, id

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.device.VirtualDisk.html

=pod

=head1 disk_DELETE

=head2 PURPOSE

This function removes a disk from a virtualmachine and destroys it

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

Id of the disk to destroy

=back

=head2 RETURNS

A JSON with task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 annotations

=head2 PURPOSE

The ActionClass for annotations functions

=pod

=head1 annotations_GET

=head2 PURPOSE

This function retrieves a list of annotations and their ids

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with annotation name and ids

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.CustomFieldsManager.Value.html

=pod

=head1 annotation

=head2 PURPOSE

The ActionClass for annotation functions

=pod

=head1 annotation_GET

=head2 PURPOSE

This function retrieves the annotation value

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item name

Name of the annotation

=back

=head2 RETURNS

A JSON with the value of the annotation

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.wssdk.apiref.doc_50%2Fvim.ExtensibleManagedObject.html

=pod

=head1 annotation_DELETE

=head2 PURPOSE

This function invokes annotation_POST with an empty value

=pod

=head1 annotation_PUT

=head2 PURPOSE

This function changes value of an annotation

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item value

The requested value for the annotation

=back

=head2 RETURNS

A JSON on success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.CustomFieldsManager.html#setField

=pod

=head1 events

=head2 PURPOSE

The ActionClass for events functions

=pod

=head1 events_GET

=head2 PURPOSE

This function retrieves events attached to virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a list of events

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.event.EventManager.html#QueryEvent

=pod

=head1 event

=head2 PURPOSE

The ActionClass for event functions

=pod

=head1 event_GET

=head2 PURPOSE

This function retrieves a list of events according to filter

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item filter

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a list of events according to filter

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.event.VmEvent.html

=pod

=head1 cdroms

=head2 PURPOSE

The ActionClass for cdroms functions

=pod

=head1 cdroms_GET

=head2 PURPOSE

This function retrieves a list of cdroms in virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with cdroms listed

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 cdroms_POST

=head2 PURPOSE

This function adds a cdrom to the virtual machine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

A CDROM is attached to the ide controller, which has a maximum of 4 devices.

=head2 SEE ALSO

=pod

=head1 cdrom

=head2 PURPOSE

The ActionClass for cdrom functions

=pod

=head1 cdrom_GET

=head2 PURPOSE

This function retrieves infromation about a specific cdrom

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

The id of the cdrom

=back

=head2 RETURNS

A JSON with the cdrom information: id, key, backing, label

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

Backing is the image in the drive

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.device.VirtualCdrom.html

=pod

=head1 cdrom_PUT

=head2 PURPOSE

This function changes the cdrom backing

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

The id of the cdrom

=item exclusive

Should the device be considered exclusive to the vm

=item deviceName

T.B.D.

=item iso

The path to the iso: example: [datastore] folder/something.iso

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 cdrom_DELETE

=head2 PURPOSE

This function removes a CDROM fro ma virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 interfaces

=head2 PURPOSE

The ActionClass for interfaces functions

=pod

=head1 interfaces_GET

=head2 PURPOSE

This function returns the list of interfaces

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a list of interfaces

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 interfaces_POST

=head2 PURPOSE

This function adds an interface to the virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 interface

=head2 PURPOSE

The ActionClass for interface functions

=pod

=head1 interface_GET

=head2 PURPOSE

This function retriees informaiton aboout an interface

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.device.VirtualEthernetCard.html

=pod

=head1 interface_PUT

=head2 PURPOSE

This function changes the network of an interface

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item network

Moref to the requested network
FIXME

=item id

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 interface_DELETE

=head2 PURPOSE

This function removes an interface from a virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 powerstatus

=head2 PURPOSE

The ActionClass for powerstatus functions

=pod

=head1 powerstatus_GET

=head2 PURPOSE

This function Retrieves the powerstatus of a virtualmachine

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

A JSON with the current powerstatus

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 powerstate

=head2 PURPOSE

The ActionClass for powerstate functions

=pod

=head1 powerstate_PUT

=head2 PURPOSE

This function changes the powerstate to the requested state

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item state

This option is taken from URI. Possible values: standby, shutdown, reboot, poweron, poweroff

=back

=head2 RETURNS

A JSON with either succes, or a task moref

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

=pod

=head1 snapshots

=head2 PURPOSE

The ActionClass for snapshots functions

=pod

=head1 snapshots_GET

=head2 PURPOSE

This function returns all snapshots information

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

Returns JSON with all snapshot information, and also current snapshot 

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.ConfigInfo.html

=pod

=head1 snapshots_POST

=head2 PURPOSE

This function create a snapshot of the vm

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item name

This parameter specifies the snapshot name

=item desc

This parameter specifies the snapshots description

=back

=head2 RETURNS

Return JSON on success with mo_ref of snapshot

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#createSnapshot

=pod

=head1 snapshots_DELETE

=head2 PURPOSE

This function removes all snapshots from a virtual machine, and consolidates disks

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=back

=head2 RETURNS

Returns a JSON with success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html#removeAllSnapshots

=pod

=head1 snapshot

=head2 PURPOSE

The ActionClass for snapshot functions

=pod

=head1 snapshot_GET

=head2 PURPOSE

This subroutine returns information about the snapshot

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

This option is taken from the URI

=back

=head2 RETURNS

Returns JSON containing following data: name, createTime, description, moref_value, id, state 

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.ConfigInfo.html

=pod

=head1 snapshot_PUT

=head2 PURPOSE

This subroutine reverts to a snapshot

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

This option is taken from the URI

=back

=head2 RETURNS

A JSON containing success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/index.jsp#com.vmware.wssdk.apiref.doc_50/vim.vm.Snapshot.html#revert

=pod

=head1 snapshot_DELETE

=head2 PURPOSE

This subroutine removes a snapshot and concolidates the disks

=head2 PARAMETERS

=over

=item mo_ref_value

This option is taken from the URI

=item id

This option is taken from the URI

=back

=head2 RETURNS

A JSON contaning success

=head2 DESCRIPTION

=head2 THROWS

=head2 COMMENTS

=head2 SEE ALSO

http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.vm.Snapshot.html#remove


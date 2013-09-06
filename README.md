ManageLocalAdminScript
======================

Script to check on local admin accounts and manage those accounts, including automatic rights removal

The script consists of three parts - detailed installation instructions will follow soon.

To enforce automatic administration rights removal, you need the LaunchDaemon de.timo-lemburg.LocalAdminExpiration.plist.
This file must be copied into the /Library/LaunchDaemons/ folder.

The ExpirationCheck.sh does the checking of the expiry dates of the local admin accounts and disables them. This script is
regulary triggered by the LaunchDaemon.

The LocalAdminPreparation.sh needs to be run to set up all needed components. This is the creation of new 
admin groups, manipulation of the authorization file to include the new groups, fire up the LaunchDaemon etc.

The ManageLocalAdmins.sh script does the setup of new admin accounts, the management of the rights for those accounts 
as well as the disabling and reenabling of the accounts.

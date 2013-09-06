#!/bin/bash

## Launching LaunchDaemon
if [ `launchctl list | grep -c de.timo-lemburg.LocalAdminExpiration` -eq 0 ]
then
  sudo launchctl load -w /Library/LaunchDaemons/de.timo-lemburg.LocalAdminExpiration.plist
fi

##Setting up AppStore Admin Group
if [ `dscl . -list /Groups | grep -cw appstoreadmin` -eq 0 ]
then
  sudo dseditgroup -o create -i 511 -r "AppStore Administrators" -a admin -t group appstoreadmin
else
    sudo dseditgroup -o edit -i 511 -r "AppStore Administrators" -a admin -t group appstoreadmin
fi
sudo /usr/libexec/PlistBuddy /etc/authorization -c "Set rights:system.install.app-store-software:group appstoreadmin"


##Setting up Installadmin Group
if [ `dscl . -list /Groups | grep -cw installadmin` -eq 0 ]
then
  sudo dseditgroup -o create -i 511 -r "Installation Administrators" -a admin -t group installadmin
else
    sudo dseditgroup -o edit -i 511 -r "Installation Administrators" -a admin -t group installadmin
fi
sudo /usr/libexec/PlistBuddy /etc/authorization -c "Set rights:system.install.software:group installadmin"

chmod -R -N /Applications
chmod -R +a "group:installadmin allow list,add_file,search,add_subdirectory,readattr,writeattr,readextattr,writeextattr,delete,delete_child,file_inherit,directory_inherit" /Applications

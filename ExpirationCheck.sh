#!/bin/bash

## Script for checking the expiration dates of local admin accounts.

###################################################
## Start of function declaration                 ##
###################################################

## Check if user running this script is root
if [ $UID -gt 0 ]
then
    echo "Please run this Script as root."
    exit 77
fi

## Get expiration date from expiration file
declare -a expiration_user_array=()
declare -a expiration_date_array=()
i=0
for checklist in $(defaults read /usr/local/tl/LocalAdmin/Expiration.plist | awk '{gsub("\"",""); {print$1}}')
do
    if [ ${#checklist} -gt 1 -a $checklist != "LastModification" ]
    then
        expiration_user_array[$i]=$checklist
        expiration_date_array[$i]=`defaults read /usr/local/tl/LocalAdmin/Expiration.plist $checklist`
        let "i += 1"
    fi
done

## Check for expired accounts
now=`date -j +%s`
i=0
for expiration_check in ${expiration_date_array[@]}
do
    if [ $expiration_check -le $now ]
    then
        dscl . -append /Users/${expiration_user_array[$i]} AuthenticationAuthority ";DisabledUser;"
        defaults delete /usr/local/tl/LocalAdmin/Expiration.plist ${expiration_user_array[$i]}
        defaults write /usr/local/tl/LocalAdmin/Expiration.plist LastModification `date -j +%d.%m.%Y`
    fi
    let "i += 1"
done

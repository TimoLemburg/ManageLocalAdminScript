#!/bin/bash

## Script for creating a local admin account

## A new local account will be created for an existing user with the username followed by _admin,
## e.g. user testuser will receive a local account named testuser_admin.
## This account will NOT have full administration right but will be authorized for special
## tasks as granted by the authorities. 


###################################################
## Start of function declaration                 ##
###################################################


###################################################
## Start Screen                                  ##
###################################################
function start-screen {
## Looking for users, that are or have been local admin users

    active_count=0
    disabled_count=0
    localadmin_count=0
    i=0
    if test -f /usr/local/tl/LocalAdmin/Expiration.plist
    then
        defaults write /usr/local/tl/LocalAdmin/Expiration.plist LastModification `date -j +%d.%m.%Y`
    fi

    clear
    echo "*********************************************"
    echo "** Local Admin Management Script           **"
    echo "*********************************************"
    echo ""
    echo "Checking for local admin users on this Mac:"
    echo ""
    check_expiration_dates
    if [ $(dscl . list /Users | grep -v ^_.* | grep -c _admin) -gt 0 ]
    then
        for adminlist in $(dscl . list /Users | grep -v ^_.* | grep _admin)
        do
            i=0
            for check in ${expiration_user_array[@]}
            do
                if [ "$check" == "$adminlist" ] ; then
                    expiration_date=`date -j -f %s ${expiration_date_array[$i]} +%d.%m.%Y`
                fi
                let "i += 1"
            done
            if [ $(dscl . -read /Users/$adminlist AuthenticationAuthority | grep -c DisabledUser) -gt 0 ]
            then
                echo "  $adminlist (disabled)"
                disabled_count=1
                localadmin_count=1
            else
                echo "  $adminlist (active), expiry date set to $expiration_date"
                active_count=1
                localadmin_count=1
            fi
        done
    else
        echo "No local admin users found"
    fi

    echo ""
    echo "Choose your action from the list:"
    echo ""
    if [ $active_count -gt 0 ]
    then
        echo "  (C)hange account setting for an active local admin account"
        echo "  (D)isable an active local admin account"
    fi
    if [ $localadmin_count -gt 0 ]
    then
        echo "  (E)rase existing local admin account"
    fi
    echo "  (N)ew account creation"
    if [ $disabled_count -gt 0 ]
    then
        echo "  (R)eactivate disabled local admin account and change settings"
    fi

    echo ""
    echo "  Press any other key to exit this script."
    echo ""
    read -p "  Your choice: " -n 1 input
    case $input in
        C) change_account_settings ;;
        D) disable_account ;;
        E) erase_account ;;
        N) new_account ;;
        R) reactivate_account ;;
        *) echo ""; exit 0;
    esac
}

###################################################
## Change existing local account settings        ##
###################################################
function change_account_settings {

    echo ""
    echo ""
    echo "*********************************************"
    echo "** Change existing local account settings  **"
    echo "*********************************************"
    echo ""

    check_to_continue

    echo ""
    read -p "  Enter local admin user shortname to be disabled: " input

    check_account_validity

    echo ""
    account=$input

    set_date
    set_lifetime_settings
    set_rights

}



###################################################
## Disable existing local admin account          ##
###################################################
function disable_account {

    echo ""
    echo ""
    echo "*********************************************"
    echo "** Disable an existing local admin account **"
    echo "*********************************************"
    echo ""
    echo "  A disabled user account cannot be accessed any"
    echo "  more until it is reactivated again."

    check_to_continue

    echo ""
    read -p "  Enter local admin user shortname to be disabled: " input

    check_account_validity

    echo ""
    echo "  Disabling local admin user account $input..."
    sudo dscl . -append /Users/$input AuthenticationAuthority ";DisabledUser;"
    defaults delete /usr/local/tl/LocalAdmin/Expiration.plist $input
    defaults write /usr/local/tl/LocalAdmin/Expiration.plist LastModification `date -j +%d.%m.%Y`
    echo "  User account $input has been disabled."
    echo ""
    read -n 1 -p "  Press any key to return to the main menu."
    start-screen
}



###################################################
## Erase existing local admin account            ##
###################################################
function erase_account {

    echo ""
    echo ""
    echo "*********************************************"
    echo "** Erase an existing local admin account   **"
    echo "*********************************************"
    echo ""
    echo "  Be warned, that this step cannot be undone!"

    check_to_continue

    echo ""

    read -p "  Enter local admin user shortname to be deleted: " input

    check_account_validity

    echo "  Please confirm once more that the user $input"
    echo "  shall be deleted including the user home folder"
    echo "  on this Mac. This cannot be undone!"
    echo ""
    read -p "Type the user shortname for confirmation one last time: " confirmation
    if [ $confirmation == $input ]
    then
        echo ""
        if test -d /Users/$input
        then
            echo "  Deleting home directory of user $input..."
            sudo rm -R /Users/$input
        fi

        echo "  Deleting administrative group settings"
        i=0
        while [ -n "${admingroup[$i]}" ]
        do
            if [ $(dseditgroup -o checkmember -m $input ${admingroup[$i]} | awk '{print $1}' | grep -cx "yes") -gt 0 ]
            then
                dseditgroup -o edit -d $input ${admingroup[$i]}
            fi
            let "i += 1"
        done

        echo "  Deleting account details"
        sudo dscl . delete /Users/$input
        echo "  Local admin account has been deleted."
        echo ""
        read -n 1 -p "  Press any key to return to the main menu."
        start-screen
    else
        echo ""
        echo "  The confirmation did not match the user shortname,"
        echo "  therefore the erase process has been halted."
        echo ""
        read -n 1 -p "  Press any key to return to the main menu."
        start-screen
    fi
}


###################################################
## New local admin account creation              ##
###################################################
function new_account {

    echo ""
    echo ""
    echo "*********************************************"
    echo "** Creating a new local admin account      **"
    echo "*********************************************"
    echo ""
    echo "  You can create a new local admin account for any"
    echo "  user that already has an account on this Mac."

    check_to_continue

    echo ""
    echo "  Enter the shortname for the user who shall get"
    echo "  local admin privileges. Enter the regular username"
    echo "  without the _admin."
    echo ""
    read -p "  Current username: " input
    check_input=`echo $input | awk '{ print substr( $0, length($0) - 1, length($0) ) }' | grep -xc "_admin"`
    if [ "$(finger $input 2> /dev/null | awk 'NR==1' | awk '{print $2}')" != "$input" ]
    then
        echo ""
        echo "  The user $input is not a user on this machine."
        echo ""
        read -n 1 -p "  Press any key to return to the main menu."
        start-screen
    elif [ $check_input != "0" ]
    then
        echo ""
        echo "  You used a username with _admin at the end. This is"
        echo "  not a valid entry, you must use a regular user shortname."
        echo ""
        read -n 1 -p "  Press any key to return to the main menu."
        start-screen
    fi

    echo ""
    echo "  We need some more details to be able to create the account."
    echo "  Please enter the following values. You will get a summary in the end"
    echo "  and will need to confirm the values before the account will be created."
    echo ""
    new_user_shortname=$input"_admin"
    new_user_name="Local admin account for "$input
    read -s -p "  Initial password: " new_user_password
    echo ""
    new_user_uniqueid=502
    while [ "$(id -u $new_user_uniqueid 2> /dev/null)" -eq "$new_user_uniqueid" ] 2> /dev/null
    do
        let "$new_user_uniqueid += 1"
    done
    new_user_home="/Users/"$new_user_shortname

    set_date

    echo ""
    echo "  Account shortname: "$new_user_shortname
    echo "  Account name: "$new_user_name
    echo "  Account password: "$new_user_password
    echo "  Account UniqueID: "$new_user_uniqueid
    echo "  Account home folder: "$new_user_home
    echo "  Account lifetime ends: "$revoke_date_readable
    echo ""
    echo "  Are these settings correct?"
    read -n 1 -p "  Type (Y) to create the account, any other key for the main menu: " input
    if  [ $input != "Y" ]
    then
        echo ""
        echo "  Account creation aborted by user interaction."
        read -n 1 -p "  Press any key to return to the main menu."
        start-screen
    fi

    echo ""
    echo "  Creating a new local admin account "$new_user_shortname"..."
    sudo dscl . create /Users/$new_user_shortname
    sudo dscl . create /Users/$new_user_shortname RealName $new_user_name
    sudo dscl . passwd /Users/$new_user_shortname $new_user_password
    sudo dscl . create /Users/$new_user_shortname UniqueID $new_user_uniqueid
    sudo dscl . create /Users/$new_user_shortname NFSHomeDirectory $new_user_home
    sudo dscl . create /Users/$new_user_shortname UserShell /bin/bash
    sudo dscl . create /Users/$new_user_shortname PrimaryGroupID 20
    sudo createhomedir -c -u $new_user_shortname
    account=$new_user_shortname

    set_lifetime_settings

    set_rights

    echo ""
    read -n 1 -p "  Press any key to return to the main menu."
    start-screen
}


###################################################
## Reactivate a disable local admin account      ##
###################################################
function reactivate_account {

    echo ""
    echo ""
    echo "***********************************************"
    echo "** Reactivate a disabled local admin account **"
    echo "***********************************************"
    echo ""
    echo "  A disabled user account cannot be accessed any"
    echo "  more until it is reactivated again by this script."

    check_to_continue

    echo ""
    read -p "  Enter local admin user shortname to be reactivated: " input

    check_account_validity

    if [ $(dscl . -read /Users/$input AuthenticationAuthority | grep -c DisabledUser) -eq 0 ]
    then
        echo "  The account $input is not disabled."
        echo ""
        read -n 1 -p "  Press any key to return to the main menu."
        start-screen
    fi

    echo ""
    echo "  Reactivating disabled admin user account $input..."
    dscl . -read /Users/$input AuthenticationAuthority | sed 's/AuthenticationAuthority: //;s/DisabledUser//g;s/[; ]*$//' | xargs dscl . -create /Users/$input AuthenticationAuthority
    echo "  User account $input has been reactivated."
    echo ""

    change_account_settings

    read -n 1 -p "  Press any key to return to the main menu."
    start-screen
}


###################################################
## Declaration of repeatedly used sub functions  ##
###################################################
function check_to_continue {
    echo ""
    echo "  Do you want to continue?"
    read -p "  (Y) to continue, any other key for the main menu: " -n 1 input
    if [ -z $input ]
    then
        start-screen
    elif [ $input != "Y" ]
    then
        start-screen
    fi
    echo ""
}

function check_account_validity {
    if [ $(dscl . list /Users | grep -x $input | grep -v ^_.* | grep -c _admin) == 0 ]
    then
        echo ""
        echo "  The user shortname entered is either not a local"
        echo "  admin account (ending with _admin) or is not available"
        echo "  on this Mac."
        echo ""
        read -n 1 -p "  Press any key to return to the main menu."
        start-screen
    fi
    echo ""

}

function set_date () {
    tomorrow_readable=`date -v+1d "+%d.%m.%Y"`
    tomorrow_check=`date -v+1d +%s`
    max_date_readable=`date -v+180d "+%d.%m.%Y"`
    max_date_check=`date -v+180d +%s`

    echo ""
    echo "  Enter the account expiration date. Valid dates"
    echo "  range from "$tomorrow_readable" to "$max_date_readable"."

    read -p "  Enter date (dd.mm.yyyy, dots will be set automatically): " -n 2 -d . revoke_day; read -p "." -n 2 revoke_month; read -p "." -n 4 revoke_year;echo ""
    echo ""

    case $revoke_day in
        0[1-9]) day_ok=true ;;
        1[0-9]) day_ok=true ;;
        2[0-9]) day_ok=true ;;
        3[0-1]) day_ok=true ;;
        *) day_ok=false ;;
    esac
    case $revoke_month in
        0[1-9]) month_ok=true ;;
        1[0-2]) month_ok=true ;;
        *) month_ok=false ;;
    esac

    if [ $day_ok == false ] || [ $month_ok == false ] || [ -z $revoke_year ]
    then
        echo "  Error in date, illegal date format."
        echo ""
        read -n 1 -p "  Press any key to enter a new date."
        echo ""
        set_date
    fi

    revoke_date=$revoke_day""$revoke_month""$revoke_year
    revoke_date_readable=$revoke_day"."$revoke_month"."$revoke_year
    if [ ${#revoke_date} -ne 8 ]
    then
        echo "  Error: The expiration date must have 8 digits."
        echo ""
        read -n 1 -p "  Press any key to enter a new date."
        echo ""
        set_date
    fi

    revoke_date_check=`date -j \`echo $revoke_month""$revoke_day""0000""$revoke_year\` +%s`

    if [ $revoke_date_check -lt $tomorrow_check ]
    then
        echo "  The expiration date must be greater than "$tomorrow_readable"."
        echo ""
        read -n 1 -p "  Press any key to return to enter another date."
        set_date
    elif [ $revoke_date_check -gt $max_date_check ]
    then
        echo ""
        echo "  The expiration date must be less than "$max_date_readable"."
        echo ""
        read -n 1 -p "  Press any key to return to enter another date."
        set_date
    fi
}

function set_lifetime_settings {
    ## Use settings given by other functions to create a plist file with expiration dates.
    ## A LaunchDaemon will check that plist daily to disable expired accounts

    echo "  Writing expiration record."
    defaults write /usr/local/tl/LocalAdmin/Expiration.plist $account -int $revoke_date_check

}


function check_expiration_dates {
    ## Get expiration date from expiration file
    i=0
    for checklist in $(defaults read /usr/local/tl/LocalAdmin/Expiration.plist | awk '{gsub("\"",""); {print$1}}')
    do
        if [ ${#checklist} -gt 1 ]
        then
            expiration_user_array[$i]=$checklist
            expiration_date_array[$i]=`defaults read /usr/local/tl/LocalAdmin/Expiration.plist $checklist`
            let "i += 1"
        fi
    done

}


function set_rights {
## Function uses $account as local admin account!

    ## Asking for individual access rights if any are available
    if [ "$(echo ${#admingroup[@]})" != 0 ];
    then
        echo ""
        echo "  Please choose the administrative tasks needed on a per se basis."
        echo "  Type (Y) for each given task, all other keys are understood as 'No'."
        echo ""
        i=0
        while [ -n "${admingroup[$i]}" ]
        do
            read -p "  Allow $account to ${admingroupdescription[$i]}? " -n 1 input
            echo ""
            if [ $input = "Y" ]
            then
                sudo dseditgroup -o edit -a $account ${admingroup[$i]}
            else
                if [ "$(dseditgroup -o checkmember -m $account ${admingroup[$i]} | awk '{print $1}' | grep -cx "yes")" -gt 0 ]
                then
                    sudo dseditgroup -o edit -d $account ${admingroup[$i]}
                fi

            fi
            let "i += 1"
        done
        echo ""
        echo "  All available administrative permissions checked."
        echo "  Did you correctly choose the rights needed?"
        read -p "  Type (N) to repeat setting the rights, all other keys to continue: " -n 1 input
        echo ""
            if [ $input = "N" ]
            then
                set_rights
            fi
    else
        echo ""
        echo "  No administrative group available."
        echo ""
        read -n 1 -p "  Press any key to continue."
        echo ""
    fi
}



###################################################
## End of function declaration                   ##
###################################################


###################################################
## Start of the script                           ##
###################################################

## Check if user running this script is root
if [ $UID -gt 0 ]
	then
	echo "Please run this script as root."
	exit 77
fi

## Check existing groups for administrative access to the Mac
declare -a admingroupcheck=('lpadmin' 'installadmin' 'appstoreadmin');
declare -a admingroupcheckdescription=('printer management' 'install software packages' 'install and upgrade from AppStore')
declare -a admingroup=();
declare -a admingroupdescription=();
declare -a expiration_user_array=();
declare -a expiration_date_array=();
i=0
c=0
while [ -n "${admingroupcheck[$i]}" ]
do
    currentcheck=${admingroupcheck[$i]}
    if [ $(dscl . ls /Groups | grep -cn ${admingroupcheck[$i]}) -gt 0 ]
    then
        admingroup[$c]=${admingroupcheck[$i]}
        admingroupdescription[$c]=${admingroupcheckdescription[$i]}
        let "c += 1"
    fi
    let "i += 1"
done

## Run function with main screen
start-screen

exit 0

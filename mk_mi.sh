#/bin/bash
set -euo pipefail
IFS=$'\n\t'

#---------------------------------------------------------------
# mk_mi.sh
# Author: Kellyn Gorman
# Deploys a Managed Instance via Azure CLI in an EXISTING RESOURCEGROUP
# You need the name of the resource group, VNet, Subnet for this to complete.
# Initial Script- 10/24/2019
#---------------------------------------------------------------
# -e: immediately exit if anything is missing
# -o: prevents masked errors
# IFS: deters from bugs, looping arrays or arguments (e.g. $@)
#---------------------------------------------------------------

usage() { echo "Usage: $0 -g <groupname> -i <instancename> -v <vnet> -n <subnet> -u <username> -p <password> -l <zone>" 1>&2; exit 1; }

declare groupname=""
declare instancename=""
declare vnet=""
declare snet=""
declare username=""
declare password=""
declare zone=""

# Initialize parameters specified from command line
while getopts ":g:i:v:n:u:p:l:" arg; do
        case "${arg}" in
                g)
                        groupname=${OPTARG}
                        ;;
                v)
                        vnet=${OPTARG}
                        ;;
                n)
                        snet=${OPTARG}
                        ;;
                i)
                        instancename=${OPTARG}
                        ;;
                u)
                        username=${OPTARG}
                        ;;
                p)
                        password=${OPTARG}
                        ;;
		l)
			zone=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))


if [[ -z "$groupname" ]]; then
        echo "Enter the existing group_name to house all resources for your managed instance inside:"
        read groupname
        [[ "${groupname:?}" ]]
fi

if [[ -z "$vnet" ]]; then
        echo "what's the name of the virtual network in the group?"
        read vnet
        [[ "${vnet:?}" ]]
fi

if [[ -z "$snet" ]]; then
        echo "what's the name of the subnet in the Vnet in the group?"
        read snet
        [[ "${snet:?}" ]]
fi

if [[ -z "$instancename" ]]; then
        echo "Choose a name for your managed instance, lower letters, hyphen allowed in naming convention, example: mi-edw1"
        read instancename 
        [[ "${instancename:?}" ]]
fi

if [[ -z "$username" ]]; then
        echo "Choose an Administrator username, example: MiAdmin"
        read username
        [[ "${username:?}" ]]
fi

if [[ -z "$password" ]]; then
        echo "Choose a password that meets security requirements, example: SQLAdm1nt3st1ng!"
        read password
        [[ "${password:?}" ]]
fi

if [[ -z "$zone" ]]; then
        echo "Finally, choose an Azure Location Zone to create everything in. Choose one from the following list"
        az account list-locations | grep name | awk  '{print $2}'| tr -d \"\,
        echo "Enter the location name:"
        read zone
        [[ "${zone:?}" ]]
fi

#Last of parameter information for the script
export subscriptionID=$(az account show | grep id |awk  '{print $2}'| tr -d \"\,)
export logfile=mi_deploy

# Set default subscription ID if not already set by customer.
# Created on 10/14/2018
az account set --subscription $subscriptionID
 
echo "Create the Managed Instance"
az sql mi create -n $instancename -u $username -p $password \
           -g $groupname -l "$zone" \
           --vnet-name $vnet --subnet $snet

echo "This is your Admin User,Password and Proxy Password:"  > $logfile.txt
echo $username $password  >> $logfile.txt
echo "This is the subscription the MI was created under and the IP address associated with the firewall:"
echo $subscriptionID $myip >> $logfile.txt
echo "This is your Azure location zone:" $zone >> $logfile.txt
echo "This is the name of your managed instance:" >> $logfile.txt
echo $instancename >> $logfile.txt
echo "This is the subscription deployed to and the Firewall IP:" >> $logfile.txt
echo "This list verifies your instance was created:" az sql mi list >> $logfile.txt
echo "------------------------------------------------------------------------------------------------------------"

echo "Managed Instance Creation Complete."

#/bin/bash
set -euo pipefail
IFS=$'\n\t'

#---------------------------------------------------------------
# mi_deploy.sh
# Author: Kellyn Gorman
# Deploys a Managed Instance via Azure CLI to Azure
# Initial Script- 03/14/2019
#---------------------------------------------------------------
# -e: immediately exit if anything is missing
# -o: prevents masked errors
# IFS: deters from bugs, looping arrays or arguments (e.g. $@)
#---------------------------------------------------------------

usage() { echo "Usage: $0 -g <groupname> -i <instancename> -v <vnet> -u <username> -p <password> -l <zone>" 1>&2; exit 1; }

declare groupname=""
declare instancename=""
declare vnet=""
declare username=""
declare password=""
declare zone=""

# Initialize parameters specified from command line
#while getopts ":i:g:p:l:" arg; do
while getopts ":g:i:v:u:p:l:" arg; do
        case "${arg}" in
                g)
                        groupname=${OPTARG}
                        ;;
                v)
                        vnet=${OPTARG}
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
        echo "Choose a Group name to house all resources for your managed instance inside:"
        read groupname
        [[ "${groupname:?}" ]]
fi

if [[ -z "$vnet" ]]; then
        echo "Choose a name for your virtual network"
        read vnet
        [[ "${vnet:?}" ]]
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
        az account list-locations | grep name | grep us | grep -v australia | awk  '{print $2}'| tr -d \"\,
        echo "Enter the location name:"
        read zone
        [[ "${zone:?}" ]]
fi

#Last of parameter information for the script

echo "getting IP Address for Azure Cloud Shell for firewall rule"
export subscriptionID=$(az account show | grep id |awk  '{print $2}'| tr -d \"\,)
export myip=$(curl http://ifconfig.me)
export startip=$myip
export endip=$myip
export logfile=mi_deploy
export snet=$vnet"_snet"

#---------------------------------------------------------------
# Customers should only update the variables in the top of the script, nothing below this line.
#---------------------------------------------------------------

# Set default subscription ID if not already set by customer.
# Created on 10/14/2018
az account set --subscription $subscriptionID
 
# Create a resource group
az group create \
	--name $groupname \
	--location $zone

 
echo "Create VNet"
az network vnet create \
  --name $vnet \
  --resource-group $groupname \
  --subnet-name $snet

echo "Create Routing Table to Support MI"
az network route-table create -g $groupname  -n MyRouteTable

az network route-table route create -g $groupname --route-table-name MyRouteTable -n MiRoute \
   --next-hop-type Internet --address-prefix 0.0.0.0/0

az network vnet subnet update \
  --vnet-name $vnet  \
  --name $snet \
  --resource-group $groupname \
  --route-table MyRouteTable

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

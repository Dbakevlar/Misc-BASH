#/bin/bash
set -euo pipefail
IFS=$'\n\t'

#---------------------------------------------------------------
# cs_firewall.sh
# Author: Kellyn Gorman
# Creates a Firewall for the Azure Cloud Shell to SQL Server in the Resource group you pass
# Initial Script- 04/18/2019
#---------------------------------------------------------------
# -e: immediately exit if anything is missing
# -o: prevents masked errors
# IFS: deters from bugs, looping arrays or arguments (e.g. $@)
#---------------------------------------------------------------

usage() { echo "Usage: $0 -g <groupname> -s <servername> " 1>&2; exit 1; }

declare groupname=""
declare servername=""

# Initialize parameters specified from command line
while getopts ":g:s:" arg; do
	case "${arg}" in
		g)
			groupname=${OPTARG}
			;;
		s)
			servername=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))


# Enter the name of the group and server that you want to create the firewall for

if [[ -z "$groupname" ]]; then
	echo "What is the resource group that you want to create a firewall rule for? "
	echo "Enter your Resource Group name:"
	read groupname
	[[ "${groupname:?}" ]]
fi

if [[ -z "$servername" ]]; then
	echo "What Azure DB server would you like to create a firewall rule for the Azure cloud shell?"
	echo "Enter the server name:"
	read servername
	[[ "${servername:?}" ]]

fi

# The ip address range that you want to allow to access your Server. 

echo "getting IP Address for Azure Cloud Shell for firewall rule"
export myip=$(curl http://ifconfig.me)
export startip=$myip
export endip=$myip

# Configure a firewall rule for the server
# Remove the Firewall Rule if exists:
az sql server firewall-rule delete \
        --resource-group $groupname \
        --server $servername \
        --name AllowCloudShellIp

echo "Removed previous firewall rule if exists, to keep firewall rules cleaned up."
#Create Firewall Rule
az sql server firewall-rule create \
	--resource-group $groupname \
	--server $servername \
	--name AllowCloudShellIp \
	--start-ip-address $startip \
	--end-ip-address $endip


echo "Firewall Created for $startip for $groupname on $servername."

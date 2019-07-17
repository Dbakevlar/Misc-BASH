#/bin/bash
set -euo pipefail
IFS=$'\n\t'
# Set Job Run name here for logging:
export jobrun=ora_vm

#---------------------------------------------------------------
# mk_oravm.sh
# keeps to Microsoft bash script formatting
# creates a Linux VM with Oracle software after choosing installation urn and type of install.
# Requirements- sku information, (versions of install for sript call)
#---------------------------------------------------------------
# -e: immediately exit if anything is missing
# -o: prevents masked errors
# IFS: deters from bugs, looping arrays or arguments (e.g. $@)
#---------------------------------------------------------------

usage() { echo "Usage: $0 -g <groupname> -u <urn> -o <oraname> -sz <size> -a <adminuser> -l <zone> " 1>&2; exit 1; }

declare groupname=""
declare urn=""
declare oraname=""
declare size=""
declare adminuser=""
declare zone=""


# Initialize parameters specified from command line
while getopts ":g:s:v:o:sz:a:l:" arg; do
	case "${arg}" in
		g)
			groupname=${OPTARG}
			;;
		u)
			urn=${OPTARG}
			;;
		o)
			oraname=${OPTARG}
			;;
		sz)
			size=${OPTARG}
			;;
		a)
			adminuser=${OPTARG}
			;;
		l)
			zone=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

if [[ -z "$groupname" ]]; then
	echo "What is the name for the resource group to create the deployment in? Example: ORA_GRP "
	echo "Enter your Resource Group name:"
	read groupname
	[[ "${groupname:?}" ]]
fi

# Create the latest version of Oracle VM installations available and push to a file
az vm image list --offer Oracle --all --publisher Oracle --output table >db.lst

if [[ -z "$urn" ]]; then
	echo "Here's the installation version urns available, including Oracle and Oracle Linux "
     cat db.lst | awk  '{print $4}'
	echo "Enter the urn you'd like to install, feel free to copy from the list and paste here:"
	read urn
	[[ "${urn:?}" ]]
fi

if [[ -z "$oraname" ]]; then
	echo "What unique name your Oracle database server? This will be used for disk naming, must be unique.  Example: ora122db1 "
	echo "Enter the DB Server name:"
	read oraname
	[[ "${oraname:?}" ]]
fi

if [[ -z "$size" ]]; then
	echo "What size deployment would you like, choose from the following: StandardSSD_LRS, Standard_LRS, UltraSSD_LRS ?  Example:  "
	echo "Enter the Size name from above:"
	read size
	[[ "${size:?}" ]]
fi

if [[ -z "$adminuser" ]]; then
	echo "Choose an Admin user to manage your server.  This is not the ORACLE user for the box, but an ADMIN user"
	echo "Enter in the admin user name, example: azureuser"
	read adminuser
	[[ "${adminuser:?}" ]]
fi

if [[ -z "$zone" ]]; then
	echo "You must choose a location region to deploy your resources to.  The list as follows:"
        az account list-locations | grep name | awk  '{print $2}'| tr -d \"\, | grep us | grep -v australia
	echo "Enter the zone from the list above:"
	read zone
	[[ "${zone:?}" ]]
fi


# Build Steps

# Create a Resource Group, this must be a unique tenant and choose the location zone to deploy to:
az group create --name $groupname --location $zone

#Make this resource group and zone default
az configure --defaults group=$groupname location=$zone

# Create Oracle VM
az vm create \
    --name $oraname \
    --image $urn:latest \
    --admin-username $adminuser \
    --generate-ssh-keys

az vm open-port \
    --name $oraname \
    --port 22 \
    --priority 330 

# Create Storage Disks to use with database
az vm disk attach --vm-name $oraname \
    --caching ReadWrite \
    --name $oraname"dsk" \
    --sku $size \
    --new 


echo "Deployment of Oracle VM $oraname in resource group $groupname Complete"
echo "Keys generated for authentication"
echo "Admin name is $adminuser"

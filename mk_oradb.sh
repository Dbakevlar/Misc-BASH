#/bin/bash
set -euo pipefail
IFS=$'\n\t'
# Set Job Run name here for logging:
export jobrun=ora_db

#---------------------------------------------------------------
# mk_oradb.sh
# keeps to Microsoft bash script formatting
# creates an Oracle database on a VM after choosing installation sku and type of install.
# Requirements- sku information, (versions of install for sript call)
#---------------------------------------------------------------
# -e: immediately exit if anything is missing
# -o: prevents masked errors
# IFS: deters from bugs, looping arrays or arguments (e.g. $@)
#---------------------------------------------------------------

usage() { echo "Usage: $0 -g <groupname> -s <sku> -v <version> -o <oraname> -sz <size> -a <adminuser> -l <zone> " 1>&2; exit 1; }

declare groupname=""
declare sku=""
declare version=""
declare oraname=""
declare size=""
declare adminuser=""
declare zone=""


# Initialize parameters specified from command line
while getopts ":g:s:v:o:a:l:sz:" arg; do
	case "${arg}" in
		g)
			groupname=${OPTARG}
			;;
		s)
			sku=${OPTARG}
			;;
		v)
			version=${OPTARG}
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
az vm image list --offer Oracle --all --publisher Oracle >db.lst

if [[ -z "$sku" ]]; then
	echo "Here's the installation version, from 12c through 18c available for Oracle: "
    cat db.lst | grep sku | awk  '{print $2}'| tr -d \"\,
	echo "Enter the version you'd like to install, the numbering convention must be exact, feel free to copy from the list and paste here:"
	read sku
	[[ "${sku:?}" ]]
fi

if [[ -z "$version" ]]; then
	echo "Along with installation version, the script needs to know if Enterprise, (Ee) or Standard, (Se) version?"
	echo "Enter either Ee or Se and the answer IS cap-sensitive"
	read version
	[[ "${version:?}" ]]
fi

if [[ -z "$oraname" ]]; then
	echo "What would you like to name your Oracle database server?  Example: ora122db1 "
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
	echo "Enter the zone from the list above:"
	read zone
	[[ "${zone:?}" ]]
fi


# Get Correct URN value from sku and version entered:
urn=$(cat db.lst | grep $version:$sku | grep urn | awk '{print $2}' | tr -d \"\,)
export logfile=./$jobrun.txt

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

#  --size Standard_DS2_v2 \

# Create Storage Disks to use with database
az vm disk attach --vm-name $oraname \
    --caching ReadWrite \
    --name $oraname"dsk" \
    --sku $size \
    --new 


echo "Deployment of Oracle VM $oraname in resource group $groupname Complete"
echo "Keys generated for authentication"
echo "Admin name is $adminuser"

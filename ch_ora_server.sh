#!/bin/bash
IFS=$'\n\t'

#################################################################
# Script to collect information and workload from Linux server  #
# Author: Kegorman, Microsoft					                #
# Assumption is SAR utility is installed on server              #
#################################################################
usage() { echo "Usage: $0 -o <ora_db> -u <username> -p <password>" 1>&2; exit 1; }

# Validate the value of ORACLE_HOME #
# If ORACLE_HOME is empty #
if [ -z $ORACLE_HOME ]
then
        echo "Set the ORACLE_HOME variable"
        exit 1
fi

declare ora_db=""
#declare username=""
#declare password=""

# Initialize parameters specified from command line
while getopts ":o:u:p:" arg; do
	case "${arg}" in
		o)
			ora_db=${OPTARG}
			;;
		u)
			username=${OPTARG}
			;;
		p)
			password=${OPTARG}
			;			
			esac
done
shift $((OPTIND-1))


outfile=(uname -n).txt

echo "Need to know the database we are going to collect information on"
if [[ -z "$ora_db" ]]; then
	echo "Type in the databaes that we want to collect information on today"
	read ora_db
	[[ "${ora_db:?}" ]]
fi
echo "Need a database username that has access to AWR data"
if [[ -z "$username" ]]; then
	echo "Type in the username to be used for access to the database"
	read username
	[[ "${username:?}" ]]
fi
echo "Need the password to this database user"
if [[ -z "$password" ]]; then
	echo "Type in the password for the user to the database"
	read password
	[[ "${password:?}" ]]
fi

echo "Host Information" > $outfile
echo "================" >> $outfile
uname -a >> $outfile


echo "CPU Info" >> $outfile
echo "--------" >> $outfile
cat /proc/cpuinfo | grep "model name" >> $outfile
cat /proc/cpuinfo | grep "cpu cores" >> $outfile
echo "Memory Info"
echo "--------"
cat /proc/meminfo | grep MemTotal >> $outfile
cat /proc/meminfo | grep HugePages_Total >> $outfile

echo "Server Workload Data" >> $outfile
echo "===================="
iostat -c
# Collect CPU data every 60 seconds, five times to see the CPU workload
iostat -xtc 60 5 >> $outfile
#Collect memory info every 60 seconds, five times to see the memory distribution
vmstat 60 5 >> $outfile
#IO Information, every 60 seconds, five times
iostat -x 60 5 >> $outfile
#Network High level info
netstat -st >> $outfile

#Locate Number of Database Running on Server
echo "What databases are on this server? Each PMon will tell us" >> $outfile
ps -ef | grep pmon >> $outfile

echo "Capture Database Information" >> $outfile
echo "============================"
export ORACLE_SID=$ora_db


#Log into database and collect information using secondary script
  $ORACLE_HOME/bin/sqlplus -s $username/$password  << EOF >> $outfile
@ora_db_rvw.sql;
EOF
date >> $outfile
exit

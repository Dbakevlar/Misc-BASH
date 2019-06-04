#/bin/bash
set -euo pipefail
#set -eux pipefail
IFS=$'\n\t'

#---------------------------------------------------------------
# hdi_deploy.sh
# Author: Kellyn Gorman
# Deploys HDInsight and Support Structure via Azure CLI to Azure
# Scripted- 06/04/2019
#---------------------------------------------------------------
# -e: immediately exit if anything is missing
# -o: prevents masked errors
# IFS: deters from bugs, looping arrays or arguments (e.g. $@)
#---------------------------------------------------------------
usage() { echo "Usage: $0  -g <groupname> -h <holname> -l <zone> -p <password>" 1>&2; exit 1; }
declare groupname=""
declare holname=""
declare zone=""
declare password=""

# Initialize parameters specified from command line
while getopts ":g:h:l:p:" arg; do
        case "${arg}" in
		g)
			groupname=${OPTARG}
			;;
		h)
			holname=${OPTARG}
			;;
		l)
			zone=${OPTARG}
			;;
                p)
                        password=${OPTARG}
                        ;;
		esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
#login to azure using your credentials

if [[ -z "$groupname" ]]; then
	echo "What is the name for the resource group to create the deployment in? Example: EDU_Group "
	echo "Enter your Resource Group name:"
	read groupname
	[[ "${groupname:?}" ]]
fi


if [[ -z "$holname" ]]; then
	echo "Choose a 3-5 letter-number acronym , lower case convention to be used for a unique deployment name- Example: xxx1"
	read holname
	[[ "${holname:?}" ]]
fi

if [[ -z "$zone" ]]; then
	echo "What will be the Azure location zone to create everything in? Choose from the list below: "
	az account list-locations | grep name | awk  '{print $2}'| tr -d \"\, | grep us | grep -v australia
	echo "Enter the location name:"
	read zone
	[[ "${zone:?}" ]]
fi

if [[ -z "$password" ]]; then
	echo "This is the password naming convention to be used for the ssh and cluster.  Must meet standards for passwords, example: CL1t3st1ng"
	read password
	[[ "${password:?}" ]]
fi
#Check for Template file that we will update

export templateFile1="templatehdi.json"
touch $templateFile1

if [ ! -f "$templateFile1" ]; then

        echo "$templateFile1 not found"

        exit 1

fi


export subscriptionID=$(az account show | grep id |awk  '{print $2}'| tr -d \"\,)
export myip=$(curl http://ifconfig.me)
export startip=$myip
export endip=$myip
export logfile=./hdi_deploy.txt
export hdiname=${holname}insdpy1
export schema='$schema'
export clpassword=HdiSght${password}1!
export sshpassword=ClHd${password}1!


#Generate JSON Template to set names and eliminate requests for more info
cat > ./${templateFile1} << EOF
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "clusterName": {
      "type": "string",
      "defaultValue": "$hdiname",
      "metadata": {
        "description": "The name of the HDInsight cluster to create."
      }
    },
    "clusterLoginUserName": {
      "type": "string",
      "defaultValue": "admin",
      "metadata": {
        "description": "These credentials can be used to submit jobs to the cluster and to log into cluster dashboards."
      }
    },
    "clusterLoginPassword": {
      "type": "securestring",
      "defaultValue": "$clpassword",
      "metadata": {
        "description": "The password must be at least 10 characters in length and must contain at least one digit, one non-alphanumeric character, and one upper or lower case letter."
      }
    },
    "sshUserName": {
      "type": "string",
      "defaultValue": "sshuser",
      "metadata": {
        "description": "These credentials can be used to remotely access the cluster."
      }
    },
    "sshPassword": {
      "type": "securestring",
      "defaultValue": "$sshpassword",
      "metadata": {
        "description": "The password must be at least 10 characters in length and must contain at least one digit, one non-alphanumeric character, and one upper or lower case letter."
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]",
      "metadata": {
        "description": "Location for all resources."
      }
    }
  },
  "variables": {
    "defaultStorageAccount": {
      "name": "[uniqueString(resourceGroup().id)]",
      "type": "Standard_LRS"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "name": "[variables('defaultStorageAccount').name]",
      "location": "[parameters('location')]",
      "apiVersion": "2016-01-01",
      "sku": {
        "name": "[variables('defaultStorageAccount').type]"
      },
      "kind": "Storage",
      "properties": {}
    },
    {
      "type": "Microsoft.HDInsight/clusters",
      "name": "[parameters('clusterName')]",
      "location": "[parameters('location')]",
      "apiVersion": "2018-06-01-preview",
      "dependsOn": [
        "[concat('Microsoft.Storage/storageAccounts/',variables('defaultStorageAccount').name)]"
      ],
      "tags": {},
      "properties": {
        "clusterVersion": "3.6",
        "osType": "Linux",
        "tier": "Standard",
        "clusterDefinition": {
          "kind": "spark",
          "configurations": {
            "gateway": {
              "restAuthCredential.isEnabled": true,
              "restAuthCredential.username": "[parameters('clusterLoginUserName')]",
              "restAuthCredential.password": "[parameters('clusterLoginPassword')]"
            }
          }
        },
        "storageProfile": {
          "storageaccounts": [
            {
              "name": "[replace(replace(reference(resourceId('Microsoft.Storage/storageAccounts', variables('defaultStorageAccount').name), '2016-01-01').primaryEndpoints.blob,'https://',''),'/','')]",
              "isDefault": true,
              "container": "[parameters('clusterName')]",
              "key": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', variables('defaultStorageAccount').name), '2016-01-01').keys[0].value]"
            }
          ]
        },
        "computeProfile": {
          "roles": [
            {
              "name": "headnode",
              "targetInstanceCount": 2,
              "hardwareProfile": {
                "vmSize": "Standard_D12_v2"
              },
              "osProfile": {
                "linuxOperatingSystemProfile": {
                  "username": "[parameters('sshUserName')]",
                  "password": "[parameters('sshPassword')]"
                }
              },
              "virtualNetworkProfile": null,
              "scriptActions": []
            },
            {
              "name": "workernode",
              "targetInstanceCount": 2,
              "hardwareProfile": {
                "vmSize": "Standard_D13_v2"
              },
              "osProfile": {
                "linuxOperatingSystemProfile": {
                  "username": "[parameters('sshUserName')]",
                  "password": "[parameters('sshPassword')]"
                }
              },
              "virtualNetworkProfile": null,
              "scriptActions": []
            }
          ]
        }
      }
    }
  ],
  "outputs": {
    "storage": {
      "type": "object",
      "value": "[reference(resourceId('Microsoft.Storage/storageAccounts', variables('defaultStorageAccount').name))]"
    },
    "cluster": {
      "type": "object",
      "value": "[reference(resourceId('Microsoft.HDInsight/clusters',parameters('clusterName')))]"
    }
  }
}
EOF

# Set default subscription ID if not already set by customer.
az account set --subscription $subscriptionID
 
echo "Create a resource group"
az group create \
	--name $groupname \
	--location $zone

#Set Defaults for Group and location
az configure --defaults group=$groupname location=$zone

# Deploy HDInsight Step
echo "Create HDIsnight"
az group deployment create --resource-group $groupname \
   --template-file $templateFile1


# Log Deployment Info
echo "This is your Azure location zone: $zone" > $logfile
echo "Information about the HDInsight Deployment::" >> $logfile 
echo "Name of HDInsight Cluster: $hdiname" >> $logfile
echo "Cluster Password: $clpassword" >> $logfile
echo "SSH Password: $sshpassword" >> $logfile

echo "All Steps in the deployment are now complete."

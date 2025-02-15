#!/bin/bash
function apply-kubernetes()
{
	servicename="${1}"
    if [ -f "$servicename" ]; then
        echo "File $servicename exists."
        kubectl apply -f ./$servicename || { echo "$servicename apply failed"; exit 1; }
    else
        echo "File $servicename does not exist."
    fi
}

function kubernetes-configmap()
{
    configMapRef="${1}"
    configMapRefPath="${2}"
    config_map_data=$(kubectl get configmap "$configMapRef" -o json)
    # Check if the ConfigMap exists
    if [[ -z "$config_map_data" ]]; then
        echo "ConfigMap $config_map_name does not exist."
        kubectl create configmap $configMapRef --from-env-file=$configMapRefPath
    fi

}


function create_folder_if_not_exists() {
    local folder_path="$1"
    
    # Check if the folder exists
    if [ ! -d "$folder_path" ]; then
        # If it doesn't exist, create it
        mkdir -p "$folder_path"
        echo "Folder created: $folder_path" >> $NOLUCK/log.log 2>&1
    else
        echo "Folder already exists: $folder_path" >> $NOLUCK/log.log 2>&1
    fi
}




# Function to validate the password
validate_password() {
  password="$1"
  
  # Check if the password has at least 8 characters
  if [ ${#password} -lt 8 ]; then
    return 1
  fi

  # Check if the password contains at least one special character from the allowed list
  if ! [[ "$password" =~ [#+*?!^] ]]; then
    return 1
  fi

  return 0
}

# Function to validate the password
validate_password_ft() {
  password="$1"
  
  # Check if the password has at least 8 characters
  if [ ${#password} -lt 8 ]; then
    return 1
  fi

  # Check if the password contains at least one special character from the allowed list
  if ! [[ "$password" =~ [#+*?!%$^] ]]; then
    return 1
  fi

  return 0
}

# Function to read a validated password
read_validated_password() {
  prompt="$1"
  validate_password="$2"
  while true; do
    read -s -p "$prompt: " password
    echo
    read -s -p "Confirm $prompt: " password_confirm
    echo
    if [ "$password" == "$password_confirm" ]; then
      if $validate_password "$password"; then
        break
      else
        echo "Password must have at least 8 characters and at least one special character. Please try again."
      fi
    else
      echo "Passwords do not match. Please try again."
    fi
  done
}

function install_aws_cli() {
	pip3 install requests
	pip3 install boto3
	pip3 install awscli
	pip3 install --user requests
	pip3 install --user boto3
	pip3 install --user awscli
	if [[ -f aws-config.env ]] ; then
		echo "Automatically configuring AWS CLI."
		export $(cat aws-config.env | xargs)
		mkdir /root/.aws || (echo "Failed to create AWS folder" && exit 1)	
		echo "[default]" >> /root/.aws/credentials
		echo "AWS_ACCESS_KEY_ID = $AWS_ACCESS_KEY_ID" >> /root/.aws/credentials
		echo "AWS_SECRET_ACCESS_KEY = $AWS_SECRET_ACCESS_KEY" >> /root/.aws/credentials
		
		if [[ "$AWS_DEFAULT_OUTPUT" -eq "" ]] ; then
			export AWS_DEFAULT_OUTPUT=json
		fi
		
		if [[ "$AWS_DEFAULT_REGION" -eq "" ]] ; then
			export AWS_DEFAULT_REGION=eu-central-1
		fi
		
		echo "[default]"  >> /root/.aws/config
		echo "output = $AWS_DEFAULT_OUTPUT" >> /root/.aws/config
		echo "region = $AWS_DEFAULT_REGION" >> /root/.aws/config
		
		cp -R /root/.aws /tmp/"$USER_NAME"/ || { echo "command failed"; exit 1; }
		chown -R "$USER_NAME" /tmp/"$USER_NAME"/.aws || { echo "command failed"; exit 1; }	
	else
		aws configure
	fi
}

#Remove all cron jobs for the current user
if [ -z "$(crontab -l 2>/dev/null)" ]; then
    crontab -r
else
    echo "Crontab contains tasks, skipping removal."
fi

USER_NAME=$(logname)
echo 'noluck_HOME=/noluck' >> /etc/environment 
echo "INSTALL_DIR=/tmp" | sudo tee -a /etc/environment 
echo 'nanop=noluckSec!' >> /etc/environment 
echo "USER_NAME=$USER_NAME" | sudo tee -a /etc/environment 
source /etc/environment
if [ -d "/tmp/utilities" ]; then
    # Call validate_files.sh
    ./validate_files.sh

    # Check the exit status of validate_files.sh
    if [ $? -ne 0 ]; then
        echo "File validation failed: there are missing files in 'utilities' or 'images-otd'. Exiting."
    fi

    echo "File validation succeeded. Continuing with installation."
    echo "Installing dependencies..."
    ./offline-preparation.sh
else
    # Check connectivity to 8.8.8.8
	if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
			echo "Network connectivity detected. Running online preparation..."
			./online-preparation.sh
	else
		echo "Network connectivity not detected. Exiting."
	fi

fi


create_folder_if_not_exists $NOLUCK
create_folder_if_not_exists $NOLUCK/postgres
create_folder_if_not_exists $NOLUCK/postgres/data
create_folder_if_not_exists $NOLUCK/postgres/archivedir 
create_folder_if_not_exists $NOLUCK/assets
create_folder_if_not_exists $NOLUCK/assets/files
create_folder_if_not_exists $NOLUCK/elasticsearch
create_folder_if_not_exists $NOLUCK/elasticsearch/logs
create_folder_if_not_exists $NOLUCK/elasticsearch/data
create_folder_if_not_exists $NOLUCK/logstash
create_folder_if_not_exists $NOLUCK/kibana
create_folder_if_not_exists $NOLUCK/vault
create_folder_if_not_exists $NOLUCK/vault/config
create_folder_if_not_exists $NOLUCK/netdata
create_folder_if_not_exists $NOLUCK/netdata/plugins
create_folder_if_not_exists $NOLUCK/netdata/logs
create_folder_if_not_exists $NOLUCK/netdata/plugins/python
create_folder_if_not_exists $NOLUCK/grafana/plugins
create_folder_if_not_exists $NOLUCK/grafana/data
create_folder_if_not_exists $NOLUCK/prometheus
create_folder_if_not_exists $NOLUCK/prometheus/data
create_folder_if_not_exists $NOLUCK/nginx/logs
create_folder_if_not_exists $NOLUCK/postgres/data

echo Chaning owner to: "$USER_NAME" >> $NOLUCK/log.log 2>&1
chown -R "$USER_NAME" $NOLUCK/prometheus
chown -R "$USER_NAME" $NOLUCK || { echo "command failed"; exit 1; }
chown -R "$USER_NAME" /var/log$NOLUCK || { echo "command failed"; exit 1; }
echo 'LD_LIBRARY_PATH=/usr/local/lib' >> /etc/environment 
write_noluck_dockers_script "/usr/local/bin$NOLUCK-dockers" 
write_noluck_services_script "/usr/local/bin$NOLUCK-services" 
write_noluck_stats_script "/usr/local/bin$NOLUCK-stats" 
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
echo 'net.ipv4.icmp_echo_ignore_all=1' >> /etc/sysctl.conf
echo 'net.core.netdev_budget=2400' >> /etc/sysctl.conf
echo 'net.core.netdev_budget_usecs=20000' >> /etc/sysctl.conf
#apt install -y python3-pip

# if [ -f "/swapfile" ] ; then
# 	echo "Swap is already enable"
# else
# 	while true; do
# 		read -p "Do you wish to enable swap? " yn
# 		case $yn in
# 		[Yy]* )	./enable-swap.sh; break;;
# 		[Nn]* ) break;;
# 			* ) echo "Please answer yes or no.";;
# 		esac
# 	done
# fi

# while true; do
#     read -p "Are you installing a standalone server? " yn
#     case $yn in
# 	[Yy]* )	./setup-slave.sh "y"; break;;
# 	[Nn]* ) ./setup-slave.sh "n"; break;;
#         * ) echo "Please answer yes or no.";;
#     esac
# done

./configure-ip-dns.sh ssl;

./defender-type.sh 3;

while true; do
    read -p "Do you wish to modify support details? " yn
    case $yn in
	[Yy]* )	./support.sh "y"; break;;
	[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
	esac
done


while true; do
    read -p "Do you wish to have a single password for all the services? " yn
    case $yn in
        [Yy]* )    
            # Read and validate the password
            read_validated_password "Enter your password for all the services" "validate_password"
            # Use the validated password variable in your script
            # ./update-pw.sh KEYCLOAK $password
            ./update-pw.sh POSTGRES $password
            ./update-pw.sh MoTAdmin $password
			#./update-pw.sh factorytalkprog $password
			#./update-pw.sh factorytalksuper $password
            break;;
        [Nn]* )    

            # Read and validate the password
            read_validated_password "Enter your password for postgres service" "validate_password"
            # Use the validated password variable in your script
            #echo "Password is set to: $password"
            ./update-pw.sh POSTGRES $password

            # Read and validate the password
            read_validated_password "Enter your password for MoTAdmin user" "validate_password"
            # Use the validated password variable in your script
            #echo "Password is set to: $password"
            ./update-pw.sh MoTAdmin $password

            break;;
        * ) 
            echo "Please answer yes or no."
            ;;
    esac
done


while true; do
    read -p "Enable FactoryTalk support? " yn
    case $yn in
	[Yy]* )	
		while true; do
			read -p "Do you wish to have a single password to superuser & programmer? " yn
			case $yn in
				[Yy]* )    
					# Read and validate the password
					read_validated_password "Enter your password for all the services" "validate_password_ft"
					# Use the validated password variable in your script
					./update-pw.sh factorytalksuper $password
					./update-pw.sh factorytalkprog $password
					break;;
				[Nn]* )    
					# Read and validate the password
					read_validated_password "Enter your password for factorytalkprog user" "validate_password_ft"
					# Use the validated password variable in your script
					#echo "Password is set to: $password"
					./update-pw.sh factorytalkprog $password

					# Read and validate the password
					read_validated_password "Enter your password for factorytalksuper user" "validate_password_ft"
					# Use the validated password variable in your script
					#echo "Password is set to: $password"
					./update-pw.sh factorytalksuper $password
					break;;
				* ) 
					echo "Please answer yes or no."
					;;
			esac
		done
	break;;
	[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
	esac
done

sudo -E ./02-install-server.sh $USER_NAME
 

sudo ./03-install-server.sh
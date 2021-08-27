#!/usr/bin/env bash

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

## Functions (root and getopt checks are functionless, and are located at the bottom of the script)

usage(){
	echo "Usage: Docker Swarm Installer -[OPTIONS]"
	echo
	echo "OPTIONS"
	echo "-d, --dev"
	echo "        Denotes a development install (setup without using a hard disk)."
	echo "-l, --leader"
	echo "        Denotes a leader (or manager) node. Will initialize a new swarm if it is not part of one, and then provides tokens for managers and workers to join."
	echo "        If node is already part of a swarm and is a leader/manager in that swarm, it will simply provide tokens for other nodes to join."
	echo "-h, --help"
	echo "        Displays this usage menu then exits."
	echo
	exit 1
} >&2

root_check() {
# Validate script is being run as root.  Exit if not.
	if [ "$EUID" -ne "0" ]; then
		echo "${red}USAGE: Script must be run as root!  Exiting..."
		exit 4
	fi
}

getopt_check() {
# Check to see if getopt is installed, if not, install it
	if [[ $(getopt -T >/dev/null 2>&1 ; echo $?) -ne 4 ]]; then
		echo "ERROR: getopt is not found."
		echo -n "Installing getopt now... "
		nohup yum install util-linux* -y -q >/dev/null 2>&1 & PID=$! ; disown -h $PID
		wait
		if [[ $(rpm -qf `type -p getopt` | wc -l) -ge 1 ]]; then
			echo "getopt install complete!"
			return
		else
			echo "${red}Failed to install getopt!"
			echo -e " Exiting."
			exit 4
		fi
	fi
}

leader_check() {
	if [[ `hostname | egrep qun[0-9]{3} | wc -l` -gt 0 ]];then
		return
	elif [[ `hostname | egrep q[0-9]{3} | wc -l` -gt 0 ]];then
		return
	elif [[ `hostname | egrep m[0-9]{3} | wc -l` -gt 0 ]];then
		return		
	else
		echo -e "\n${red}You have chosen the option for a leader node, which is reserved exclusively for queens or managers.${reset}\n"
		usage
	fi

}

docker_check() {
	docker --version >/dev/null 2>&1
	if [[ $? -eq 0 ]];then
		echo "${green}Docker already installed${reset}"
		docker --version
		init_install=false
	else
		echo "Docker not installed, proceeding with installation"
		init_install=true
	fi

	return
}

disk_check() {
# Checks for disk if dev option is not selected
	counter=0
	disk_name=$(fdisk -l | grep GB | awk '{print $2}' | cut -d ":" -f 1)
	names=($disk_name)
	disk_size=$(fdisk -l | grep GB | awk '{print $3}' | cut -d "." -f 1)
	sizes=($disk_size)

	echo "Checking for suitable disk: "
	for num in ${sizes[@]}; do
		if [ $num -ge 60 -a $num -lt 110 ];then
			check_disk=$(pvs | grep ${names[$counter]})

			# Check to see if hard disk is already being used for docker
			if grep -q docker <<<"$check_disk | awk '{print $2}'";then
				echo "Docker has already been formatted for ${names[$counter]}"
				swarm_setup
				exit 2

			# Check to see if a hard disk is free to use for docker (not allocated for something else
			elif [[ -z $check_disk ]];then
				echo "Suitable disk found: ${green}${names[$counter]}${reset} to be configured for Docker usage"
				index=${names[$counter]}

				return
			fi
		fi
	((counter++))
	done

	# This echo and exit must be placed outside of the loop so that it will have a chance to check all potential disk allocations
	while true; do
		echo "No suitable disk found for Docker install. Would you like to proceed anyways? (y/n)"
		read response </dev/tty
		if [[ "$response" == [Yy] ]];then
			no_install=true
			return
		elif [[ "$response" == [Nn] ]];then
			exit 2
		else
			echo "Type y or n to install or exit"
		fi
	done
}

docker_log() {
	cat << EOF > /etc/logrotate.d/syslog
/var/log/cron
/var/log/maillog
/var/log/messages
/var/log/secure
/var/log/spooler
{
    size 100M
    copytruncate
    rotate 10
    compress
    maxage 90
    sharedscripts
    postrotate
        /bin/kill -HUP `cat /var/run/syslogd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}
EOF

	return
}

foreward_enable() {
	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/docker.conf
	sysctl --system >/dev/null 2>&1

	echo "Config files successfully updated and reloaded"

	return
}

dependency_check(){
# Check for required dependencies and install them if not already installed.
	printf "Checking dependencies...\n"
	for dep in yum-utils device-mapper-persistent-data lvm2 unzip;do
		if (rpm -qa | grep -q $dep); then
			echo "$dep already installed"
		else
			yum install $dep -y -q
			wait
			echo "$dep Installed"
		fi
	done

	return
}

add_repo(){
# Add the docker repository for OL
	echo "Adding docker repository..."
	if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
    echo "Local copy of repo not found cloning from github..."
		wget -O /etc/yum.repos.d/docker-ce.repo https://raw.githubusercontent.com/jaredbrogan/Docker/main/docker-ce.repo
		wait
		yum-config-manager --add-repo /etc/yum.repos.d/docker-ce.repo
	fi
	#Commenting this out since the docker provided repo refrences variables that are not present in OL7 that exists in CentOS
	#yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	if [[ $? -gt 0 ]]; then
		echo "${red}Could not grab repo. Exiting${reset}"
		exit 4
	fi
}

install_docker(){
  # Check if public repo is on server, if so enable ol7 addons.
	if [ -f /etc/yum.repos.d/public-yum-ol7.repo ]; then
		yum-config-manager --enable ol7_addons >/dev/null 2>&1
	fi
  
	printf "Installing Docker...\n"
  deps = (docker-ce docker-ce-cli containerd.io)
  # Install docker packages
	for item in ${deps[@]}; do
		if (rpm -qa | grep -q $item); then
			echo "$item already installed"
		else
			yum install $item -y -q >/dev/null 2>&1
			wait
			echo "$item Installed"
		fi
	done
}

start_docker(){
  # Start and enable docker
	systemctl start docker
	systemctl enable docker
	echo "Complete...Docker has been installed and started."

	return
}

configure_block() {
# Feeds the Docker daemon
	cat << EOF > /etc/docker/daemon.json
{
  "storage-driver": "devicemapper",
  "storage-opts": [
    "dm.directlvm_device=$index",
    "dm.thinp_percent=95",
    "dm.thinp_metapercent=1",
    "dm.thinp_autoextend_threshold=80",
    "dm.thinp_autoextend_percent=20",
    "dm.directlvm_device_force=false"
  ]
}
EOF
	systemctl restart docker
	echo "Block Device ${green}$index${reset} successfully configured for Docker use"

	return
}

add_docker_user() {
	generate_password=$(date | md5sum | head -c 20)
	dock_pass="${generate_password}"

	useradd docker -g docker
	echo -e "\n========================================"
	echo -n "Setting password for account..."
	echo "${dock_pass}" | passwd docker --stdin >/dev/null ; passwd -l docker >/dev/null
	echo 'Complete!'
	echo -e "\tThe temporary password for this account is: ${green}${dock_pass}"

	return
}

configure_firewall() {
  if [[ $(firewall-cmd --state) != "running" ]]; then
    echo -en "\e\x1b[36m\e[2mINFO: \e\x1b[31m\e[0m"; echo "The firewall is not currently running...starting"
    systemctl start firewalld; systemctl enable firewalld
    wget -qP /etc/firewalld/services/ https://raw.githubusercontent.com/jaredbrogan/Docker/dev/firewalld/docker.xml
    firewall-cmd --reload -q
    firewall-cmd --zone=public --add-service=docker --permanent -q
    firewall-cmd --reload -q
    echo "Firewall updated"
  else
    echo -en "\e\x1b[36m\e[2mINFO: \e\x1b[31m\e[0m"; echo "Firewall is already running, creating firewall service."
    wget -qP /etc/firewalld/services/ https://raw.githubusercontent.com/jaredbrogan/Docker/dev/firewalld/docker.xml
    firewall-cmd --reload -q
    firewall-cmd --zone=public --add-service=docker --permanent -q
    firewall-cmd --reload -q
    echo "Firewall updated"
  fi

return
}

swarm_setup () {
# If leader option is selected, a new swarm will be created if one does not exist, then tokens will be given
	docker swarm init >/dev/null 2>&1
	echo -e "\n==================================="
	docker swarm join-token manager
	echo "Copy the entire command above and paste into nodes that will be added as a manager"
	echo -e "\n==================================="
	docker swarm join-token worker
	echo "Copy the entire command above and paste into nodes that will be added as a worker"

	return
}


#==========================
# Main
root_check # Check so you don't install getopt when randomly running the script
getopt_check

# Read the options
# mandatory argument = :   ||  optional argument = ::
TEMP=`getopt -o dlh --long dev,leader,help -- "$@"`
if [[ $? != 0 ]];then # Verify that there are no rogue options
	usage
fi
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -d|--dev)
            dev=true ; shift ;;
        -l|--leader)
			leader_check # Block located right under getopt_check
			leader=true ; shift ;;
        -h|--help)
            usage ; break ;;
        --) shift ; break ;;
    esac
done
shift $((OPTIND -1))

docker_check

if [[ $init_install = true ]];then
	if [[ $dev != true ]];then
		disk_check
	fi
	docker_log
	foreward_enable
	dependency_check
	add_repo
	install_docker
	start_docker
	if [[ $dev != true ]];then
		configure_block
	fi
	add_docker_user
	configure_firewall
fi
if [[ $leader == true ]];then
	swarm_setup
fi

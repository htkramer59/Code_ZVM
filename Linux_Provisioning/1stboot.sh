#! /bin/bash
#
# first boot script
#
# function: run at first boot and adapt some files 
#           for the newly created server
#
function change_ssh_host_keys {
# Remove existing keys
echo "ssh-keygen -A"
# Generating new keys
echo "ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key"
echo "ssh-keygen -q -N "" -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key"
echo "ssh-keygen -q -N "" -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key"
echo "ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key"
}

function change_host {
echo "$prefix cp -p $hostfile $hostfile.`date -I`"
echo "$prefix echo $hostname > $hostfile"
echo
}

function change_hosts_file {
# Your input here, you coult take the input from the config disk (1C0)
}

function change_network { 
echo "$prefix cp -p $netwfile $netwfile.`date -I`"
echo "$prefix cat $netwfile | sed 's/ipaddress/$ipaddress/g' > $netwfile"
echo
}
#
#
# Some config items
#
configdasd='01C0'
mountpoint='/mnt'
hostfile='/etc/hostname'
netwfile='/etc/sysconfig/network/ifcfg-eth0.4029'
#
# Determine if we are running as root
#
amiroot=`who | grep -c root`	
if [ $amiroot == '1' ] ; then
	prefix=''
	else
	prefix='sudo'
	fi
#
# Stop the network service
#
# 	$prefix systemctl stop network
# 	$prefix systemctl disable network

#
# Check if the config mdisk is present in CP directory
#
noconfig=`$prefix vmcp query $configdasd 2>&1 | grep -c HCPQVD`
if [ $noconfig == '1' ] ; then
	echo "1C0 config disk not available"
	exit 128
	fi
#
# Check if the config mdisk is enabled and online
#
notenabled=`$prefix lszdev | grep -c $configdasd`
if [ $notenabled == '0' ] ; then
	#	$prefix cio_ignore --add $configdasd
	online=`$prefix chccwdev -e $configdasd 2>&1 | grep -c online` 
	fi
#
# If the device name of config mdisk  
#
if [ $online == '1' ] ; then
	name=`$prefix lsdasd | grep -i $configdasd | tr -s \  | cut -d\  -f3`
	else
	echo "Can not set $configdasd online"
	exit 228
	fi
#
# Get the server name
#
myid=`$prefix vmcp query userid | tr -s \  |cut -d\  -f1`
#
# Mount the config mdisk
#
$prefix cmsfs-fuse /dev/$name $mountpoint -a -o allow_other,nonempty,noauto_cache,sync_read,ro
#
# Check if the config disk contains the input file if so invoke it
#
inputpresent=`$prefix ls /mnt | grep -c $myid.1STBOOT 2>&1`
if [ $inputpresent == '1' ] ; then
	. $mountpoint/$myid.1STBOOT
	#
	# Change the ip-address of the server
	# Change the hostname of the server
	# Any other changes we need to make
	# Think of: /etc/hosts
	#           /etc/ssh/ssh.config
	#           /etc/ssh/*.key
	#           /etc/shadow
	#
	change_host
	change_network
	# change_hosts_file
	# change_ssh_host_keys
	echo
	else
	echo "No input file fount for $myid.1STBOOT"
	exit 328
	fi
#
# Unmount the config mdisk and disable it
#
$prefix fusermount -u $mountpoint
$prefix chccwdev -d $configdasd
# 	$prefix cio_ignore --remove $configdasd

#
# Start the network service
#
# 	$prefix systemctl enable network
# 	$prefix systemctl start network

#
# Remove myself from the start up 
#
# 	$prefix systemctl stop 1stboot
# 	$prefix systemctl disable 1stboot

#
# Remove myself (clean up)
#
# 	$prefix rm /etc/.../1stboot
#       $prefix rm /etc/systemd/system/1stboot.service


	



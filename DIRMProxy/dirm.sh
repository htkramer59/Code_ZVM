#! /bin/bash
function help {
	clear
	echo "Some of the most used commands:"
	echo "   dirm add <user> like <protouserid>"
	echo "   dirm for <user> amdisk....."   	
	echo "   dirm for <user> cmdisk....."   	
	echo "   dirm for <user> dmdisk....."   	
	echo "   dirm for <user> clonedisk....."   	
	echo "   dirm for <user> review"			
	echo 
	echo "See the zVM Directory Maintenance documentation for the available commands/queries"
	echo 
	echo "Notes:"
	echo "  Some commands maybe blocked on the zVM end in the proxy"
	echo "  The server needs to be authorized in the proxy"
	echo "  DIRMAINT Syntax is NOT CHECKED in this code"
	echo "  Short forms of the DIRMAINT commands are NOT SUPPORTED"
	echo 
	echo "To identify the proxy issue: declare -x DIRMPROXY=\"<your proxy server>\"" 
	echo "To set the maximum wait time: declare -x DIRMWAIT=\"<your wait time>\""
	exit
}
cmdline=$*
echo $cmdline
if [ $cmdline = '?' ] || [ -z $cmdline ] ; then
	help
fi

dirmproxy=$DIRMPROXY         # Identify the proxy user id
maxwait=$DIRMWAIT           # maximum wait time
if [ -z $dirmproxy ] ; then
	echo "No proxy server defined"
	exit
	fi
if [ -z $maxwait ] ; then
	echo "No max wait time defined, setting to default of 5"
	maxwait='5'
fi
# Check if there is a CMS reader available
rdr=`sudo lszdev c | tail -n 1 | tr -s \  | cut -d\  -f3`
if [ $rdr = 'no' ] ; then
	sudo chccwdev -e c
	fi
# Send the command to the proxy user id
reply=`sudo vmcp smsg $dirmproxy $cmdline`
errmsg=`echo $reply | cut -d\  -f1 | cut -b1-3`
if [ "$errmsg" = 'HCP' ] ; then
	echo "$reply"
	exit
fi
# Wait for the results
cntr='1'
while [ -z $fileno ] ; do
	fileno=`sudo vmcp QUERY RDR ALL | grep -i dirm | grep -i $1 | tail -n 1 | tr -s \  | cut -d\  -f2`
	if [ -z $fileno ]; then
		sleep 1s
		cntr=$((cntr+1))
		if [ "$cntr" -gt "$maxwait" ] ; then
			echo "No response within $maxwait seconds,"
			echo "Probable causes:"
			echo "  * syntax error on query"
			echo "  * this server is not authorised"
		 	echo "  * command not allowed"
			echo "  * time out too short"
			echo
			echo "Proxy id: $dirmproxy"	
			echo "Query: $cmdline"
			exit
		fi
	fi
	
done
# Receive the file from the proxy user
sudo vmur receive -t -f $fileno dirm_$1
# Show the content of the file
sudo less dirm_$1 
# Clean up
sudo rm dirm_$1




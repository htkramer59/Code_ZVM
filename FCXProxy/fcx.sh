#! /bin/bash
function help {
	clear
	echo "Some of the most used queries:"
	echo "   user     or    user \(sort %cpu"
	echo "   cpu"		
	echo "   sysload"
	echo 
	echo "See the zVM PerfKit documentation for the available commands/queries"
	echo 
	echo "Notes:"
	echo "  Some commands maybe blocked on the zVM end in the proxy"
	echo "  The server needs to be authorized in the proxy"
	echo "  Has been tested on SuSE, needs s390-tools installed"
	echo 
	echo "To identify the proxy issue: declare -x FCXPROXY=\"<your proxy server>\" or "	
	echo "                           : export FCXPROXY=<your proxy server>"
	echo "To set the maximum wait time: declare -x FCXWAIT=\"<your wait time>\" or "
	echo "                            : export FCXWAIT=<your wait time>"
	echo "Make sure these are incorporated in .profile_bash or .profile"
	exit
}
cmdline="$*"
if [ $1 = '?' ] || [ -z "$1" ] ; then
	help
fi
fcxproxy=$FCXPROXY         # Identify the proxy user id
maxwait=$FCXWAIT           # maximum wait time
if [ -z $fcxproxy ] ; then
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
reply=`sudo vmcp smsg $fcxproxy $*`
errmsg=`echo $reply | cut -d\  -f1 | cut -b1-3`
if [ "$errmsg" = 'HCP' ] ; then
	echo "$reply"
	exit
fi
# Wait for the results
cntr='1'
while [ -z $fileno ] ; do
	fileno=`sudo vmcp QUERY RDR ALL | grep -i fcx | grep -i $1 | tail -n 1 | tr -s \  | cut -d\  -f2`
	if [ -z $fileno ]; then
		sleep 1s
		cntr=$((cntr+1))
		if [ "$cntr" -gt "$maxwait" ] ; then
			echo "No response within $maxwait seconds, probably syntax error on query"
			echo "  or this server is not authorised"
			echo "Proxy id: $fcxproxy"	
			echo "Query: $*"
			exit
		fi
	fi
	
done
# Receive the file from the proxy user
sudo vmur receive -t -f $fileno fcx_$1
# Show the content of the file
sudo less fcx_$1 
# Clean up
sudo rm fcx_$1




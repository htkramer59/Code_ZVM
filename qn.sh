#! /bin/bash 
#
# Some settings
# 
search=`echo "$*" | tr [:lower:] [:upper:]`
fn=`basename $0`
workfile=`echo "$HOME/$fn"'_work.file'`
outfile=`echo "$HOME/$fn"'_out.file'`
srchfile=`echo "$HOME/$fn"'_srch.file'`
#
# Get the info from CP	
#
zvmnode=`sudo vmcp query userid | tr -s \  | cut -d\  -f3`
for name in `sudo vmcp query names | tr -s \  | tr -d [\ ] | tr , \  |grep -ve ^VSM-` ; do
	echo $name >> $workfile
done
#
# If there are search arguments filter them
#
if [ -n "$search" ] ; then
	mv $workfile $srchfile
	for s in $search ; do
		wc=`echo $s | grep -c \*`
		if [ $wc = 0 ] ; then
			grepval=$s
		else
			grepval='^'`echo "$s" | cut -d\* -f1`
		fi
		grep -e $grepval $srchfile >> $workfile
	
	done
	else 
	search=ALL
fi
linesinfile=`cat $workfile | wc -l`
#
# Compose a list of the 1st characters
#
present=''
for alfa in `cat $workfile | sort | cut -b1-1 | uniq` ; do
	present=`echo "$present $alfa"`
done
last=`echo "$present" | rev | cut -b1-1` 
#
# Add a count
#
for alfa in $present ; do
	cnt=`cat $workfile | sort | cut -b1-1 |grep -c $alfa`
	cnt='________'$cnt
	cnt=`echo $cnt | rev | cut -b1-8 | rev`'______'
	echo "* $alfa$cnt" >> $outfile
	for list in `cat $workfile | sort | grep ^$alfa` ; do
		id=`echo $list | cut -d- -f1 | rev`
		id='________'$id
		id=`echo $id | rev | cut -b1-8`
		stat=`echo $list | cut -d- -f2`
		stat='_____'$stat
		stat=`echo $stat | rev | cut -b1-5 | rev`
		echo " $id - $stat" >> $outfile
	done
	if [ $alfa != $last ]; then
		echo '                 ' >> $outfile 
	fi
done
#
# Imitate the CMS pipeline snake stage
#
clear
now=`date  --rfc-3339=seconds|cut -d\+ -f1`
echo "$now $fn issued from $HOSTNAME at $zvmnode"
echo
snake $outfile 5
echo
echo "Results for $search $linesinfile"
#
# Clean up
#
if [ -e $workfile ] ; then	
	rm $workfile
fi
if [ -e $outfile ] ; then	
	rm $outfile
fi
if [ -e $srchfile ] ; then
	rm $srchfile
fi

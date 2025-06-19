#! /bin/bash 
#
# Assign some variables
#
infile=$1
cols=$2 
#
# Set a defaults
#
if [ -z $cols ]; then	
 	cols=4
fi
#
# Check some things
#
check=0
linesinfile=`cat $infile | wc -l`
linesprcol=$((linesinfile/cols))
check=$((linesinfile-(cols*linesprcol)))
#
# Add 1 if it does not fit in the lines
#
if [ $check != 0 ] ; then
	linesprcol=$((linesprcol+1))
fi
#
# Read the input file
#
i=1
while IFS= read -r line ; do
	line[$i]=`echo "$line"`
	i=$((i+1))
done < "$infile"
#
# Rework the output
#
for o in `seq 1 $linesprcol` ; do
	out=''
	n=$o
	for i in `seq 1 $cols` ; do
		out=`echo "$out ${line[$n]}"`
		n=$((n+linesprcol))
	done
	echo "$out"
done


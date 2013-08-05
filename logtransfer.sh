#!/bin/sh

#Initialization
##Config file
conf=logtransfer.conf
s3bucket=oglogs
s3mount=/tmp/amazons3

#loading up parameters from config file
source ./$conf
#s=$(<$conf)
#set -- $s
#backuptype=$1
#hostname=$2
#retention=$3

#making sure bucket is mounted
if grep -qs '/tmp/amazons3' /proc/mounts; then
	echo "It's mounted"
elif [ -d "$s3mount" ]; then
	echo "Existing folder $s3mount"
	echo "Mount not found!". 
	echo "Mounting......"
	s3fs $s3bucket $s3mount || eval 'echo "Unable to mount S3 Bucket. Failed command s3fs $s3bucket $s3mount" 1>&2; exit 1'
elif [ ! -d "$s3mount" ]; then
	echo "Non existing folder $s3mount"
	echo "Creating folder"
	mkdir $s3mount ||  eval 'echo "Unable to create folder $3mount. Failed command mkdir $s3mount" 1>&2; exit 1'
	echo "Mount not found!"
	echo "Mounting......"
	s3fs $s3bucket $s3mount || eval 'echo "Unable to mount S3 Bucket. Failed command s3fs $s3bucket $s3mount" 1>&2; exit 1'
fi
echo $backuptype

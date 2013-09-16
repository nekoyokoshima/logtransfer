#!/bin/sh

#Initialization
conf=logtransfer.conf #Config file
s3bucket=oglogs #Amazon S3 bucket name
s3mount=/tmp/amazons3 #Mount point for Amazon bucket

#Loading up parameters from config file
source ./$conf

#Making sure bucket is mounted
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

#Backup Types
#1) Web Server Nginx Logs
#2) Web Server Website Logs
#3) ABP Server Logs
#4) ABP Server Tomcat Logs
#5) MySQL Backups
#6) Custom folder. Path set in custom_foler in $conf


#Function to do the actual transfer depending on the backuptype
transfer() {
if [ -z $1 ]
	#Errs on no parameters passed
	then
	echo "No Parameters passed to function"
	return 0
fi
if [ $1 = 1 ] #Web Server Nginx Logs
	then
	echo "Backuptype = 1"
	mkdir -p $s3mount/$hostname ##Create root folder if it does not exist
	rsync -azv --human-readable --progress  --bwlimit=$bwlimit --include '*.gz' --exclude '*' /var/log/nginx/ /tmp/amazons3/$hostname/nginx
fi
if [ $1 = 2 ] #Web Server Website Logs
	then
	echo "Backuptype = 2"
	mkdir -p $s3mount/$hostname/betrails ##Create Betrails folder if it does not exist
	for d in "/var/www/"*
		do
			echo $d;
			echo "$d";
			echo $(basename "$d");
			rsync -azv --human-readable --progress  --bwlimit=$bwlimit --include '*.gz' --exclude '*' $d/log/old/ /tmp/amazons3/$hostname/betrails/$(basename "$d")
		done
	#get number of folders in array
	#for $i in array rsync <options> /var/www/array[@] /tmp/amazons3/$hostname/betrails/array[@]
fi
if [ $1 = 3 ] #ABP Server Logs
	then
	echo "Backuptype = 3"
fi
if [ $1 = 4 ] #ABP Server Tomcat Logs
	then
	echo "Backuptype = 4"
fi
if [ $1 = 5 ] #MySQL Backups
	then
	echo "Backuptype = 5"
fi
if [ $1 = 6 ] #Custom folder. Path set in custom_foler in $conf
	then
	echo "Backuptype = 6"
	#list
	find . -maxdepth 1 -type f
	#backup
	for item in $list
	do
	s3cmd
	done
	#deletion
fi
}

#Determine backup types needed.
mdkir -p $s3mount/$hostname ##Create root folder if it does not exist

echo $backuptype
IFS=' ' b_split=($backuptype)
for i in ${b_split[@]}
	do 
	transfer $i #calling transfer function accordingly
	done

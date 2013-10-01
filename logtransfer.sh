#!/bin/sh

#Initialization
conf=logtransfer.conf #Config file
s3bucket=oglogs #Amazon S3 bucket name
s3cmd_opts="--multipart-chunk-size-mb=1024"
#Loading up parameters from config file
source ./$conf

#Making sure s3cmd is installed and appropriate version
for cmd in s3cmd; do
   [[ $("$cmd" --version) =~ ([0-9][.][0-9.]*) ]] && version="${BASH_REMATCH[1]}"
   if ! awk -v ver="$version" 'BEGIN { if (ver < 1.5) exit 1; }'; then
      echo "ERROR: %s version 1.5 or higher required\n" "$cmd"
      echo "Download it from http://s3tools.org/s3cmd"
   fi
done

#Backup Types
#1) Web Server Nginx Logs
#2) Web Application Logs
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
	IFS=' ' b_split=($nginx_path)
	for nginx in ${b_split[@]}
		do
			s3cmd sync -v $s3cmd_opts $nginx s3://$s3bucket/$hostname/WebServerLogs/
		done
	#deletion
fi

if [ $1 = 2 ] #Web Application Logs
	then
	echo "Backuptype = 2"
	for wwwdir in "/var/www/*"
		do
			echo $wwwdir;
			s3cmd sync -v $s3cmd_opts $wwwdir/log/old s3://$s3bucket/$hostname/WebAppLogs/
		done
	#deleteion
fi

if [ $1 = 3 ] #ABP Server Logs
	then
	echo "Backuptype = 3"
	IFS=' ' b_split=($abp_path)
	for abp in ${b_split[@]}
		do
			s3cmd sync -v $s3cmd_opts $abp s3://$s3bucket/$hostname/ABPServerLogs/
		done
fi

if [ $1 = 4 ] #ABP Server Tomcat Logs
	then
	echo "Backuptype = 4"
fi

if [ $1 = 5 ] #MySQL Backups
	then
	echo "Backuptype = 5"
	for mysqllist in `find $mysql_path -maxdepth 1 -type f`
		do
			s3cmd $s3cmd_opts sync $mysql_path s3://oglogs/mysql/2013/$kukki/
		done
	#deletion
fi

if [ $1 = 6 ] #Custom folder. Path set in custom_foler in $conf
	then
	echo "Backuptype = 6"
fi
}

#Determine backup types needed.
#mdkir -p $s3mount/$hostname ##Create root folder if it does not exist

echo $backuptype
IFS=' ' b_split=($backuptype)
for i in ${b_split[@]}
	do
	transfer $i #calling transfer function accordingly
	done
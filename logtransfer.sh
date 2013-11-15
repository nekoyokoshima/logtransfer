#!/bin/sh
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"
cd /root/bin/logtransfer

#Initialization
conf=logtransfer.conf #Config file
source ./$conf

#Function to check if required rpm are installed
rpmcheck() {
echo -n "Checking for $1........"
if rpm -qa | grep -Eq "^$1"; then
        echo -e "${green}[OK]$NC"
else
        echo -e "${red}[failed]$NC"
echo -n "Installing $1.........."
        yum install -y $1 &>/dev/null
        retval=$?
                if [[ "$retval" == "0" ]]; then
                        echo -e "${green}[OK]$NC"
                else
                        echo -e "${red}[failed]$NC"
                        exit 1
                fi
fi
}

proccheck(){
echo -n "Checking if $1 is running........"
ps cax | grep $1 > /dev/null

  if [ $? -eq 0 ]; then
    echo -e "${green}[OK]$NC"
  else
    echo -e "${red}[Staring]$NC"s
    service $1 start
    chkconfig $1 on
  fi
}

#Colors
red='\e[0;31m'
yellow='\e[1;33m'
green='\e[1;32m'
blue='\e[1;34m'
NC='\e[0m' # No Color
##------PRE-REQUISITE CHECKING-------##
#Making sure s3cmd is installed and appropriate version
for cmd in s3cmd; do
	[[ $("$cmd" --version 2>/dev/null) =~ ([0-9][.][0-9.]*) ]] && version="${BASH_REMATCH[1]}"
	if ! awk -v ver="$version" 'BEGIN { if (ver < 1.5) exit 1; }'; then
		echo -e "ERROR: $cmd version 1.5 or higher required\n"
#Attempting install of appropiate version     
		read -p "Would you like to download and install s3cmd? (y/[n])" -n 1 -r
		echo ""
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			wget http://goo.gl/vvJKT7 -O /tmp/s3cmd-1.5.0-alpha3.tar.gz  #http://goo.gl/fP6q3j <-- This is 1.5.0-alpha1
			tar -xvf /tmp/s3cmd-1.5.0-alpha3.tar.gz --strip-components=1 -C /usr/sbin/ s3cmd-master/s3cmd
			tar -zxvf /tmp/s3cmd-1.5.0-alpha3.tar.gz --strip-components=1 -C /usr/sbin/ s3cmd-master/S3
			cp ~/bin/logtransfer/s3cfg ~/.s3cfg
			rm -f /tmp/s3cmd-1.5.0-alpha3.tar.gz
		fi
	fi

#Check for required RPMs (rpmcheck {package name})
rpmcheck at
proccheck at 
rpmcheck python-magic


#Auto-update Script if needed
if [ "$auto_update" = "1" ]
then
        local_commit=`git log -n 1 --pretty=format:"%H"`
        git fetch
        repo_commit=`git log origin/master | head -1 | awk {'print $2'}`
        if [ "$local_commit" != "$repo_commit" ]
        then
                        echo -e "${red}Script is scheduled for update$NC"
                        git pull || { echo >&2 "failed with $?"; exit 1; }
                        echo "/root/bin/logtransfer/logtransfer.sh >/dev/null" | at now + 1 minute
                        echo 'Exiting!'
                        exit
        else
                        echo 'Script is already up-to-date'
        fi
fi

#Check if s3cmd installed properly
s3cmd ls &>/dev/null
retval=$?
	if [[ "$retval" == "0" ]]
		then echo -e "s3cmd tested working ok\n"
		else 
		echo -e "Something went wrong\n"
		echo "Relevant Info:"
		echo -e "${red}which s3cmd output"
		echo -e "------------------$NC"
		which s3cmd
		echo -e "${red}s3cmd ls output"
		echo -e "---------------$NC"
		s3cmd ls
		exit 1
	fi	
done
##----END PRE-REQUISITE CHECKING----##

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
			s3cmd sync $s3cmd_opts $nginx/old/ s3://$s3bucket/$hostname/WebServerLogs/
		done
fi

if [ $1 = 2 ] #Web Application Logs
	then
	echo "Backuptype = 2"
	for wwwdir in /var/www/*
		do
			echo -e "${red}$wwwdir$NC"
			folder=${wwwdir#*www/}
			s3cmd sync $s3cmd_opts $wwwdir/log/old/ s3://$s3bucket/$hostname/WebAppLogs/$folder/
		done
fi

if [ $1 = 3 ] #ABP Server Logs
        then
        echo "Backuptype = 3"
        IFS=' ' b_split=($abp_path)
        if [ ${#b_split[*]} -gt 1 ]
                then
                        for abp in ${b_split[@]}
                                do
                                        echo -e "${red}$abp$NC"
                                        folder=${abp#*home/}
                                        folder=${folder%/platform*}
                                        s3cmd sync $s3cmd_opts $abp s3://$s3bucket/$hostname/ABPServerLogs/$folder/
                                done
                else
                        echo -e "${red}$abp_path$NC"
                        s3cmd sync $s3cmd_opts $abp_path s3://$s3bucket/$hostname/ABPServerLogs/
        fi

fi

if [ $1 = 4 ] #ABP Server Tomcat Logs
	then
	echo "Backuptype = 4"
	IFS=' ' b_split=($tomcat_path)
	for tomcat in ${b_split[@]}
		do
			s3cmd sync $s3cmd_opts $tomcat s3://$s3bucket/$hostname/ABPTomcatLogs/
		done	
fi

if [ $1 = 5 ] #MySQL Backups
	then
	echo "Backuptype = 5"
	for mysqllist in `find $mysql_path -maxdepth 1 -type f`
		do
			echo $mysqllist #s3cmd sync $s3cmd_opts $mysql_path s3://oglogs/mysql/2013/$mysqllist/
		done
fi

if [ $1 = 6 ] #Custom folder. Path set in custom_foler in $conf
	then
	echo "Backuptype = 6"
fi
}

#Determine backup types needed.

echo $backuptype
IFS=' ' b_split=($backuptype)
for i in ${b_split[@]}
	do
	transfer $i #calling transfer function accordingly
	done
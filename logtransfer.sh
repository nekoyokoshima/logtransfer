#!/bin/sh
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"
cd /root/bin/logtransfer

#Initialization
conf=logtransfer.conf #Config file
source ./$conf
source ./functions.conf

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
			wget https://www.dropbox.com/s/yakw8nqxs553ng5/s3cfg -O ~/.s3cfg
			cp ~/bin/logtransfer/s3cfg ~/.s3cfg
			rm -f /tmp/s3cmd-1.5.0-alpha3.tar.gz
		fi
	fi

#Check for new .s3cfg configs
s3cfgcheck

#Check for required RPMs (rpmcheck {package name})
rpmcheck at
proccheck atd 
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

#Determining backup types needed.
echo $backuptype
IFS=' ' b_split=($backuptype)
for i in ${b_split[@]}
	do
	transfer $i #calling transfer function accordingly
	done

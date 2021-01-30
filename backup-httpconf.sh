#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script:Take backup of httpd conf files. Create /etc/httpd/backups directory if not present
#
# Author:       Denny Vettom
#Ver   : 1.0   #Backs up and deltes zip files and tar files older than 14 days.
#Ver   : 1.1   #Dispatcher 2 ackup added. 
#Ver   : 1.2   updated to handle existign as well as dispatcher 2 
#Ver   : 1.3   changed to create zip file that can be extracted in /etc/httpd or my script
# ----------------------------------------------------------------------------

HOSTNAME=`hostname`
DATE=`date +%Y%m%d`
TIMESTAMP=`date +%H%M.%Y%m%d`
N_ARG=$#
SCR_HOME=`dirname $0`
SCR_NAME=`basename $0`
ERROR_FLAG=0
[[ $SCR_HOME = . ]] && SCR_HOME=`pwd`

LOG=SCR_NAME.$DATE.log
PATH=$PATH:/bin:/sbin:/usr/bin:/user/local/bin
# ----------------------------------------------------------------------------
# Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
# ----------------------------------------------------------------------------

function CHECK_FAILURE
{
        if [ $1 -ne 0 ]
        then
                echo -e "\e[0;41m ERROR : $2  \e[0m "  | tee -ai ${LOG}
                ERROR_FLAG=1
                FINISH
        fi
}


USER=root

#Ensure script is run as root user
 CURRENT_USER_ID=`id | awk -F\( '{ print $2 }' | awk -F\) '{ print $1 }'`
 if [ $CURRENT_USER_ID != $USER ]
 then
        echo -e "  \e[1;32m INFO : Please execute command as $USER \e[0m "
        exit
 fi





# Take action only if Dispatcher
if [ -d /etc/httpd ]
then
	#Create backup directory if it does not already exist
	[[ ! -d /etc/httpd/backups ]] && mkdir -p /etc/httpd/backups 

    cd /etc/httpd
    zip /etc/httpd/backups/`hostname`.dispatcherconf.${TIMESTAMP}.zip -q -r conf*
    CHECK_FAILURE $? " ERROR : Failed to create backup, please perform manually"

   
	echo""
	echo echo " INFO : Backup of Dispatcher files completed. Conf and conf.d files saved in tar file below"
	ls -l /etc/httpd/backups/`hostname`.dispatcherconf.${TIMESTAMP}.zip

else
	echo -e " \e[0;41m  ERROR : Could not find /etc/httpd directory.  Is this Dispatcher instance?"
	exit 1
fi

#Remove Older backup files
	find /etc/httpd/backups/ -mtime +14 -name "`hostname`.dispatcherconf.*.tar" -exec rm {} \;
	find /etc/httpd/backups/ -mtime +14 -name "*.zip" -exec rm {} \;

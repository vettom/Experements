#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script: Copy log files to a temp dir in logs.
# 
# Author:       Denny Vettom
#
# Usage:
# ----------------------------------------------------------------------------
PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/bin:/opt/csw/bin:/usr/ccs/bin
HOSTNAME=`hostname`
DATE=`date +%Y%m%d`
TIMESTAMP=`date +%H%M.%Y%m%d`
N_ARG=$#
SCR_HOME=`dirname $0`
SCR_NAME=`basename $0`
USER=crx


# ----------------------------------------------------------------------------
# Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
# ----------------------------------------------------------------------------

function CHECK_FAILURE
{
        if [ $1 -ne 0 ]
        then
                echo -e  " \e[0;41m ERROR:  $2 \e[0m" | tee -ai ${LOG}
                exit
        fi
}


#Check whether Publish or Author to ser directory
if [ -d /mnt/crx/publish ]
then
	LOG=/mnt/crx/publish/crx-quickstart/logs
	LOGDIR=/mnt/crx/publish/crx-quickstart/logs/$DATE
elif [ -d /mnt/crx/author ]
then
	LOG=/mnt/crx/author/crx-quickstart/logs
	LOGDIR=/mnt/crx/author/crx-quickstart/logs/$DATE
else
	echo -e " \e[0;41m ERROR: Author/Publish directory not found, is this AMS AEM instance? \e[0m "
        exit
fi

#Create directory if it does not already exist
 if [ ! -d $LOGDIR ] 
 then
 	sudo -u $USER mkdir $LOGDIR
 	CHECK_FAILURE $? "Failed to create $LOGDIR as $USER Please check Path and permission and sudo access to $USER" 
 fi

# Copy all logs to new logs directory

for i in `find $LOG/ -maxdepth 1 -name "*.log" -mtime 0 `
do
	sudo -u $USER  cp $i $LOGDIR
done
sudo chown -R crx:crx $LOGDIR

echo -e "  \e[1;32m Logs stored in $LOGDIR \e[0m " 
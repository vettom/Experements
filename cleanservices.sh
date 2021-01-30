#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script: Restart all monitoring services to release load
#
# Author:       Denny Vettom
#Ver   : 1.0   #Backs up and deltes zip files and tar files older than 14 days. Exec
# ----------------------------------------------------------------------------

HOSTNAME=`hostname`
DATE=`date +%Y%m%d`
TIMESTAMP=`date +%H%M.%Y%m%d`
N_ARG=$#
SCR_HOME=`dirname $0`
SCR_NAME=`basename $0`
ERROR_FLAG=0
[[ $SCR_HOME = . ]] && SCR_HOME=`pwd`
USER_ID="root"      #Set if script has to run as particular user
LOG=SCR_NAME.$DATE.log
PATH=$PATH:/bin:/sbin:/usr/bin:/user/local/bin
# ----------------------------------------------------------------------------
# Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
# ----------------------------------------------------------------------------

function CHECK_FAILURE
{
        if [ $1 -ne 0 ]
        then
                echo -e "\e[0;41m ERROR : $2  \e[0m " | tee -ai ${LOG}
                ERROR_FLAG=1
                FINISH
        fi
}
echo "Reloading systemctl"
sudo systemctl daemon-reload
echo "Restarting Splunk"
sudo service splunk restart
echo "Restarting Hubble"
sudo service hubble restart
echo "Restarting Newrelic Infra"
sudo service  newrelic-infra restart
echo "Restarting Salt"
sudo service salt-minion restart
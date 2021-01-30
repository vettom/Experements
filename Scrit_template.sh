#!/usr/local/bin/bash
#!/bin/bash
# ----------------------------------------------------------------------------
# Purpose : Standard set of variables
# Author:       Denny Vettom
# Dependencies: 
#
# ----------------------------------------------------------------------------
# Name          Date            Comment                         Version
# ----------------------------------------------------------------------------
# DV            31/01/2021     Initial Version with color        V 1.0
#  

PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/bin:/opt/csw/bin:/usr/ccs/bin
HOSTNAME=`hostname`
DATE=`date +%Y%m%d`
TIMESTAMP=`date +%H%M.%Y%m%d`
N_ARG=$#
SCR_HOME=`dirname $0`
SCR_NAME=`basename $0`
ERROR_FLAG=0
[[ $SCR_HOME = . ]] && SCR_HOME=`pwd`

## Define/modify following variable as required.

USER_ID=""      #Set if script has to run as particular user
LOG=/dev/null           #User for summary log, contents of this file will me mailed.

# ---------------------------------------------------------------------------- 
# If USER_ID is set verify the the script is running as specified user
# ----------------------------------------------------------------------------
if [ ! -z $USER_ID ]
then
        CURRENT_USER_ID=`id | awk -F\( '{ print $2 }' | awk -F\) '{ print $1 }'`
        if [ ${CURRENT_USER_ID} != ${USER_ID} ];then
                echo -e  " \e[0;41m  ERROR! this script must be executed as user [${USER_ID}]. Your current ID is [${CURRENT_USER_ID}]. \e[0m  "  
                ERROR_FLAG=1
                FINISH
                exit
        fi
fi

# ----------------------------------------------------------------------------
# function  LOGTIDY to clear old logs/files while keeping specified number copy. Accepts 2 arguments FILE-NAME and Number
# of backups required.
# ----------------------------------------------------------------------------
function LOGTIDY
{
# Two arguments are expected and if not function will fail
#ARG1= Log file name
#ARG2= Number of files to retain
ARG=$#
        if [ $ARG -lt 2 ]
                then
                echo -e "\e[1;32m Two arguments are expected log file name and number of backups required. \e[0m " 
                echo -e "\e[1;32m LOGTIDY domain.log 5 \e[0m " 
        fi

LOGFILE=$1
VER=$2
        while [ $VER -gt 1 ]
        do
                PREV_VER=`expr $VER - 1 `
                test -f "$LOGFILE.$PREV_VER" && mv "$LOGFILE.$PREV_VER"  "$LOGFILE.$VER"
                VER=`expr $VER - 1 `
        done

        test -f $LOGFILE && mv $LOGFILE $LOGFILE.1
}

# ----------------------------------------------------------------------------
# Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
# ----------------------------------------------------------------------------

function CHECK_FAILURE
{
        if [ $1 -ne 0 ]
        then
                R1  " ERROR : $2 " | tee -ai ${LOG}
                ERROR_FLAG=1
                exit 1
        fi
}

function R { echo -e "\e[31m $1 \e[0m " }
function G { 
                echo -e "\e[0;32m $1 \e[0m "  
            }
            
function P { 
                echo -e "\e[35m $1 \e[0m "  
            }
            
function R1 { 
                echo -e "\e[41m $1 \e[0m "  
            }
function G1 { 
                echo -e "\e[0;42m $1 \e[0m "  
            }
            
function P1 { 
                echo -e "\e[45m $1 \e[0m "  
            }


# -------------------------------------------------------------------
#       END of STANDARD FUNCTIONS and declaration.
# -------------------------------------------------------------------


    #!/bin/bash
    # ----------------------------------------------------------------------------
    #
    # Script: Script to take thread dump of AEM Java. No argument required
    # By default it takes 10 dumps with 5 sec interval. Can over ride by passing count and interval
    # Script must run as root
    # Author:       Denny Vettom
    #
    # Usage: Run without any arguments.
    # ----------------------------------------------------------------------------
    PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/bin:/opt/csw/bin:/usr/ccs/bin
    HOSTNAME=`hostname`
    DATE=`date +%Y%m%d`
    TIMESTAMP=`date +%H%M.%Y%m%d`
    N_ARG=$#
    SCR_HOME=`dirname $0`
    SCR_NAME=`basename $0`
    USER=crx

     #Ensure script is run as root user
     CURRENT_USER_ID=`id | awk -F\( '{ print $2 }' | awk -F\) '{ print $1 }'`
     if [ $CURRENT_USER_ID != root ]
     then
        echo -e "  \e[1;32m INFO : Please execute command as Root \e[0m "
        exit
     fi 


     #Check whether Publish or Author to ser directory
    if [ -d /mnt/crx/publish ]
    then
        LOGDIR=/mnt/crx/publish/crx-quickstart/logs/$DATE
    elif [ -d /mnt/crx/author ]
    then
        LOGDIR=/mnt/crx/author/crx-quickstart/logs/$DATE
    else
        echo -e " \e[0;41m ERROR: Author/Publish directory not found, is this AMS AEM instance? \e[0m "
        exit
    fi

    if [ $# -eq 0 ]; then
        echo ""
        echo >&2 "Usage: $SCR_NAME [ <count> [ <delay> ] ]"
        echo >&2 "    Defaults: count = 10, delay = 5 (seconds)"
        echo >&2 "    Default user is crx and Java process detected by script."
        echo ""
        echo ""
        echo "INFO: Sleep 5 sec before running with defaults"
        sleep 5
        echo " Running $SCR_NAME 10 5"
    fi

    count=${1:-10}  # defaults to 10 times
    delay=${2:-5} # defaults to 5 seconds


    # ----------------------------------------------------------------------------
    # Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
    # ----------------------------------------------------------------------------

    function CHECK_FAILURE
    {
            if [ $1 -ne 0 ]
            then
                    echo -e "\e[0;41m ERROR : $2  \e[0m " 
                    exit
            fi
    }




    #ensure single Java process run by CRX
    PIDCOUNT=`pgrep -a -u crx  | grep -E 'cq-publish-4503.jar|cq-author-4502.jar' | grep -v grep | awk '{ print $1}' | wc -l`
    if [ $PIDCOUNT -ne 1 ]
    then
        echo "\e[0;41m  Java process not found or more than 1 Java process found \e[0m "
        pgrep -a -u crx  | grep -E 'cq-publish-4503.jar|cq-author-4502.jar'
        exit
    else
       PID=`pgrep -a -u crx  | grep -E 'cq-publish-4503.jar|cq-author-4502.jar' | grep -v grep | awk '{ print $1}'`
    fi


    #Create directory if it does not already exist
     if [ ! -d $LOGDIR ]
     then
        sudo -u $USER mkdir $LOGDIR
        CHECK_FAILURE $? " Failed to create $LOGDIR Please check Path and permission"
     fi

    #Ready to take thread dump
    echo -e "  \e[1;32m Taking thread dump of PID=$PID \e[0m"


    #Execute Jstact series
    JSTACK_PATH=`which jstack`

    while [ $count -gt 0 ]
    do
        sudo -u $USER $JSTACK_PATH $PID >$LOGDIR/jstack.$PID.$(date +%s.%N)
        top -H -b -n1 -p $PID >$LOGDIR/top.$PID.$(date +%s.%N)
        sleep $delay
        let count--
        echo -n "."
    done

    echo ""
    echo -e "  \e[1;32m Thread dump stored in $LOGDIR \e[0m"
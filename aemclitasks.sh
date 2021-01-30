#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script: Single script to list AEM patches, List packages, upload, install Package
#  Improve to handle failure and retry
# Author:   	Denny Vettom 
#
# Usage:
#
# Dependencies: None, just connectivity to Servers
#
# Additions:
#
# ----------------------------------------------------------------------------
# History:
# ----------------------------------------------------------------------------
# Name      	Date        	Comment                     	Version
# ----------------------------------------------------------------------------
# DV        	1/09/17    	Initial creation.                   V 1.0
# DV           25/01/17     Fixed logging, and retry            V 1.1
# DV           30/07/18     Adjusted SP listingg, and patch     V 1.2
# DV           20/09/20     added mem,jetty and oldgen.         V 1.2
# ----------------------------------------------------------------------------

PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/bin:/opt/csw/bin:/usr/ccs/bin
HOSTNAME=`hostname`
DATE=`date +%Y%m%d`
TIMESTAMP=`date +%H%M.%Y%m%d`
N_ARG=$#
SCR_HOME=`dirname $0`
SCR_NAME=`basename $0`
ERROR_FLAG=0
[[ $SCR_HOME = . ]] && SCR_HOME=`pwd`
PROTOCOL=https

#Set LOG Variables for Package Install
[[ -d $SCR_HOME/logs ]] && LOG=$SCR_HOME/logs/install-summary.log || LOG=$SCR_HOME/install-summary.log   #Summary echo to here
[[ -d $SCR_HOME/logs ]] && INSTLOG=$SCR_HOME/logs/pkginstall.log || INSTLOG=$SCR_HOME/pkginstall.log   #Output of Curl  and other logs

# ----------------------------------------------------------------------------
# Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
# ----------------------------------------------------------------------------

function CHECK_FAILURE
{
    	if [ $1 -ne 0 ]
    	then
            	echo -e "\e[0;41m ERROR : $2  \e[0m "  
            	
            	exit 1
    	fi
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
#   	END of STANDARD FUNCTIONS and declaration.
# -------------------------------------------------------------------

function LOGTIDY
{
    #ARG1= Log file name
    #ARG2= Number of files to retain
    ARG=$# ; [[ $ARG -lt 2 ]] && echo "Not enough argument to cycle Logs" | tee -ai $INSTLOG
    
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

function RESET
{ #Reset all variables for clean env
    unset ACTION URL AEM_TYPE PORT PASS PROTOCOL

}

function USAGE 
{
    echo ""

    echo " Script Usage ...."
    echo
        echo "   install           # Upload packages and install to one or more servers"
        echo "   patch             # List AEM version and Patches on local server"
        echo "   pkg               # List all packages on local server "
        echo "   upload            # Upload package/s to remote AEM server/s"
        echo "   download          # Download package from remote AEM server"
        echo "   Check             # Check status of CRX and Groovy bundles"
        echo "   crxstart          # Start CRX Bundles"
        echo "   crxstop           # Stop CRX bundles"
        echo "   groovystart       # Start Groovy bundles"
        echo "   groovystop        # Stop Groovy bundles"
        echo "   mem               # Show JVM Memory"
        echo "   oldgen            # Show oldgen usage"
        echo "   jetty             # Show jetty threads"
        echo "   thread            # Generate Thread dumps"
        echo "   heap              # Generate Heapdump"
        echo "   gc                # Trigger GC collection"
 
        echo""
        

}


function GETPASS
{ #Function to get CQ admin password
    if [ -z $AEM_TYPE ]
    then
        echo -n "Please Enter Password:"
            stty -echo
            read PASS
            stty echo
    else
        PASS=`sudo sudo -u nagios pass CQ_Admin` 
        if [ $? -ne 0 ]
        then
            echo -n "Please Enter Password:"
            stty -echo
            read PASS
            stty echo
        fi
    fi
}

#Verify Author or Publish if neither accept input
if [ -d /mnt/crx/author ]
then
    AEM_TYPE=author
    PORT=4502
    AEM_TYPE=author
    URL=localhost
    PROTOCOL=http
    GETPASS
elif [ -d /mnt/crx/publish ]
then
    AEM_TYPE=publish
    PORT=4503
    AEM_TYPE=publish
    URL=localhost
    PROTOCOL=http
    GETPASS
    
fi

function Validate-AMS-AEM 
{
    if [ ! -f /etc/sysconfig/cq5 ]
    then
        echo " ERROR : This option works on AMS AEM instance only "
        exit 2 
    fi
    sudo ls /usr/local/nagios/libexec/ > /dev/null 2>&1
    if [ $? -ne 0 ]
    then 
        echo " Error sudo ls to Nagios folder failed. Please check " 
        exit 2
    fi

}

function UPLOADPACKAGES
{ #Accept pakage and URL as argument and upload only not install.
        echo ""
        echo -n "Server IP's separated by space eg: IP-1 IP-2 (default localhost) :"
        read SERVERS
        [[ -z $SERVERS ]] && SERVERS=localhost
        
        echo -n "Server PORT? (default 4503)  :"
        read PORT
        [[ -z $PORT ]] && PORT=4503
        [ $PORT -eq 4502 ] || [ $PORT -eq 4503 ] && PROTOCOL=http  || PROTOCOL=https
        echo -n "Package/s separated by space (eg: pkg1 pkg2) :"
        read PACKAGES        
        [[ -z $PACKAGES ]] && echo "At least one package name must be specified" && exit 2
        GETPASS


        #Start Loop to install packages, Packages then Servers.
        for PKG in $PACKAGES
        do
            for URL in $SERVERS
            do
                echo ""
                echo "  UPLOADING $PKG to $URL" 
                curl -k -u admin:$PASS -F file=@"$PKG"   -F force=true -F install=false $PROTOCOL://$URL:$PORT/crx/packmgr/service.jsp
        	done
        done       	
}



function INSTALLPACKAGES
{  #Accept Package and URL as argument and install all packages on all servers specified
        echo ""
        echo -n "Server IP's separated by space eg: IP-1 IP-2 (default localhost) :"
        read SERVERS
        [[ -z $SERVERS ]] && SERVERS=localhost
        
        echo -n "Server PORT? (default 4503)  :"
        read PORT
        [[ -z $PORT ]] && PORT=4503
        [ $PORT -eq 4502 ] || [ $PORT -eq 4503 ] && PROTOCOL=http  || PROTOCOL=https
        echo -n "Package/s separated by space (eg: pkg1 pkg2) :"
        read PACKAGES        
        [[ -z $PACKAGES ]] && echo "At least one package name must be specified" && exit 2
        GETPASS
    

        #Sleep 5 sec before install start
        echo ""
        echo "  Waiting 10 sec before starting installation, press Ctrl+C to abort"
        echo "  Package installation details are saved $INSTLOG."
	
        sleep 10
        #Rotate logs maintaining 5 recent versions
        LOGTIDY $LOG 5
        LOGTIDY $INSTLOG 5

        #Start Loop to install packages, Packages then Servers.
        for PKG in $PACKAGES
        do
            for URL in $SERVERS
            do
                echo ""
                echo "  Installing $PKG on $URL"   | tee -ai $LOG

                curl -k -u admin:$PASS -F file=@"$PKG"   -F force=true -F install=true $PROTOCOL://$URL:$PORT/crx/packmgr/service.jsp  >> $INSTLOG 2>&1

                #Check output log for success message
                if  `tail -4 $INSTLOG | grep -q 'status code="200"'`; then
                    echo "  SUCCESS: $PKG installed on $URL" | tee -ai $LOG
                    echo ""
                    echo "############################################"  >> $INSTLOG
                else
                    echo""
                    echo "  ERROR: FAILED to install $PKG on $URL. " | tee -ai $LOG
                    echo "Please check $INSTLOG and $LOG for details" | tee -ai $LOG
                    echo " Last 5 lines from $INSTLOG" | tee -ai $LOG
                    echo "    ****######################################################*** "  | tee -ai $LOG
                    tail -5 $INSTLOG   | tee -ai $LOG 
                    echo "    ****######################################################*** "   | tee -ai $LOG
                    echo ""
                    echo -n "Do you want to Continue or Abort (c/a)?="
                    read RESPONSE
                        if [ $RESPONSE = c ]
                        then
                            echo " WARNING : Skipping this package install"
                            continue
                        else
                            echo  " WARNING : Please yetry the install again"
                            exit 2
                        fi
                fi

            done
            echo ""
            echo "Sleep 60 sec to allow any bundles restarts to finish"
            sleep 60
        done
    echo""
    echo "  Installation completed, peroforming additional check to confirm package is listed "   | tee -ai $LOG
  #Additional check after package install to verify all packages are listed.
  for URL in $SERVERS
  do
    unset PKGLIST
    echo ""
    echo "  Verifying Packages on $URL"  | tee -ai $INSTLOG $LOG
    PKGLIST=`curl -# -k -u admin:"$PASS" $PROTOCOL://$URL:$PORT/crx/packmgr/service.jsp?cmd=ls  | grep downloadName |awk -F\> '{ print $2}' | awk -F\< '{ print $1}' | sort`

    for PKG in $PACKAGES
    do
        echo $PKGLIST | grep $PKG  > /dev/null 2>&1
        [[ $? -eq 0 ]] && echo "  SUCCESS: $PKG verified on $URL"  | tee -ai $LOG  || echo "  ERROR: $PKG not found on $URL OR package name does not match file name. "  | tee -ai $LOG
    done

    

  done
echo ""
echo "Install summary in $LOG, Details in $INSTLOG"
} 

function LISTPATCHES
{ #Function to list patches
    #Prompt for input of not running on AEM instance
    if [ -z $AEM_TYPE ]
    then
        echo "Script not executed on AEM instance Prompting for input"
        echo -n "Server URL? :"
        read URL
        echo -n "Server PORT? :"
        read PORT
        GETPASS
        [ $PORT -eq 4502 ] || [ $PORT -eq 4503 ] && PROTOCOL=http  || PROTOCOL=https
    else
        #Adding here to check version only if run on the server itself
        echo ""
        echo ""
        VERSION=`sudo ls /mnt/crx/$AEM_TYPE/crx-quickstart/app/*quickstart.jar | awk -F\- '{print $4}'`
        BASEVER=`echo $VERSION | awk -F. '{ print $1"."$2}'`
        echo ""
        echo "          AEM Version = $VERSION"
        echo ""
    fi


    

    echo ""
    echo " Installed Service Packs"
    curl -# -k -u admin:"$PASS" $PROTOCOL://$URL:$PORT/crx/packmgr/service.jsp?cmd=ls  | grep downloadName |awk -F\> '{ print $2}' | awk -F\< '{ print $1}' | sort  | grep -i "aem-service-pkg"  | grep $BASEVER | sort
    echo""
    echo "Installed Hotfixes"
     curl -# -k -u admin:"$PASS" $PROTOCOL://$URL:$PORT/crx/packmgr/service.jsp?cmd=ls  | grep downloadName | awk -F\> '{ print $2}' | awk -F\< '{ print $1}' | sort  | grep -i -e "\-hotfix\-" -e "\-cfp\-"  | grep $BASEVER | sort
        echo ""
RESET
}

function LISTPACKAGES
{  # Get list of all packages
    
    #Prompt for input of not running on AEM instance
    if [ -z $AEM_TYPE ]
        then
            echo "Not running on AEM instance Prompting for input"
            echo -n "Server URL? :"
            read URL
            echo -n "Server PORT? :"
            read PORT
            GETPASS
            [ $PORT -eq 4502 ] || [ $PORT -eq 4503 ] && PROTOCOL=http  || PROTOCOL=https
    fi
    #Get list of packages
    curl -# -k -u admin:"$PASS" $PROTOCOL://$URL:$PORT/crx/packmgr/service.jsp?cmd=ls  | grep downloadName |awk -F\> '{ print $2}' | awk -F\< '{ print $1}' | sort

}

function GETPACKAGES
{  #Script to get packages from remote sercers and store in local directory
        echo ""
        echo -n "Source Server IP :"
        read URL
        echo -n "Server PORT? (default 4503)  :"
        read PORT
        [[ -z $PORT ]] && PORT=4503
        echo -n "Path to Package/s separated by space (eg /etc/packages/package.zip) :"
        read PACKAGES        
        [[ -z $PACKAGES ]] && echo "At least one package name must be specified" && exit 2
        [ $PORT -eq 4502 ] || [ $PORT -eq 4503 ] && PROTOCOL=http  || PROTOCOL=https
        echo -n "Source Server Password :"
        stty -echo
        read PASS
        stty echo

        #Process and get each packages from Source
        for PKG in $PACKAGES
        do
            echo "Downloading $PKG from $URL"
            curl -# -k -u admin:"$PASS" $PROTOCOL://$URL:$PORT$PKG > `basename $PKG`
            [[ $? -ne 0 ]] && echo "Failed to get package $PKG"
        done

}

function CheckBundles
{
    echo ""

}

function StopCRX
{
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/org.apache.sling.jcr.davex -F action=stop
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/com.adobe.granite.crx-explorer -F action=stop
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/com.adobe.granite.crxde-lite -F action=stop

}

function StartCRX
{
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/org.apache.sling.jcr.davex -F action=start
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/com.adobe.granite.crx-explorer -F action=start
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/com.adobe.granite.crxde-lite -F action=start

}

function StopGroovy
{
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/aem-groovy-console -F action=stop
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/aem-groovy-extension-bundle -F action=stop
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/groovy-all -F action=stop

} 
  
function StartGroovy

{
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/aem-groovy-console -F action=start
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/aem-groovy-extension-bundle -F action=start
    curl -u admin:$PASS http://$URL:$PORT/system/console/bundles/groovy-all -F action=start
}


#Based on argument execute function
ACTION=$1
case $ACTION in
        install)
             INSTALLPACKAGES
        ;;
        patch)
             LISTPATCHES
        ;;
        pkg)
            LISTPACKAGES
        ;;
        upload)
			UPLOADPACKAGES
		;;
        download)
            GETPACKAGES
        ;;
        check)
            CheckBundles
        ;;
        crxstop)
            StopCRX
        ;;
        crxstart)
            StartCRX
        ;;
        groovystop)
            StopGroovy
        ;;
        groovystart)
            StartGroovy
        ;;

        mem)
            Validate-AMS-AEM
            sudo /usr/local/nagios/libexec/check_mem 96 98
        ;;

        oldgen)
             Validate-AMS-AEM
             sudo /usr/local/nagios/libexec/check_old_gen 96 99
        ;;

        jetty)
            Validate-AMS-AEM
            sudo /usr/local/nagios/libexec/check_jstack
        ;;
        thread)
            Validate-AMS-AEM
            [[ -x /home/vettom/bin/threaddump.sh ]] && sudo /home/vettom/bin/threaddump.sh
        ;;
        heap)
            Validate-AMS-AEM
            [[ -x /home/vettom/bin/heapdump.sh ]] && sudo /home/vettom/bin/heapdump.sh
        ;;
        gc)
            Validate-AMS-AEM
            [[ -x /home/vettom/bin/gctrigger.sh ]] && sudo /home/vettom/bin/gctrigger.sh
        ;;
        *)
             USAGE; RESET; error=1; exit
        ;;
esac




#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script:Take fresh backup of httpd and deploy dispatcher 2 config to Dispatceher. 
# Customer's zip file must contain all necessary file included in conf.d and conf.dispatcher.d.
# AMS default file will not be overwritten, and 100% sync ensure with delete of removed files.
# Author:       Denny Vettom
# Ver   : 1.0   #Developed for disptacher 2  dispatcehers.
# Ver   : 1.1   Updated with fix for rsync, added file cout comparisson.
# Ver   : 1.1   Fixed exclude file rule.
# Ver   : 1.2   Fixed exclude rule folder, added link count
# Ver   : 1.3   Added Color
# Ver   : 1.4   Updated to validate file present.
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
AMSDEFAULTS=/tmp/amsdispatcher2files.txt
# ----------------------------------------------------------------------------
# Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
# ----------------------------------------------------------------------------

function CHECK_FAILURE
{
        if [ $1 -ne 0 ]
        then
                echo -e "\e[0;41m ERROR : $2  \e[0m "  | tee -ai ${LOG}
                ERROR_FLAG=1
                exit 1
        fi
}

function Info { 
                echo -e "\e[1;32;1;40m $1 \e[0m "  
            }
function Warn { 
                echo -e "\e[3;34;1;43m $1 \e[0m "  
            }
function Err { 
                echo -e "\e[1;32;1;41m $1 \e[0m "  
            }
function Attn {
                   echo -e "\e[1;38;1;44m $1  \e[0m "  
                }

USER=root


#Ensure script is run as root user
 CURRENT_USER_ID=`id | awk -F\( '{ print $2 }' | awk -F\) '{ print $1 }'`
 if [ $CURRENT_USER_ID != $USER ]
 then
        Info "   INFO : Please execute command as Root "
        exit
 fi

function BACKUPHTTPD 
{


		if [ -d /etc/httpd ]
		then
			#Create backup directory if it does not already exist
			[[ ! -d /etc/httpd/backups ]] && mkdir -p /etc/httpd/backups 

			#Create backup. If new structure take backup ofconf.dispatcher.d as well.
		    if [ -d /etc/httpd/conf.dispatcher.d ]
		    then
		    	cd /etc/httpd
		    	zip /etc/httpd/backups/`hostname`.dispatcherconf.${TIMESTAMP}.zip -q -r conf*
		    	CHECK_FAILURE $? " ERROR : Failed to create backup, please perform manually"

				echo""
				echo " INFO : Backup completed. /etc/httpd/backups/`hostname`.dispatcherconf.${TIMESTAMP}.zip"
			fi

		else
			Err " ERROR : Could not find /etc/httpd directory.  Is this Dispatcher instance?"
            echo ""
			exit 1
		fi

		#Remove Older backup files
			find /etc/httpd/backups/ -mtime +14 -name "*.zip" -exec rm {} \;

}


#Start of custom script action
function DEPLOYCONF {
	# Verifying zip file is valid and have 50+ files in it
	unzip -l $ZIPFILE  > /dev/null 2>&1
	CHECK_FAILURE $? " ERROR : Failed to unzip $ZIPFILE to verify using unzip -l"

	TMPDIR=/tmp/HTTPD_$TIMESTAMP  

 	# Create temp folder
	mkdir -p $TMPDIR
	CHECK_FAILURE $? " ERROR: Failed to Create $TMPDIR"

	# # Copy zip file to temp location
	# cp $ZIPFILE $TMPDIR 
	# CHECK_FAILURE $? " ERROR: Failed to copy $ZIPFILE to $TMPDIR"

	ZIPFILENAME=`basename $ZIPFILE`
	unzip -q $ZIPFILE -d  $TMPDIR > /dev/null 2>&1
	CHECK_FAILURE  $? " ERROR: Failed to unzip the $ZIPFILE in temp location"

	echo " INFO : Files Unzipped to $TMPDIR. "

	#No check and verify require directory structur exist and no new dir.
	#Expecting 3 DiR at present total 5 including the conf and conf.d dir
	echo " INFO : Counting number of directories to ensure necessary dispatcher folders exists"
	DIRCOUNT=`find $TMPDIR/conf.d/ $TMPDIR/conf.dispatcher.d/ -type d | wc -l`
	[[ $DIRCOUNT -lt 14 ]] && echo " ERROR: Check the zip file and ensure directory structure is correct and contains cond.d and cond.disptcher.d with all files" && exit
    
    DCOUNT=`ls $TMPDIR/ | wc -l`
    if [ $DCOUNT -gt 2 ]
    then
         Warn "WARNING : More than 2 dir found in Zip file, conf.d and conf.dispatcher.d will be processed, rest will be ignored."
         Info "INFO : Check for special instructions for rest of files or advise customer after install"
         echo "Following files found."
         echo ""
         ls $TMPDIR/
         echo ""
    fi

	# Add some more check to ensure directory structure exists as expected
	[ ! -d $TMPDIR/conf.d/available_vhosts ] || [ ! -d $TMPDIR/conf.d/enabled_vhosts ]  || [ ! -d $TMPDIR/conf.d/rewrites ]  || [ ! -d $TMPDIR/conf.d/redirects ] \
	 || [ ! -d $TMPDIR/conf.d/variables ] && echo " ERROR: Folers missing in $TMPDIR/conf.d, verify zip file is complete! " && exit 
	[ ! -d $TMPDIR/conf.dispatcher.d/available_farms ] || [ ! -d $TMPDIR/conf.dispatcher.d/cache ] || [ ! -d $TMPDIR/conf.dispatcher.d/clientheaders ] || [ ! -d $TMPDIR/conf.dispatcher.d/enabled_farms ] \
	 || [ ! -d $TMPDIR/conf.dispatcher.d/filters ] || [ ! -d $TMPDIR/conf.dispatcher.d/vhosts ]  && echo " ERROR: Some folders missing in $TMPDIR/conf.dispatcher.d, verify zip file is complete! " && exit


	echo " INFO : Directory structure found as expected, ready to perform sync"
	
	#Now that all dir verified start the sync for each.
    echo ""
    echo "                ---------------------------------------------------------------"
    echo ""
    echo -e "          \e[0;32m  rsync -rvcl --delete   $TMPDIR/conf.d/ /etc/httpd/conf.d/ --exclude-from=$AMSDEFAULTS  \e[0m"
    echo -e "          \e[0;32m  rsync -rvcl --delete   $TMPDIR/conf.dispatcher.d/ /etc/httpd/conf.dispatcher.d/ --exclude-from=$AMSDEFAULTS \e[0m"
    echo ""
    echo "                ---------------------------------------------------------------"
    echo ""
	
	echo -n -e "  Execute above commands to sync Dispatcher? \e[0;33m y/n: \e[0m"
	read ANS

		if [ $ANS = y ]
	    then
			mv $ZIPFILE /etc/httpd/backups/
			echo " INFO : $ZIPFILE moved to /etc/httpd/backups/"
			#Take Backup by runnign backup script
			echo " INFO : Creating backup of existing httpd configuration"
			BACKUPHTTPD
			source /etc/sysconfig/httpd
			echo " INFO : Synching $TMPDIR/conf.d/ to /etc/httpd/conf.d/" ; sleep 3
			rsync -rvcl --delete 	$TMPDIR/conf.d/ /etc/httpd/conf.d/ --exclude-from=$AMSDEFAULTS
			CHECK_FAILURE $? " ERROR: Failed to sync /etc/httpd/conf.d/ "
			echo " SUCCESS : Synched /etc/httpd/conf.d/"
			
			echo " INFO : Synching $TMPDIR/conf.dispatcher.d/ to /etc/httpd/conf.dispatcher.d/" ; sleep 3
			rsync -rvcl --delete 	$TMPDIR/conf.dispatcher.d/ /etc/httpd/conf.dispatcher.d/ --exclude-from=$AMSDEFAULTS
			CHECK_FAILURE $? " ERROR: Failed to sync /etc/httpd/conf.dispatcher.d/ "
			echo " SUCCESS : Synched /etc/httpd/conf.dispatcher.d/"
			
			
            CONFD_SOURCE_COUNT=`find $TMPDIR/conf.d/ -type f | wc -l`
            CONFD_DEST_COUNT=`find /etc/httpd/conf.d/ -type f | wc -l`

            CONFDISPD_SOURCE_COUNT=`find $TMPDIR/conf.dispatcher.d/ -type f | wc -l`
            CONFDISPD_DEST_COUNT=`find /etc/httpd/conf.dispatcher.d/ -type f | wc -l`
            
            CONFD_SOURCE_LINK_COUNT=`find $TMPDIR/conf.d/ -type l | wc -l`
            CONFD_DEST_LINK_COUNT=`find /etc/httpd/conf.d/ -type l | wc -l`

            CONFDISPD_SOURCE_LINK_COUNT=`find $TMPDIR/conf.dispatcher.d/ -type l | wc -l`
            CONFDISPD_DEST_LINK_COUNT=`find /etc/httpd/conf.dispatcher.d/ -type l | wc -l`

            echo  "  -------------File Count--------------------"
            echo -e "  \e[1;42m  Directory             Cout Source   Count /etc/httpd \e[0m "
            echo -e " \e[0;32m   conf.d.               $CONFD_SOURCE_COUNT           $CONFD_DEST_COUNT \e[0m "
            echo -e " \e[0;32m   conf.dispatcher       $CONFDISPD_SOURCE_COUNT           $CONFDISPD_DEST_COUNT \e[0m "
            echo -e " \e[0;32m   conf.d Links          $CONFD_SOURCE_LINK_COUNT           $CONFD_DEST_LINK_COUNT \e[0m "
            echo -e " \e[0;32m   conf.dispatcher Links $CONFDISPD_SOURCE_LINK_COUNT           $CONFDISPD_DEST_LINK_COUNT   \e[0m "
            echo "  -------------------------------------------"


			if [ $CONFD_SOURCE_COUNT !=  $CONFD_DEST_COUNT ]  || [ $CONFDISPD_SOURCE_COUNT != $CONFDISPD_DEST_COUNT ] || [ $CONFD_SOURCE_LINK_COUNT != $CONFD_DEST_LINK_COUNT ] || [ $CONFDISPD_SOURCE_LINK_COUNT != $CONFDISPD_DEST_LINK_COUNT ]
			then
				echo ""
				Err "  ERROR : File count not mattching for package and httpd, please verify package/sync job"
                echo ""
				exit
			fi


			echo " SUCCESS : Dispatcher configuration updated. (sleep 10 sec)"
			sleep 10 
			echo ""
			echo ""
			echo " INFO :Testing configuration by running httpd -t "
			sleep 2
			restorecon -R /etc/httpd
			httpd -t

            echo ""
            echo ""
            echo -e "   \e[0;33m   **** --------------------------------------------------------------- **** \e[0m"
            Attn "               Perform MANUAL RESTART of Apache ( service httpd restart )   "
            echo -e "    \e[1;33m  **** --------------------------------------------------------------- **** \e[0m"
	        echo  ""

		elif [ -z $ANS ]
		then
			echo " ERROR: Cancelling Sync job."
			exit 1

		else
			echo " ERROR: Cancelling Sync job."
			exit 1
		fi

	echo " INFO: Zip file and backup saved in /etc/httpd/backups/"
	echo ""

}

function CREATE_EXCLUDEFILE {
	[[ -f $AMSDEFAULTS ]]  && rm -f $AMSDEFAULTS

	cat << EOF > $AMSDEFAULTS
README
userdir.conf
welcome.conf
available_vhosts/aem_author.vhost
available_vhosts/aem_publish.vhost
available_vhosts/aem_lc.vhost
available_vhosts/aem_flush.vhost
available_vhosts/aem_health.vhost
available_vhosts/000_unhealthy_author.vhost
available_vhosts/000_unhealthy_publish.vhost
rewrites/base_rewrite.rules
rewrites/xforwarded_forcessl_rewrite.rules
whitelists/000_base_whitelist.rules
variables/ams_default.vars
dispatcher_vhost.conf
logformat.conf
security.conf
enabled_vhosts/aem_author.vhost
enabled_vhosts/aem_flush.vhost
enabled_vhosts/aem_health.vhost
enabled_vhosts/aem_publish.vhost
available_farms/000_ams_author_farm.any
available_farms/999_ams_publish_farm.any
available_farms/001_ams_lc_farm.any
enabled_farms/999_ams_publish_farm.any
enabled_farms/000_ams_author_farm.any
cache/ams_author_cache.any
cache/ams_author_invalidate_allowed.any
cache/ams_publish_cache.any
cache/ams_publish_invalidate_allowed.any
clientheaders/ams_author_clientheaders.any
clientheaders/ams_publish_clientheaders.any
clientheaders/ams_common_clientheaders.any
clientheaders/ams_lc_clientheaders.any
filters/ams_author_filters.any
filters/ams_publish_filters.any
filters/ams_lc_filters.any
renders/ams_author_renders.any
renders/ams_publish_renders.any
renders/ams_lc_renders.any
vhosts/ams_author_vhosts.any
vhosts/ams_publish_vhosts.any
vhosts/ams_lc_vhosts.any
dispatcher.any
EOF
}


#  ---------- ********* End of Functions  ****** --------------

#First Introduction menu to explain what script does
	echo ""
	echo ""
	echo "################## Barclays Dispatcher config Deploy ##################################"
	echo ""
	echo "       Script to deploy Dispatcher 2 config if complete package provided."
	echo "       Zip file must contain all dispatcher configuration files"
	echo "       Rsync of conf.d, and conf.dispatcher.d executed with delete option."
	echo ""
	echo "       *** AMS default files are execluded and not overwritten ***"
	echo ""
	echo "######################################################################################"
	
	echo " "
	echo " "
	echo " "
	echo " "

	# Make sure it is running on Dispatcher with dispatcher 2 directory structure.
	if [ -d /etc/httpd/conf.dispatcher.d ] && [ -d /etc/httpd/conf.d ]
	then

		#If not argument prompt for file name
		
		if [ -z $1 ]
		then
			echo -e -n " \e[0;32m  Please enter full Path to zip filename : \e[0m"
			read ZIPFILE
			sleep 2
		else
			
			ZIPFILE=$1
			sleep 2

		fi

        # Check if the file is accessible
        if [ ! -f $ZIPFILE ]
        then
            Err " ERROR : $ZIPFILE not found, ensure file in current path or provide full path to file."
            echo ""
            exit 2
        fi

        # Create exclude file
		CREATE_EXCLUDEFILE
		# Now got Zip file so do deploy.
		[[ -d $TMPDIR ]] && rm -fr $TMPDIR/*.zip $TMPDIR/conf* && rmdir $TMPDIR
		DEPLOYCONF
		# Clean up at end
		[[ -d $TMPDIR ]] && rm -fr $TMPDIR/*.zip $TMPDIR/conf* && rmdir $TMPDIR
		[[ -f $AMSDEFAULTS ]]  && rm -f $AMSDEFAULTS
	else
		echo "  ERROR : Httpd config folders not found, is this host a dispatcher?"
		exit 1
	fi

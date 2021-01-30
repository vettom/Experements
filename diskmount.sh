#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script: to mount and unmount disk to /mnt/Disk1
#  Defaults to device name 
#
# Author:       Denny Vettom
#Ver   : 1
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


#Ensure script is run as root user
 CURRENT_USER_ID=`id | awk -F\( '{ print $2 }' | awk -F\) '{ print $1 }'`
 if [ $CURRENT_USER_ID != root ]
 then
    echo -e "  \e[1;32m INFO : Please execute command as Root \e[0m "
    exit
 fi



if [ -z $2 ]
then
    DEV="/dev/nvme2n1"
else
    DEV=$2
fi

# ----------------------------------------------------------------------------
# Check if a task failed or not, if failed append message to $LOG and set ERROR_FLAG and FINISH
# ----------------------------------------------------------------------------

function CHECK_FAILURE
{
        if [ $1 -ne 0 ]
        then
                echo -e "\e[0;41m ERROR : $2  \e[0m " | tee -ai ${LOG}
                exit 3
        fi
}

if [ $N_ARG -lt 1 ]
then
    echo "Run with. option <mount/unmount>  <optional device or defaults to /dev/nvme2n1>"
    echo " diskmount.sh mount /dev/nvme2n1"
    exit 2
fi

if [ $1 == mount ]
then
    echo "Mounting $DEV to /mnt/Disk1"
    vgs vg50 > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        echo "VG50 exist, please remove "
        exit 5
    fi
    vgimportclone --basevgname vg50  $DEV
    CHECK_FAILURE $? "Failed to import device $DEV"
    vgchange -ay
    /sbin/cryptsetup -c aes-cbc-plain -s 256 -d /opt/keys/instance_key.pub create CryptedEBS_restore /dev/mapper/vg50-lv0
    CHECK_FAILURE $? "Failed to create Crypt Volume"
    [[ -d /mnt/Disk1 ]] ||  mkdir /mnt/Disk1
    CHECK_FAILURE $? "Failed to create /mnt/Disk1"
    mount /dev/mapper/CryptedEBS_restore /mnt/Disk1
    CHECK_FAILURE $? "Failed to mount disk "

    echo " Success: disk mounted om /mnt/Disk1"
    ls -l /mnt/Disk1/crx

elif [ $1 == umount ]
then
    echo "Unmounting and removing vg50 and device $DEV"
    df -h /mnt/Disk1 > /dev/null 2>&1
    [[ $? -eq 0 ]] && umount -f /mnt/Disk1
    vgs vg50 > /dev/null 2>&1 
    CHECK_FAILURE $? "Failed VG50 not found aborting"
    cryptsetup remove CryptedEBS_restore
    lvchange -an /dev/vg50/lv0
    lvremove /dev/vg50/lv0
    CHECK_FAILURE $? "Failed to remove LV"
    vgremove /dev/vg50
    CHECK_FAILURE $? "Failed to remove vg50 "
    rmdir /mnt/Disk1

    echo " SUCCESS : Disk unmounted and vg removed"
else
    echo "Invalid option $1"
fi
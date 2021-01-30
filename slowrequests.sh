#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script: Script to evaluate slow requests on Publish/Author
#  It also list incmplete requests from request log. 
# Pass $1 argument for custom requestlogfile.
# Author:       Denny Vettom
#
# Usage: No arguments
# ----------------------------------------------------------------------------
# Name          Date            Comment                         Version
# ----------------------------------------------------------------------------
# DV            14/12/2018      Initial creation.               V1
# DV            4/1/2019      Updated to accept argument.       V1
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



#Check whether Publish or Author to set directory
if [ -d /mnt/crx/publish ]
then
	AEMTYPE=publish
elif [ -d /mnt/crx/author ]
then
	AEMTYPE=author
else
	echo -e " \e[0;41m ERROR: Author or Publish Dir not found in /mnt/crx \e[0m "
    exit
fi

JavaFile="/tmp/IncompleteRequests.java"
Requestlog=$1
[[ -z $Requestlog ]] && Requestlog="/mnt/crx/$AEMTYPE/crx-quickstart/logs/request.log"

echo ""
echo -e "  \e[1;32m  INFO : Using ${Requestlog} \e[0m "
echo -e "  \e[1;32m  INFO : To use custom request log file pass it as argument with path. \e[0m "
cat <<EOF > $JavaFile
//package com.adobe.ams;


import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.Charset;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.*;

/*
Original Author: Elaine Sun
Find out requests that have not been fulfilled from AEM request log, with the situation in mind in which AEM
may be restarted multiple times a day, and request ID and not be unique.
*/
public class IncompleteRequests {

    static String REQUEST_LINE_INDICATOR = " -> ";
    static String RESPONSE_LINE_INDICATOR = " <- ";
    public static void main(String[] args) {
        // write your code here
        String fileName = args[0];
        Map<Integer, List<String>> lineMap = new LinkedHashMap<>();
        String line;
        try (
                InputStream fis = new FileInputStream(fileName);
                InputStreamReader isr = new InputStreamReader(fis, Charset.forName("UTF-8"));
                BufferedReader br = new BufferedReader(isr);
        ) {
            while ((line = br.readLine()) != null) {
                Integer requestId = getRequestId(line);
                if (requestId == null) continue; // Try to make the most of the situation even with some invalid log entries in request log
                List<String> val = lineMap.get(requestId);
                if (line.contains(REQUEST_LINE_INDICATOR)) {
                    if (val == null) {
                        val = new LinkedList<String>(Arrays.asList(line));
                    } else {
                        val.add(line);
                    }
                    lineMap.put(requestId, val);
                } else if (line.contains(RESPONSE_LINE_INDICATOR)) {
                    if (val != null) {
                        val.remove(val.size() - 1); // Typically when there are multiple requests with same ID, it is due to restart and request ID starts from beginning again. And the earlier requests did not finish.
                        if (!val.isEmpty()) {
                            lineMap.put(requestId, val);
                        }
                    } else {
                        System.err.println("Hum. Could not find the corresponding request line for " + line);
                    }
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
        printResult (lineMap);
    }

    private static Integer getRequestId (String line) {
        StringTokenizer tokenizer = new StringTokenizer(line, " ");
        int i = 0;
        while (tokenizer.hasMoreTokens()) {
            i++;
            String resultStr = tokenizer.nextToken();
            if (i <= 2) continue;
            else {
                try {
                    return Integer.valueOf(resultStr.substring(1, resultStr.length() - 1));
                } catch (NumberFormatException e) {
                    System.err.println ("Hum. Request ID is not a number in line: " + line);
                }
            }
        }
        System.err.println ("Hum, this doesn't look like a valid request log entry: " + line);
        return null;
    }

    private static void printResult (Map<Integer, List<String>> lineMap) {
        for (Integer key : lineMap.keySet()) {
            // ...
            List<String> lines = lineMap.get(key);
            for (String line : lines) {
                System.out.println(line);
            }
        }
    }
}


EOF

# List all Slow requests
CLASSPATH=$CLASSPATH:/tmp ; export CLASSPATH

if [ -f $JavaFile ]
then
    # Compile script
    javac $JavaFile
    echo ""
    echo ""
    echo -e "  \e[1;32m  -------- Incomplete Requests  --------  \e[0m "

    java IncompleteRequests $Requestlog

    echo ""
    rm -f $JavaFile ; rm -f /tmp/IncompleteRequests.class
else
    echo "" 
    echo -e " \e[0;41m ERROR : File $SCR_HOME/IncompleteRequests.java not found, ignoring incomplete requests list \e[0m "
fi


echo ""
echo -e "  \e[1;32m  -------- Slow Requests  -------- \e[0m "
echo ""
# Process request.log and show top 20 slowest requests.
 if [ -f /mnt/crx/$AEMTYPE/crx-quickstart/opt/helpers/rlog.jar ] && [ -f $Requestlog ]
 then
    #Run the request logs check
    java -jar /mnt/crx/$AEMTYPE/crx-quickstart/opt/helpers/rlog.jar -n 20 $Requestlog|  grep -v java.util.NoSuchElementException
 else
    echo  -e " \e[0;41m  ERROR: File Not Found /mnt/crx/$AEMTYPE/crx-quickstart/opt/helpers/rlog.jar or \e[0m " $Requestlog  
 fi


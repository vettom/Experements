#!/bin/sh
# Upload file to Daycare using curl
 
HOST='sjftp.adobe.com'
USER=ftpaem1680
PASS='Wtfits5$ag'
 
read -p "$(tput setaf 6)File to upload: $(tput sgr0)" FILENAME
echo "Uploading $FILENAME to $HOST folder aem_support"
curl --ftp-ssl -# -k --user ftpaem1680:'Wtfits5$ag' -T "$FILENAME" ftp://sjftp.adobe.com/aem_support/
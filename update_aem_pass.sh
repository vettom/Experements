#!/bin/bash
set -e
 
user=admin
while [[ $1 == -* ]]; do
  case $1 in
    -u|--user) user=$2; shift 2;;
    -k|--insecure) insecure=-k; shift;;
    -d|--debug) debug=-v; set -x; shift;;
    --) shift; break;;
    *) echo "Unsupported option $1"; error=1; break;;
  esac
done
[[ $error || ! $OLD || ! $NEW ]] && \
  echo "Syntax: OLD=<pass> NEW=<pass> $0 [-d|--debug] [-u <user(admin)>] [<server(localhost:4502)>] ..." && \
  exit $error

[[ $# -lt 1 ]] && set -- localhost:4502
curl="curl $insecure $debug -sSf --connect-timeout 5 -u $user:$OLD"

for server; do
  echo -n "Server $server: "
  if [[ $user == admin ]]; then
    echo -n "changing Felix console admin: "
    $curl "$server/system/console/configMgr/org.apache.felix.webconsole.internal.servlet.OsgiManager" \
      -d apply=true -d propertylist=password -d "password=$NEW" || \
      { echo curl failed, try -d; exit 1; }
    echo OK
  fi

  echo -n "looking for user $user: "
  out=`$curl -i "$server/bin/querybuilder.json?path=/home/users&1_property=rep:authorizableId&1_property.value=$user&p.limit=-1"` || \
    { echo curl failed, try -d; exit 1; }
  [[ $out == *\"results\":1,* ]] || { echo "$out"; exit 1; }
  path=`jq -r .hits[0].path <<< "${out#*$'\n\r\n'}"`

  echo -n "changing $path: "
  out=`$curl -i "$server$path.rw.userprops.html" \
    --data-urlencode "rep:password=$NEW" --data-urlencode ":currentPassword=$OLD"` || \
    { echo curl failed, try -d; exit 1; }
  [[ $out == *id=\"Status\"\>200* ]] && echo OK || { echo "$out"; exit 1; }
done

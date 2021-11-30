#!/bin/bash

if [ -z "$1" ]
then
      echo "setting minor to 9"
      minor="9"
else
      echo "minor is set to ${1}"
      minor=${1}
fi
if [ -z "$2" ]
then
      echo "setting zstream to 4"
      zstream="4"
else
      echo "z-stream is set to ${2}"
      zstream=${2}
fi
CL_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.${minor}.${zstream}/openshift-client-linux-4.${minor}.${zstream}.tar.gz"
IN_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.${minor}.${zstream}/openshift-install-linux-4.${minor}.${zstream}.tar.gz"
OPM_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.${minor}.${zstream}/opm-linux-4.${minor}.${zstream}.tar.gz"

wget -qO - ${CL_URL}  |sudo tar xfz - -C /usr/local/bin/
wget -qO - ${IN_URL}  |sudo tar xfz - -C /usr/local/bin/
wget -qO - ${OPM_URL} |sudo tar xfz - -C /usr/local/bin/
echo

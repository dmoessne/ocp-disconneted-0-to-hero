#!/bin/bash
set -euxo pipefail
pushd  $HOME/registry/
#https://access.redhat.com/solutions/4844461
clear
echo "create a file named token, populated with the token optained from https://console.redhat.com/openshift/token/show "
echo ""
read -p "Are you ready to populate the token file? " -n 1 -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Enter your token now:"
    read  TOKEN
    echo $TOKEN > $HOME/registry/secrets/token
else
   echo "No way to proceed without a token"
   exit
fi


export OFFLINE_ACCESS_TOKEN=`cat $HOME/registry/secrets/token`
export BEARER=$(curl \
--silent \
--data-urlencode "grant_type=refresh_token" \
--data-urlencode "client_id=cloud-services" \
--data-urlencode "refresh_token=${OFFLINE_ACCESS_TOKEN}" \
https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | jq -r .access_token)


curl -sX POST https://api.openshift.com/api/accounts_mgmt/v1/access_token --header "Content-Type:application/json" --header "Authorization: Bearer $BEARER" > $HOME/registry/secrets/rh-pull-secret

podman login ${HOSTNAME}:5000 -u test -p test 

cat ${XDG_RUNTIME_DIR}/containers/auth.json |jq -c . > $HOME/registry/secrets/local-secret.json	
jq -s '.[0] * .[1]'  $HOME/registry/secrets/rh-pull-secret ${XDG_RUNTIME_DIR}/containers/auth.json > $HOME/registry/secrets/pull-secret.json

export OCP_RELEASE=$(oc version -o json  --client | jq -r '.releaseClientVersion')
export LOCAL_REGISTRY="${HOSTNAME}:5000"
export LOCAL_REPOSITORY='ocp4/openshift4'
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON="$HOME/registry/secrets/pull-secret.json"
export RELEASE_NAME="ocp-release"
export ARCHITECTURE=x86_64


oc adm release mirror -a ${LOCAL_SECRET_JSON} \
 --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} \
 --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
 --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE} |tee -a $HOME/registry/release-mirror.out

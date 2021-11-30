#!/bin/bash
clear
set -euxo pipefail

oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
#sleep 120
oc get po -n openshift-marketplace

rm -rf ${XDG_RUNTIME_DIR}/containers/auth.json
podman login ${HOSTNAME}:5001 -u test2 -p test2
cat ${XDG_RUNTIME_DIR}/containers/auth.json |jq -c . > $HOME/registry2/secrets/local-secret2.json
jq -s '.[0] * .[1]'  $HOME/registry/secrets/rh-pull-secret ${XDG_RUNTIME_DIR}/containers/auth.json > $HOME/registry2/secrets/pull-secret.json

pushd $HOME/registry2
LOCAL_REGISTRY="${HOSTNAME}:5001"
LOCAL_SECRET_JSON="$HOME/registry2/secrets/pull-secret.json"
GOPATH=$HOME/go
INDEX_IMAGE="registry.redhat.io/redhat/redhat-operator-index:v4.9"
CUST_INDEX_IMAGE="ocp4/redhat-operator-index:v4.9"

# uncoment below for full red hat catalog sync
#oc adm catalog mirror \
#    ${INDEX_IMAGE} \
#    ${LOCAL_REGISTRY}/redhat-operator-catalog \
#    -a ${LOCAL_SECRET_JSON} \
#    --index-filter-by-os="linux/amd64"

# as opm doesn't take secrets on cmdline but we want to automate we need this step
cp $LOCAL_SECRET_JSON ${XDG_RUNTIME_DIR}/containers/auth.json

# we want just a subset here, hence pruning the index image before syncing
# if you need to get the index first to see which packages are available, we need to install gprcurl
# and run an image
# 
# get grpcurl 
#go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
#sudo cp ~/go/bin/grpcurl /usr/local/bin/
#
# start the image and get package list
#podman run --name index-pod -d -p50051:50051 -it $INDEX_IMAGE
#grpcurl -plaintext localhost:50051 api.Registry/ListPackages > packages.out
#podman rm -f index-pod
#
# you can manually choose and would need to change the package list in the next command
#
#IMAGE_LIST=(sandboxed-containers-operator,ocs-operator,local-storage-operatorkubevirt-hyperconverged,advanced-cluster-management)
IMAGE_LIST=(ocs-operator,local-storage-operator)
opm index prune -f ${INDEX_IMAGE} -p ${IMAGE_LIST} -t ${LOCAL_REGISTRY}/${CUST_INDEX_IMAGE}
podman push ${LOCAL_REGISTRY}/${CUST_INDEX_IMAGE}

oc adm catalog mirror \
    ${LOCAL_REGISTRY}/${CUST_INDEX_IMAGE} \
    ${LOCAL_REGISTRY}/redhat-operator-catalog \
    -a ${LOCAL_SECRET_JSON} \
    --index-filter-by-os="linux/amd64"


clear

ICSP=$(find $HOME/registry/ -name imageContentSourcePolicy.yaml)
CS=$(find $HOME/registry/ -name catalogSource.yaml)

oc create -f $ICSP
sleep 60
oc create -f $CS
sleep 120
oc get po -n openshift-marketplace

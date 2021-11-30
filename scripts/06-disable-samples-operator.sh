#!/bin/bash
clear
set -euxo pipefail

pushd $HOME/registry
oc get -o json configs.samples.operator.openshift.io/cluster | jq .spec.managementState
echo
oc patch configs.samples.operator.openshift.io/cluster --type merge --patch '{"spec":{"managementState":"Removed"}}'
echo
oc get -o json configs.samples.operator.openshift.io/cluster | jq .spec.managementState

#!/bin/bash
set -euxo pipefail

pushd $HOME/registry
rm -rf cluster
mkdir cluster
cat << EOF >install-config.yaml
apiVersion: v1
baseDomain: emeatam.support
proxy:
  httpProxy: http://PROXY_IP:3128
  httpsProxy: http://PROXY_IP:3128 
  noProxy: emeatam.support
controlPlane:
  hyperthreading: Enabled
  name: master
  platform:
    aws:
      zones:
      - eu-west-1a
      - eu-west-1b
      - eu-west-1c
      rootVolume:
        iops: 4000
        size: 500
        type: io1
      type: m5.xlarge
  replicas: 3
compute:
- hyperthreading: Enabled
  name: worker
  platform:
    aws:
      rootVolume:
        iops: 2000
        size: 500
        type: io1 
      type: m5.xlarge
      zones:
      - eu-west-1a
      - eu-west-1b
      - eu-west-1c
  replicas: 3
metadata:
  name: test-cluster
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineCIDR: 192.168.0.0/16
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  aws:
    region: eu-west-1
    userTags:
      adminContact: dmoessne
      costCenter: 118
    subnets: 
    - subnet-011039285f089d6ee
    - subnet-0170a50309510fe58
    - subnet-07863ceb931ff1fc5
pullSecret:  '....'
fips: false
sshKey: '...' 
publish: Internal
EOF

cp install-config.yaml install-config.yaml.orig

ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/ocp_id.rsa -q -N ""

export PRIMARY_IP=$(ip route get 1 | awk '{print $7;exit}')
export SECRET=$(echo "pullSecret: '`cat $HOME/registry/secrets/local-secret.json`'")
export PUB_KEY=$(echo "sshKey: `cat $HOME/.ssh/ocp_id.rsa.pub`")

sed -i "s/PROXY_IP/$PRIMARY_IP/g; s/pullSecret.*/$SECRET/g; s#sshKey.*#$PUB_KEY#g" install-config.yaml 

echo "additionalTrustBundle: |" >> install-config.yaml
cat /etc/pki/ca-trust/source/anchors/ca.pem |sed 's/^/  /g' >>install-config.yaml
cat release-mirror.out |grep -A 6 imageContentSources > $HOME/registry/ImageContentPolicy
cat $HOME/registry/ImageContentPolicy >> install-config.yaml

cp install-config.yaml cluster/

openshift-install create cluster --dir cluster/ 

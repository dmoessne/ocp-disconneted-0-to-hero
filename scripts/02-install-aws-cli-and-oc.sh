#!/bin/bash
set -euxo pipefail

pushd /tmp
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /bin/aws
popd
helper/fetch.sh 

sudo bash -c '/usr/local/bin/oc completion bash >/etc/bash_completion.d/openshift'
oc version
openshift-install version

if [ ! -d $HOME/.aws ]
   then
   mkdir $HOME/.aws
fi
cat << EOF >> $HOME/.aws/credentials
[default]
aws_access_key_id = <AWSKEY>
aws_secret_access_key = <AWSSECRETKEY>
region = <REGION>
EOF

echo "you need to fill in AWS credentials into  $HOME/.aws/credentials"
echo "then run aws sts get-caller-identity to test"

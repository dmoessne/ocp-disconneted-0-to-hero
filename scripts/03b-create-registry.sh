#!/bin/bash
set -euxo pipefail

rm -rf  $HOME/registry2
mkdir $HOME/registry2
mkdir $HOME/registry2/secrets
pushd $HOME/registry2
mkdir create-registry-certs
pushd create-registry-certs

cat > ca-config2.json << EOF
{
    "signing": {
        "default": {
            "expiry": "87600h"
        },
        "profiles": {
            "server": {
                "expiry": "87600h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "87600h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat > ca-csr2.json << EOF
{
    "CN": "Test Registry Self Signed CA",
    "hosts": [
        "${HOSTNAME}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "San Francisco"
        }
    ]
}
EOF

cat > server2.json << EOF
{
    "CN": "Test Registry Self Signed CA",
    "hosts": [
        "${HOSTNAME}"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "San Francisco"
        }
    ]
}
EOF

# generate ca-key.pem, ca.csr, ca.pem
cfssl gencert -initca ca-csr2.json | cfssljson -bare ca2 -

# generate server-key.pem, server.csr, server.pem
cfssl gencert -ca=ca2.pem -ca-key=ca2-key.pem -config=ca-config2.json -profile=server server2.json | cfssljson -bare server

# enable schema version 1 images
cat > registry-config2.yml << EOF
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
compatibility:
  schema1:
    enabled: true
EOF

sudo mkdir -p /opt/registry2/{auth,certs,data}

sudo firewall-cmd --add-port=5001/tcp --zone=internal --permanent
sudo firewall-cmd --add-port=5001/tcp --zone=public   --permanent
sudo firewall-cmd --add-service=http  --permanent
sudo firewall-cmd --reload

sudo htpasswd -bBc /opt/registry2/auth/htpasswd test2 test2

sudo cp registry-config2.yml /opt/registry2/.
sudo cp server-key.pem server-key2.pem
sudo cp server-key2.pem /opt/registry2/certs/.
sudo cp server.pem server2.pem
sudo cp server2.pem /opt/registry2/certs/.
sudo cp /opt/registry2/certs/server2.pem /etc/pki/ca-trust/source/anchors/
sudo cp ca2.pem /etc/pki/ca-trust/source/anchors/

sudo update-ca-trust extract

# Now that certs are in place, run the local image registry as a service
sudo bash -c 'cat << EOF > /etc/systemd/system/ops-registry.service
[Unit]
Description=ops registry (ops-registry)
After=network.target

[Service]
Type=simple
TimeoutStartSec=5m

ExecStartPre=-/usr/bin/podman rm "ops-registry"
ExecStartPre=/usr/bin/podman pull quay.io/dmoessne/registry:2
ExecStart=/usr/bin/podman run --name ops-registry --net host \
  -v /opt/registry2/data:/var/lib/registry:z \
  -v /opt/registry2/auth:/auth:z \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_HTTP_ADDR=0.0.0.0:5001" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
  -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -v /opt/registry2/certs:/certs:z \
  -v /opt/registry2/registry-config2.yml:/etc/docker/registry/config.yml:z \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server2.pem \
  -e REGISTRY_HTTP_TLS_KEY=/certs/server-key2.pem \
  quay.io/dmoessne/registry:2
  
ExecReload=-/usr/bin/podman stop "ops-registry"
ExecReload=-/usr/bin/podman rm "ops-registry"
ExecStop=-/usr/bin/podman stop "ops-registry"
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF'


sudo systemctl --system daemon-reload
sudo systemctl enable --now ops-registry.service


popd
rm -rf create-registry-certs
sleep 5
curl -u test2:test2 https://"${HOSTNAME}":5001/v2/_catalog

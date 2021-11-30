i#!/bin/bash
set -euxo pipefail

sudo yum install -y firewalld squid vim wget unzip openssl python3 bind-utils
sudo alternatives --set python /usr/bin/python3

sudo systemctl enable firewalld --now
sudo firewall-cmd --add-port=3128/tcp --permanent
sudo firewall-cmd --add-port=3128/tcp

sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.orig
cat << EOF > /tmp/squid.conf
acl SSL_ports port 443
# Ports where clients can connect to.
acl Safe_ports port 80		# http
acl Safe_ports port 443		# https
acl CONNECT method CONNECT
acl allowlist dstdomain "/etc/squid/sites.allowlist.txt"

# if connection is not to any of this port, Sqiud rejects. otherwise check the next rule.
http_access deny !Safe_ports

# Squid cache manager app
http_access allow localhost manager
http_access deny manager

# localhost is allowed. if source is not localhost, squid checks the next rule
http_access allow localhost

# we only want to trust whitelieted pages 
#http_access allow all
http_access allow allowlist

# IMPORTANT LINE: deny anything that's not allowed above
http_access deny all

# listen on this port as a proxy
http_port 3128

# memory settings
cache_mem 512 MB
coredump_dir /var/spool/squid3

refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern ^gopher:	1440	0%	1440
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0 # refresh_pattern [-i] regex min percent max [options]
# here, . means 'any link'. Cache for at least 0, at most 20160 minutes, ot 50% of its age since 'last-modified' header.
refresh_pattern .		0	50%	20160

# delete x-forwarded-for header in requests (anonymize them)
forwarded_for delete

EOF

sudo cp /tmp/squid.conf /etc/squid/squid.conf

cat << EOF > /tmp/sites.allowlist.txt
# just allowed sites/domains
# .google.com for proxy probe
.google.com
# needed for AWS connection stuff if done the way used here to setup env
.amazonaws.com
EOF

sudo cp /tmp/sites.allowlist.txt /etc/squid/sites.allowlist.txt

sudo systemctl enable squid --now

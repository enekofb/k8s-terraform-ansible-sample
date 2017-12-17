#!/bin/bash

yum install -y nc
curl -o - https://bootstrap.pypa.io/get-pip.py | python
pip install -q awscli
server_name=$(aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=$(curl -s -o - http://169.254.169.254/latest/meta-data/instance-id)" "Name=tag-key,Values=Name" --query 'Tags[*].Value' --output text)
domain=$(aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=$(curl -s -o - http://169.254.169.254/latest/meta-data/instance-id)" "Name=tag-key,Values=Domain" --query 'Tags[*].Value' --output text)

hostname $${server_name}.$${domain}
echo "$${server_name}.$${domain}" > /etc/hostname
echo "127.0.0.1   $${server_name}.$${domain} $${server_name}" >> /etc/hosts

# Put the public key of our user CA in place.
cat << EOF > /etc/ssh/users_ca.pub
${users_ca_publickey}
EOF

# Ensure the centos user is the only user that can be accessed via certificate
cat << EOF > /etc/ssh/authorized_principals
ubuntu
EOF

# Line return is important!
cat << EOF >> /etc/ssh/sshd_config

TrustedUserCAKeys /etc/ssh/users_ca.pub
AuthorizedPrincipalsFile  /etc/ssh/authorized_principals
EOF

# Restart the ssh server
service sshd restart


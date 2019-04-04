#!/bin/bash

# no need to sudo su, EC2 user-data scripts are run as root
# update the image
yum update -y
# install Maria (MySQL fork)
yum install -y mariadb-server
service mariadb start
# install Java (Amazon Corretto 8)
# enable the corretto repo
amazon-linux-extras enable corretto8
# install the JDK, not the JRE
yum install -y java-1.8.0-amazon-corretto-devel
# setup the docker compose service definition
mkdir /srv/app
curl -o /srv/app/app.jar https://s3.amazonaws.com/acg-cors.kevinbaynes.com/public-jars/hello-0.0.4.jar
# make the ec2 user the owner of the app service folder
chown -R ec2-user: /srv/app
# map calls to port 80 on this machine to port 8080, where the java-app is listening
# otherwise, if we try to run java-app on port 80, it must be run as root (security problem)
# iptables are not persistent - see setup-iptables.sh
# download iptables mapping script
curl -o /srv/app/setup-iptables.sh https://raw.githubusercontent.com/kbaynes/ec2-l2-java-mariadb/master/setup-iptables.sh
# run the mapping
/bin/bash /srv/app/setup-iptables.sh
# set a cron to re-run the mapping on reboot (works on Amazon Linux 2)
(crontab -l 2>/dev/null; echo "@reboot /bin/bash /srv/app/setup-iptables.sh") | crontab -
# setup systemd unit file to run compose app as a service
curl -o /etc/systemd/system/java-app.service https://raw.githubusercontent.com/kbaynes/ec2-l2-java-mariadb/master/app.service
systemctl enable java-app

systemctl start java-app
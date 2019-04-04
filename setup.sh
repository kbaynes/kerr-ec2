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
# setup the app location and download the jar - runs Tomcat on 8080
mkdir /srv/app
curl -o /srv/app/app.jar https://s3.amazonaws.com/acg-cors.kevinbaynes.com/public-jars/hello-0.0.4.jar
# make the ec2 user the owner of the app service folder
chown -R ec2-user: /srv/app
# map calls to port 80 on this machine to port 8080, where the java-app is listening
# otherwise, if we try to run java-app on port 80, it must be run as root (security problem)
# setup systemd unit file to run iptable mapping as a service (iptables are not persistent)
curl -o /etc/systemd/system/java-app-onstartup.service https://raw.githubusercontent.com/kbaynes/ec2-l2-java-mariadb/master/app-onstartup.service
systemctl enable java-app-onstartup
systemctl start java-app-onstartup
# setup systemd unit file to run compose app as a service
curl -o /etc/systemd/system/java-app.service https://raw.githubusercontent.com/kbaynes/ec2-l2-java-mariadb/master/app.service
systemctl enable java-app
systemctl start java-app

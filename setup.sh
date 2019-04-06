#!/bin/bash

# no need to sudo su, EC2 user-data scripts are run as root
# update the image
yum update -y
# install Maria (MySQL replacement)
yum install -y mariadb-server
service mariadb start
systemctl enable mariadb
# allow for maria to startup then secure maria last in script
# install Java (Amazon Corretto 8)
# enable the corretto repo
amazon-linux-extras enable corretto8
# install the JDK, not the JRE
yum install -y java-1.8.0-amazon-corretto-devel
# setup the app location and download the jar - runs Tomcat on 8080
mkdir /srv/app
curl -o /srv/app/app.jar https://s3.amazonaws.com/acg-cors.kevinbaynes.com/public-jars/simple-spring-data-jpa-mysql-0.0.1.jar
curl -o /srv/app/app-onstartup.sh https://raw.githubusercontent.com/kbaynes/ec2-l2-java-mariadb/master/app-onstartup.sh
# make the ec2 user the owner of the app service folder
chown -R ec2-user: /srv/app
# map calls to port 80 on this machine to port 8080, where the java-app is listening
# otherwise, if we try to run java-app on port 80, it must be run as root (security problem)
# setup systemd unit file to run iptable mapping as a service (iptables are not persistent)
curl -o /etc/systemd/system/java-app-onstartup.service https://raw.githubusercontent.com/kbaynes/ec2-l2-java-mariadb/master/app-onstartup.service
systemctl enable java-app-onstartup
systemctl start java-app-onstartup
# setup systemd unit file to run spring boot app as a service
curl -o /etc/systemd/system/java-app.service https://raw.githubusercontent.com/kbaynes/ec2-l2-java-mariadb/master/app.service
systemctl enable java-app
systemctl start java-app
# secure Maria : Change root password and only allow root access from localhost
# create a DB called 'app_db' and a user 'app_user' with full permissions
# allow remote access by app_user, with full permissions to app_db
db_root_password="RootSecretPassword"
app_user_password="UserSecretPassword"
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('$db_root_password') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
CREATE DATABASE app_db;
USE app_db;
CREATE USER 'app_user' IDENTIFIED BY '$app_user_password';
GRANT ALL PRIVILEGES ON app_db.* TO 'app_user'@'%' WITH GRANT OPTION;
CREATE TABLE notes (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  note VARCHAR(255) NOT NULL,
  date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO notes (note) VALUES ('My first note! Ah, I remember it well.');
INSERT INTO notes (note) VALUES ('A hotdog is a sandwich.');
INSERT INTO notes (note) VALUES ('Dear Diary: skipped over a nope rope and petted a floof.');
INSERT INTO notes (note) VALUES ('The Cake is a LIE!');
INSERT INTO notes (note) VALUES ('Dear Diary: So many things have happened since my first note. How naive I was then!');
FLUSH PRIVILEGES;
EOF

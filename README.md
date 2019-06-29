# Kerr Lake Data Server

## Overview

This server performs hourly batch operations to generate data for [Lake-Data.com](http://lake-data.com) for Kerr Lake in NC/VA and is triggered to start up once per hour via CloudWatch event. It downloads the file at 
[http://epec.saw.usace.army.mil/dsskerr.txt](http://epec.saw.usace.army.mil/dsskerr.txt) to S3. Next the application checks the S3 location for any new raw files and processes all files (one or more) and stores the data in the local MariaDB. It then generates JSON data which is stored on S3 and served up with the [Lake-Data.com](http://lake-data.com) site. Then it shuts itself down and awaits the next wakeup call from the CloudWatch event. This is to minimize compute time costs in AWS.

This repo provides the setup of the server, which simply runs a jar on startup. The code for the Spring Boot application jar which performs a set of  operations is available in the [kerr-batch](https://github.com/kbaynes/kerr-batch) repo.

This project provides easy setup of an AWS EC2 Linux 2 AMI instance, which runs a Java Spring Boot jar which connects to a MariaDB instance running the same server. It was cloned from the repo [kbaynes/ec2-l2-java-mariadb](https://github.com/kbaynes/ec2-l2-java-mariadb) To get started fast, skip to the *EC2 Setup* section.

## Goal

The goal of this project is to provide batch processing of data to be supplied to [Lake-Data.com](http://lake-data.com) for Kerr Lake in NC/VA.

## Motivation

The motivation is to have updated information about Kerr Lake in NC/VA which can be supplied to the web application.

## Setup Overview

Setup is performed via setup.sh, used during EC2 instance launching at Configure Instance Details > Advanced Details > User Data. The file can be uploaded directly, or copied and pasted as text into the input field. This script updates the image, installs MariaDB and Java, and then sets up some services. [MariaDB](https://aws.amazon.com/rds/mariadb/) is used because it is a drop in replacement for MySQL and is easy to install on the Linux 2 AMI and provides a clear path to move the data layer to other AWS services such as [Aurora](https://aws.amazon.com/rds/aurora/). [Amazon Corretto](https://aws.amazon.com/corretto/) is used because it is a no-cost OpenJDK build used and supported by Amazon, and is easily installable.

Setup downloads four files: app.service, app-onstartup.service, app-onstartup.sh, and the [kerr-batch](https://github.com/kbaynes/kerr-batch) Spring Boot application jar. It creates a /srv/app directory and downloads all files into that directory.

The app.service unit file runs the application jar on startup.

The app-onstartup.service runs the app-onstartup.sh shell script on startup. The onstartup portion is necessary to avoid running the application jar as root. They can be omitted, if the app.service user is set to root, rather than ec2-user. The app-onstartup.sh script simply creates an iptables route that maps all calls on port 80 to port 8080, which is where the application is listening. This allows the ec2-user to run the application at startup, because to run the app on port 80 requires the root user. This configuration is a bit more elaborate, but is more secure. Theoretically, it is possible to persist the iptables by loading them with a crontab @reboot, or a line in rc.local, but the systemd unit solution is simple and robust on systemd (modern) systems.

Using the app-onstartup script it should be simple to map calls on alternate ports to the ssh (22) and mysql (3306) ports, then configure the security group to expose the alternate ports rather than the standard ports, for a bit of extra security.

Setup also secures MariaDB by setting the root user (MariaDB root user, not system root user) user password, and limiting root access to localhost. It then removes the test user and test DB, and creates a DB called 'app_db', and a user called 'app_user', which has full access to app_db. Keep the passwords as defined or the application will fail to connect.

## EC2 Setup

To use this setup script on Amazon EC2:
- Click Launch Instance and select the Amazon Linux 2 AMI instance (tested with 64-bit x86)
- Select a type (tested with t2.micro: Variable ECUs, 1 vCPUs, 2.5 GHz, Intel Xeon Family, 1 GiB memory, EBS only), click Next
- On Configure Instance Details, expand the Advanced Details section at the bottom, copy the contents of setup.sh into the User Data input field or select 'as file' and select the setup.sh file, then keep clicking Next
- On Configure Security Group: Do not use 'Default Security Group' because it does not have any open ports. Create a Security Group in EC2 and open ports 80 (web), 22 (ssh) and 3306 (mysql). The wizard on this page makes it easy if you do not already have a Security Group for these types of instances. I use MyDefaultDMZ security group which has these ports open by default.
- Click Review and Launch, then Launch. It's easiest if you have a default SSH key pair configured so you can simply select it from the dropdown.

Initial setup until the app was running was about 2 minutes. The application runs a set of operations then shuts down the instance. Confirm that the instance ran by checking the CloudWatch logs.

By my tests, the server rebooted and the app was running again in about 30 seconds.

If you have Security Group configured and default SSH keys configured, then it should be possible have a running applicaition server in less than 5 minutes.

### Notes

Good [StackOverflow answer](https://stackoverflow.com/questions/21503883/spring-boot-application-as-a-service/22121547#22121547) for setting up a systemd unit file.

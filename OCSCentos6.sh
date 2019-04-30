#!/bin/bash

#Initializing var
if [[ "$USER" != 'root' ]]; then
	echo "Run this script with root privileges."
	exit
fi

if [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
	OS=centos
	RCLOCAL='/etc/rc.d/rc.local'
	chmod +x /etc/rc.d/rc.local
else
	echo "This script installer only works on Centos system."
	exit
fi

#Requirement
yum -y update && yum -y install curl

# Checking Status
MYIP=$(curl -4 icanhazip.com)

# go to root
cd

#Start Installing
clear
echo ""
echo ""
echo ""
echo "Configure Database OCS Panel Name"
echo "(Make sure the database name contains no spaces, symbols, or special characters.)"
read -p "Database Name    : " -e -i OCSShigeno NamaDatabase
echo "Input MySQL Password:"
echo "(Use different Password for your database, dont use VPS password.)"
read -p "Database Password: " -e -i shigeno PasswordDatabase
echo ""
echo "All questions have been answered."
read -n1 -r -p "Press any key to continue ..."

#Set Repo
cd
wget http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
rpm -Uvh epel-release-6-8.noarch.rpm
rpm -Uvh remi-release-6.rpm

if [ "$OS" == "x86_64" ]; then
  wget https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
  rpm -Uvh rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
else
  wget https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/rpmforge-release-0.5.3-1.el6.rf.i686.rpm
  rpm -Uvh rpmforge-release-0.5.3-1.el6.rf.i686.rpm
fi

sed -i 's/enabled = 1/enabled = 0/g' /etc/yum.repos.d/rpmforge.repo
sed -i -e "/^\[remi\]/,/^\[.*\]/ s|^\(enabled[ \t]*=[ \t]*0\\)|enabled=1|" /etc/yum.repos.d/remi.repo
rm -f *.rpm

# update
yum -y update
yum -y groupinstall 'Development Tools' && yum -y install cmake && yum -y install expect-devel
	
#Install MySQL & Create Database
yum -y install mysql-server
chown -R mysql:mysql /var/lib/mysql/
chmod -R 755 /var/lib/mysql/
chkconfig mysqld on
service mysqld start
#mysql_secure_installation
so1=$(expect -c "
spawn mysql_secure_installation; sleep 3
expect \"\";  sleep 3; send \"\r\"
expect \"\";  sleep 3; send \"Y\r\"
expect \"\";  sleep 3; send \"$PasswordDatabase\r\"
expect \"\";  sleep 3; send \"$PasswordDatabase\r\"
expect \"\";  sleep 3; send \"Y\r\"
expect \"\";  sleep 3; send \"Y\r\"
expect \"\";  sleep 3; send \"Y\r\"
expect \"\";  sleep 3; send \"Y\r\"
expect eof; ")
echo "$so1"
#\r
#Y
#pass
#pass
#Y
#Y
#Y
#Y
so2=$(expect -c "
spawn mysql -u root -p; sleep 3
expect \"\";  sleep 3; send \"$PasswordDatabase\r\"
expect \"\";  sleep 3; send \"CREATE DATABASE IF NOT EXISTS $NamaDatabase;EXIT;\r\"
expect eof; ")
echo "$so2"
#pass
#CREATE DATABASE IF NOT EXISTS OCS_PANEL;EXIT;

#Install Webserver
yum -y install nginx php php-fpm php-cli php-mysql php-mcrypt
rm -f /usr/share/nginx/html/index.html

cat > /etc/nginx/nginx.conf <<END3
user www-data;

worker_processes 1;
pid /var/run/nginx.pid;

events {
	multi_accept on;
  worker_connections 1024;
}

http {
	gzip on;
	gzip_vary on;
	gzip_comp_level 5;
	gzip_types    text/plain application/x-javascript text/xml text/css;

	autoindex on;
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  server_tokens off;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;
  client_max_body_size 32M;
	client_header_buffer_size 8m;
	large_client_header_buffers 8 8m;

	fastcgi_buffer_size 8m;
	fastcgi_buffers 8 8m;

	fastcgi_read_timeout 600;

  include /etc/nginx/conf.d/*.conf;
}
END3
sed -i 's/www-data/nginx/g' /etc/nginx/nginx.conf
mkdir -p /home/vps/public_html
wget -O /home/vps/public_html/index.html "http://script.hostingtermurah.net/repo/index.html"
echo "<?php phpinfo(); ?>" > /home/vps/public_html/info.php
rm /etc/nginx/conf.d/*
args='$args'
uri='$uri'
document_root='$document_root'
fastcgi_script_name='$fastcgi_script_name'
cat > /etc/nginx/conf.d/vps.conf <<END4
server {
  listen       85;
  server_name  127.0.0.1 localhost;
  access_log /var/log/nginx/vps-access.log;
  error_log /var/log/nginx/vps-error.log error;
  root   /home/vps/public_html;

  location / {
    index  index.html index.htm index.php;
    try_files $uri $uri/ /index.php?$args;
  }

  location ~ \.php$ {
    include /etc/nginx/fastcgi_params;
    fastcgi_pass  127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
  }
}

END4
sed -i 's/apache/nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/;session.save_path = "/tmp"/session.save_path = "/tmp"/g' /etc/php.ini

useradd -m vps && mkdir -p /home/vps/public_html
rm -f /home/vps/public_html/index.html && echo "<?php phpinfo() ?>" > /home/vps/public_html/info.php
chown -R nginx:nginx /home/vps/public_html
chown nginx:nginx /var/lib/php/session
chmod -R +rw /home/vps/public_html
chmod -R +rw /home/vps/public_html/*
chmod -R +rx /home/vps
chkconfig nginx on
chkconfig php-fpm on
		
service php-fpm restart
service nginx restart

#Install zip shigeno Script
yum -y install zip unzip
cd /home/vps/public_html
wget https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/OCSPanelCentos6.zip
unzip OCSPanelCentos6.zip
rm -f OCSPanelCentos6.zip
chown -R nginx:nginx /home/vps/public_html
chmod -R +rw /home/vps/public_html
chmod 777 /home/vps/public_html/config
chmod 777 /home/vps/public_html/config/inc.php
chmod 777 /home/vps/public_html/config/route.php

# OCS Panel Configuration
clear
echo "Configuration on VPS is done!"
echo "Now you have to configure OCS Panel through your browser!"
echo "Open Your Browser, go to http://$MYIP:85"
echo "Input the details of your Database"
echo "-----"
echo "Database:"
echo "- Database Host: localhost"
echo "- Database Name: $NamaDatabase"
echo "- Database User: root"
echo "- Database Pass: $PasswordDatabase"
echo ""
echo "Admin Login:"
echo "- Username: (Username of the OCS admin you like)"
echo "- Password: (password for OCS Admin Panel)"
echo "- Re-Enter Password: (Re-enter password)"
echo ""
echo "Press the Install button on the OCS Panel, and wait for the installation to complete."
echo "If you installed via browser, back to putty/juicessh, and then press [ENTER]!"
sleep 3
echo ""
read -p "If the above step has been done, please Press [Enter] key to continue... "
echo ""

#Delete Folder Install
rm -fR /home/vps/public_html/installation

#Delete History
cd
rm -f /root/.bash_history && history -c
rm -f /etc/sistem/secure/panel.sh
echo "unset HISTFILE" >> /etc/profile

# info
clear
echo ""
echo "--------------------------------------------------------------------------------"| tee -a log-install-ocspanel.txt
echo "Installing OCS Panel successfully done!" 								| tee -a log-install-ocspanel.txt
echo "Please login to your OCS Panels" 								| tee -a log-install-ocspanel.txt
echo "URL: http://$MYIP:85/" 											| tee -a log-install-ocspanel.txt
echo "Username: (Use the username you have input in the browser)" 	| tee -a log-install-ocspanel.txt
echo "Password: (Use the password you have input in the browser)"    | tee -a log-install-ocspanel.txt
echo "" 																| tee -a log-install-ocspanel.txt
echo "Installatin Log: /root/log-install-ocspanel.txt" 				| tee -a log-install-ocspanel.txt
echo "--------------------------------------------------------------------------------"| tee -a log-install-ocspanel.txt
echo "Copyright https://www.HostingTermurah.net"  						| tee -a log-install-ocspanel.txt
echo "Script Created By Steven Indarto(fb.com/stevenindarto2)"   		| tee -a log-install-ocspanel.txt
echo "Modified by shigeno"                      	                 	| tee -a log-install-ocspanel.txt
echo "--------------------------------------------------------------------------------"| tee -a log-install-ocspanel.txt
echo ""
echo ""
cd

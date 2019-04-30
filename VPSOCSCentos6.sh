#!/bin/bash
# Script By Urabe
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

# disable se linux
echo 0 > /selinux/enforce
sed -i 's/SELINUX=enforcing/SELINUX=disable/g'  /etc/sysconfig/selinux

# set time GMT +7
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
service sshd restart

# disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.d/rc.local

#Add DNS Server ipv4
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
sed -i '$ i\echo "nameserver 8.8.8.8" > /etc/resolv.conf' /etc/rc.local
sed -i '$ i\echo "nameserver 8.8.4.4" >> /etc/resolv.conf' /etc/rc.local
sed -i '$ i\echo "nameserver 8.8.8.8" > /etc/resolv.conf' /etc/rc.d/rc.local
sed -i '$ i\echo "nameserver 8.8.4.4" >> /etc/resolv.conf' /etc/rc.d/rc.local

# install wget and curl
yum -y install wget curl

#Start Installing
clear
echo ""
echo ""
echo ""
echo "Configure Database OCS Panel Name"
echo "(Make sure the database name contains no spaces, symbols, or special characters.)"
read -p "Database Name    : " -e -i OCSurabe NamaDatabase
echo "Input MySQL Password:"
echo "(Use different Password for your database, dont use VPS password.)"
read -p "Database Password: " -e -i Passurabe PasswordDatabase
echo ""
echo "All questions have been answered."
read -n1 -r -p "Press any key to continue ..."

# update
yum -y update

# install webserver
yum -y install nginx php-fpm php-cli
service nginx restart
service php-fpm restart
chkconfig nginx on
chkconfig php-fpm on

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

# remove unused
yum -y remove sendmail;
yum -y remove httpd;
yum -y remove cyrus-sasl


# update
yum -y update
yum -y groupinstall 'Development Tools' && yum -y install cmake && yum -y install expect-devel

# install essential package
yum -y install wondershaper rrdtool screen iftop htop nmap bc nethogs openvpn vnstat ngrep mtr git zsh mrtg unrar rsyslog rkhunter mrtg net-snmp net-snmp-utils expect nano bind-utils
yum -y groupinstall 'Development Tools'
yum -y install cmake

yum -y --enablerepo=rpmforge install axel sslh ptunnel unrar

# disable exim
service exim stop
chkconfig exim off
	
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

# setting vnstat
vnstat -u -i eth0
echo "MAILTO=root" > /etc/cron.d/vnstat
echo "*/5 * * * * root /usr/sbin/vnstat.cron" >> /etc/cron.d/vnstat
service vnstat restart
chkconfig vnstat on

# install screenfetch
cd
wget -O /usr/bin/screenfetch "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/screenfetch"
chmod +x /usr/bin/screenfetch
echo "clear" >> .bash_profile
echo "screenfetch" >> .bash_profile

# install openvpn
wget -O /etc/openvpn/openvpn.tar "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/openvpn-centos.tar"
cd /etc/openvpn/
tar xf openvpn.tar
wget -O /etc/openvpn/1194.conf "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/1194-centos.conf"
if [ "$OS" == "x86_64" ]; then
  wget -O /etc/openvpn/1194.conf "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/1194-centos64.conf"
fi
wget -O /etc/iptables.up.rules "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/iptables.up.rules"
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.local
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.d/rc.local
MYIP=`dig +short myip.opendns.com @resolver1.opendns.com`;
MYIP2="s/xxxxxxxxx/$MYIP/g";
sed -i $MYIP2 /etc/iptables.up.rules;
sed -i 's/venet0/eth0/g' /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
sysctl -w net.ipv4.ip_forward=1
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
service openvpn restart
chkconfig openvpn on
cd

# configure openvpn client config
cd /etc/openvpn/
wget -O /etc/openvpn/client.ovpn "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/open-vpn.conf"
sed -i $MYIP2 /etc/openvpn/client.ovpn;
cp client.ovpn /home/vps/public_html/
cd

# install badvpn
wget -O /usr/bin/badvpn-udpgw "https://raw.github.com/arieonline/autoscript/master/conf/badvpn-udpgw"
sed -i '$ i\screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300' /etc/rc.local
sed -i '$ i\screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300' /etc/rc.d/rc.local
chmod +x /usr/bin/badvpn-udpgw
screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300

# install mrtg
cd /etc/snmp/
wget -O /etc/snmp/snmpd.conf "https://raw.github.com/arieonline/autoscript/master/conf/snmpd.conf"
wget -O /root/mrtg-mem.sh "https://raw.github.com/arieonline/autoscript/master/conf/mrtg-mem.sh"
chmod +x /root/mrtg-mem.sh
service snmpd restart
chkconfig snmpd on
snmpwalk -v 1 -c public localhost | tail
mkdir -p /home/vps/public_html/mrtg
cfgmaker --zero-speed 100000000 --global 'WorkDir: /home/vps/public_html/mrtg' --output /etc/mrtg/mrtg.cfg public@localhost
curl "https://raw.github.com/arieonline/autoscript/master/conf/mrtg.conf" >> /etc/mrtg/mrtg.cfg
sed -i 's/WorkDir: \/var\/www\/mrtg/# WorkDir: \/var\/www\/mrtg/g' /etc/mrtg/mrtg.cfg
sed -i 's/# Options\[_\]: growright, bits/Options\[_\]: growright/g' /etc/mrtg/mrtg.cfg
indexmaker --output=/home/vps/public_html/mrtg/index.html /etc/mrtg/mrtg.cfg
echo "0-59/5 * * * * root env LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg" > /etc/cron.d/mrtg
LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
cd

# setting port ssh
echo "Port 143" >> /etc/ssh/sshd_config
echo "Port  22" >> /etc/ssh/sshd_config
service sshd restart
chkconfig sshd on

# install dropbear
yum -y install dropbear
echo "OPTIONS=\"-p 109 -p 110 -p 442\"" > /etc/sysconfig/dropbear
echo "/bin/false" >> /etc/shells
service dropbear restart
chkconfig dropbear on

# install vnstat gui
cd /home/vps/public_html/
wget http://www.sqweek.com/sqweek/files/vnstat_php_frontend-1.5.1.tar.gz
tar xf vnstat_php_frontend-1.5.1.tar.gz
rm vnstat_php_frontend-1.5.1.tar.gz
mv vnstat_php_frontend-1.5.1 vnstat
cd vnstat
sed -i 's/eth0/venet0/g' config.php
sed -i "s/\$iface_list = array('venet0', 'sixxs');/\$iface_list = array('venet0');/g" config.php
sed -i "s/\$language = 'nl';/\$language = 'en';/g" config.php
sed -i 's/Internal/Internet/g' config.php
sed -i '/SixXS IPv6/d' config.php
cd

# install fail2ban
yum -y install fail2ban
service fail2ban restart
chkconfig fail2ban on

# install squid
yum -y install squid
wget -O /etc/squid/squid.conf "https://raw.github.com/arieonline/autoscript/master/conf/squid-centos.conf"
sed -i $MYIP2 /etc/squid/squid.conf;
service squid restart
chkconfig squid on

# install stunnel
yum install stunnel
wget -O /etc/pki/tls/certs/stunnel.pem "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/stunnel.pem"
wget -O /etc/stunnel/stunnel.conf "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/stunnel.conf"
mkdir /var/run/stunnel
chown nobody:nobody /var/run/stunnel
stunnel /etc/stunnel/stunnel.conf

# install ddos deflate
cd
yum -y install dnsutils dsniff
wget https://github.com/jgmdev/ddos-deflate/archive/master.zip
unzip master.zip
cd ddos-deflate-master
./install.sh
rm -rf /root/master.zip

# setting banner
rm /etc/issue.net
wget -O /etc/issue.net "https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/issue.net"
sed -i 's@#Banner@Banner@g' /etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/issue.net"@g' /etc/default/dropbear
service ssh restart
service dropbear restart

# install webmin
cd
wget http://prdownloads.sourceforge.net/webadmin/webmin-1.660-1.noarch.rpm
rpm -i webmin-1.660-1.noarch.rpm;
rm webmin-1.660-1.noarch.rpm
service webmin restart
chkconfig webmin on

# Setting IPtables
cat > /etc/iptables.up.rules <<-END
*filter
:FORWARD ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i eth0 -o ppp0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i ppp0 -o eth0 -j ACCEPT
-A OUTPUT -d 23.66.241.170 -j DROP
-A OUTPUT -d 23.66.255.37 -j DROP
-A OUTPUT -d 23.66.255.232 -j DROP
-A OUTPUT -d 23.66.240.200 -j DROP
-A OUTPUT -d 128.199.213.5 -j DROP
-A OUTPUT -d 128.199.149.194 -j DROP
-A OUTPUT -d 128.199.196.170 -j DROP
-A OUTPUT -d 103.52.146.66 -j DROP
-A OUTPUT -d 5.189.172.204 -j DROP
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
-A POSTROUTING -s 192.168.100.0/24 -o eth0 -j MASQUERADE
-A POSTROUTING -s 10.1.0.0/24 -o eth0 -j MASQUERADE
COMMIT
END
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.local
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.d/rc.local
iptables-restore < /etc/iptables.up.rules

# install bmon
yum -y install bmon

# download script
cd /usr/local/bin
wget -O menu "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/menu.sh"
wget -O usernew "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/usernew.sh"
wget -O trial "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/trial.sh"
wget -O delete "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/hapus.sh"
wget -O check "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/user-login.sh"
wget -O member "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/user-list.sh"
wget -O restart "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/resvis.sh"
wget -O speedtest "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/speedtest_cli.py"
wget -O info "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/info.sh"
wget -O about "https://raw.githubusercontent.com/Clrkz/VPSAutoScrptz/master/about.sh"

echo "0 0 * * * root /sbin/reboot" > /etc/cron.d/reboot

chmod +x menu
chmod +x usernew
chmod +x trial
chmod +x delete
chmod +x check
chmod +x member
chmod +x restart
chmod +x speedtest
chmod +x info
chmod +x about

# cron
service crond start
chkconfig crond on

# cron
service crond start
chkconfig crond on

#Install zip urabe Script
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

# cron
service crond start
chkconfig crond on

# finalizing
chown -R nginx:nginx /home/vps/public_html
service nginx start
service php-fpm start
service vnstat restart
service openvpn restart
service snmpd restart
service sshd restart
service dropbear restart
service fail2ban restart
service squid restart
service webmin restart
service crond start
chkconfig crond on

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
echo "Copyright 2019"  						| tee -a log-install-ocspanel.txt
echo "Script Created By urabe of PHCorner.net"   		| tee -a log-install-ocspanel.txt
echo "Modified by urabe"                      	                 	| tee -a log-install-ocspanel.txt
echo "--------------------------------------------------------------------------------"| tee -a log-install-ocspanel.txt
echo ""
echo ""
cd

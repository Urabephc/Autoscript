#!/bin/bash
# Original script by urabe of PHC 
# For OCS Panel

if [ $USER != 'root' ]; then
	echo "You must run this as root"
	exit
fi

# initializing var
export DEBIAN_FRONTEND=noninteractive
OS=`uname -m`;

if [[ -e /etc/debian_version ]]; then
	#OS=debian
	RCLOCAL='/etc/rc.local'
else
	echo "You are not running this script on Debian OS"
	exit
fi

vps="vps";

if [[ $vps = "vps" ]]; then
	source="https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript
else
	source="https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript
fi

# go to root
cd

clear
echo ""
echo "I need to ask some questions before starting setup"
echo "You can leave the default option and just hit enter if you agree with the option"
echo ""
echo "First I need to know the new password of MySQL root user:"
read -p "Enter Password: " -e -i urabe DatabasePass
echo ""
echo "Finally, name the Database Name for OCS Panels"
echo " Please, use one word only, no special characters other than Underscore (_)"
read -p " Database Name: " -e -i OCS_PANEL DatabaseName
echo ""
echo "Okay, that's all I need. We are ready to setup your OCS Panel now"
read -n1 -r -p "Press any key to continue..."

wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg|apt-key add -
sleep 2
echo "deb http://build.openvpn.net/debian/openvpn/release/2.4 stretch main" > /etc/apt/sources.list.d/openvpn-aptrepo.list
#Requirement
apt update
apt upgrade -y
apt install openvpn nginx php-fpm stunnel4 squid3 dropbear easy-rsa vnstat ufw build-essential fail2ban zip -y

# initializing var
MYIP=`ifconfig eth0 | awk 'NR==2 {print $2}'`
MYIP2="s/xxxxxxxxx/$MYIP/g";
cd /root
wget "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/plugin.tgz"
wget "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript/menu.zip"

# disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6


# set time GMT +8
ln -fs /usr/share/zoneinfo/Asia/Manila /etc/localtime

# install webmin
cd
wget "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/webmin_1.801_all.deb"
dpkg --install webmin_1.801_all.deb;
apt-get -y -f install;
sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
rm /root/webmin_1.801_all.deb
service webmin restart

# install screenfetch
cd
wget -O /usr/bin/screenfetch "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/screenfetch.sh"
chmod +x /usr/bin/screenfetch
echo "clear" >> .profile
echo "screenfetch" >> .profile

# install dropbear
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=442/g' /etc/default/dropbear
echo "/bin/false" >> /etc/shells

# install squid3
cat > /etc/squid/squid.conf <<-END
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
acl SSH dst xxxxxxxxx-xxxxxxxxx/32
http_access allow SSH
http_access allow manager localhost
http_access deny manager
http_access allow localhost
http_access deny all
http_port 8080
http_port 3128
coredump_dir /var/spool/squid3
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname urabe
END
sed -i $MYIP2 /etc/squid/squid.conf;

# setting banner
rm /etc/issue.net
wget -O /etc/issue.net "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/issue.net"
sed -i 's@#Banner@Banner@g' /etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/issue.net"@g' /etc/default/dropbear
service ssh restart
service dropbear restart

#install OpenVPN
cp -r /usr/share/easy-rsa/ /etc/openvpn
mkdir /etc/openvpn/easy-rsa/keys

# replace bits
sed -i 's|export KEY_COUNTRY="US"|export KEY_COUNTRY="PH"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_PROVINCE="CA"|export KEY_PROVINCE="Rizal"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_CITY="SanFrancisco"|export KEY_CITY="Antipolo"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_ORG="Fort-Funston"|export KEY_ORG="Urabe"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_EMAIL="me@myhost.mydomain"|export KEY_EMAIL="urabevpn@gmail.com"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_OU="MyOrganizationalUnit"|export KEY_OU="urabevpn"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_NAME="EasyRSA"|export KEY_NAME="urabevpn"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_OU=changeme|export KEY_OU=urabevpn|' /etc/openvpn/easy-rsa/vars
#Create Diffie-Helman Pem
openssl dhparam -out /etc/openvpn/dh2048.pem 2048
# Create PKI
cd /etc/openvpn/easy-rsa
cp openssl-1.0.0.cnf openssl.cnf
. ./vars
./clean-all
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" --initca $*
# create key server
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" --server server
# setting KEY CN
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" client
cd
#cp /etc/openvpn/easy-rsa/keys/{server.crt,server.key} /etc/openvpn
cp /etc/openvpn/easy-rsa/keys/server.crt /etc/openvpn/server.crt
cp /etc/openvpn/easy-rsa/keys/server.key /etc/openvpn/server.key
cp /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/ca.crt
chmod +x /etc/openvpn/ca.crt

# Setting Server
tar -xzvf /root/plugin.tgz -C /usr/lib/openvpn/
chmod +x /usr/lib/openvpn/*
cat > /etc/openvpn/server.conf <<-END
port 1194
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
verify-client-cert none
username-as-common-name
plugin /usr/lib/openvpn/plugins/openvpn-plugin-auth-pam.so login
server 192.168.10.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "route-method exe"
push "route-delay 2"
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
log openvpn.log
verb 3
ncp-disable
cipher none
auth none

END
systemctl start openvpn@server
#Create OpenVPN Config
mkdir -p /home/vps/public_html
cat > /home/vps/public_html/client.ovpn <<-END

# Created by urabe
auth-user-pass
client
dev tun
proto tcp
remote $MYIP 1194
persist-key
persist-tun
pull
resolv-retry infinite
nobind
user nobody
comp-lzo
remote-cert-tls server
verb 3
mute 2
connect-retry 5 5
connect-retry-max 8080
mute-replay-warnings
redirect-gateway def1
script-security 2
cipher none
auth none
http-proxy $MYIP 8080
http-proxy-option CUSTOM-HEADER CONNECT HTTP/1.1
http-proxy-option CUSTOM-HEADER Host weixin.qq.cn
http-proxy-option CUSTOM-HEADER X-Forward-Host weixin.qq.cn
http-proxy-option CUSTOM-HEADER Connection: Keep-Alive
http-proxy-option CUSTOM-HEADER Proxy-Connection: keep-alive
END
echo '<ca>' >> /home/vps/public_html/client.ovpn
cat /etc/openvpn/ca.crt >> /home/vps/public_html/client.ovpn
echo '</ca>' >> /home/vps/public_html/client.ovpn

cat > /home/vps/public_html/OpenVPN-Stunnel.ovpn <<-END

# Created by urabe
auth-user-pass
client
dev tun
proto tcp
remote 127.0.0.1 1194
route $MYIP 255.255.255.255 net_gateway
persist-key
persist-tun
pull
resolv-retry infinite
nobind
user nobody
comp-lzo
remote-cert-tls server
verb 3
mute 2
connect-retry 5 5
connect-retry-max 8080
mute-replay-warnings
redirect-gateway def1
script-security 2
cipher none
auth none
END
echo '<ca>' >> /home/vps/public_html/OpenVPN-Stunnel.ovpn
cat /etc/openvpn/ca.crt >> /home/vps/public_html/OpenVPN-Stunnel.ovpn
echo '</ca>' >> /home/vps/public_html/OpenVPN-Stunnel.ovpn

cat > /home/vps/public_html/stunnel.conf <<-END

client = yes
debug = 6

[openvpn]
accept = 127.0.0.1:1194
connect = $MYIP:587
TIMEOUTclose = 0
verify = 0
sni = m.facebook.com
END

# Configure Stunnel
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj '/CN=127.0.0.1/O=localhost/C=PH' -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem
cat > /etc/stunnel/stunnel.conf <<-END

sslVersion = all
pid = /stunnel.pid
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
client = no

[openvpn]
accept = 587
connect = 127.0.0.1:1147
cert = /etc/stunnel/stunnel.pem

[dropbear]
accept = 443
connect = 127.0.0.1:442
cert = /etc/stunnel/stunnel.pem

END

#Setting UFW
ufw allow ssh
ufw allow 1194/tcp
sed -i 's|DEFAULT_INPUT_POLICY="DROP"|DEFAULT_INPUT_POLICY="ACCEPT"|' /etc/default/ufw
sed -i 's|DEFAULT_FORWARD_POLICY="DROP"|DEFAULT_FORWARD_POLICY="ACCEPT"|' /etc/default/ufw

# set ipv4 forward
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf

#Setting IPtables
cat > /etc/iptables.up.rules <<-END
*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -j SNAT --to-source xxxxxxxxx
-A POSTROUTING -o eth0 -j MASQUERADE
-A POSTROUTING -s 192.168.10.0/24 -o eth0 -j MASQUERADE
COMMIT
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:fail2ban-ssh - [0:0]
-A INPUT -p tcp -m multiport --dports 22 -j fail2ban-ssh
-A INPUT -p ICMP --icmp-type 8 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -p tcp --dport 22  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 80  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 143  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 442  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 443  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 587  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 1147  -m state --state NEW -j ACCEPT
-A INPUT -p udp --dport 1147  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 3128  -m state --state NEW -j ACCEPT
-A INPUT -p udp --dport 3128  -m state --state NEW -j ACCEPT
-A INPUT -p tcp --dport 8080  -m state --state NEW -j ACCEPT
-A INPUT -p udp --dport 8080  -m state --state NEW -j ACCEPT 
-A INPUT -p tcp --dport 10000  -m state --state NEW -j ACCEPT
-A fail2ban-ssh -j RETURN
COMMIT
*raw
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
COMMIT
END
sed -i $MYIP2 /etc/iptables.up.rules;
iptables-restore < /etc/iptables.up.rules

# install webserver
cd
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript/nginx.conf"
mkdir -p /home/vps/public_html
echo "<pre>Setup by urabe</pre>" > /home/vps/public_html/index.html
wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript/vps.conf"
service nginx restart

apt-get -y install nginx php php-fpm php-cli php-mysql php-mcrypt
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup 
mv /etc/nginx/conf.d/vps.conf /etc/nginx/conf.d/vps.conf.backup 
wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript/nginx.conf" 
wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript/vps.conf" 
sed -i 's/cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php-fpm/php.ini 
sed -i 's/listen = \/var\/run\/php-fpm.sock/listen = 127.0.0.1:9000/g' /etc/php-fpm/pool.d/www.conf

useradd -m vps
mkdir -p /home/vps/public_html
rm /home/vps/public_html/index.html
rm /home/vps/public_html/index.php
echo "<?php phpinfo() ?>" > /home/vps/public_html/info.php
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html

# Create and Configure rc.local
cat > /etc/rc.local <<-END
#!/bin/sh -e

exit 0
END
chmod +x /etc/rc.local
sed -i '$ i\echo "nameserver 8.8.8.8" > /etc/resolv.conf' /etc/rc.local
sed -i '$ i\echo "nameserver 8.8.4.4" >> /etc/resolv.conf' /etc/rc.local
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.local

# Configure menu
apt-get install unzip
cd /usr/local/bin/
wget "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript/menu.zip" 
unzip menu.zip
chmod +x /usr/local/bin/*

# add eth0 to vnstat
vnstat -u -i eth0

# compress configs
cd /home/vps/public_html
zip configs.zip client.ovpn OpenVPN-Stunnel.ovpn stunnel.conf

# install libxml-parser
apt-get install -y libxml-parser-perl

# finalizing
vnstat -u -i eth0
apt-get -y autoremove
chown -R www-data:www-data /home/vps/public_html
service nginx start
service php7.0-fpm start
service vnstat restart
service openvpn restart
service dropbear restart
service fail2ban restart
service squid restart

#apt-get update
apt-get update -y
apt-get install build-essential expect -y

apt-get install -y mysql-server

#mysql_secure_installation
so1=$(expect -c "
spawn mysql_secure_installation; sleep 3
expect \"\";  sleep 3; send \"\r\"
expect \"\";  sleep 3; send \"Y\r\"
expect \"\";  sleep 3; send \"$DatabasePass\r\"
expect \"\";  sleep 3; send \"$DatabasePass\r\"
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

cd
chown -R mysql:mysql /var/lib/mysql/
chmod -R 755 /var/lib/mysql/

#Install zip
apt-get  install zip
cd /home/vps/public_html
wget "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Debian9/Autoscript/premiumscript/OCS.zip"
unzip OCS.zip
rm -f OCS.zip
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html

#mysql -u root -p
so2=$(expect -c "
spawn mysql -u root -p; sleep 3
expect \"\";  sleep 3; send \"$DatabasePass\r\"
expect \"\";  sleep 3; send \"CREATE DATABASE IF NOT EXISTS $DatabaseName;EXIT;\r\"
expect eof; ")
echo "$so2"
#pass
#CREATE DATABASE IF NOT EXISTS OCS_PANEL;EXIT;

chmod 777 /home/vps/public_html/config
chmod 777 /home/vps/public_html/config/inc.php
chmod 777 /home/vps/public_html/route.php

apt-get -y --force-yes -f install libxml-parser-perl

clear
echo "Open Browser, access http://$MYIP:81 and complete the data as below!"
echo "Database:"
echo "- Database Host: localhost"
echo "- Database Name: $DatabaseName"
echo "- Database User: root"
echo "- Database Pass: $DatabasePass"
echo ""
echo "Admin Login:"
echo "- Username: anything you want"
echo "- Enter Password: anything you want"
echo "- Re-enter New Password: as desired"
echo ""
echo "Click Install and wait for the process to finish, go back to terminal and then press [ENTER key]!"

sleep 3
echo ""
read -p "If the above step has been done, please Press [Enter] key to continue...."
echo ""
read -p "If you really believe the above step has been done, please Press [Enter] key to continue..."
echo ""

cd
rm -f /root/.bash_history && history -c
echo "unset HISTFILE" >> /etc/profile

chmod 755 /home/vps/public_html/config
chmod 644 /home/vps/public_html/config/inc.php
chmod 644 /home/vps/public_html/config/route.php

#clearing history
history -c
rm -rf /root/*
cd /root

# info
clear
echo " "
echo "Installation has been completed!!"
echo "DEVICE WILL REBOOT IN 10 SECONDS"
echo "PLEASE WAIT PATIENTLY AND RELOGIN TO YOUR VPS"
echo " "
echo "--------------------------- Configuration Setup Server -------------------------"
echo "                         Copyright PHCorner.net                          "
echo "                                Modified by urabe                        "
echo "--------------------------------------------------------------------------------"
echo ""  | tee -a log-install.txt
echo "Server Information"  | tee -a log-install.txt
echo "   - Fail2Ban    : [ON]"  | tee -a log-install.txt
echo "   - IPtables    : [ON]"  | tee -a log-install.txt
echo "   - Auto-Reboot : [OFF]"  | tee -a log-install.txt
echo "   - IPv6        : [OFF]"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Application & Port Information"  | tee -a log-install.txt
echo "   - OpenVPN		: TCP 1194 "  | tee -a log-install.txt
echo "   - OpenVPN-Stunnel	: 587 "  | tee -a log-install.txt
echo "   - Dropbear		: 442"  | tee -a log-install.txt
echo "   - Stunnel	: 443"  | tee -a log-install.txt
echo "   - Squid Proxy	: 3128, 8080, 80 (limit to IP Server)"  | tee -a log-install.txt
echo "   - Nginx		: 80"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Premium Script Information"  | tee -a log-install.txt
echo "   To display list of commands: menu"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Important Information"  | tee -a log-install.txt
echo "   - Download Config OpenVPN : http://$MYIP/configs.zip"  | tee -a log-install.txt
echo "   - Installation Log        : cat /root/log-install.txt"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   - Webmin                  : http://$MYIP:10000/"  | tee -a log-install.txt
echo ""
echo "------------------------------ Modified by urabe -----------------------------"
echo "-----Rebooting your VPS -----"
sleep 5
reboot

# setting repo

## Urabe/CentOS 7 64-Bit ##

wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -ivh epel-release-latest-7.noarch.rpm

wget https://rpms.remirepo.net/enterprise/remi-release-7.rpm
rpm -ivh remi-release-7.rpm

# update

yum -y update

# install wget curl nano

yum -y install wget curl
yum -y install nano

# initializing var
OS=`uname -p`;
MYIP=`curl -s ifconfig.me`;
MYIP2="s/xxxxxxxxx/$MYIP/g";

# remove unused

yum -y remove sendmail;
yum -y remove httpd;
yum -y remove cyrus-sasl

# install webserver
yum -y install nginx php-fpm php-cli
systemctl restart nginx
systemctl restart php-fpm
systemctl enable nginx
systemctl enable php-fpm

# install essential package
yum -y install rrdtool screen iftop htop nmap bc nethogs vnstat ngrep mtr git zsh mrtg unrar rsyslog rkhunter mrtg net-snmp net-snmp-utils expect nano bind-utils
yum -y groupinstall 'Development Tools'
yum -y install cmake

yum -y --enablerepo=rpmforge install axel sslh ptunnel unrar

# disable exim
systemctl stop exim
systemctl disable exim

# setting vnstat
vnstat -u -i venet0
echo "MAILTO=root" > /etc/cron.d/vnstat
echo "*/5 * * * * root /usr/sbin/vnstat.cron" >> /etc/cron.d/vnstat
sed -i 's/eth0/venet0/g' /etc/sysconfig/vnstat
systemctl restart vnstat
systemctl enable vnstat

# install screenfetch
cd
wget https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/screenfetch
mv screenfetch /usr/bin/screenfetch
chmod +x /usr/bin/screenfetch
echo "clear" >> .bash_profile
echo "screenfetch" >> .bash_profile

# install webserver
cd
wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/nginx.conf"
sed -i 's/www-data/nginx/g' /etc/nginx/nginx.conf
mkdir -p /home/vps/public_html
echo "<pre>|Setup by urabe | </pre>" > /home/vps/public_html/index.html
echo "<?php phpinfo(); ?>" > /home/vps/public_html/info.php
rm /etc/nginx/conf.d/*
wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/vps.conf"
sed -i 's/apache/nginx/g' /etc/php-fpm.d/www.conf
chmod -R +rx /home/vps
systemctl restart php-fpm
systemctl restart nginx

# install mrtg
cd /etc/snmp/
wget -O /etc/snmp/snmpd.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/snmpd.conf"
wget -O /root/mrtg-mem.sh "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/mrtg-mem.sh"
chmod +x /root/mrtg-mem.sh
systemctl restart snmpd
systemctl enable snmpd
snmpwalk -v 1 -c public localhost | tail
mkdir -p /home/vps/public_html/mrtg
cfgmaker --zero-speed 100000000 --global 'WorkDir: /home/vps/public_html/mrtg' --output /etc/mrtg/mrtg.cfg public@localhost
curl "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/mrtg.conf" >> /etc/mrtg/mrtg.cfg
sed -i 's/WorkDir: \/var\/www\/mrtg/# WorkDir: \/var\/www\/mrtg/g' /etc/mrtg/mrtg.cfg
sed -i 's/# Options\[_\]: growright, bits/Options\[_\]: growright/g' /etc/mrtg/mrtg.cfg
indexmaker --output=/home/vps/public_html/mrtg/index.html /etc/mrtg/mrtg.cfg
echo "0-59/5 * * * * root env LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg" > /etc/cron.d/mrtg
LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
cd

# setting port ssh
sed -i '/Port 22/a Port 444' /etc/ssh/sshd_config
sed -i '/Port 22/a Port  90' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port  22/g' /etc/ssh/sshd_config
systemctl restart sshd
systemctl enable sshd

# install dropbear
yum -y install dropbear
echo "OPTIONS=\"-p 109 -p 110 -p 143\"" > /etc/sysconfig/dropbear
echo "/bin/false" >> /etc/shells
service start dropbear
chkconfig enable dropbear

# install squid
yum -y install squid
wget -O /etc/squid/squid.conf "https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/squid-centos7.conf"
sed -i $MYIP2 /etc/squid/squid.conf;
systemctl restart squid
systemctl enable squid

# install vnstat gui
cd /home/vps/public_html/
wget https://raw.githubusercontent.com/Urabephc/Autoscript/master/Centos7/vnstat_php_frontend-1.5.1.tar.gz
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
systemctl restart fail2ban
systemctl enable fail2ban

# install Webmin
wget https://excellmedia.dl.sourceforge.net/project/webadmin/webmin/1.890/webmin-1.890-1.noarch.rpm
yum -y install perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect
rpm -U webmin-1.890-1.noarch.rpm
systemctl restart webmin
systemctl enable webmin


# download script
cd
wget https://raw.githubusercontent.com/shigeno143/OCSPanelCentos6/master/install-premiumscript.sh -O - -o /dev/null|sh


# cron
systemctl restart crond
systemctl enable crond

# set time GMT +8
ln -fs /usr/share/zoneinfo/Asia/Philippines /etc/localtime

# finalisasi
chown -R nginx:nginx /home/vps/public_html
systemctl restart nginx
systemctl restart php-fpm
systemctl restart vnstat
systemctl restart snmpd
systemctl restart sshd
systemctl restart dropbear
systemctl restart fail2ban
systemctl restart squid
systemctl restart webmin
systemctl restart crond

# info
clear
echo "Setup By urabe" | tee log-install.txt
echo "===============================================" | tee -a log-install.txt
echo "Premium Script Information"  | tee -a log-install.txt
echo "   Type menu to display the command lists"  | tee -a log-install.txt
echo "Service"  | tee -a log-install.txt
echo "-------"  | tee -a log-install.txt
echo "OpenSSH  : 22, 444"  | tee -a log-install.txt
echo "Dropbear : 143"  | tee -a log-install.txt
echo "Squid   : 3128, 8080, 80 (limit to IP SSH)"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Tools"  | tee -a log-install.txt
echo "-----"  | tee -a log-install.txt
echo "axel"  | tee -a log-install.txt
echo "bmon"  | tee -a log-install.txt
echo "htop"  | tee -a log-install.txt
echo "iftop"  | tee -a log-install.txt
echo "mtr"  | tee -a log-install.txt
echo "nethogs"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Script"  | tee -a log-install.txt
echo "------"  | tee -a log-install.txt
echo "screenfetch"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "----------"  | tee -a log-install.txt
echo "Webmin   : http://$MYIP:10000/"  | tee -a log-install.txt
echo "vnstat   : http://$MYIP/vnstat/"  | tee -a log-install.txt
echo "MRTG     : http://$MYIP/mrtg/"  | tee -a log-install.txt
echo "Timezone : Asia/Philippines"  | tee -a log-install.txt
echo "Fail2Ban : [on]"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Log Installasi --> /root/log-install.txt"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Please Reboot Your VPS!"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "==============================================="  | tee -a log-install.txt

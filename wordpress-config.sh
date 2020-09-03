sudo su
yum install -y httpd24 php56 php56-mysqlnd

#Replace the HTTPd Config File
cat << EOF > /etc/httpd/conf/httpd.conf
ServerRoot "/etc/httpd"
Listen 80
Include conf.modules.d/*.conf
User apache
Group apache
ServerAdmin root@localhost
<Directory />
    AllowOverride none
    Require all denied
</Directory>
DocumentRoot "/var/www/html"
<Directory "/var/www">
    AllowOverride None
    Require all granted
</Directory>
<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
<IfModule dir_module>
    DirectoryIndex index.html
</IfModule>
<Files ".ht*">
    Require all denied
</Files>
ErrorLog "logs/error_log"
LogLevel warn
ErrorLogFormat "{\"time\":\"%{%usec_frac}t\", \"function\" : \"[%-m:%l]\",\"process\" : \"[pid%P]\" ,\"message\" : \"%M\"}"
<IfModule log_config_module>/
    LogFormat "{ \"timestamp\" : \"%{%Y-%m-%d}tT%{%T}t.%{msec_frac}tZ\", \"client-ip\" : \"%h\", \"forwarded-ip\" : \"%{X-Forwarded-For}i\", \"request\" : \"%U\", \"query\" : \"%q\", \"method\" : \"%m\", \"status\" : \"%>s\", \"user-agent\" : \"%{User-agent}i\", \"ref\": \"%{Referer}i\", \"bytes-received\" : \"%I\", \"bytes-sent\" : \"%O\", \"ms\" : \"%{ms}T\", \"server-port\" : \"%p\", \"host-name\" : \"%{Host}i\" }" cloudwatch
    CustomLog "logs/access_log" cloudwatch
</IfModule>
<IfModule alias_module>
    ScriptAlias /cgi-bin/ "/var/www/cgi-bin/"
</IfModule>
<Directory "/var/www/cgi-bin">
    AllowOverride None
    Options None
    Require all granted
</Directory>
<IfModule mime_module>
    TypesConfig /etc/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
    AddType text/html .shtml
    AddOutputFilter INCLUDES .shtml
</IfModule>
AddDefaultCharset UTF-8
<IfModule mime_magic_module>
    MIMEMagicFile conf/magic
</IfModule>
EnableSendfile on
IncludeOptional conf.d/*.conf
EOF

service httpd start
chkconfig httpd on
yum install -y vsftpd

# Write the vsftpd config file
cat << EOF > /etc/vsftpd/vsftpd.conf
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
vsftpd_log_file=/var/log/vsftpd.log
log_ftp_protocol=YES
xferlog_std_format=YES
dual_log_enable=YES
connect_from_port_20=YES
chroot_local_user=NO
listen=YES
pam_service_name=vsftpd
tcp_wrappers=YES
local_root=/var/www/
userlist_deny=YES
pasv_enable=YES
pasv_min_port=1024
pasv_max_port=1048
EOF
echo "pasv_address="$(curl -s icanhazip.com) >> /etc/vsftpd/vsftpd.conf
#adduser awsftpuser
echo "root:password123456" | /usr/sbin/chpasswd
sed -i '/root/d' /etc/vsftpd/user_list
sed -i '/root/d' /etc/vsftpd/ftpusers
#echo "awsftpuser:awsftpuser" | /usr/sbin/chpasswd
#usermod -d /var/www awsftpuser
#usermod -a -G root awsftpuser
chmod -R 777 /var/www/*
chown -R root:root /var/www/*
service vsftpd restart
chkconfig --level 345 vsftpd on
yum install -y mysql-server
service mysqld start
chkconfig mysqld on
mysqladmin -uroot create wordpress
mysqladmin -u root password 'password'
echo "<?php phpinfo() ?>"  > /var/www/html/phpinfo.php
cd /var/www/html
wget https://wordpress.org/wordpress-4.4.tar.gz
tar -xzvf wordpress*
cd wordpress
cat << 'EOF' > wp-config.php
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'root');
define('DB_PASSWORD', 'password');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');
$table_prefix  = 'wp_';
define('WP_DEBUG', true);
if ( !defined('ABSPATH') )
        define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
define('FS_METHOD','direct');
EOF
echo '<meta http-equiv="refresh" content="0; url=/wordpress/" />' > /var/www/html/index.html
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
mkdir ~/.aws
echo "[profile AmazonCloudWatchAgent]" > ~/.aws/config
echo "output = json" >> ~/.aws/config
echo "region = us-east-2" >> ~/.aws/config
cat << 'EOF' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
        "agent": {
                "metrics_collection_interval": 60,
                "run_as_user": "root"
        },
        "logs": {
                "logs_collected": {
                        "files": {
                                "collect_list": [
                                        {
                                                "file_path": "/var/log/httpd/access_log",
                                                "log_group_name": "access_log",
                                                "log_stream_name": "{instance_id}"
                                        },
                                        {
                                                "file_path": "/var/log/httpd/error_log",
                                                "log_group_name": "error_log",
                                                "log_stream_name": "{instance_id}"
                                        },
                                        {
                                                "file_path": "/var/log/vsftpd.log",
                                                "log_group_name": "vsftpd_log",
                                                "log_stream_name": "{instance_id}"
                                        },
                                        {
                                                "file_path": "/var/log/audit/audit.log",
                                                "log_group_name": "audit.log",
                                                "log_stream_name": "{instance_id}"
                                        },
                                        {
                                                "file_path": "/var/log/secure",
                                                "log_group_name": "secure",
                                                "log_stream_name": "{instance_id}"
                                        },
                                        {
                                                "file_path": "/var/log/cron",
                                                "log_group_name": "cron",
                                                "log_stream_name": "{instance_id}"
                                        }
                                ]
                        }
                }
        },
        "metrics": {
                "metrics_collected": {
                        "cpu": {
                                "measurement": [
                                        "cpu_usage_idle",
                                        "cpu_usage_iowait",
                                        "cpu_usage_user",
                                        "cpu_usage_system"
                                ],
                                "metrics_collection_interval": 60,
                                "totalcpu": false
                        },
                        "disk": {
                                "measurement": [
                                        "used_percent",
                                        "inodes_free"
                                ],
                                "metrics_collection_interval": 60,
                                "resources": [
                                        "*"
                                ]
                        },
                        "diskio": {
                                "measurement": [
                                        "io_time"
                                ],
                                "metrics_collection_interval": 60,
                                "resources": [
                                        "*"
                                ]
                        },
                        "mem": {
                                "measurement": [
                                        "mem_used_percent"
                                ],
                                "metrics_collection_interval": 60
                        },
                        "swap": {
                                "measurement": [
                                        "swap_used_percent"
                                ],
                                "metrics_collection_interval": 60
                        }
                }
        }
}
EOF
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
# Reboot script to reset WordPress
cat << 'EOF' > ~/reset-wp.sh
#!/bin/bash
echo "Is a load balancer is being used [Y/N]:"
read input
if [ "$input" = "N" ] ; then
        echo "No load balancer is being used"
        WP_URL="http://`curl -s http://169.254.169.254/latest/meta-data/public-hostname/`/wordpress"

elif [ "$input" = "Y" ] ; then
        echo "Ok, a load balancer is being used. Paste in the FQDN of the LB:"
        read ALB
        WP_URL="http://$ALB/wordpress"
else
        echo "invalid input. Aborting"
fi
DB_HOSTNAME=`grep DB_HOST /var/www/html/wordpress/wp-config.php | cut -d ',' -f2 | awk -F "'"  '{ print $2 }'`
DB_USER=root
DB_PWD=password
DB_NAME=wordpress
mysql -u $DB_USER --password=$DB_PWD -h $DB_HOSTNAME $DB_NAME -e "UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='siteurl' OR option_name='home'"
echo "The URL is "$WP_URL
EOF
chmod +x ~/reset-wp.sh
cd /tmp
wget https://downloads.wordpress.org/plugin/sql-table-lookup.zip
unzip sql-table-lookup.zip -d /var/www/html/wordpress/wp-content/plugins/
wget https://downloads.wordpress.org/plugin/gb-gallery-slideshow.1.6.zip
unzip gb-gallery-slideshow.1.6.zip -d /var/www/html/wordpress/wp-content/plugins/
wget https://downloads.wordpress.org/plugin/instant-web-highlighter.4.0.zip
unzip instant-web-highlighter.4.0.zip -d /var/www/html/wordpress/wp-content/plugins/

# Install nmap
yum install -y nmap

# Install the Inspector Agent
wget https://inspector-agent.amazonaws.com/linux/latest/install
bash install
rm -f /tmp/*

# Plant some fake AWS Keys on the System
mkdir /home/ec2-user/.aws
cat <<- EOF4 > /home/ec2-user/.aws/credentials
[default]
aws_access_key_id = AKIAJYSOCJXDYU3RNQFQ
aws_secret_access_key = WnukQBKjg6dc89221LHnupvvlwh96sIc1WNL7vhv
EOF4
chown ec2-user:ec2-user /home/ec2-user/.aws/credentials
cat <<- EOF5 > /home/ec2-user/secret-ec2.pem
-----BEGIN RSA PRIVATE KEY-----
MIIFpQIBAAKCAQEAwGmZkKcdaHvRM3q6ldiwuMzNAeeFSutHmpiLt9igK0vfNuKw
JSZVnkeRwVykSJK6B6zNVYxRpBHXCwDs2EkffvIC0lVb6lJ6XywQLE9jwEJItFdg
cnsa62brj+mJL8Lui1AFElNS59gPJ+1YE7lfw6EM2sRABAqm5NMUSTzcqE7VASVc
BeApG2A9zwZrhR+6ezn2H7BElTtpggvdbH6HOCewMIZy5e6xH5FsK4oPOPIa4+H0
h20TS6/lxlB6vbxttlRG/GUAde05c8pmksDNF5JA+MfLXwn7Eam1mnErB8yHUx4A
Jnx0FWujKI+8slDulDk/EM40rz7s58IZiTPqRwIDAQABAoIBAQCDXNUZ2+4I8ld+
RPDz9s+cKz5faXgoEP9+vVzONFgNlywapaNKiaR0fjo1gBEs9veI2+IH4NewIvnk
qkoI08tr+MASZ3JsRMkFBuk3xy+8B8TpUqonHoLcrvht9SvS7su7UvNTco2seWbH
hJPYS3vk7KQBC3EFEVyl5rH32lRvlsssAoJAeRxWZXWcWL5su9V+IKD/cd40QnJj
OASk2VenVymdBFnxY7w6wxCx5dyElazmW2q6X6uHKWVtcZffqQw7mQPJ34/MvKmb
fi/+qFf+IBfuyfj0ZwzrkQa7U0WmHusxEmMraCOWiTpDCcZnPpo7ni96WFntQBOj
g+6hcceRAoGBAOcU5OPkvbtBrVujqw1nFME5Ha9gUmbHOcYunHOQsfC1bp3echQ+
CkMacpMMojjA4sO1XyEABHC8IDGnQHIQUeuHFu0TqmYvJYOCmo2g/Dsq9tyTg4j5
MNz7yJ3ob66wisGZadxLeWluwD4OYTHmkUKU7a/LEXdrb+QALwGyBLRJAoGBANUp
OndBDwovY0bby+gLXb8Koip+d7xSRhk59eHtKJIW9VNcww4ad+8UGQ4ndMfKZdqD
qc0U+aMfWbYnReCzCnGuCiEpyuTQuXNaig0EaxBYY6zcIIG7weRPsLWUdamIgrjH
DfM5L+SawKbV+BZm5/XchF/PGgFHhxkiHr6HzooPAoGBAICfubQ8O3vC1/r9RBYG
vZ+76hEXXWaGGFt+0GjnLpSceMD486jey5mEXCgLzTQn8VEcYKIev1n87TKWNSII
gYDHRfSakKumLIxiIyMYa62HgbdPiNSyWAd5QrbajWfALswKV8leXWtZUTp5iJJd
E5frC85hCwzcyYAwtfmMnF+5AoGBAJK2PLJlyec1tHvJvi9o204pEHJ09w5cBjlI
pk6ov3rFaHbG6s2jNBcOWyxdxcfZK39ZjZ5EqIk4g7OWlkbQlAioQ/qNXENe0bVu
hIPvHY1zeK86FvmT9CCjJLnlg5J7DZYGEzjrjGYoiR6LOKSakV6sN0QGNBzbUUXg
MQ7sRCDLAoGAfoHiNSKh3rzGGXkVUfnUpTffx5rBWMcosQ0k8JMOGJCk+BO3iwHW
QFAvN6RnOcsaH2gXrzCRGh7ZlwHO6JX4Ggjt/UZ9huWn9TOLkgyzvLEn84ci1hig
NDxp6xUB+1ZinCsDX8Jtv9JgxZ42cq8K2ihkXuJrj/X7Pym9zcJEEKs=
-----END RSA PRIVATE KEY-----
EOF5
chown ec2-user:ec2-user /home/ec2-user/secret-ec2.pem
chmod 400 /home/ec2-user/secret-ec2.pem

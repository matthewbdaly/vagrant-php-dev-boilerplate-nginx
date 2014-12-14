#!/usr/bin/env bash

# Update apt
apt-get -y update && apt-get -y dist-upgrade && apt-get -y autoremove && apt-get -y clean

# Install requirements
apt-get install -y nginx build-essential checkinstall php5-fpm php5-cli php5-mcrypt php5-gd php-apc git sqlite php5-sqlite curl php5-curl php5-dev php-pear php5-xdebug vim-nox msmtp-mta

# Install MySQL
sudo debconf-set-selections <<< 'mysql-server-<version> mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server-<version> mysql-server/root_password_again password root'
sudo apt-get -y install mysql-server php5-mysql

# Setup hosts file
VHOST=$(cat <<'EOF'
server {
        listen   80;
     

        root /var/www/webapp;
        index index.php index.html index.htm;

        server_name example.com;

        location / {
                try_files $uri $uri/ /index.html;
        }

        error_page 404 /404.html;

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
              root /var/www/webapp;
        }

        # pass the PHP scripts to FastCGI server listening on /var/run/php5-fpm.sock
        location ~ \.php$ {
                try_files $uri =404;
                fastcgi_pass unix:/var/run/php5-fpm.sock;
                fastcgi_index index.php;
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                include fastcgi_params;
                
        }

}
EOF
)
echo "${VHOST}" > /etc/nginx/sites-available/default

# Configure XDebug
XDEBUG=$(cat <<EOF
zend_extension=/usr/lib/php5/20100525/xdebug.so
xdebug.profiler_enable=1
xdebug.profiler_output_dir="/tmp"
xdebug.profiler_append=0
EOF
)
echo "${XDEBUG}" > /etc/php5/conf.d/xdebug.ini

# Configure MSMTP
MSMTP=$(cat <<EOF
# ------------------------------------------------------------------------------
# msmtp System Wide Configuration file
# ------------------------------------------------------------------------------

# A system wide configuration is optional.
# If it exists, it usually defines a default account.
# This allows msmtp to be used like /usr/sbin/sendmail.

# ------------------------------------------------------------------------------
# Accounts
# ------------------------------------------------------------------------------

# Main Account
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account default
host smtp.gmail.com
port 587
auth on
from user@gmail.com
user user@gmail.com
password password
logfile /var/log/msmtp.log

# ------------------------------------------------------------------------------
# Configurations
# ------------------------------------------------------------------------------

# Construct envelope-from addresses of the form "user@oursite.example".
#auto_from on
#maildomain fermmy.server

# Use TLS.
#tls on
#tls_trust_file /etc/ssl/certs/ca-certificates.crt

# Syslog logging with facility LOG_MAIL instead of the default LOG_USER.
# Must be done within "account" sub-section above
#syslog LOG_MAIL

# Set a default account

# ------------------------------------------------------------------------------
EOF
)
echo "${MSMTP}" > /etc/msmtprc
touch /var/log/msmtp.log
chmod a+w /var/log/msmtp.log

# Configure PHP to use MSMTP
sudo sed -i "s[^;sendmail_path =.*[sendmail_path = '/usr/bin/msmtp -t'[g" /etc/php5/fpm/php.ini

# Fix a minor security issue
sudo sed -i "s[^cgi.fix_pathinfo=1.*[cgi.fix_pathinfo=0[g" /etc/php5/fpm/php.ini

# Fix another issue
sudo sed -i "s[^listen = .*[listen = /var/run/php5-fpm.sock[g" /etc/php5/fpm/pool.d/www.conf

# Install Composer globally
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Restart web servers
sudo service nginx restart
sudo service php5-fpm restart

# Create the database
mysql -uroot -proot < /var/www/webapp/sql/setup.sql

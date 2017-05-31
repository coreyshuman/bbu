#!/bin/bash

###
# A simple vagrant provisioning script for setting up a wordpress development box.
# Configured to work with Ubuntu 14 "Trusty"
# installs : apache2, php 5.5, mysql-server and client, wordpress
#
# Original by Greg Goforth
# Modified by Corey Shuman 1/24/17 to allow external secrets (passwords etc)
###

# secret variables, can be overriden using "provision-secrets.sh"
# make sure to add new variables to the switch statement below
dbusername="wordpress"
dbpassword="secret"
dbname="wordpress"

# Loop over input arguments and update above secret variables
# (Expecting key=value pairs for each argument)
for var in "$@"
do
    IFS="=" read key value <<< "$var"
    case "$key" in
        # add keys here
        "dbusername") dbusername="$value" ;;
        "dbpassword") dbpassword="$value" ;;
        "dbname") dbname="$value" ;;
    esac
done

# some coloring in outputs.
COLOR="\033[;35m"
COLOR_RST="\033[0m"

#update linux box and making sure it's up to date
echo -e "${COLOR}---updating system---${COLOR_RST}\n"
sudo apt-get -qq update
sudo apt-get upgrade -y  >> /vagrant/vm_build.log 2>&1


# install useful tools
echo -e "${COLOR}---installing some tools: zip,unzip,curl, python-software-properties---${COLOR_RST}\n"
sudo apt-get install -y software-properties-common python-software-properties zip unzip >> /vagrant/vm_build.log 2>&1
sudo apt-get install -y curl build-essential vim git >> /vagrant/vm_build.log 2>&1

# install Mysql
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${dbpassword}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${dbpassword}"
echo -e "${COLOR}---installing MySql---${COLOR_RST}\n"
sudo apt-get install -y mysql-server mysql-client  >> /vagrant/vm_build.log 2>&1

# install Apache
echo -e "${COLOR}---installing Apache---${COLOR_RST}\n"
sudo apt-get install -y apache2  >> /vagrant/vm_build.log 2>&1
# remove default html location and create symlink
sudo rm -rf /var/www/html
sudo ln -fs /vagrant /var/www/html

# install php 5
echo -e "${COLOR}---installing php---${COLOR_RST}\n"
sudo apt-get install -y php5 libapache2-mod-php5 php5-mcrypt php5-curl php5-mysql php5-xdebug php5-gd  >> /vagrant/vm_build.log 2>&1
sudo apt-get install -y php5-mcrypt
sudo php5enmod mcrypt

#install phpMyAdmin
echo -e "${COLOR}---installing phpmyadmin---${COLOR_RST}\n"
debconf-set-selections <<< "phpmyadmin phpmyadmin/internal/skip-preseed boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"
sudo apt-get install phpmyadmin -y  >> /vagrant/vm_build.log 2>&1

#setup access to phpmyadmin
sudo echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf

# setup the wordpress database
echo -e "${COLOR}---setup wordpress database---${COLOR_RST}\n"
sudo mysql -u root -p${dbpassword} -e "DROP DATABASE IF EXISTS ${dbname};"
sudo mysql -u root -p${dbpassword} -e "create database ${dbname};"
sudo mysql -u root -p${dbpassword} -e "grant usage on *.* to ${dbusername}@localhost identified by '${dbpassword}';"
sudo mysql -u root -p${dbpassword} -e "grant all privileges on ${dbname}.* to ${dbusername}@localhost;"
# preload database based on files in sql/*.sql
for file in ./sql/*.sql ; do         # Use ./* ... NEVER bare *
  if [ -e "$file" ] ; then   # Check whether file exists.
     # COMMAND ... "$file" ...
     mysql -u root -p${dbpassword} ${dbname}; < "$file"
  fi
done

# setup apache to run as vagrant
echo -e "${COLOR}---run apache as vagrant to avoid issues with permissions---${COLOR_RST}\n"
sudo sed -i 's_www-data_vagrant_' /etc/apache2/envvars
# fix phpmyadmin permissions
sudo chown -R vagrant:vagrant /var/lib/phpmyadmin/tmp
sudo chown -R root:vagrant /var/lib/phpmyadmin/blowfish_secret.inc.php
sudo chown -R root:vagrant /var/lib/phpmyadmin/config.inc.php

# enable mod rewrite for apache2
echo -e "${COLOR}---enabling rewrite module---${COLOR_RST}\n"
if [ ! -f /etc/apache2/mods-enabled/rewrite.load ] ; then
    a2enmod rewrite
fi

# enable deflate module for apache2
if [ ! -f /etc/apache2/mods-enabled/deflate.load ] ; then
    a2enmod deflate
fi

#enable modrewrite for htaccess
echo -e "${COLOR}---enable FollowSymLinks---${COLOR_RST}\n"
sudo sed -i "/VirtualHost/a <Directory /var/www/html/> \n Options Indexes FollowSymLinks MultiViews \n AllowOverride All \n Order allow,deny \n  allow from all \n </Directory>" /etc/apache2/sites-available/000-default.conf

# Increase the upload size to 500MB
echo -e "\n--- Increasing upload size limit ---\n"
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 500M/" /etc/php5/apache2/php.ini
sed -i "s/post_max_size = .*/post_max_size = 500M/" /etc/php5/apache2/php.ini

# set php to display errors
echo -e "\n--- We definitly need to see the PHP errors, turning them on ---\n"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini

# restart apache2
echo -e "${COLOR}---restarting apache2---${COLOR_RST}\n"
sudo service apache2 restart  >> /vagrant/vm_build.log 2>&1

# install wordpress
echo -e "${COLOR}---installing wordpress---${COLOR_RST}\n"
sudo wget http://wordpress.org/latest.tar.gz >> /dev/null 2>&1

# extract wordpress
echo -e "${COLOR}---extracting wordpress---${COLOR_RST}\n"
sudo tar xfz latest.tar.gz

#move wordpress files and delete tarball
echo -e "${COLOR}---moving wordpress---${COLOR_RST}\n"
mv wordpress/* /vagrant
rm latest.tar.gz

echo -e "${COLOR}---All Done!---${COLOR_RST}\n"

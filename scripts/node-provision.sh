#!/bin/bash

###
# A simple vagrant provisioning script for setting up a Node development box.
# Configured to work with Ubuntu 14 "Trusty"
# installs : apache2, php 5.5, mysql-server and client, node js v7, and gulp
#
# Original by Greg Goforth
# Modified by Corey Shuman 1/30/17 to allow external secrets (passwords etc)
###

# secret variables, can be overriden using "provision-secrets.sh"
# make sure to add new variables to the switch statement below
dbusername="vagrant"
dbpassword="secret"
dbname="vagrant"

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

echo -e "${COLOR}---updating system---${COLOR_RST}"
apt-get update >> /vagrant/vm_build.log 2>&1

echo -e "${COLOR}---installing some tools: zip,unzip,curl, python-software-properties---${COLOR_RST}"

# install useful tools
echo -e "${COLOR}---installing some tools: zip,unzip,curl, python-software-properties---${COLOR_RST}\n"
sudo apt-get install -y software-properties-common python-software-properties zip unzip >> /vagrant/vm_build.log 2>&1
sudo apt-get install -y curl build-essential vim git >> /vagrant/vm_build.log 2>&1

# add pi-rho/dev repo for tmux
add-apt-repository -y ppa:pi-rho/dev >> /vagrant/vm_build.log 2>&1

# install dev tools
echo -e "${COLOR}---installing dev tools: tmux, python, g++, make---${COLOR_RST}\n"
apt-get update >> /vagrant/vm_build.log 2>&1
apt-get install -y tmux >> /vagrant/vm_build.log 2>&1
apt-get install -y python g++ make >> /vagrant/vm_build.log 2>&1

# install node js 7.x and gulp
echo -e "${COLOR}---installing NodeJS 7 and Gulp---${COLOR_RST}\n"
curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
apt-get install -y nodejs >> /vagrant/vm_build.log 2>&1
npm install -g gulp >> /vagrant/vm_build.log 2>&1

# installing mysql
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${dbpassword}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${dbpassword}"
echo -e "${COLOR}---installing MySql---${COLOR_RST}"
apt-get install -y mysql-server mysql-client >> /vagrant/vm_build.log 2>&1

# installing apache2
echo -e "${COLOR}---installing Apache---${COLOR_RST}"
apt-get install -y apache2 >> /vagrant/vm_build.log 2>&1
rm -rf /var/www
ln -fs /vagrant /var/www

# installing php 5.3
echo -e "${COLOR}---installing php 5.3---${COLOR_RST}"
apt-get install -y php5 libapache2-mod-php5 php5-mcrypt php5-curl php5-mysql php5-xdebug php5-gd >> /vagrant/vm_build.log 2>&1
apt-get install -y php5-mcrypt
php5enmod mcrypt

# setup xdebug uncomment below if you want to enable xdebug, requires a client
# on the host os to be listening for xdebug connections

#cat << EOF | sudo tee -a /etc/php5/conf.d/xdebug.ini
#xdebug.remote_enable = 1
#xdebug.remote_host = 127.0.0.1
#xdebug.remote_connect_back = 1
#xdebug.remote_port = 9000
#xdebug.profiler_enable = 1
#xdebug.profiler_output_dir = "<AMP home\tmp>"
#xdebug.idekey = PHPSTORM
#xdebug.remote_autostart = 1
#EOF

# setup the database
# loops through sql folder and loads .sql files into database
cd /vagrant
echo -e "${COLOR}---installing sql files into database---${COLOR_RST}"
sudo mysql -u root -p${dbpassword} -e "create database ${dbname};"
sudo mysql -u root -p${dbpassword} -e "grant usage on *.* to ${dbusername}@localhost identified by '${dbpassword}';"
sudo mysql -u root -p${dbpassword} -e "grant all privileges on ${dbname}.* to ${dbusername}@localhost;"
for file in ./sql/*.sql ; do         # Use ./* ... NEVER bare *
  if [ -e "$file" ] ; then   # Check whether file exists.
     # COMMAND ... "$file" ...
     mysql -u root -p${dbpassword} ${dbname}; < "$file"
  fi
done

#make sure we can use local .htaccess
echo -e "${COLOR}---allow overrides for .htaccess---${COLOR_RST}"
sudo sed -i 's_www/html_www_' /etc/apache2/sites-available/000-default.conf
sudo sed -i 's_</VirtualHost>_Include /vagrant/scripts/allow-override.conf\n</VirtualHost>_' /etc/apache2/sites-available/000-default.conf
a2dissite 000-default.conf && a2ensite 000-default.conf

#ensure apache runs as vagrant
echo -e "${COLOR}---run apache as vagrant to avoid issues with permissions---${COLOR_RST}"
sudo sed -i 's_www-data_vagrant_' /etc/apache2/envvars

#enable mod rewrite for apache2
echo -e "${COLOR}---enabling rewrite module---${COLOR_RST}"
if [ ! -f /etc/apache2/mods-enabled/rewrite.load ] ; then
    a2enmod rewrite
fi

#deflat module for apache2
if [ ! -f /etc/apache2/mods-enabled/deflate.load ] ; then
    a2enmod deflate
fi

# restart apache2
echo -e "${COLOR}---restarting apache2---${COLOR_RST}"
service apache2 restart >> /vagrant/vm_build.log 2>&1

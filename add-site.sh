#/usr/bin/env bash

read -p "dbrootpwd= " dbrootpwd
read -p "website_root= " website_root
echo 
echo "1. ospos"
echo "2. wordpress"
read -p "choose 1 or 2: " _choice

install_ospos(){
    dbname="ospos"
    dbusername="adminospos"
    dbuserpwd="$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32} )"
    dbencryptionkey="$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32} )"

    cd ~
    rm -rf ${website_root}
    path_to_ospos_file=$( wget --no-check-certificate -qO- https://github.com/opensourcepos/opensourcepos/releases/latest | grep '\.zip' | grep href | head -n 1 | cut -f2 -d\" )
    wget --no-check-certificate -qO latest.ospos.zip "https://github.com${path_to_ospos_file}"
    apt-get -qq install unzip
    unzip -qq latest.ospos.zip -d ${website_root}
    rm -f latest.ospos.zip

    # http://www.opensourceposguide.com/guide/gettingstarted/installation
    # https://github.com/opensourcepos/opensourcepos/wiki/Getting-Started-installations
    cd "${website_root}/database"
    mysql -uroot -p${dbrootpwd} <<EOF
DROP USER IF EXISTS '${dbusername}'@'localhost';
DROP DATABASE IF EXISTS ${dbname};
CREATE DATABASE ${dbname} COLLATE utf8mb4_general_ci;
CREATE USER '${dbusername}'@'localhost' IDENTIFIED BY '${dbuserpwd}';
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbusername}'@'localhost';
FLUSH PRIVILEGES;
use ospos;source ./database.sql;COMMIT;
quit
EOF
    sed -i "/.*MYSQL_USERNAME.*/ s/admin/${dbusername}/" ${website_root}/application/config/database.php
    sed -i "/.*MYSQL_PASSWORD.*/ s/pointofsale/${dbuserpwd}/" ${website_root}/application/config/database.php
    sed -i "/.*ENCRYPTION_KEY.*/ s/...$/\'${dbencryptionkey}\';/" ${website_root}/application/config/config.php

# ?????????????????????????????????????????
# ### backup database ### #
# /usr/local/mysql/bin/mysqldump -u root -p --all-databases > /root/mysql.dump
# /usr/local/mysql/bin/mysql -u root -p < /root/mysql.dump
# flush privileges
# ?????????????????????????????????????????

}

# https://wordpress.org/support/article/how-to-install-wordpress/
install_wp(){
    dbname="wordpress"
    dbusername="adminwp"
    dbuserpwd="$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32} )"

    cd ~
    rm -rf ${website_root}
    wget --no-check-certificate -q https://wordpress.org/latest.tar.gz
    tar -xf latest.tar.gz
    mv wordpress ${website_root}
    rm -f latest.tar.gz

    # https://wordpress.org/support/article/how-to-install-wordpress/
    cd "${website_root}"
    mysql -uroot -p${dbrootpwd} <<EOF
DROP USER IF EXISTS '${dbusername}'@'localhost';
DROP DATABASE IF EXISTS ${dbname};
CREATE DATABASE ${dbname} COLLATE utf8mb4_general_ci;
CREATE USER '${dbusername}'@'localhost' IDENTIFIED BY '${dbuserpwd}';
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbusername}'@'localhost';
FLUSH PRIVILEGES;
quit
EOF
    mv wp-config-sample.php wp-config.php
    sed -i "/.*DB_NAME.*/ s/database_name_here/${dbname}/" wp-config.php
    sed -i "/.*DB_USER.*/ s/username_here/${dbusername}/" wp-config.php
    sed -i "/.*DB_PASSWORD.*/ s/password_here/${dbuserpwd}/" wp-config.php
    # https://dev.mysql.com/doc/refman/5.6/en/charset-charsets.html
    # https://www.eversql.com/mysql-utf8-vs-utf8mb4-whats-the-difference-between-utf8-and-utf8mb4/
    sed -i "/.*DB_CHARSET.*/ s/utf8/utf8mb4/" wp-config.php
    # https://api.wordpress.org/secret-key/1.1/salt/
    sed -i '/.*put your unique phrase here.*/r'<( wget --no-check-certificate -qO- https://api.wordpress.org/secret-key/1.1/salt/ | grep define ) wp-config.php
    sed -i '/.*put your unique phrase here.*/d' wp-config.php
    rm -f wget-log*
}

case "${_choice}" in
    1)
        install_ospos
        ;;
    2)
        install_wp
        ;;
    *)
        echo "Input error! "
        ;;
esac

cat >~/db_info <<EOF
dbuserpwd= ${dbuserpwd}
dbencryptionkey= ${dbencryptionkey}
EOF

cat ~/db_info
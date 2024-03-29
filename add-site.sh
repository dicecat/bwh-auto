#!/usr/bin/env bash

# http://www.opensourceposguide.com/guide/gettingstarted/installation
# https://github.com/opensourcepos/opensourcepos/wiki/Getting-Started-installations
install_ospos() {
    dbname="ospos"
    dbusername="adminhenry"
    dbuserpwd="$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c${1:-32})"
    dbencryptionkey="$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c${1:-32})"

    cd ~
    rm -rf ${website_root}
    path_to_ospos_file=$(wget --no-check-certificate -qO- https://github.com/opensourcepos/opensourcepos/releases/latest | grep '\.zip' | grep href | head -n 1 | cut -f2 -d\")
    wget --no-check-certificate -qO latest.ospos.zip "https://github.com${path_to_ospos_file}"
    apt-get -qq install unzip
    unzip -qq latest.ospos.zip -d ${website_root}
    rm -f latest.ospos.zip

    [ -f /usr/local/mariadb/data/ospos ] && rm -f /usr/local/mariadb/data/ospos/*
    cd "${website_root}/database"
    mysql -uroot -p${dbrootpwd} <<EOF
DROP USER IF EXISTS '${dbusername}'@'%';
DROP DATABASE IF EXISTS ${dbname};
CREATE DATABASE ${dbname} COLLATE utf8mb4_general_ci;
CREATE USER '${dbusername}'@'%' IDENTIFIED BY '${dbuserpwd}';
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbusername}'@'%' IDENTIFIED BY '${dbuserpwd}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
quit
EOF
    mysql -u${dbusername} -p${dbuserpwd} <<EOF
use ${dbname};source ./database.sql;COMMIT;
quit
EOF
    sed -i "/.*MYSQL_USERNAME.*/ s/admin/${dbusername}/" ${website_root}/application/config/database.php
    sed -i "/.*MYSQL_PASSWORD.*/ s/pointofsale/${dbuserpwd}/" ${website_root}/application/config/database.php
    sed -i "/.*ENCRYPTION_KEY.*/ s/...$/\'${dbencryptionkey}\';/" ${website_root}/application/config/config.php
    echo "OSPOS installed. Access your website to complete the installation."
}

# https://wordpress.org/support/article/how-to-install-wordpress/
install_wp() {
    dbname="wordpress"
    dbusername="adminhenry"
    dbuserpwd="$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c${1:-32})"

    cd ~
    rm -rf ${website_root}
    wget --no-check-certificate -q https://wordpress.org/latest.tar.gz
    tar -xf latest.tar.gz
    mv wordpress ${website_root}
    rm -f latest.tar.gz

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
    # https://www.eversql.com/mysql-utf8-vs-utf8mb4-whats-the-difference-between-utf8-and-utf8mb4/
    # https://dev.mysql.com/doc/refman/5.6/en/charset-charsets.html
    sed -i "/.*DB_CHARSET.*/ s/utf8/utf8mb4/" wp-config.php
    # https://api.wordpress.org/secret-key/1.1/salt/
    sed -i '/.*put your unique phrase here.*/r'<(wget --no-check-certificate -qO- https://api.wordpress.org/secret-key/1.1/salt/ | grep define) wp-config.php
    sed -i '/.*put your unique phrase here.*/d' wp-config.php
    rm -f wget-log*
    echo "WordPress installed. Access your website to complete the installation."
}

# protect your ip & domain while using CDN
ban_direct_access() {
    # TODO: make backup; restore default domain config
    cp -f ${apache_location}/conf/vhost/${domain}.conf ${apache_location}/conf/vhost/${domain}.conf.prns
    # remove http redirect on domain.conf
    sed -i "s/\(.*Redirect.*\)/#\1/" ${apache_location}/conf/vhost/${domain}.conf
    sed -i "s/\(.*Rewrite.*\)/#\1/" ${apache_location}/conf/vhost/${domain}.conf
    cat >${apache_location}/conf/vhost/direct.conf <<EOF
<VirtualHost *:80>
    ServerName default
    <Location />
        Require all denied
    </Location>
    <Directory />
        Require all denied
    </Directory>
</VirtualHost>
<VirtualHost *:443>
    ServerName default
    <Location />
        Require all denied
    </Location>
    <Directory />
        Require all denied
    </Directory>
</VirtualHost>
EOF
    service httpd restart
    echo "In SSL/TLS app of CloudFlare, set encryption mode to Flexible."
    echo "And enable Always Use HTTPS option. Then it should work. Reboot if not."
}

choice_of_web() {
    [ "${_choice_of_web}" == "prep" ] && return 0

    if [ "${_choice_of_web}" != "_main_call" ]; then
        if [ ! -f ~/autoall.essential ]; then
            _choice_of_web="_no_ess_file" && return 0
        else
            dbrootpwd=$(cat ~/autoall.essential | grep 'root password' | cut -f3 -d\ )
            website_root=$(cat ~/autoall.essential | grep 'web root' | cut -f3 -d\ )
            domain=$(echo -e "${website_root}" | cut -f4 -d\/)
            apache_location=/usr/local/apache
        fi
    fi

    case "${_choice_of_web}" in
        1 | 2 | 0)
            return 0
            ;;
        *)
            echo
            echo "The following web contents are available:"
            echo "[1] WordPress"
            # echo "[2] OSPOS"
            echo "[0] Ban direct IP access & work with CloudFlare."
            echo "[Otherwise] Do nothing & just skip any of the above"
            read -p "Enter your choice of web contents: " _choice_of_web
            echo
            ;;
    esac
}

install_choice_of_web() {
    case "${_choice_of_web}" in
        1)
            install_wp
            ;;
        2)
            install_ospos
            ;;
        0)
            ban_direct_access
            ;;
        prep)
            ;;
        _no_ess_file)
            echo "~/autoall.essential not found. Skip installing web for now."
            ;;
        *)
            echo "No valid choice of web contents. Skip installing web for now."
            ;;
    esac
}

_choice_of_web=$1
choice_of_web
install_choice_of_web

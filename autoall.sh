#!/usr/bin/env bash

# Regards to
# @madeye     <https://github.com/madeye>
# @teddysun   <https://github.com/teddysun>

[ ! "$(command -v wget)" ] && apt-get -qq install wget
wget --no-check-certificate -qO ~/add-site.sh https://raw.githubusercontent.com/dicecat/bwh-auto/master/add-site.sh
wget --no-check-certificate -qO ~/ss-libev.sh https://raw.githubusercontent.com/dicecat/bwh-auto/master/ss-libev.sh
. ~/ss-libev.sh prep 2>&1 >/dev/null
. ~/add-site.sh prep && _choice_of_web="_main_call"
chmod +x ~/*.sh

install_util() {
    util_pkg_list=(
        host                `#func set_domain` \
        unattended-upgrades `#func update_sys` \
        git                 `#func install_lamp_git` \
        certbot             `#func get_cert` \
        sendmail            `#func essential_info`
    )
    apt-get -y update
    for util_pkg in ${util_pkg_list[@]}; do
        [ ! "$(command -v ${util_pkg})" ] && apt-get -qq install ${util_pkg}
    done
}

# Set domain
set_domain() {
    echo
    echo -e "[${green}Info${plain}] Please wait a few seconds..."
    echo
    apt-get -qq install host
    [ ! "$(command -v host)" ] && echo -e "[${red}Error${plain}] command host not found! Please try again." && exit 1
    clear
    echo -e "[${green}Required: domain${plain}]"
    echo "A valid domain which points to the IP of this VPS is required to obtain SSL certificate."
    echo -e "Please enter ${yellow}your domain${plain}:"
    read domain
    domain="${domain%% *}"
    [ -z "${domain}" ] && domain="Invalid"
    host ${domain} 2>&1 >/dev/null
    while [ $? -ne 0 ]; do
        echo -e "[${red}Error${plain}] Invalid domain. Please try again:"
        read domain
        domain="${domain%% *}"
        [ -z "${domain}" ] && domain="Invalid"
        host ${domain} 2>&1 >/dev/null
    done
    echo -e "domain = ${yellow}${domain}${plain}"
}

set_email_addr() {
    echo
    echo -e "[${green}Optional: email address${plain}]"
    echo "A valid email address is required if you need to disable pw and use key pairs to login."
    echo "The private key will be sent to your email after this script ends."
    echo -e "${red}You will lose access to and have to reset your VPS if the private key is lost.${plain}"
    echo "Other essential info will be saved to ~/autoall.essential."
    echo "Please make 100% sure you understand the notes above. Otherwise just skip..."
    echo -e "Please enter your ${yellow}email address${plain} (Press ${yellow}Enter${plain} to skip):"
    read email_addr
    [ -z "${email_addr}" ] && return 0
    #validate email_addr
    while [ ! -z "${email_addr}" ]; do
        if [[ "${email_addr}" =~ ^([A-Za-z]+[A-Za-z0-9]*((\.|\-|\_)?[A-Za-z]+[A-Za-z0-9]*){1,})@(([A-Za-z]+[A-Za-z0-9]*)+((\.|\-|\_)?([A-Za-z]+[A-Za-z0-9]*)+){1,})+\.([A-Za-z]{2,})+$ ]]; then
            echo -e "email_addr = ${yellow}${email_addr}${plain}"
            return 0
        else
            echo -e "[${red}Error${plain}] Invalid email address. Please try again:"
            read email_addr
        fi
    done
}

set_pw_enc() {
    [ -z "${email_addr}" ] && pw_enc="" && return 0
    echo
    echo -e "[${green}NOTE: password${plain}]"
    echo "A password is used together with the key pair. "
    echo -e "Please enter ${yellow}password${plain} (Default: ${yellow}${email_addr}${plain}):"
    read pw_enc
    [ -z "${pw_enc}" ] && pw_enc="${email_addr}"
    echo -e "password = ${yellow}${pw_enc}${plain}"
}

# update system
update_sys() {
    # lsb_release -a
    export DEBIAN_FRONTEND=noninteractive
    apt-get update && apt-get -qq -o Dpkg::Options::="--force-confnew" dist-upgrade
    # config auto-update
    # https://wiki.debian.org/UnattendedUpgrades
    # https://discourse.ubuntu.com/t/package-management/11908
    apt-get -qq install unattended-upgrades
    cat >/etc/apt/apt.conf.d/20auto-upgrades <<-EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "3";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

# https://www.moerats.com/archives/612/
enable_BBR() {
    sysctl net.ipv4.tcp_available_congestion_control | grep bbr >/dev/null
    if [ $? -ne 0 ]; then
        cat /etc/sysctl.conf | grep 'net.core.default_qdisc' >./bbr.tmp
        cat /etc/sysctl.conf | grep 'net.ipv4.tcp_congestion_control' >>./bbr.tmp
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
        echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
        sysctl -p
    else
        return 0
    fi
    lsmod | grep bbr
    if [ $? -ne 0 ]; then
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
        cat ./bbr.tmp >>/etc/sysctl.conf
        rm -f ./bbr.tmp
        echo -e "[${yellow}Warning${plain}] BBR not enabled."
    fi
}

# bwh installed BBR by default

# https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-centos-6
fix_swap() {
    # (if /swap exists) remove the original swap
    swapoff /swap && rm -f /swap
    swapoff /swapfile && rm -f /swapfile
    # add a new 512M swap
    dd if=/dev/zero of=/swap bs=1024 count=512k
    chown root:root /swap
    chmod 600 /swap
    mkswap /swap
    swapon /swap
    # (if /swap non-exist) boot to load
    sleep 30
    if [ ! -s /swap ]; then
        echo -e "[${red}Error${plain}] Fail to create swap."
        exit 1
    fi
    swap_stat=$(swapon -s | grep swap | grep 524284)
    if [ -z "${swap_stat}" ]; then
        echo -e "[${red}Error${plain}] Fail to load swap. Reboot and run this script again."
        exit 1
    fi
}

# install ss-libev & v2-ray-plugin
# sourced from ss-libev.sh
# install_shadowsocks(){}

install_lamp_git() {
    # lamp install prep
    dbrootpwd="$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c${1:-32})"

    apt-get -qq install git
    cd /root
    git clone https://github.com/teddysun/lamp.git
    cd /root/lamp
    chmod +x *.sh
    # php 8 not supported, https://opensourcepos.org/faq/ https://make.wordpress.org/core/ 
    ./lamp.sh --apache_option 1 --db_option 7 --db_root_pwd "$dbrootpwd" --php_option 1 --db_manage_modules adminer --kodexplorer_option 2
    #./lamp.sh --apache_option 1 --db_option 7 --db_root_pwd "$dbrootpwd" --php_option 1 --kodexplorer_option 2
    cd /root
    # check lamp install status
    [ ! "$(command -v php)" ] && echo -e "[${red}Error${plain}] Fail to install lamp stack!" && exit 1
}

#post install
set_folder() {
    apache_location=/usr/local/apache
    website_root="/data/www/${domain}"
    php_admin_value="php_admin_value open_basedir ${website_root}:/tmp:/var/tmp:/proc"

    # enable ssl & ws
    # https://lamp.sh/faq.html Q13
    # https://httpd.apache.org/docs/2.4/mod/mod_proxy_wstunnel.html
    # https://help.aliyun.com/document_detail/98727.html
    sed -i '/.*mod_ssl.so.*/ s/^#//' ${apache_location}/conf/httpd.conf
    sed -i 's@#Include conf/extra/httpd-ssl.conf@Include conf/extra/httpd-ssl.conf@g' ${apache_location}/conf/httpd.conf
    sed -i '/.*wstunnel.*/ s/^#//' ${apache_location}/conf/httpd.conf
    /etc/init.d/httpd restart

    mkdir -p ${website_root}
    mkdir -p /data/www/default.lamp
    cp -prf /data/www/default/* ${website_root}
    mv /data/www/default/* /data/www/default.lamp
}

# https://certbot.eff.org/lets-encrypt/ubuntubionic-other
get_cert() {
    if [ -f /etc/letsencrypt/live/$domain/fullchain.pem ]; then
        echo -e "[${green}Info${plain}] cert already got, skip."
    else
        apt-get update
        apt-get -qq install certbot
        certbot certonly --agree-tos --register-unsafely-without-email --webroot -w ${website_root} -d ${domain}
        if [ ! -f /etc/letsencrypt/live/$domain/fullchain.pem ]; then
            echo -e "[${red}Error${plain}] Failed to get cert."
            exit 1
        fi
    fi
    ssl_certificate="/etc/letsencrypt/live/${domain}/fullchain.pem"
    ssl_certificate_key="/etc/letsencrypt/live/${domain}/privkey.pem"
}

check_lets_cron() {
    if [ "$(command -v crontab)" ]; then
        if crontab -l | grep -q "certbot renew --disable-hook-validation"; then
            echo "Cron job for automatic renewal of certificates exists."
        else
            echo "Cron job for automatic renewal of certificates does not exist. Create it."
            (
                crontab -l
                echo '0 3 */60 * * certbot renew --disable-hook-validation --post-hook "/etc/init.d/httpd restart"'
            ) | crontab -
        fi
    else
        echo -e "[${yellow}Warning${plain}] crontab command not found, please set up a cron job manually."
    fi
}

create_vhost80() {
    cat >${apache_location}/conf/vhost/${domain}.conf <<EOF
<VirtualHost *:80>
    ${php_admin_value}
    ServerName ${domain}
    ServerAlias ${domain}
    DocumentRoot ${website_root}
    <Directory ${website_root}>
        SetOutputFilter DEFLATE
        Options FollowSymLinks
        AllowOverride All
        Order Deny,Allow
        Require all granted
        DirectoryIndex index.php index.html index.htm
    </Directory>
    ErrorLog /data/www/${domain}/http_error.log
    CustomLog /data/www/${domain}/http_access.log combined
</VirtualHost>
EOF

    echo "Reloading the apache config file..."
    if ${apache_location}/bin/apachectl -t; then
        /etc/init.d/httpd restart
        echo "Reload succeed"
        echo
    else
        echo -e "\033[31mError:\033[0m Reload failed. Apache config file had an error, please fix it and try again."
        exit 1
    fi
}

create_vhost443() {
    ss_port=$(cat /etc/shadowsocks-libev/config.json | grep server_port | cut -f2 -d: | cut -f1 -d,)
    sed -i '/.*VirtualHost>/d;' ${apache_location}/conf/vhost/${domain}.conf
    cat >>${apache_location}/conf/vhost/${domain}.conf <<EOF
    Redirect 301 / https://${domain}
    RewriteEngine on
    RewriteCond %{SERVER_NAME} =${domain}
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
<VirtualHost *:443>
    ${php_admin_value}
    ServerName ${domain}
    ServerAlias ${domain}
    DocumentRoot ${website_root}
    <Directory ${website_root}>
        SetOutputFilter DEFLATE
        Options FollowSymLinks
        AllowOverride All
        Order Deny,Allow
        Require all granted
        DirectoryIndex index.php index.html index.htm
    </Directory>
    ErrorLog  /data/www/${domain}/https_error.log
    CustomLog  /data/www/${domain}/https_access.log combined
    SSLEngine on
    SSLCertificateFile ${ssl_certificate}
    SSLCertificateKeyFile ${ssl_certificate_key}
    <Location "/data/www/plug">
        ProxyPass ws://127.0.0.1:${ss_port}/ upgrade=WebSocket
        ProxyAddHeaders Off
        ProxyPreserveHost On
        RequestHeader append X-Forwarded-For %{REMOTE_ADDR}s
    </Location>
</VirtualHost>
EOF

    echo "Reloading the apache config file..."
    if ${apache_location}/bin/apachectl -t; then
        /etc/init.d/httpd restart
        echo "Reload succeed"
        echo
    else
        echo -e "\033[31mError:\033[0m Reload failed. Apache config file had an error, please fix it and try again."
        exit 1
    fi
}

modify_ssconf() {
    sed -i '/plugin/d;' /etc/shadowsocks-libev/config.json
    sed -i '/}/d;' /etc/shadowsocks-libev/config.json
    sed -i '${s/$/,/}' /etc/shadowsocks-libev/config.json
    sed -i '${s/,,/,/}' /etc/shadowsocks-libev/config.json
    cat >>/etc/shadowsocks-libev/config.json <<EOF
    "plugin":"v2ray-plugin",
    "plugin_opts":"server;tls;host=${domain};path=/data/www/plug;cert=${ssl_certificate};key=${ssl_certificate_key}"
}
EOF
    /etc/init.d/shadowsocks restart
}

# https://www.findhao.net/easycoding/1714
# disable pw login
disable_pw_login() {
    # skip this part if pw_enc not set
    [ -z "${pw_enc}" ] && return 0
    # generate key pair
    # https://laishanhai1040.github.io/2019/07/21/Shadowsocks-setup-summary/
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    ssh-keygen -b 512 -t ed25519 -N "${pw_enc}" -f /root/.ssh/id_ed25519 <<<y
    chmod 600 ~/.ssh/id_ed25519.pub
    cat >>/etc/ssh/sshd_config <<-EOF
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/id_ed25519.pub
PasswordAuthentication no
PermitEmptyPasswords no
EOF
    service sshd restart
}

# process essential info
essential_info() {
    # save essential info to autoall.essential
    # cat /etc/shadowsocks-libev/config.json > /root/autoall.essential
    print_ss_info >/root/autoall.essential
    cat >>/root/autoall.essential <<-EOF

MySQL credentials:
root password: ${dbrootpwd}
web root: ${website_root}

EOF
    [ -z "${pw_enc}" ] && return 0 || cat /root/.ssh/id_ed25519 >>/root/autoall.essential
    #openssl enc -base64 -in /root/autoall.essential -out /root/autoall.essential.enc -pass pass:"${pw_enc}"

    # email private key to ssh into server after reboot
    apt-get -qq install sendmail
    echo -e "From: admin <admin@${domain}>\nTo: ${email_addr}\nSubject: Log in to access essential info from installation" | cat - /root/.ssh/id_ed25519 | sendmail -t
}

####################
#                  #
#     Run it!      #
#                  #
####################

check_environment
#install_util
set_domain
set_email_addr
set_pw_enc
choice_of_web
update_sys
enable_BBR
fix_swap
install_shadowsocks
install_lamp_git
# nasty fix for debian: mod_md disabled in 1st installation, but enable in 2nd attempt
if grep -Eqi "debian" /etc/issue /proc/version; then
    echo y | bash /root/lamp/uninstall.sh
    install_lamp_git
fi
set_folder
create_vhost80
get_cert
check_lets_cron
create_vhost443
modify_ssconf
disable_pw_login
essential_info
install_choice_of_web
reboot

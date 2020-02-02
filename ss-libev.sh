#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Regards to
# @madeye     <https://github.com/madeye>
# @teddysun   <https://github.com/teddysun>

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Stream Ciphers
common_ciphers=(
    aes-256-gcm
    aes-192-gcm
    aes-128-gcm
    aes-256-ctr
    aes-192-ctr
    aes-128-ctr
    aes-256-cfb
    aes-192-cfb
    aes-128-cfb
    camellia-128-cfb
    camellia-192-cfb
    camellia-256-cfb
    xchacha20-ietf-poly1305
    chacha20-ietf-poly1305
    chacha20-ietf
    chacha20
    salsa20
    rc4-md5
)

# https://github.com/shadowsocks/shadowsocks-libev
# dependencies other than libmbedtls & libsodium
apt_depends=(
    autoconf automake libtool 
    gettext 
    build-essential 
    libpcre3-dev 
    libev-dev 
    libc-ares-dev
)

check_environment(){
    # Check root priviledge
    if [ `whoami` != "root" ]; then
        echo -e "[${red}Error${plain}] This script must be run as root!"
        exit 1
    fi
    # Check OS system
    if ! grep -Eqi "debian|raspbian|ubuntu" /etc/issue /proc/version; then
        echo -e "[${red}Error${plain}] This script only runs in Ubuntu or Debian!"
        exit 1
    fi
    # set current folder
    cd /root/
    cur_dir=$( pwd )
}

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

install_prepare(){
    if [ -s /etc/shadowsocks-libev/config.json ]; then
        cp -f /etc/shadowsocks-libev/config.json /etc/shadowsocks-libev/config.json.backup
        shadowsockspwd=`grep password /etc/shadowsocks-libev/config.json |cut -f4 -d\"`
        shadowsocksport=`grep server_port /etc/shadowsocks-libev/config.json |cut -f2 -d: |cut -f1 -d,`
    else
        shadowsockspwd="$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32} )"
        shadowsocksport=$(shuf -i 9000-19999 -n 1)
    fi
    # pick=13
    shadowsockscipher=${common_ciphers[12]}
}

get_latest_version(){
    libsodium_file="libsodium-stable"
    libsodium_url="https://download.libsodium.org/libsodium/releases/LATEST.tar.gz"

    mbedtsl_ver=`wget --no-check-certificate -qO- https://tls.mbed.org/download-archive |grep gpl.tgz |grep mbedtls |head -n1 |cut -f2 -d\" |cut -f4 -d\/ |cut -f2 -d-`
    mbedtls_file="mbedtls-${mbedtsl_ver}"
    mbedtls_url="https://tls.mbed.org/download/${mbedtls_file}-gpl.tgz"

    shadowsocks_libev_file=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep name | grep tar | cut -f4 -d\" | cut -f1-3 -d.)
    shadowsocks_libev_url=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep browser_download_url | cut -f4 -d\")

    v2_file=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest | grep linux-amd64 | grep name | cut -f4 -d\")
    v2_url=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest | grep linux-amd64 | grep browser_download_url | cut -f4 -d\")

    shadowsocks_libev_init="/etc/init.d/shadowsocks"
    shadowsocks_libev_debian="https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-libev-debian"
}

download(){
    local filename=$(basename $1)
    if [ -f ${1} ]; then
        rm -f "${filename}"
    fi
    echo "download ${filename} now..."
    wget --no-check-certificate -cq -t3 -T60 -O ${1} ${2}
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Download ${filename} failed."
        exit 1
    fi
}

# Download latest versions
download_files(){
    cd ${cur_dir}
    get_latest_version

    download "${libsodium_file}.tar.gz" "${libsodium_url}"
    download "${mbedtls_file}-gpl.tgz" "${mbedtls_url}"
    download "${shadowsocks_libev_file}.tar.gz" "${shadowsocks_libev_url}"
    download "$v2_file" "$v2_url"
    download "/etc/init.d/shadowsocks" "${shadowsocks_libev_debian}"
}

config_shadowsocks(){
    # /etc/shadowsocks-libev/config.json
    if [ -s /etc/shadowsocks-libev/config.json.backup ]; then
        mv /etc/shadowsocks-libev/config.json.backup /etc/shadowsocks-libev/config.json
        return 0
    fi
    mkdir -p /etc/shadowsocks-libev
    cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":"0.0.0.0",
    "server_port":${shadowsocksport},
    "password":"${shadowsockspwd}",
    "timeout":300,
    "user":"nobody",
    "method":"${shadowsockscipher}",
    "fast_open":true,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp",
    "plugin":"v2ray-plugin",
    "plugin_opts":"server"
}
EOF
}

error_detect_depends(){
    local command=$1
    local depend=`echo "${command}" | awk '{print $4}'`
    echo -e "[${green}Info${plain}] Starting to install package ${depend}"
    ${command} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Failed to install ${depend}"
        exit 1
    fi
}

install_dependencies(){
    apt-get -y update
    for depend in ${apt_depends[@]}; do
        error_detect_depends "apt-get -y install ${depend}"
    done
}

install_libsodium(){
    cd ${cur_dir}
    tar xf ${libsodium_file}.tar.gz
    cd ${libsodium_file}
    ./configure --prefix=/usr && make && make install
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Failed to install ${libsodium_file}."
        install_cleanup
        exit 1
    fi
    ldconfig
}

install_mbedtls(){
    cd ${cur_dir}
    tar xf ${mbedtls_file}-gpl.tgz
    cd ${mbedtls_file}
    make SHARED=1 CFLAGS=-fPIC
    make DESTDIR=/usr install
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Failed to install ${mbedtls_file}."
        install_cleanup
        exit 1
    fi
    ldconfig
}

# Install shadowsocks-libev
install_ss(){
    cd ${cur_dir}
    tar xf ${shadowsocks_libev_file}.tar.gz
    cd ${shadowsocks_libev_file}
    ./configure --disable-documentation && make && make install
    if [ $? -eq 0 ]; then
        chmod +x /etc/init.d/shadowsocks
        update-rc.d -f shadowsocks defaults
    else
        echo -e "[${red}Error${plain}] Failed to install shadowsocks-libev. "
        install_cleanup
        exit 1
    fi
}

# Install v2ray-plugin
install_v2(){
    cd ${cur_dir}
    tar xf $v2_file
    mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
    if [ ! -f /usr/local/bin/v2ray-plugin ];then
        echo -e "[${red}Error${plain}] Failed to install v2ray-plugin."
        install_cleanup
        exit 1
    fi
}

start_ss(){
    # Start shadowsocks
    ldconfig
    /etc/init.d/shadowsocks restart
    if [ $? -eq 0 ]; then
        echo -e "[${green}Info${plain}] Shadowsocks-libev start success!"
    else
        echo -e "[${yellow}Warning${plain}] Shadowsocks-libev start failure!"
    fi
}

install_cleanup(){
    cd ${cur_dir}
    rm -rf ${libsodium_file} ${libsodium_file}.tar.gz
    rm -rf ${mbedtls_file} ${mbedtls_file}-gpl.tgz
    rm -rf ${shadowsocks_libev_file} ${shadowsocks_libev_file}.tar.gz
    rm -f $v2_file
}

print_ss_info(){
    clear
    echo
    echo -e "Congratulations, shadowsocks-libev server install completed!"
    echo -e "Your Server IP        : ${red} $( wget -qO- -t1 -T2 ipv4.icanhazip.com ) ${plain}"
    echo -e "Your Server Port      : ${red} ${shadowsocksport} ${plain}"
    echo -e "Your Password         : ${red} ${shadowsockspwd} ${plain}"
    echo -e "Your Encryption Method: ${red} ${shadowsockscipher} ${plain}"
    echo -e "Your Plugin           : ${red} v2ray-plugin ${plain}"
    echo -e "Your Plugin options   : ${red} tls;host=${domain};path=/data/www/plug ${plain}"
    echo -e "Enjoy it!"
}

install_shadowsocks(){
    check_environment
    disable_selinux
    install_prepare
    install_dependencies
    download_files
    config_shadowsocks
    install_libsodium
    install_mbedtls
    install_ss
    install_v2
    start_ss
    install_cleanup
}

# Uninstall shadowsocks-libev
uninstall_shadowsocks(){
    if [ ! -f /etc/init.d/shadowsocks ]; then
        echo -e "[${red}Error${plain}] shadowsocks-libev not installed, please check it and try again."
        echo
        exit 1
    fi

    /etc/init.d/shadowsocks status > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        /etc/init.d/shadowsocks stop
    fi
    update-rc.d -f shadowsocks remove
    rm -fr /etc/shadowsocks-libev
    rm -f /usr/local/bin/ss-local
    rm -f /usr/local/bin/ss-tunnel
    rm -f /usr/local/bin/ss-server
    rm -f /usr/local/bin/ss-manager
    rm -f /usr/local/bin/ss-redir
    rm -f /usr/local/bin/ss-nat
    rm -f /usr/local/lib/libshadowsocks-libev.a
    rm -f /usr/local/lib/libshadowsocks-libev.la
    rm -f /usr/local/include/shadowsocks.h
    rm -f /usr/local/lib/pkgconfig/shadowsocks-libev.pc
    rm -f /usr/local/share/man/man1/ss-local.1
    rm -f /usr/local/share/man/man1/ss-tunnel.1
    rm -f /usr/local/share/man/man1/ss-server.1
    rm -f /usr/local/share/man/man1/ss-manager.1
    rm -f /usr/local/share/man/man1/ss-redir.1
    rm -f /usr/local/share/man/man1/ss-nat.1
    rm -f /usr/local/share/man/man8/shadowsocks-libev.8
    rm -fr /usr/local/share/doc/shadowsocks-libev
    rm -f /etc/init.d/shadowsocks
    rm -f /usr/local/bin/v2ray-plugin
    echo -e "[${green}Info${plain}] shadowsocks-libev removed successfully."
    echo -e "[${green}Info${plain}] Run ${green}~/lamp/lamp.sh uninstall${plain} to remove lamp."
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "${action}" in
    install|uninstall)
        ${action}_shadowsocks
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: $(basename $0) [install|uninstall]"
        ;;
esac

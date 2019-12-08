# Tested on [BandwagonHost VPS](https://tinyurl.com/y4v2rl2u) running Ubuntu 18.04.

## 1. What it does
1) install shadowsocks-libev and v2ray-plugin;
2) install lamp of the latest version;
3) config ss over ws+tls behind web service;
4) (optional) install web contents (OSPOS or WordPress);

## 2. Requirements
1) a valid domain pointed to the IP address of your VPS;
2) (optional) an password to private key, if you choose to use key pair to log in;
3) (optional) an email address, if you want to receive essential info after things done.

## 3. Usage
1) wget --no-check-certificate -qO ~/autoall.sh https://git.io/JeyRB
2) bash ~/autoall.sh 2>&1 | tee autoall.log

## Changelog

### v0.2

Add add-site.sh functionality. Optional to add OSPOS or WordPress web contents.

Either add-site.sh or ss-libev.sh should also work independent of autoall.sh.

### v0.1

Initial scripts to automatically install ss, plugin, lamp, and configure ws+tls behind web service.

By default, the script installs lastest version or lamp stack. 
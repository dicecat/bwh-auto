# bwh-auto: scripts to simplify the setup of ss+ws+tls+web

## Scripts tested OK on [BandwagonHost VPS](https://tinyurl.com/y4v2rl2u) running Ubuntu 18.04

## 1. What it does

1) install shadowsocks-libev and v2ray-plugin;
2) install lamp of the latest version;
3) config ss over ws+tls behind web service;
4) (optional) install web contents (OSPOS or WordPress);

## 2. Requirements

1) a VPS running Ubuntu, might work on Debian;
2) a valid domain pointed to the IP address of your VPS;
3) (optional) an email address to receive private key;
4) (optional if chosen 3) set up a password to private key.

## 3. Usage

1) wget --no-check-certificate -qO ~/autoall.sh https://git.io/JeyRB
2) bash ~/autoall.sh 2>&1 | tee autoall.log

## Changelog

### v0.2

Add add-site.sh functionality. Optional to add OSPOS or WordPress web contents. <br />
Either add-site.sh or ss-libev.sh should also work independently of autoall.sh.

### v0.1

Initial scripts to automatically install ss, plugin, lamp, and configure ws+tls behind web service. <br /> 
By default, the script installs lastest version of lamp stack.

# bwh-auto: simplify the setup of ss+ws+tls+web

## Tested OK on [BandwagonHost VPS](https://tinyurl.com/y4v2rl2u) running Ubuntu 22.04

## What it does

1) install shadowsocks-libev and v2ray-plugin;
2) install lamp stack of the latest version;
3) config ss over ws+tls behind web service;
4) (optional) install web contents (WordPress).

## Requirements

1) a VPS running Ubuntu, might work on Debian;
2) a valid domain pointing to the IP address of your VPS;
3) (optional) an email address to receive private key;
4) (optional if chosen 3) set up a password to private key.

## Usage

Start a screen session (optional):

```
apt update && apt -y install screen && screen -S autoall
```
SSH into your VPS and run commands:  

```
wget --no-check-certificate -qO ~/autoall.sh https://git.io/JeyRB
bash ~/autoall.sh 2>&1 | tee autoall.log
```
After reboot, SSH into VPS (e.g. from KiwiVM panel) and access essential info by:  

```
cat ~/autoall.essential
```

## Changelog

### 20220905

Minor fix for dead links. Tested OK on Ubuntu 22.04.

### 20191208

Add add-site.sh functionality.  
Optional to add WordPress web contents.  
Optional to ban direct IP access, preventing WordPress from exposing your IP & domain.  
Either add-site.sh or ss-libev.sh should also work independently after autoall.sh runs.

### 20191206

Initial scripts to automatically install ss, plugin, lamp, and configure ws+tls behind web service.  
By default, the script installs lastest version of lamp stack.

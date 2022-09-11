# bwh-auto: simplify the setup of ss+ws+tls+web

## Tested OK on [BandwagonHost VPS](https://tinyurl.com/y4v2rl2u) Ubuntu 22.04 / Debian 11

## What it does

1) install shadowsocks-libev and v2ray-plugin;
2) install lamp stack (thanks to [lamp.sh](https://lamp.sh));
3) config ss over ws+tls;
4) (optional) install web contents (WordPress).

## Requirements

1) a VPS running Ubuntu / Debian;
2) a valid domain pointing to the IP address of your VPS;
3) (optional) an email address to receive SSH private key;
4) (optional if chosen 3) set up a password to private key.

## Usage

Start a screen session (recommended):

```
apt update && apt -y install screen && screen -S autoall
```
Run scripts:  

```
wget --no-check-certificate -qO ~/autoall.sh https://git.io/JeyRB
bash ~/autoall.sh 2>&1 | tee autoall.log
```
After reboot, reconnect to VPS via SSH (get SSH private key from email if required), or use "Root shell" in KiwiVM:

```
cat ~/autoall.essential
```

## Changelog

### 20220910

Workaround fix for Debian 11.

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

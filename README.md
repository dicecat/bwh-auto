# Tested on BandwagonHost VPS running Ubuntu 18.04.
# 
# [Support me & register an BandwagonHost account ](https://tinyurl.com/y4v2rl2u)

1. Things done
1) install shadowsocks-libev and v2ray-plugin;
2) install lamp;
3) config ss over ws+tls behind web service.

2. Requirements
1) an accessible domain;
2) (optional) an password to private key, if you choose to use key pair to log in;
3) (optional) an email address, if you want to receive essential info after things done.

3. Usage
1) apt-get -qq install screen host
2) screen -S bwh
3) wget --no-check-certificate -qO ~/autoall.sh https://raw.githubusercontent.com/dicecat/bwh-auto/master/autoall.sh
4) chmod +x ~/autoall.sh
5) ~/autoall.sh 2>&1 | tee autoall.log


# Tested on [BandwagonHost VPS](https://tinyurl.com/y4v2rl2u) running Ubuntu 18.04.

1. Things done
1) install shadowsocks-libev and v2ray-plugin;
2) install lamp;
3) config ss over ws+tls behind web service.

2. Requirements
1) a valid domain pointed to the IP address of your VPS;
2) (optional) an password to private key, if you choose to use key pair to log in;
3) (optional) an email address, if you want to receive essential info after things done.

3. Usage
1) apt-get -qq install screen host
2) screen -S bwh
3) wget --no-check-certificate -qO ~/autoall.sh https://git.io/JeyRB
4) bash ~/autoall.sh 2>&1 | tee autoall.log


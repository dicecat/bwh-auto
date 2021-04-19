#!/usr/bin/env bash
mkdir -p ~/osposdb
cd ~/osposdb
dbrootpwd=$(cat ~/autoall.essential | grep 'root password' | cut -f3 -d\ )
mysqldump -uroot -p${dbrootpwd} ospos | gzip >"osposdb_$(date +\%Y_\%m_\%d_\%H).sql.gz"
#sleep 10
rclone copy "osposdb_$(date +\%Y_\%m_\%d_\%H).sql.gz" drive:/osposdb
#find . -mtime +10 -type f -delete

if crontab -l | grep -q "backupmysqldb"; then
    exit 0;
else
    (
        crontab -l
        echo '30 3 * * * /root/backupmysqldb.sh'
    ) | crontab -
fi

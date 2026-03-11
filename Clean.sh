#!/bin/bash

# 清理Linux和宝塔面板隐私日志脚本
# 使用方法: sudo bash clean_privacy_logs.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用root权限运行此脚本${NC}"
    echo "使用方法: sudo bash $0"
    exit 1
fi

echo -e "${YELLOW}=== 开始清理隐私日志 ===${NC}\n"

# 1. 清理系统日志
echo -e "${GREEN}[1/8] 清理系统日志...${NC}"
> /var/log/messages 2>/dev/null
> /var/log/syslog 2>/dev/null
> /var/log/auth.log 2>/dev/null
> /var/log/secure 2>/dev/null
> /var/log/wtmp 2>/dev/null
> /var/log/btmp 2>/dev/null
> /var/log/lastlog 2>/dev/null
> /var/log/faillog 2>/dev/null
echo "系统日志已清理"

# 2. 清理bash历史记录
echo -e "\n${GREEN}[2/8] 清理bash历史记录...${NC}"
history -c
> ~/.bash_history
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        > "$user_home/.bash_history" 2>/dev/null
    fi
done
> /root/.bash_history
echo "bash历史记录已清理"

# 3. 清理宝塔面板日志
echo -e "\n${GREEN}[3/8] 清理宝塔面板日志...${NC}"
if [ -d "/www/server/panel" ]; then
    > /www/server/panel/logs/error.log 2>/dev/null
    > /www/server/panel/logs/request.log 2>/dev/null
    rm -f /www/server/panel/logs/*.log 2>/dev/null

    # 清理数据库中的操作日志
    if [ -d "/www/server/panel/data/db" ]; then
        cd /www/server/panel
        python3 -c "
import sqlite3
import os

# 清理 log.db（操作日志）
if os.path.exists('/www/server/panel/data/db/log.db'):
    conn = sqlite3.connect('/www/server/panel/data/db/log.db')
    cursor = conn.cursor()
    cursor.execute('SELECT name FROM sqlite_master WHERE type=\"table\"')
    tables = cursor.fetchall()
    for table in tables:
        cursor.execute(f'DELETE FROM {table[0]}')
    conn.commit()
    conn.execute('VACUUM')
    conn.close()

# 清理 default.db（旧位置）
if os.path.exists('/www/server/panel/data/default.db'):
    conn = sqlite3.connect('/www/server/panel/data/default.db')
    cursor = conn.cursor()
    cursor.execute('DELETE FROM logs')
    cursor.execute('DELETE FROM binding')
    conn.commit()
    conn.execute('VACUUM')
    conn.close()

# 清理 db/default.db（新位置 - 包含登录日志）
if os.path.exists('/www/server/panel/data/db/default.db'):
    conn = sqlite3.connect('/www/server/panel/data/db/default.db')
    cursor = conn.cursor()
    cursor.execute('DELETE FROM logs')
    cursor.execute('DELETE FROM binding')
    cursor.execute('DELETE FROM ssh_login_record')
    cursor.execute('DELETE FROM temp_login')
    conn.commit()
    conn.execute('VACUUM')
    conn.close()
" 2>/dev/null
        echo "宝塔面板日志和数据库记录已清理"
    else
        echo "宝塔面板日志已清理"
    fi
else
    echo "未检测到宝塔面板"
fi

# 4. 清理Nginx日志
echo -e "\n${GREEN}[4/8] 清理Nginx日志...${NC}"
if [ -d "/www/wwwlogs" ]; then
    > /www/wwwlogs/*.log 2>/dev/null
    find /www/wwwlogs -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
    echo "Nginx日志已清理"
fi
if [ -d "/var/log/nginx" ]; then
    > /var/log/nginx/access.log 2>/dev/null
    > /var/log/nginx/error.log 2>/dev/null
    echo "系统Nginx日志已清理"
fi

# 5. 清理Apache日志
echo -e "\n${GREEN}[5/8] 清理Apache日志...${NC}"
if [ -d "/var/log/apache2" ]; then
    > /var/log/apache2/access.log 2>/dev/null
    > /var/log/apache2/error.log 2>/dev/null
    echo "Apache日志已清理"
elif [ -d "/var/log/httpd" ]; then
    > /var/log/httpd/access_log 2>/dev/null
    > /var/log/httpd/error_log 2>/dev/null
    echo "Apache日志已清理"
fi

# 6. 清理MySQL/MariaDB日志
echo -e "\n${GREEN}[6/8] 清理MySQL日志...${NC}"
if [ -f "/www/server/data/*.log" ]; then
    > /www/server/data/*.log 2>/dev/null
fi
> /var/log/mysql/error.log 2>/dev/null
> /var/log/mariadb/mariadb.log 2>/dev/null
mysql -e "RESET MASTER;" 2>/dev/null
echo "MySQL日志已清理"

# 7. 清理FTP日志
echo -e "\n${GREEN}[7/8] 清理FTP日志...${NC}"
> /var/log/vsftpd.log 2>/dev/null
> /var/log/xferlog 2>/dev/null
if [ -d "/www/server/pure-ftpd/logs" ]; then
    > /www/server/pure-ftpd/logs/*.log 2>/dev/null
fi
echo "FTP日志已清理"

# 8. 清理其他日志
echo -e "\n${GREEN}[8/8] 清理其他日志...${NC}"
> /var/log/cron 2>/dev/null
> /var/log/maillog 2>/dev/null
> /var/log/mail.log 2>/dev/null
journalctl --vacuum-time=1s 2>/dev/null
echo "其他日志已清理"

echo -e "\n${YELLOW}=== 清理完成 ===${NC}"
echo -e "${GREEN}所有隐私日志已清理完毕！${NC}"

#!/bin/bash

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then 
  echo "错误：请以 root 权限运行此脚本"
  exit 1
fi

# 2. 自动识别系统并清理默认 MOTD 信息
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

case "$OS" in
    ubuntu|debian)
        true > /etc/motd 2>/dev/null
        true > /etc/issue 2>/dev/null
        true > /etc/issue.net 2>/dev/null
        [ -d /etc/update-motd.d ] && chmod -x /etc/update-motd.d/* 2>/dev/null || true
        ;;
    armbian)
        true > /etc/motd 2>/dev/null
        [ -d /etc/update-motd.d ] && chmod -x /etc/update-motd.d/* 2>/dev/null || true
        [ -f /etc/default/armbian-motd ] && sed -i 's/ENABLED=true/ENABLED=false/' /etc/default/armbian-motd 2>/dev/null
        ;;
    alpine)
        true > /etc/motd 2>/dev/null
        true > /etc/issue 2>/dev/null
        # 确保 Alpine 具备登录日志记录文件
        [ -f /var/log/wtmp ] || touch /var/log/wtmp 2>/dev/null
        if ! command -v bash >/dev/null 2>&1; then apk add bash 2>/dev/null; fi
        ;;
    *)
        true > /etc/motd 2>/dev/null
        ;;
esac

# 3. 写入 custom-motd.sh 脚本
TARGET_PATH="/etc/profile.d/custom-motd.sh"

cat << 'EOF' > $TARGET_PATH
#!/bin/bash

# 1. 核心逻辑：防止 sudo 切换或非交互式 Shell 时重复显示
[ -n "$SUDO_USER" ] && return
[[ $- != *i* ]] && return 2>/dev/null

# 颜色定义
GREEN='\033[1;32m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; RED='\033[1;31m'; RESET='\033[0m'

# 2. 基础信息采集
USER_NAME=$(whoami)
HOSTNAME=$(hostname 2>/dev/null || uname -n)

# 系统版本 (防止多行 PRETTY_NAME 重复)
OS_VER=$(grep -m 1 "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d '=' -f 2 | tr -d '"')
[ -z "$OS_VER" ] && OS_VER="Unknown OS"

# 时间与星期
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
WEEKDAY_NUM=$(date '+%u')
case "$WEEKDAY_NUM" in
    1) WEEKDAY="星期一" ;; 2) WEEKDAY="星期二" ;; 3) WEEKDAY="星期三" ;;
    4) WEEKDAY="星期四" ;; 5) WEEKDAY="星期五" ;; 6) WEEKDAY="星期六" ;;
    7) WEEKDAY="星期日" ;; *) WEEKDAY="未知" ;;
esac

# 统一读取 /proc/uptime 计算运行时间
if [ -f /proc/uptime ]; then
    UPTIME=$(awk '{
        up=int($1);
        d=int(up/86400);
        h=int((up%86400)/3600);
        m=int((up%3600)/60);
        if(d>0) printf "%d天 ", d;
        if(h>0 || d>0) printf "%d小时 ", h;
        printf "%d分钟", m;
    }' /proc/uptime)
else
    UPTIME=$(uptime 2>/dev/null | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
fi

# 内存与磁盘使用率
MEM_INFO=$(free -h 2>/dev/null | grep -Ei "mem|内存" | awk '{print $3 " / " $2}')
DISK_INFO=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
DISK_PERCENT=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')

# 系统最后更新日志记录
if [ -f /var/log/apt/history.log ]; then
    LAST_UPDATE=$(stat -c %y /var/log/apt/history.log 2>/dev/null | cut -d '.' -f1)
elif [ -f /var/log/dpkg.log ]; then
    LAST_UPDATE=$(stat -c %y /var/log/dpkg.log 2>/dev/null | cut -d '.' -f1)
elif [ -f /var/log/apk.log ]; then
    LAST_UPDATE=$(stat -c %y /var/log/apk.log 2>/dev/null | cut -d '.' -f1)
else
    LAST_UPDATE="未知"
fi
[ -z "$LAST_UPDATE" ] && LAST_UPDATE="未知"

# 3. Docker 状态与容器分类
if command -v docker &> /dev/null; then
    RUNNING_APPS=$(docker ps --format "{{.Names}}" 2>/dev/null | sort)
    EXITED_APPS=$(docker ps -a --filter "status=exited" --filter "status=created" --format "{{.Names}}" 2>/dev/null | sort)
    D_TOTAL_COUNT=$(docker ps -a -q 2>/dev/null | wc -l | tr -d ' ')
    D_IMAGES=$(docker images -q 2>/dev/null | wc -l | tr -d ' ')
    D_STATUS="✅ Docker 运行中：容器 $D_TOTAL_COUNT 个，镜像 $D_IMAGES 个"
else
    D_STATUS="❌ 未安装 Docker"
fi

# 4. 输出界面
echo -e "${GREEN}👋 欢迎回来, ${USER_NAME}@${HOSTNAME}!${RESET}"
echo -e "${BLUE}------------------------------------------------------------${RESET}"
echo -e "⏰ ${BLUE}当前时间:${RESET}    ${CYAN}${CURRENT_DATE} (${WEEKDAY})${RESET}"
echo -e "🆙 ${BLUE}运行时间:${RESET}    ${CYAN}${UPTIME}${RESET}"
echo -e "💾 ${BLUE}内存使用:${RESET}    ${CYAN}${MEM_INFO}${RESET}"
echo -e "🗂️ ${BLUE}磁盘使用:${RESET}    ${CYAN}${DISK_INFO}${RESET}"
echo -e "📦 系统更新:${RESET}    ${CYAN}${LAST_UPDATE}${RESET}"
echo -e "🖥️ 系统版本:${RESET}    ${CYAN}${OS_VER}${RESET}"
echo -e "${BLUE}------------------------------------------------------------${RESET}"

# 5. Docker 容器列表
echo -e "\n${YELLOW}🐳 Docker 状态:${RESET}   ${D_STATUS}"

if [ -n "$RUNNING_APPS" ]; then
    for app in $RUNNING_APPS; do
        echo -e "${GREEN}✅ $app 运行中${RESET}"
    done
fi
if [ -n "$EXITED_APPS" ]; then
    for app in $EXITED_APPS; do
        echo -e "${RED}❌ $app 未运行${RESET}"
    done
fi

# 6. 最近登录记录 (彻底剔除 BusyBox 表头与系统关重启记录)
if command -v last &> /dev/null; then
    LAST_LOGS=$(last 2>/dev/null | grep -vE "reboot|wtmp|^$|^USER|LOGIN" | head -n 3)
    if [ -n "$LAST_LOGS" ]; then
        echo -e "\n${YELLOW}🛡️ 最近登录记录:${RESET}"
        echo "$LAST_LOGS" | awk '{printf "  %-8s %-10s %-15s %s %s %s %s\n", $1, $2, $3, $4, $5, $6, $7}'
    fi
fi

# 7. 磁盘预警
if [ -n "$DISK_PERCENT" ] && [ "$DISK_PERCENT" -ge 70 ] 2>/dev/null; then
    echo -e "\n${RED}💔 警告：磁盘使用率已达到 ${DISK_PERCENT}%，请及时清理！${RESET}"
fi
echo ""
EOF

# 4. 设置权限
chmod +x $TARGET_PATH
echo "✅ 修复完成！重新登录 SSH 验证即可（注：Alpine 运行此命令后，下一次登录开始便会自动记录并正常展示）。"

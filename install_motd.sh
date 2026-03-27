#!/bin/bash

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then 
  echo "错误：请以 root 权限运行此脚本"
  exit 1
fi

# 2. 自动识别系统并清理默认信息
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

case "$OS" in
    ubuntu|debian)
        true > /etc/motd
        true > /etc/issue
        true > /etc/issue.net
        [ -d /etc/update-motd.d ] && chmod -x /etc/update-motd.d/* 2>/dev/null || true
        ;;
    armbian)
        chmod -x /etc/update-motd.d/* 2>/dev/null || true
        [ -f /etc/default/armbian-motd ] && sed -i 's/ENABLED=true/ENABLED=false/' /etc/default/armbian-motd 2>/dev/null
        ;;
    alpine)
        true > /etc/motd
        true > /etc/issue
        if ! command -v bash >/dev/null 2>&1; then apk add bash 2>/dev/null; fi
        ;;
    *)
        true > /etc/motd
        ;;
esac

# 3. 写入你的原始脚本内容 (完全保留你的缩进和逻辑)
TARGET_PATH="/etc/profile.d/custom-motd.sh"

cat << 'EOF' > $TARGET_PATH
#!/bin/bash

# 1. 核心逻辑：防止 sudo 切换时重复显示
# 如果是从 mac 用户通过 sudo -i 进来的，直接退出，不显示第二次
[ -n "$SUDO_USER" ] && return

# 颜色定义
GREEN='\033[1;32m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; RED='\033[1;31m'; RESET='\033[0m'

# 2. 基础信息采集
USER_NAME=$(whoami)
HOSTNAME=$(hostname)
OS_VER=$(grep "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2)

# 时间与星期
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
WEEKDAY_NUM=$(date '+%u')
case "$WEEKDAY_NUM" in
    1) WEEKDAY="星期一" ;; 2) WEEKDAY="星期二" ;; 3) WEEKDAY="星期三" ;;
    4) WEEKDAY="星期四" ;; 5) WEEKDAY="星期五" ;; 6) WEEKDAY="星期六" ;;
    7) WEEKDAY="星期日" ;; *) WEEKDAY="未知" ;;
esac

# 内存与磁盘
MEM_INFO=$(free -h | grep -Ei "mem|内存" | awk '{print $3 " / " $2}')
DISK_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
UPTIME=$(uptime -p | sed 's/up //')
LAST_UPDATE=$(stat -c %y /var/log/apt/history.log 2>/dev/null | cut -d '.' -f1 || echo "Unknown")

# 3. Docker 详细状态与容器分类
if command -v docker &> /dev/null; then
    RUNNING_APPS=$(docker ps --format "{{.Names}}" | sort)
    EXITED_APPS=$(docker ps -a --filter "status=exited" --filter "status=created" --format "{{.Names}}" | sort)
    D_TOTAL_COUNT=$(docker ps -a -q | wc -l)
    D_IMAGES=$(docker images -q | wc -l)
    D_STATUS="✅ Docker 运行中：容器 $D_TOTAL_COUNT 个，镜像 $D_IMAGES 个"
else
    D_STATUS="❌ 未安装 Docker"
fi

# 4. 输出界面
echo -e "${GREEN}👋 欢迎回来, ${USER_NAME}!${RESET}"
echo -e "${BLUE}------------------------------------------------------------${RESET}"
echo -e "⏰ ${BLUE}当前时间:${RESET}    ${CYAN}${CURRENT_DATE} (${WEEKDAY})${RESET}"
echo -e "🆙 ${BLUE}运行时间:${RESET}    ${CYAN}${UPTIME}${RESET}"
echo -e "💾 ${BLUE}内存使用:${RESET}    ${CYAN}${MEM_INFO}${RESET}"
echo -e "🗂️  ${BLUE}磁盘使用:${RESET}    ${CYAN}${DISK_INFO}${RESET}"
echo -e "📦 系统更新:${RESET}    ${CYAN}${LAST_UPDATE}${RESET}"
echo -e "🖥️  系统版本:${RESET}    ${CYAN}${OS_VER}${RESET}"
echo -e "${BLUE}------------------------------------------------------------${RESET}"

# 5. Docker 统计
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

# 6. 最近登录记录
if command -v last &> /dev/null; then
    echo -e "\n${YELLOW}🛡️ 最近登录记录:${RESET}"
    last -i -n 3 | grep -vE "reboot|wtmp" | head -n 3 | awk '{printf "  %-8s %-10s %-15s %s %s %s %s\n", $1, $2, $3, $4, $5, $6, $7}'
fi

# 7. 磁盘告警
if [ "$DISK_PERCENT" -ge 70 ]; then
    echo -e "\n${RED}💔 警告：磁盘使用率已达到 ${DISK_PERCENT}%，请及时清理！${RESET}"
fi
echo ""
EOF

# 4. 设置权限
chmod +x $TARGET_PATH
echo "✅ 安装成功！请重新连接 SSH 终端查看效果。"

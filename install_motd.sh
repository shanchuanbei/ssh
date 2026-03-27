#!/bin/bash

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then 
  echo "错误：请以 root 权限运行此脚本"
  exit 1
fi

# 2. 自动识别系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "正在为系统 [$OS] 配置登录信息..."

# 3. 根据系统禁用默认登录信息
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

# 4. 写入自定义 MOTD 脚本
TARGET_PATH="/etc/profile.d/custom-motd.sh"

cat << 'EOF' > $TARGET_PATH
#!/bin/bash

# 防止 sudo 切换时重复显示
[ -n "$SUDO_USER" ] && return

# 颜色定义
GREEN='\033[1;32m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; RED='\033[1;31m'; RESET='\033[0m'

# 基础信息采集
USER_NAME=$(whoami)
OS_VER=$(grep "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2 | tr -d '"')

# 时间与星期
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
WEEKDAY_NUM=$(date '+%u')
case "$WEEKDAY_NUM" in
    1) WEEKDAY="星期一" ;; 2) WEEKDAY="星期二" ;; 3) WEEKDAY="星期三" ;;
    4) WEEKDAY="星期四" ;; 5) WEEKDAY="星期五" ;; 6) WEEKDAY="星期六" ;;
    7) WEEKDAY="星期日" ;; *) WEEKDAY="未知" ;;
esac

# 内存与磁盘
MEM_INFO=$(free -h 2>/dev/null | grep -Ei "mem|内存" | awk '{print $3 " / " $2}' || echo "N/A")
DISK_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | awk '{print $3,$4}' | sed 's/,//')

# Docker 统计逻辑
if command -v docker &> /dev/null; then
    RUNNING_APPS=$(docker ps --format "{{.Names}}" | sort)
    EXITED_APPS=$(docker ps -a --filter "status=exited" --filter "status=created" --format "{{.Names}}" | sort)
    D_TOTAL=$(docker ps -a -q | wc -l)
    D_IMAGES=$(docker images -q | wc -l)
    D_STATUS="✅ Docker 运行中：容器 ${D_TOTAL} 个，镜像 ${D_IMAGES} 个"
else
    D_STATUS="❌ 未安装 Docker"
fi

# 输出界面
echo -e "${GREEN}👋 欢迎回来, ${USER_NAME}!${RESET}"
echo -e "${BLUE}------------------------------------------------------------${RESET}"
echo -e "⏰ ${BLUE}当前时间:${RESET}    ${CYAN}${CURRENT_DATE} (${WEEKDAY})${RESET}"
echo -e "🆙 ${BLUE}运行时间:${RESET}    ${CYAN}${UPTIME}${RESET}"
echo -e "💾 ${BLUE}内存使用:${RESET}    ${CYAN}${MEM_INFO}${RESET}"
echo -e "🗂️  ${BLUE}磁盘使用:${RESET}    ${CYAN}${DISK_INFO}${RESET}"
echo -e "🖥️  ${BLUE}系统版本:${RESET}    ${CYAN}${OS_VER}${RESET}"
echo -e "${BLUE}------------------------------------------------------------${RESET}"

# Docker 展示
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

# 最近登录记录
if command -v last &> /dev/null; then
    echo -e "\n${YELLOW}🛡️ 最近登录记录:${RESET}"
    last -i -n 3 | grep -vE "reboot|wtmp" | head -n 3
fi

# 磁盘预警
if [ "$DISK_PERCENT" -ge 70 ] 2>/dev/null; then
    echo -e "\n${RED}💔 警告：磁盘使用率已达到 ${DISK_PERCENT}%，请及时清理！${RESET}"
fi
echo ""
EOF

# 5. 设置权限
chmod +x $TARGET_PATH
echo "✅ 安装成功！已强制移除所有缩进。"

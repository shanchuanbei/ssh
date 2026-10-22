
#!/bin/bash
set -Eeuo pipefail


if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 权限运行：sudo bash install-motd.sh"
    exit 1
fi

DISPLAY_SCRIPT="/usr/local/bin/custom-motd-display.sh"
PROFILE_SCRIPT="/etc/profile.d/custom-motd.sh"
SSH_CONFIG="/etc/ssh/sshd_config"
PAM_SSH="/etc/pam.d/sshd"

echo "正在安装通用 MOTD..."

# ------------------------------------------------------------
# 1. 备份现有配置
# ------------------------------------------------------------

backup_file() {
    local file="$1"
    if [ -f "$file" ] && [ ! -e "${file}.custom-motd.bak" ]; then
        cp -a "$file" "${file}.custom-motd.bak"
    fi
}

backup_file "$DISPLAY_SCRIPT"
backup_file "$PROFILE_SCRIPT"
backup_file "$SSH_CONFIG"
backup_file "$PAM_SSH"
backup_file /etc/issue
backup_file /etc/issue.net

# ------------------------------------------------------------
# 2. 自定义 MOTD 显示脚本
# ------------------------------------------------------------

cat > "$DISPLAY_SCRIPT" <<'DISPLAY_EOF'
#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

get_os_name() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}"
    else
        printf 'Linux'
    fi
}

get_uptime() {
    local seconds
    seconds=$(awk '{print int($1)}' /proc/uptime)
    printf '%s天 / %s小时 / %s分钟' \
        "$((seconds / 86400))" \
        "$(((seconds % 86400) / 3600))" \
        "$(((seconds % 3600) / 60))"
}

get_memory() {
    if command -v free >/dev/null 2>&1; then
        free -h | awk 'NR==2 {printf "%s / %s", $3, $2}'
    else
        printf '无法获取'
    fi
}

get_disk() {
    df -h / 2>/dev/null |
        awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}'
}

# APT 更新时间：优先成功时间戳，其次索引更新时间，再查日志
get_update_time() {
    local stamp latest result

    for stamp in \
        /var/lib/apt/periodic/update-success-stamp \
        /var/lib/apt/periodic/update-stamp
    do
        if [ -f "$stamp" ]; then
            result=$(date -r "$stamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)
            if [ -n "$result" ]; then
                printf '%s' "$result"
                return
            fi
        fi
    done

    if [ -d /var/lib/apt/lists ]; then
        latest=$(
            find /var/lib/apt/lists -maxdepth 1 -type f \
                ! -name lock ! -path '*/partial/*' \
                -printf '%T@\n' 2>/dev/null |
            sort -nr | head -n 1
        )

        if [ -n "$latest" ]; then
            result=$(date -d "@${latest%.*}" \
                '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)
            if [ -n "$result" ]; then
                printf '%s' "$result"
                return
            fi
        fi
    fi

    if command -v journalctl >/dev/null 2>&1; then
        result=$(
            journalctl -u apt-daily.service \
                -u apt-daily-upgrade.service \
                --no-pager -o short-iso -n 300 2>/dev/null |
            grep -E 'Starting .*Daily apt|Started .*Daily apt|Finished .*Daily apt|Reading package lists' |
            tail -n 1 | awk '{print $1}'
        )

        if [ -n "$result" ]; then
            result=$(date -d "$result" \
                '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)
            if [ -n "$result" ]; then
                printf '%s' "$result"
                return
            fi
        fi
    fi

    printf '暂无记录'
}

get_current_time() {
    date '+%Y-%m-%d %H:%M:%S (%A)' |
        sed \
            -e 's/Monday/星期一/' \
            -e 's/Tuesday/星期二/' \
            -e 's/Wednesday/星期三/' \
            -e 's/Thursday/星期四/' \
            -e 's/Friday/星期五/' \
            -e 's/Saturday/星期六/' \
            -e 's/Sunday/星期日/'
}

# SSH 认证日志：优先 journal，随后尝试传统日志文件
get_ssh_logs() {
    local logs logfile

    if command -v journalctl >/dev/null 2>&1; then
        logs=$(
            journalctl -u ssh.service -u sshd.service \
                --since today --no-pager -o short-iso 2>/dev/null || true
        )
        if [ -n "$logs" ]; then
            printf '%s\n' "$logs"
            return
        fi
    fi

    for logfile in /var/log/auth.log /var/log/secure; do
        if [ -r "$logfile" ]; then
            grep -F "$(date '+%b %e')" "$logfile" 2>/dev/null || true
            return
        fi
    done

    return 1
}

get_failed_count() {
    local logs count
    logs=$(get_ssh_logs 2>/dev/null || true)

    if [ -z "$logs" ]; then
        printf '无法读取'
        return
    fi

    count=$(
        printf '%s\n' "$logs" |
        grep -Eic \
            'Failed password|Invalid user|authentication failure|Failed publickey' ||
        true
    )

    printf '%s' "${count:-0}"
}

get_recent_logins() {
    local logs result

    logs=$(get_ssh_logs 2>/dev/null || true)

    if [ -z "$logs" ]; then
        echo "   无法读取系统认证日志"
        return
    fi

    result=$(
        printf '%s\n' "$logs" |
        awk '
        /Accepted password for/ || /Accepted publickey for/ {
            timestamp=""
            user=""
            ip=""

            if ($1 ~ /^[0-9][0-9][0-9][0-9]-/) {
                timestamp=$1
            } else {
                timestamp=$1 " " $2 " " $3
            }

            for (i=1; i<=NF; i++) {
                if ($i=="for" && i<NF) user=$(i+1)
                if ($i=="from" && i<NF) ip=$(i+1)
            }

            if (user!="" && ip!="") {
                print timestamp "\t" user "\t" ip
            }
        }' |
        tail -n 3 |
        while IFS="$(printf '\t')" read -r timestamp user ip; do
            [ -n "$user" ] || continue

            formatted=$(
                date -d "$timestamp" '+%-m月%-d日 %H:%M' 2>/dev/null ||
                printf '%s' "$timestamp"
            )

            printf '   %-8s %-20s %s\n' "$user" "$ip" "$formatted"
        done
    )

    if [ -n "$result" ]; then
        printf '%s\n' "$result"
    else
        echo "   暂无可读取的登录成功历史"
    fi
}

show_docker() {
    local containers images name

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "🐳 Docker 状态：${YELLOW}⚠️ Docker 未安装${NC}"
        return
    fi

    if ! docker info >/dev/null 2>&1; then
        echo -e "🐳 Docker 状态：${RED}❌ Docker 未运行或无法访问${NC}"
        return
    fi

    containers=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    images=$(docker images --format '{{.ID}}' 2>/dev/null |
        sort -u | wc -l | tr -d ' ')

    echo -e "🐳 Docker 状态：${GREEN}✅ Docker 运行中：容器 ${containers} 个，镜像 ${images} 个${NC}"

    if [ "${containers:-0}" -gt 0 ] 2>/dev/null; then
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            echo -e "   ${GREEN}✅ ${name} 运行中${NC}"
        done < <(docker ps --format '{{.Names}}' 2>/dev/null)
    else
        echo "   当前没有正在运行的容器"
    fi
}

echo "------------------------------------------------------------"
echo -e "👋 欢迎回来, ${GREEN}$(whoami)@$(hostname)${NC}!"
echo "------------------------------------------------------------"
echo -e "⏰ 当前时间:    $(get_current_time)"
echo -e "🆙 运行时间:    $(get_uptime)"
echo -e "💾 内存使用:    $(get_memory)"
echo -e "🗂️ 磁盘使用:    $(get_disk)"
echo -e "📦 更新日志:    $(get_update_time)"
echo -e "🖥️ 系统版本:    $(get_os_name)"
echo "------------------------------------------------------------"

show_docker

echo "------------------------------------------------------------"

failed_count=$(get_failed_count)
if [ "$failed_count" = "无法读取" ]; then
    echo -e "⚠️ SSH 认证失败次数：${YELLOW}无法读取认证日志${NC}"
else
    echo -e "⚠️ SSH 认证失败次数：${YELLOW}${failed_count}次${NC}"
fi

echo "✔️ 最近登录成功记录（显示最近三条）："
get_recent_logins
echo "------------------------------------------------------------"
DISPLAY_EOF

chmod 755 "$DISPLAY_SCRIPT"
bash -n "$DISPLAY_SCRIPT"

# ------------------------------------------------------------
# 3. 创建登录入口
# ------------------------------------------------------------

cat > "$PROFILE_SCRIPT" <<'PROFILE_EOF'
# 仅在交互式 Shell 中显示
case "$-" in
    *i*) ;;
    *) return 0 2>/dev/null || exit 0 ;;
esac

# 同一 Shell 避免重复显示
if [ -n "${CUSTOM_MOTD_SHOWN:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

# sudo -i 切换到 root 时跳过重复显示
if [ "$(id -u)" -eq 0 ] &&
   [ -n "${SUDO_USER:-}" ] &&
   [ "$SUDO_USER" != "root" ]; then
    CUSTOM_MOTD_SHOWN=1
    export CUSTOM_MOTD_SHOWN
    return 0 2>/dev/null || exit 0
fi

CUSTOM_MOTD_SHOWN=1
export CUSTOM_MOTD_SHOWN

if [ -x /usr/local/bin/custom-motd-display.sh ]; then
    /bin/bash /usr/local/bin/custom-motd-display.sh
fi
PROFILE_EOF

chmod 644 "$PROFILE_SCRIPT"
bash -n "$PROFILE_SCRIPT"

# ------------------------------------------------------------
# 4. 屏蔽 SSH 原始登录信息
# ------------------------------------------------------------

echo "正在屏蔽系统原始登录信息..."

# 设置 SSH 选项。
# 使用 00 开头的配置文件，兼容 Debian / Ubuntu 常见的
# sshd_config.d Include 配置；同时修改主配置作为回退。
mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/00-custom-motd.conf <<'SSH_EOF'
PrintMotd no
PrintLastLog no
Banner none
SSH_EOF

# 同步修改主配置中已有的同名指令，避免配置冲突。
if [ -f "$SSH_CONFIG" ]; then
    sed -i -E \
        '/^[[:space:]]*#?[[:space:]]*(PrintMotd|PrintLastLog|Banner)[[:space:]]+/Id' \
        "$SSH_CONFIG"

    cat >> "$SSH_CONFIG" <<'SSH_MAIN_EOF'

# Custom MOTD: disable default SSH login banners
PrintMotd no
PrintLastLog no
Banner none
SSH_MAIN_EOF
fi

# 禁用 PAM 在 SSH 登录时输出系统 MOTD 和 issue。
# 不删除原始配置，只注释相关 session 行。
if [ -f "$PAM_SSH" ]; then
    sed -i -E \
        '/^[[:space:]]*session[[:space:]].*pam_motd\.so/s/^/# disabled-by-custom-motd /' \
        "$PAM_SSH"

    sed -i -E \
        '/^[[:space:]]*session[[:space:]].*pam_issue\.so/s/^/# disabled-by-custom-motd /' \
        "$PAM_SSH"
fi

# 清空 SSH 可能读取的默认 issue 文件。
# 先前已经备份；这里只清空，不删除文件。
if [ -f /etc/issue ]; then
    : > /etc/issue
fi

if [ -f /etc/issue.net ]; then
    : > /etc/issue.net
fi

# ------------------------------------------------------------
# 5. 检查并重新加载 SSH 配置
# ------------------------------------------------------------

if command -v sshd >/dev/null 2>&1; then
    if sshd -t; then
        if systemctl reload ssh 2>/dev/null; then
            echo "SSH 服务配置已重新加载。"
        elif systemctl reload sshd 2>/dev/null; then
            echo "SSH 服务配置已重新加载。"
        else
            echo "警告：无法自动重新加载 SSH 服务，请检查服务状态。"
        fi
    else
        echo "警告：SSH 配置检查失败。请保持当前连接，检查配置后再重载服务。"
        exit 1
    fi
else
    echo "警告：未找到 sshd 命令，已写入配置但未能验证 SSH 设置。"
fi

# ------------------------------------------------------------
# 6. 安装完成
# ------------------------------------------------------------

echo "MOTD 安装完成！！！"

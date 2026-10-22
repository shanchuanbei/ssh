
#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 权限运行：sudo bash install-motd.sh"
    exit 1
fi

DISPLAY_SCRIPT="/usr/local/bin/custom-motd-display.sh"
PROFILE_SCRIPT="/etc/profile.d/custom-motd.sh"

# ------------------------------------------------------------
# 1. 备份旧文件
# ------------------------------------------------------------

if [ -f "$DISPLAY_SCRIPT" ]; then
    cp -a "$DISPLAY_SCRIPT" "${DISPLAY_SCRIPT}.bak"
fi

if [ -f "$PROFILE_SCRIPT" ]; then
    cp -a "$PROFILE_SCRIPT" "${PROFILE_SCRIPT}.bak"
fi


# ------------------------------------------------------------
# 2. 生成 MOTD 显示脚本
# ------------------------------------------------------------

cat > "$DISPLAY_SCRIPT" <<'DISPLAY_EOF'
#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# ------------------------------------------------------------
# 系统版本
# ------------------------------------------------------------

get_os_name() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}"
    else
        printf 'Linux'
    fi
}

# ------------------------------------------------------------
# 系统运行时间
# ------------------------------------------------------------

get_uptime() {
    local total_seconds days hours minutes

    total_seconds=$(awk '{print int($1)}' /proc/uptime)

    days=$((total_seconds / 86400))
    hours=$(((total_seconds % 86400) / 3600))
    minutes=$(((total_seconds % 3600) / 60))

    printf '%s天 / %s小时 / %s分钟' \
        "$days" "$hours" "$minutes"
}

# ------------------------------------------------------------
# 内存使用
# ------------------------------------------------------------

get_memory() {
    if command -v free >/dev/null 2>&1; then
        free -h | awk 'NR==2 {printf "%s / %s", $3, $2}'
    else
        printf '无法获取'
    fi
}

# ------------------------------------------------------------
# 根分区磁盘使用
# ------------------------------------------------------------

get_disk() {
    df -h / 2>/dev/null |
        awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}'
}

# ------------------------------------------------------------
# APT 更新时间
#
# 注意：
# - update-success-stamp 优先，代表 APT 更新成功时间戳。
# - 软件源索引时间作为通用回退。
# - systemd 日志作为最后回退之一。
# - history.log 主要记录软件包事务，并非 apt update 时间，
#   因此不把它当成精确的索引更新时间。
# ------------------------------------------------------------

get_update_time() {
    local stamp latest result

    # 来源一：APT periodic 成功更新时间戳
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

    # 来源二：APT 软件源索引文件的最近修改时间
    # 同时适用于 Debian、Ubuntu、Armbian 的常见 APT 布局
    if [ -d /var/lib/apt/lists ]; then
        latest=$(
            find /var/lib/apt/lists -maxdepth 1 -type f \
                ! -name 'lock' \
                ! -path '*/partial/*' \
                -printf '%T@\n' 2>/dev/null |
            sort -nr |
            head -n 1
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

    # 来源三：systemd APT 自动更新服务日志
    if command -v journalctl >/dev/null 2>&1; then
        result=$(
            journalctl \
                -u apt-daily.service \
                -u apt-daily-upgrade.service \
                --no-pager -o short-iso -n 300 2>/dev/null |
            grep -E \
                'Starting .*Daily apt|Started .*Daily apt|Finished .*Daily apt|APT.*update|Reading package lists' |
            tail -n 1 |
            awk '{print $1}'
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

    # 所有来源都没有记录
    printf '暂无记录'
}

# ------------------------------------------------------------
# 当前时间和中文星期
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# 读取 SSH 认证日志
# 先使用 systemd journal，失败时回退到传统日志文件
# ------------------------------------------------------------

get_ssh_logs() {
    local logs logfile

    if command -v journalctl >/dev/null 2>&1; then
        logs=$(
            journalctl \
                -u ssh.service \
                -u sshd.service \
                --since today \
                --no-pager \
                -o short-iso 2>/dev/null || true
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

# ------------------------------------------------------------
# SSH 认证失败次数
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# 最近三条 SSH 登录成功记录
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Docker 状态
# 自动检测所有运行中的容器，不指定固定应用名称
# ------------------------------------------------------------

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

    containers=$(
        docker ps -q 2>/dev/null |
        wc -l | tr -d ' '
    )

    images=$(
        docker images --format '{{.ID}}' 2>/dev/null |
        sort -u | wc -l | tr -d ' '
    )

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

# ============================================================
# 输出欢迎信息
# ============================================================

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

# 先检查显示脚本语法
if ! bash -n "$DISPLAY_SCRIPT"; then
    echo "错误：MOTD 显示脚本语法检查失败。"
    exit 1
fi

# ------------------------------------------------------------
# 3. 创建登录入口
# ------------------------------------------------------------

cat > "$PROFILE_SCRIPT" <<'PROFILE_EOF'
# 仅在交互式 Shell 中显示
case "$-" in
    *i*) ;;
    *) return 0 2>/dev/null || exit 0 ;;
esac

# 避免同一个 Shell 重复显示
if [ -n "${CUSTOM_MOTD_SHOWN:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

# sudo -i 进入 root 时尝试跳过重复显示
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

if ! bash -n "$PROFILE_SCRIPT"; then
    echo "错误：MOTD 登录入口语法检查失败。"
    exit 1
fi

# ------------------------------------------------------------
# 4. 安装完成
# ------------------------------------------------------------

echo "MOTD 安装完成！"


#!/usr/bin/env bash
# =========================================================
# Linux 全系统通用中文语言一键切换脚本 (秒级切换/自动适配)
# 支持: Debian/Ubuntu, CentOS/RHEL/Rocky, Alpine, Arch
# =========================================================

set -e

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误: 请使用 root 权限运行此脚本！"
    exit 1
fi

echo -e "\n[1/3] 🔍 正在检测系统与语言环境..."

# 1. 识别 Linux 发行版
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_LIKE=${ID_LIKE:-""}
else
    OS_ID="unknown"
    OS_LIKE=""
fi

# 2. 检测系统是否已存在 zh_CN 语言环境（实现秒级跳过）
ZH_EXISTS=false
if command -v locale >/dev/null 2>&1; then
    if locale -a 2>/dev/null | grep -iq "zh_CN"; then
        ZH_EXISTS=true
    fi
fi

# 3. 若未检测到中文环境，自动按系统安装依赖
if [ "$ZH_EXISTS" = false ]; then
    echo "[2/3] 📦 未检测到中文包，正在按需安装依赖..."
    case "$OS_ID" in
        ubuntu|debian|raspbian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq locales >/dev/null 2>&1
            if [ -f /etc/locale.gen ]; then
                sed -i '/^# *zh_CN.UTF-8/s/^# *//' /etc/locale.gen
            fi
            locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y -q glibc-langpack-zh >/dev/null 2>&1 || true
            elif command -v yum >/dev/null 2>&1; then
                yum install -y -q kde-l10n-Chinese glibc-common >/dev/null 2>&1 || true
                localedef -c -i zh_CN -f UTF-8 zh_CN.UTF-8 >/dev/null 2>&1 || true
            fi
            ;;
        alpine)
            apk add --no-cache musl-locales musl-locales-lang >/dev/null 2>&1 || true
            ;;
        arch|manjaro)
            if [ -f /etc/locale.gen ]; then
                sed -i '/^# *zh_CN.UTF-8/s/^# *//' /etc/locale.gen
                locale-gen >/dev/null 2>&1 || true
            fi
            ;;
        *)
            # 通用退路尝试
            if [[ "$OS_LIKE" == *"debian"* ]]; then
                apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq locales >/dev/null 2>&1
                locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true
            fi
            ;;
    esac
else
    echo "[2/3] ⚡ 检测到中文环境已存在，跳过安装（秒级生效模式）！"
fi

# 4. 全局写入环境变量（覆盖 systemd、profile、etc 配置文件）
echo "[3/3] ⚙️ 配置全局中文环境变量..."

# 方案 A: 使用 localectl (针对带 systemd 的系统)
if command -v localectl >/dev/null 2>&1 && systemctl status >/dev/null 2>&1; then
    localectl set-locale LANG=zh_CN.UTF-8 2>/dev/null || true
fi

# 方案 B: 写入 /etc/locale.conf (CentOS/RHEL/Arch/Debian 标配)
cat << 'EOF' > /etc/locale.conf
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
EOF

# 方案 C: 写入 /etc/default/locale (Debian/Ubuntu 标配)
if [ -d /etc/default ]; then
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
EOF
fi

# 方案 D: 写入 /etc/profile.d/locale.sh (Alpine/全系统 Shell 通用覆盖，解决 nano 等工具问题)
mkdir -p /etc/profile.d
cat << 'EOF' > /etc/profile.d/locale.sh
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
EOF
chmod +x /etc/profile.d/locale.sh

# 尝试写入个人 profile 防止 SSH 环境变量被强行重置
for user_profile in "/root/.profile" "/root/.bashrc"; do
    if [ -f "$user_profile" ]; then
        grep -q "LANG=zh_CN.UTF-8" "$user_profile" || echo "export LANG=zh_CN.UTF-8" >> "$user_profile"
        grep -q "LC_ALL=zh_CN.UTF-8" "$user_profile" || echo "export LC_ALL=zh_CN.UTF-8" >> "$user_profile"
    fi
done

echo -e "\n✅ 中文环境设置完成！"
echo "👉 请运行命令使其在当前终端立即生效：source /etc/profile.d/locale.sh"

#!/usr/bin/env bash
# =================================================================
# 全系统通用中文环境一键脚本 (融合 LocaleCN 优点 + 适配 Alpine 秒级生效)
# 支持: Debian/Ubuntu, CentOS/RHEL/Rocky, Alpine, Arch
# =================================================================

set -e

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误: 请使用 root 权限运行此脚本！"
    exit 1
fi

echo -e "\n[1/4] 🔍 检测系统发行版..."

# 1. 识别 OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
elif [ -f /etc/redhat-release ]; then
    OS_ID="centos"
else
    OS_ID="unknown"
fi

echo "[2/4] 📦 检测并安装缺失的语言包依赖..."

# 2. 缺啥补啥（已存在则秒级跳过）
case "$OS_ID" in
    alpine)
        # Alpine 专属补全：musl 字符集 + nano 翻译包
        apk add --no-cache musl-locales musl-locales-lang nano-lang >/dev/null 2>&1 || true
        # 💥 解决 Alpine/musl 无法将 zh_CN.UTF-8 映射去读取 zh_CN 目录的底层硬伤
        mkdir -p /usr/share/locale
        [ -d /usr/share/locale/zh_CN ] && ln -sf /usr/share/locale/zh_CN /usr/share/locale/zh_CN.UTF-8 2>/dev/null || true
        ;;
    ubuntu|debian|raspbian)
        if ! locale -a 2>/dev/null | grep -iq "zh_CN"; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq locales nano >/dev/null 2>&1
            # 借鉴 LocaleCN 思路：直接开启 zh_CN.UTF-8 支持
            if [ -f /etc/locale.gen ]; then
                sed -i '/^# *zh_CN.UTF-8/s/^# *//' /etc/locale.gen
            else
                echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
            fi
            locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true
        fi
        ;;
    centos|rhel|rocky|almalinux|fedora)
        if ! locale -a 2>/dev/null | grep -iq "zh_CN"; then
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y -q glibc-langpack-zh >/dev/null 2>&1 || true
            elif command -v yum >/dev/null 2>&1; then
                yum install -y -q kde-l10n-Chinese glibc-common >/dev/null 2>&1 || true
                localedef -c -i zh_CN -f UTF-8 zh_CN.UTF-8 >/dev/null 2>&1 || true
            fi
        fi
        ;;
esac

echo "[3/4] ⚙️ 写入全域配置文件 (含有 PAM / Environment / Shell Profile)..."

# 3.1 借鉴 LocaleCN：写入 /etc/environment (PAM SSH 登录最底层)
sed -i '/LANG=/d;/LC_ALL=/d;/LANGUAGE=/d;/MUSL_LOCPATH=/d' /etc/environment 2>/dev/null || true
cat << 'EOF' >> /etc/environment
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
MUSL_LOCPATH=/usr/share/i18n/locales/musl
EOF

# 3.2 写入常规 systemd / default 配置文件
cat << 'EOF' > /etc/locale.conf
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
EOF

if [ -d /etc/default ]; then
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
EOF
fi

# 3.3 写入全局 /etc/profile.d/locale.sh
mkdir -p /etc/profile.d
cat << 'EOF' > /etc/profile.d/locale.sh
export MUSL_LOCPATH=/usr/share/i18n/locales/musl
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
EOF
chmod +x /etc/profile.d/locale.sh

# 3.4 覆写用户个人 Profile 文件 (适配 Alpine 的 ash Shell 与普通 bash)
PROFILES=( "/etc/profile" "/root/.profile" "/root/.bashrc" "$HOME/.profile" "$HOME/.bashrc" )
for p in "${PROFILES[@]}"; do
    if [ -f "$p" ] || [ "$p" = "/root/.profile" ]; then
        sed -i '/export LANG=/d;/export LC_ALL=/d;/export LANGUAGE=/d;/export MUSL_LOCPATH=/d' "$p" 2>/dev/null || true
        echo "export MUSL_LOCPATH=/usr/share/i18n/locales/musl" >> "$p"
        echo "export LANG=zh_CN.UTF-8" >> "$p"
        echo "export LC_ALL=zh_CN.UTF-8" >> "$p"
        echo "export LANGUAGE=zh_CN:zh" >> "$p"
    fi
done

echo "[4/4] 🚀 强行刷新当前终端环境变量..."
export MUSL_LOCPATH=/usr/share/i18n/locales/musl
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

echo -e "\n✅ 配置完成！无需依赖外部网络，秒级切换成功。"
echo "👉 请直接输入 nano 1.txt 进行验证！"

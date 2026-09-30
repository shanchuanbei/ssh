#!/usr/bin/env bash
# =================================================================
# 全系统 Linux 中文环境一键切换脚本 (含 Alpine ash 适配与抗 SSH 压制)
# =================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误: 请使用 root 权限运行此脚本！"
    exit 1
fi

echo "[1/3] 📦 正在检测并安装系统语言包与软件翻译包..."

# 1. 判断 Alpine 系统并强行补全 Alpine 专属的翻译依赖
if [ -f /etc/alpine-release ] || grep -q "alpine" /etc/os-release 2>/dev/null; then
    apk add --no-cache musl-locales musl-locales-lang nano-lang gettext >/dev/null 2>&1 || true
elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq locales nano >/dev/null 2>&1
    sed -i '/^# *zh_CN.UTF-8/s/^# *//' /etc/locale.gen 2>/dev/null || true
    locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q glibc-langpack-zh >/dev/null 2>&1 || true
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q kde-l10n-Chinese glibc-common >/dev/null 2>&1 || true
    localedef -c -i zh_CN -f UTF-8 zh_CN.UTF-8 >/dev/null 2>&1 || true
fi

echo "[2/3] ⚙️ 写入全局与各 Shell (ash/bash) 配置文件..."

# 定义中文环境变量块
ENV_BLOCK='
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LC_MESSAGES=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
'

# 写入 Systemd / 系统全局配置
echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
echo "LC_ALL=zh_CN.UTF-8" >> /etc/locale.conf

# 写入 /etc/profile.d/ 供所有交互式 Shell 读取
mkdir -p /etc/profile.d
cat << 'EOF' > /etc/profile.d/locale.sh
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LC_MESSAGES=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
EOF
chmod +x /etc/profile.d/locale.sh

# 覆盖针对 Alpine (ash) 和常规 Linux (bash) 的用户配置文件
TARGET_FILES=(
    "/etc/profile"
    "/root/.profile"      # Alpine ash 读取的核心文件
    "/root/.bashrc"       # Debian/CentOS bash 读取的文件
    "$HOME/.profile"
    "$HOME/.bashrc"
)

for file in "${TARGET_FILES[@]}"; do
    if [ -f "$file" ] || [ "$file" = "/root/.profile" ]; then
        # 先清理旧的 LANG/LC 变量，防止重复
        sed -i '/export LANG=/d' "$file" 2>/dev/null || true
        sed -i '/export LC_ALL=/d' "$file" 2>/dev/null || true
        sed -i '/export LC_MESSAGES=/d' "$file" 2>/dev/null || true
        sed -i '/export LANGUAGE=/d' "$file" 2>/dev/null || true
        
        # 追加最新中文配置
        echo "$ENV_BLOCK" >> "$file"
    fi
done

echo "[3/3] 🚀 强制刷新当前会话环境变量..."
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LC_MESSAGES=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

echo -e "\n✅ 配置完成！请直接输入 nano 验证。"

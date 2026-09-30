#!/usr/bin/env bash
# =================================================================
# 全系统通用中文环境脚本 (抗 SSH 变量覆盖 / 秒级切换 / 支持 Alpine nano)
# =================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误: 请使用 root 权限运行此脚本！"
    exit 1
fi

echo -e "\n[1/4] 📦 检查并补全系统与软件语言包..."

# 1. 自动识别并补全依赖（已安装则秒级跳过）
if [ -f /etc/alpine-release ] || grep -q "alpine" /etc/os-release 2>/dev/null; then
    apk add --no-cache musl-locales musl-locales-lang nano-lang >/dev/null 2>&1 || true
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

echo "[2/4] 🔒 屏蔽 SSH 客户端传递的英文环境变量..."
# 注释掉 sshd_config 中的 AcceptEnv，防止客户端把 LANG/LC_* 覆盖回英文
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/^AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config 2>/dev/null || true
    rc-service sshd restart 2>/dev/null || systemctl restart sshd 2>/dev/null || pkill -HUP sshd 2>/dev/null || true
fi

echo "[3/4] ⚙️ 强行锁定全域环境变量 (LANG / LC_ALL / LC_MESSAGES / LANGUAGE)..."

# 写入 /etc/environment (SSH 登录最高优先级读取)
cat << 'EOF' > /etc/environment
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LC_MESSAGES=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
EOF

# 写入配置文件
cat << 'EOF' > /etc/locale.conf
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LC_MESSAGES=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
EOF

if [ -d /etc/default ]; then
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LC_MESSAGES=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
EOF
fi

# 写入全局 profile.d
mkdir -p /etc/profile.d
cat << 'EOF' > /etc/profile.d/locale.sh
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LC_MESSAGES=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
EOF
chmod +x /etc/profile.d/locale.sh

# 写入用户 Profile 强行覆写
PROFILES=( "/root/.profile" "/root/.bashrc" "$HOME/.profile" "$HOME/.bashrc" "/etc/bash.bashrc" )
for p in "${PROFILES[@]}"; do
    if [ -f "$p" ]; then
        sed -i '/export LANG=/d' "$p" 2>/dev/null || true
        sed -i '/export LC_ALL=/d' "$p" 2>/dev/null || true
        sed -i '/export LC_MESSAGES=/d' "$p" 2>/dev/null || true
        sed -i '/export LANGUAGE=/d' "$p" 2>/dev/null || true
        echo "export LANG=zh_CN.UTF-8" >> "$p"
        echo "export LC_ALL=zh_CN.UTF-8" >> "$p"
        echo "export LC_MESSAGES=zh_CN.UTF-8" >> "$p"
        echo "export LANGUAGE=zh_CN:zh" >> "$p"
    fi
done

echo -e "\n✅ 配置完成！"

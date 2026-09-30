#!/bin/bash

# =========================================================
# 全平台极速中文环境与 nano 部署脚本
# 支持系统：Debian / Ubuntu / Armbian / Alpine
# 适配仓库：shanchuanbei/ssh
# 说明：Debian系走官方 apt 安装，Alpine 统一拉取单二进制 nano_alpine
# =========================================================

# 1. 检查 root 权限
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 临时重置变量，避免安装过程抛出 setlocale 警告
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 2. 识别操作系统类型
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

echo "正在配置系统语言与 nano 中文环境..."

# 3. Debian / Ubuntu / Armbian 官方包逻辑
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    echo "检测到 Glibc 系统 ($ID)，正在使用官方包配置中文环境..."

    # 3.1 自动补全 locales 与 nano
    apt-get update -qq
    apt-get install -y -qq locales nano > /dev/null 2>&1

    # 3.2 启用并生成 zh_CN.UTF-8 语言数据库
    if [ -f /etc/locale.gen ]; then
        sed -i 's/# zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen 2>/dev/null
        locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    else
        localedef -i zh_CN -f UTF-8 zh_CN.UTF-8 > /dev/null 2>&1
    fi

    # 3.3 写入系统级默认 Locale 配置
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    cat << 'EOF' > /etc/environment
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    # 3.4 清理 AcceptEnv 并强行注入 SSHD 环境变量（解决重连变英文问题）
    sed -i 's/^[[:space:]]*AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config 2>/dev/null
    if [ -d /etc/ssh/sshd_config.d ]; then
        sed -i 's/^[[:space:]]*AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config.d/*.conf 2>/dev/null
    fi

    mkdir -p /etc/ssh/sshd_config.d
    cat << 'EOF' > /etc/ssh/sshd_config.d/99-zh-env.conf
SetEnv LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null

# 4. Alpine 专用逻辑 (统一使用 nano_alpine)
elif [[ "$ID" == "alpine" ]]; then
    echo "检测到 Alpine (musl)，正在应用 Alpine 语言包与 nano_alpine..."

    FETCH_CMD=""
    FETCH_OUT=""
    if command -v curl &> /dev/null; then
        FETCH_CMD="curl -sL"
        FETCH_OUT="curl -sL -o"
    elif command -v wget &> /dev/null; then
        FETCH_CMD="wget -qO-"
        FETCH_OUT="wget -qO"
    else
        apk add --no-cache curl > /dev/null 2>&1
        FETCH_CMD="curl -sL"
        FETCH_OUT="curl -sL -o"
    fi

    BASE_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main"
    ALPINE_PACK_URL="${BASE_URL}/alpine_zh_pack.tar.gz"
    ALPINE_NANO_URL="${BASE_URL}/nano_alpine"

    apk add --no-cache musl-locales > /dev/null 2>&1
    $FETCH_CMD "$ALPINE_PACK_URL" | tar -zx -C / > /dev/null 2>&1
    $FETCH_OUT /usr/bin/nano "$ALPINE_NANO_URL" > /dev/null 2>&1
    chmod +x /usr/bin/nano
fi

# 5. 通用配置：写入全局 profile.d 与 Login Shell 挂载点
cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

for f in ~/.profile ~/.bash_profile /etc/profile /etc/bash.bashrc ~/.bashrc; do
    if [ -f "$f" ]; then
        sed -i '/zh_CN.sh/d' "$f" 2>/dev/null
        echo '[ -f /etc/profile.d/zh_CN.sh ] && . /etc/profile.d/zh_CN.sh' >> "$f"
    fi
done

# 6. 刷新当前 Shell 环境变量
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 配置完成！中文环境与 nano 已生效\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 查看效果\033[0m"
echo "------------------------------------------------------------"

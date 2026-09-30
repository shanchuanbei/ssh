#!/bin/bash

# 1. 检查 root 权限
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 临时重置变量，避免解压前报 setlocale 警告
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 2. 识别操作系统类型
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

# 3. Glibc 系统语言包直链 (Debian / Ubuntu / Armbian)
GLIBC_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/zh_cn_pack.tar.gz"

echo "正在极速切换系统语言为 zh_CN.UTF-8..."

# 4. 检查下载工具
FETCH_CMD=""
if command -v curl &> /dev/null; then
    FETCH_CMD="curl -sL"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -qO-"
fi

# 5. 分系统处理
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    if [ -n "$FETCH_CMD" ]; then
        echo "检测到 Glibc 系统 ($ID)，正在拉取语言包..."
        $FETCH_CMD "$GLIBC_URL" | tar -zx -C / > /dev/null 2>&1
    fi
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$ID" == "alpine" ]]; then
    echo "检测到 Alpine (musl)，正在配置 UTF-8 中文环境..."
    # Alpine 上直接安装 musl-locales 支持中文 UTF-8 编解码
    apk add --no-cache musl-locales > /dev/null 2>&1
fi

# 6. 写入通用环境变量 (保证中文输入/显示/日志不乱码)
cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

# 7. 刷新当前 Shell
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ Yes 配置完成！\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 生效\033[0m"
echo "------------------------------------------------------------"

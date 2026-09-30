#!/bin/bash

# 1. 检查 root 权限
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 临时重置变量，避免解压前抛出 setlocale 警告
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 2. 识别操作系统类型
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

# 3. GitHub 语言包直链
GLIBC_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/zh_cn_pack.tar.gz"
ALPINE_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/alpine_zh_pack.tar.gz"

echo "正在极速切换系统语言为 zh_CN.UTF-8..."

# 4. 检查下载工具
FETCH_CMD=""
if command -v curl &> /dev/null; then
    FETCH_CMD="curl -sL"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -qO-"
else
    echo "错误：系统缺少 curl 和 wget，请先安装" && exit 1
fi

# 5. 分系统解压与配置
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    echo "检测到 Glibc 系统 ($ID)，正在拉取语言包..."
    $FETCH_CMD "$GLIBC_URL" | tar -zx -C / > /dev/null 2>&1
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$ID" == "alpine" ]]; then
    echo "检测到 Alpine (musl)，正在配置 Alpine 中文环境..."
    # Alpine 需要 musl-locales 基础库，然后注入中文翻译包
    apk add --no-cache musl-locales > /dev/null 2>&1
    $FETCH_CMD "$ALPINE_URL" | tar -zx -C / > /dev/null 2>&1
else
    echo "警告：未识别的系统类型 ($ID)，尝试通用配置..."
fi

# 6. 写入全局环境变量配置文件
cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

# 7. 立即刷新当前 Shell
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 配置完成！已成功注入中文环境与 nano/vim 字典\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 查看效果\033[0m"
echo "------------------------------------------------------------"

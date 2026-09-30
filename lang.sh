#!/bin/bash

# 1. 检查 root 权限
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 临时重置变量，避免解压前因为找不到 zh_CN 语言包而报 setlocale 警告
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 2. 识别操作系统类型
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

# 3. 语言包预设直链
PACKAGE_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/zh_cn_pack.tar.gz"

echo "正在极速切换系统语言为 zh_CN.UTF-8..."

# 4. 核心处理逻辑 (Debian / Ubuntu / Armbian)
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    
    FETCH_CMD=""
    if command -v curl &> /dev/null; then
        FETCH_CMD="curl -sL"
    elif command -v wget &> /dev/null; then
        FETCH_CMD="wget -qO-"
    else
        echo "错误：系统缺少 curl 和 wget，请先安装网络工具" && exit 1
    fi

    echo "正在拉取并部署语言包 (几秒内完成)..."
    
    if ! $FETCH_CMD "$PACKAGE_URL" | tar -zx -C / > /dev/null 2>&1; then
        echo "错误：语言包下载或解压失败，请检查网络是否能连接 GitHub" && exit 1
    fi

    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$ID" == "alpine" ]]; then
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
fi

# 解压完成后，正式刷新为中文环境
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 配置完成！已成功注入中文环境与 nano/vim 字典\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 即可看效果\033[0m"
echo "------------------------------------------------------------"

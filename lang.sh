#!/bin/bash

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then 
    echo "错误：请以 root 权限运行此脚本"
    exit 1
fi

# 2. 自动识别系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "正在尝试快速切换系统语言为 zh_CN.UTF-8..."

# 3. 执行核心逻辑
if [[ "$OS" == "debian" || "$OS" == "ubuntu" || "$OS" == "armbian" ]]; then
    # 检查是否需要安装 locales 包 (仅在缺失时运行 apt，节省大量时间)
    if ! command -v locale-gen &> /dev/null; then
        echo "正在安装基础语言包..."
        apt-get update -qq && apt-get install -y locales -qq
    fi

    # 强制写入生成配置
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen

    # 检查环境是否已生成，未生成才跑 locale-gen
    if [[ $(locale -a 2>/dev/null) != *"zh_CN.utf8"* ]]; then
        echo "正在编译语言环境 (此步可能稍慢)..."
        /usr/sbin/locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    fi

    # 直接写入配置文件 (永久生效)
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$OS" == "alpine" ]]; then
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
else
    echo "暂不支持此系统的自动切换，请手动配置。"
    exit 1
fi

# 4. 尝试在当前会话生效 (加入错误重定向，防止 setlocale 报错)
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 系统语言配置已完成！\033[0m"
echo -e "\033[1;33m📢 重要提示：退出并重新连接 SSH，即可看到中文界面。\033[0m"
echo "------------------------------------------------------------"

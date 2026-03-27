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
    # 检查是否缺失基础包或翻译包
    # Ubuntu 强力推荐安装 language-pack-zh-hans 来汉化软件界面
    if ! dpkg -l | grep -q "language-pack-zh-hans" || ! command -v locale-gen &> /dev/null; then
        echo "正在安装语言支持与翻译包 (约需 10-20 秒)..."
        apt-get update -qq
        # 安装 locales (底层支持) 和 language-pack (软件汉化)
        apt-get install -y locales language-pack-zh-hans -qq
    fi

    # 强制写入生成配置
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen

    # 检查环境是否已生成，未生成才跑 locale-gen
    if [[ $(locale -a 2>/dev/null) != *"zh_CN.utf8"* ]]; then
        echo "正在编译语言环境..."
        /usr/sbin/locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    fi

    # 直接写入配置文件 (永久生效)
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    # 针对部分精简系统，解除对翻译文件的安装限制 (防止以后装软件还是英文)
    if [ -f /etc/dpkg/dpkg.cfg.d/excludes ]; then
        rm -f /etc/dpkg/dpkg.cfg.d/excludes
    fi

elif [[ "$OS" == "alpine" ]]; then
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
else
    echo "暂不支持此系统的自动切换。"
    exit 1
fi

# 4. 尝试在当前会话生效 (静默处理)
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 系统语言与软件汉化已完成！\033[0m"
echo -e "\033[1;33m📢 请执行退出并重连 SSH \033[0m"
echo "------------------------------------------------------------"

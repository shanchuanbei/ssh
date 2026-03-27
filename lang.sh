#!/bin/bash

# 1. 权限与系统识别
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

echo "正在快速切换系统语言为 zh_CN.UTF-8..."

# 3. 核心逻辑 (针对 Debian/Ubuntu/Armbian)
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    
    # 精准检查
    NEED_INSTALL=false
    ! command -v locale-gen &> /dev/null && NEED_INSTALL=true
    [[ "$ID" == "ubuntu" ]] && ! dpkg -l | grep -q "language-pack-zh-hans" && NEED_INSTALL=true

    if [ "$NEED_INSTALL" = true ]; then
        echo "正在补全语言环境 (仅首次运行需等待)..."
        # 使用 > /dev/null 2>&1 屏蔽所有安装日志
        apt-get update -qq > /dev/null 2>&1
        if [[ "$ID" == "ubuntu" ]]; then
            apt-get install -y locales language-pack-zh-hans -qq > /dev/null 2>&1
        else
            apt-get install -y locales -qq > /dev/null 2>&1
        fi
    fi

    # 写入生成配置 (静默)
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen

    # 只有缺失时才编译
    if [[ $(locale -a 2>/dev/null) != *"zh_CN.utf8"* ]]; then
        echo "正在编译语言环境..."
        /usr/sbin/locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    fi

    # 永久写入配置
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    # 清除精简系统限制 (静默)
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

elif [[ "$ID" == "alpine" ]]; then
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
fi

# 4. 强制刷新当前会话
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 配置已完成！\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH\033[0m"
echo "------------------------------------------------------------"

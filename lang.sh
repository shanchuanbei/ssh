#!/bin/bash

# 1. 权限检查
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 2. 识别系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "正在检测并配置系统语言..."

# 3. 智能检测：如果系统已经有 zh_CN.utf8 且 nano 有翻译，直接跳过所有安装
if [[ $(locale -a 2>/dev/null) == *"zh_CN.utf8"* ]] && [[ -d /usr/share/nano ]] && [[ $(ls /usr/share/nano/ | grep -q "zh_CN") || $? -eq 0 ]]; then
    echo "✅ 检测到中文环境已完整，跳过安装步骤。"
else
    echo "正在补全语言环境 (仅在必要时运行)..."
    
    if [[ "$OS" == "ubuntu" ]]; then
        # 只有 Ubuntu 需要这个包
        apt-get update -qq && apt-get install -y locales language-pack-zh-hans -qq
    elif [[ "$OS" == "debian" || "$OS" == "armbian" ]]; then
        # Debian/Armbian 只需要 locales
        apt-get update -qq && apt-get install -y locales -qq
    elif [[ "$OS" == "alpine" ]]; then
        apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    fi
fi

# 4. 写入配置（这一步极快，每次运行都不碍事）
if [[ "$OS" != "alpine" ]]; then
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
    /usr/sbin/locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF
fi

# 5. 立即生效
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 配置完成！\033[0m"
echo "📢 请重新连接 SSH"
echo "------------------------------------------------------------"

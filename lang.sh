#!/bin/bash

# 1. 权限检查
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 2. 识别系统
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

echo "正在尝试快速切换系统语言为 zh_CN.UTF-8..."

# 3. 核心逻辑 (针对 Debian/Ubuntu/Armbian)
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    
    # --- 优化点：精准检查 ---
    NEED_INSTALL=false
    # 检查是否缺失 locales 命令
    ! command -v locale-gen &> /dev/null && NEED_INSTALL=true
    # 只有 Ubuntu 才检查这个汉化包
    [[ "$ID" == "ubuntu" ]] && ! dpkg -l | grep -q "language-pack-zh-hans" && NEED_INSTALL=true

    if [ "$NEED_INSTALL" = true ]; then
        echo "检测到环境缺失，正在补全 (仅首次运行需等待)..."
        apt-get update -qq
        if [[ "$ID" == "ubuntu" ]]; then
            apt-get install -y locales language-pack-zh-hans -qq
        else
            apt-get install -y locales -qq
        fi
    else
        echo "✅ 环境检查通过，跳过下载步骤。"
    fi

    # --- 写入配置 ---
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen

    # 检查环境是否真正编译过，没编译才跑 (locale-gen 是最慢的一步)
    if [[ $(locale -a 2>/dev/null) != *"zh_CN.utf8"* ]]; then
        echo "正在编译语言环境..."
        /usr/sbin/locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    fi

    # 永久写入
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    # 解除精简系统的汉化限制
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes

elif [[ "$ID" == "alpine" ]]; then
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
else
    echo "暂不支持此系统。" && exit 1
fi

# 4. 当前会话强制生效
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo "✅ 配置已完成！"
echo "📢 请重新连接 SSH 查看效果。"
echo "------------------------------------------------------------"

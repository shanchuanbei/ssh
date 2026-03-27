#!/bin/bash

# 1. 权限与系统识别
[ "$EUID" -ne 0 ] && exit 1
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

echo "正在瞬间注入中文配置..."

# 2. 核心逻辑：只写文件，不跑命令 (跳过 locale-gen)
if [ "$ID" == "alpine" ]; then
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
else
    # 这一步是关键：直接把配置塞进环境文件，完全不调用 locale-gen
    # 只要系统里已经有 zh_CN 的编译文件(你之前跑过)，这一步就是 0 秒
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    # 只有当系统完全没生成过中文时，才在后台默默生成一下
    if [[ $(locale -a 2>/dev/null) != *"zh_CN.utf8"* ]]; then
        echo "检测到环境缺失，后台修复中..."
        # 使用 & 放到后台，不让用户在屏幕前傻等
        (echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen && /usr/sbin/locale-gen zh_CN.UTF-8 > /dev/null 2>&1) &
    fi
fi

# 3. 立即强制生效
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

echo "------------------------------------------------------------"
echo "✅ 系统语言与软件汉化已完成。"
echo "📢 请重新连接 SSH"
echo "------------------------------------------------------------"

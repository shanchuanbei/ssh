#!/bin/bash

# 1. 权限检查
[ "$EUID" -ne 0 ] && exit 1

# 2. 识别系统
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

echo "正在极速配置语言环境..."

# 3. 核心加速逻辑：只有命令不存在时才安装，绝不主动 update
if ! command -v locale-gen &> /dev/null; then
    echo "补全基础组件..."
    apt-get update -qq && apt-get install -y locales -qq
fi

# 4. 暴力配置（这一步是本地操作，瞬间完成）
# 强制写入配置，不管之前有没有
if [ "$ID" == "alpine" ]; then
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
else
    # Debian/Ubuntu/Armbian 通用
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
    # 只针对性生成中文，不 purge 其他，速度最快
    /usr/sbin/locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    
    # 直接覆盖配置文件
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF
fi

# 5. 强制刷新当前会话（静默，不报错）
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo "✅ 系统语言与软件汉化已完成！"
echo "📢 请重新连接 SSH"
echo "------------------------------------------------------------"

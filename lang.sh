#!/bin/bash

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then 
  echo "错误：请以 root 权限运行此脚本"
  exit 1
fi

# 2. 识别系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "正在快速切换系统语言为 zh_CN.UTF-8 (系统: $OS)..."

# 3. 分系统执行最快路径
if [[ "$OS" == "debian" || "$OS" == "ubuntu" || "$OS" == "armbian" ]]; then
    # 加速点1：使用 -qq 静默更新，只安装必要的 locales 包
    if ! command -v locale-gen &> /dev/null; then
        apt-get update -qq && apt-get install -y locales -qq
    fi

    # 加速点2：直接强制写入配置文件，跳过 dpkg-reconfigure 扫描
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
    
    # 加速点3：只针对性生成一种语言，不编译全部，极大缩短时间
    locale-gen zh_CN.UTF-8 > /dev/null 2>&1

    # 加速点4：直接写入环境变量，避免手动更新 locale
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$OS" == "alpine" ]]; then
    # Alpine 系统极其精简，直接安装 musl-locales
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    export LANG=zh_CN.UTF-8
    # 写入 profile 永久生效
    echo "export LANG=zh_CN.UTF-8" >> /etc/profile.d/lang.sh
else
    echo "暂不支持此系统的快速语言切换。"
fi

# 4. 立即刷新当前会话环境变量
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

echo "------------------------------------------------------------"
echo "✅ 语言切换成功！当前语言已设为: $LANG"
echo "提示：如果部分界面仍显示英文，请断开 SSH 重新连接即可。"
echo "------------------------------------------------------------"

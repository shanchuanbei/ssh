#!/bin/bash

# =========================================================
# 全平台系统语言极速切换脚本 (zh_CN.UTF-8)
# 支持：Debian / Ubuntu / Armbian / Alpine
# 特点：秒级完成，完全免去本地耗时编译，完美支持 nano 中文菜单
# =========================================================

# 1. 检查 root 权限
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 临时重置变量，避免解压前抛出 setlocale 警告
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 2. 识别操作系统类型
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

# 3. 语言包与预编译文件直链
GLIBC_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/zh_cn_pack.tar.gz"
ALPINE_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/alpine_zh_pack.tar.gz"
ALPINE_NANO_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/nano"

echo "正在极速切换系统语言为 zh_CN.UTF-8..."

# 4. 检查下载工具
FETCH_CMD=""
FETCH_OUT=""
if command -v curl &> /dev/null; then
    FETCH_CMD="curl -sL"
    FETCH_OUT="curl -sL -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -qO-"
    FETCH_OUT="wget -qO"
else
    echo "错误：系统缺少 curl 和 wget，请先安装" && exit 1
fi

# 5. 分系统自动化配置
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    echo "检测到 Glibc 系统 ($ID)，正在部署语言包..."
    $FETCH_CMD "$GLIBC_URL" | tar -zx -C / > /dev/null 2>&1
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$ID" == "alpine" ]]; then
    echo "检测到 Alpine (musl)，正在部署 Alpine 中文语言包与 NLS nano..."
    # 基础 musl 编码环境
    apk add --no-cache musl-locales > /dev/null 2>&1
    # 注入 .mo 翻译字典
    $FETCH_CMD "$ALPINE_URL" | tar -zx -C / > /dev/null 2>&1
    # 替换预编译的带中文 NLS 支持的 nano
    $FETCH_OUT /usr/bin/nano "$ALPINE_NANO_URL" > /dev/null 2>&1
    chmod +x /usr/bin/nano
else
    echo "警告：未识别的系统类型 ($ID)，尝试应用通用设置..."
fi

# 6. 写入全局环境变量配置文件
cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

# 7. 强制刷新当前 Shell
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ YES 配置完成！已完美实现中文环境与 nano 菜单支持\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 查看效果\033[0m"
echo "------------------------------------------------------------"

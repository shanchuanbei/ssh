#!/bin/bash

# =========================================================
# 全平台极速中文环境与预编译 nano 一键部署脚本
# 支持系统：Debian / Ubuntu / Armbian / Alpine
# 仓库：shanchuanbei/ssh
# 特点：秒级注入预编译 nano，彻底抛弃 apt 安装，完美支持中文界面
# =========================================================

# 1. 检查 root 权限
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 临时重置变量，避免安装过程抛出 setlocale 警告
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 2. 识别操作系统类型
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

# 3. GitHub 托管资源直链
GLIBC_PACK_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/zh_cn_pack.tar.gz"
ALPINE_PACK_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/alpine_zh_pack.tar.gz"
DEBIAN_NANO_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/nano_debian"
ALPINE_NANO_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/nano_alpine"

echo "正在极速配置系统语言与预编译中文 nano..."

# 4. 检查并匹配系统下载工具
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

# 5. 分系统自动化部署
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    echo "检测到 Glibc 系统 ($ID)，部署语言包与预编译 nano..."

    # 5.1 解压中文翻译字典 (.mo 文件)
    $FETCH_CMD "$GLIBC_PACK_URL" | tar -zx -C / > /dev/null 2>&1
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

    # 5.2 瞬间注入预编译的 Debian 版中文 nano 二进制
    $FETCH_OUT /usr/bin/nano "$DEBIAN_NANO_URL" > /dev/null 2>&1
    chmod +x /usr/bin/nano

    # 5.3 检查并自动补全 locales 基础组件（仅在必要时）
    if ! command -v locale-gen &> /dev/null; then
        apt-get update -qq && apt-get install -y -qq locales > /dev/null 2>&1
    fi

    # 5.4 注册 zh_CN.UTF-8 到 Glibc 本地数据库
    if [ -f /etc/locale.gen ]; then
        sed -i 's/# zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen 2>/dev/null
        locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    else
        localedef -i zh_CN -f UTF-8 zh_CN.UTF-8 > /dev/null 2>&1
    fi

    # 5.5 写入 Debian/Ubuntu 默认 Locale 配置
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$ID" == "alpine" ]]; then
    echo "检测到 Alpine (musl)，部署语言包与预编译 nano..."

    # 5.1 安装 musl 基础编码库
    apk add --no-cache musl-locales > /dev/null 2>&1

    # 5.2 注入中文 .mo 翻译字典
    $FETCH_CMD "$ALPINE_PACK_URL" | tar -zx -C / > /dev/null 2>&1

    # 5.3 替换预编译的 Alpine 版中文 nano 二进制
    $FETCH_OUT /usr/bin/nano "$ALPINE_NANO_URL" > /dev/null 2>&1
    chmod +x /usr/bin/nano
else
    echo "警告：未识别的系统类型 ($ID)，尝试应用通用设置..."
fi

# 6. 写入全局环境变量配置文件（自动清洗 SSH 客户端注入的 C / POSIX 变量）
cat << 'EOF' > /etc/profile.d/zh_CN.sh
# 清除 SSH 客户端可能注入的英文环境标识
[ "$LANG" = "C" ] || [ "$LANG" = "POSIX" ] && unset LANG
[ "$LANGUAGE" = "C" ] || [ "$LANGUAGE" = "POSIX" ] && unset LANGUAGE

export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

# 7. 立即刷新当前 Shell 环境变量
[ "$LANG" = "C" ] || [ "$LANG" = "POSIX" ] && unset LANG
[ "$LANGUAGE" = "C" ] || [ "$LANGUAGE" = "POSIX" ] && unset LANGUAGE

export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 部署完成！预编译 nano 与中文环境已无缝就绪\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 查看效果\033[0m"
echo "------------------------------------------------------------"

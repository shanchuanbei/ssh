#!/bin/bash

# =========================================================
# 全平台极速中文环境与预编译 nano 一键部署脚本 (终极防 SSH 还原版)
# 支持系统：Debian / Ubuntu / Armbian / Alpine
# 适配仓库：shanchuanbei/ssh
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
    echo "检测到 Glibc 系统 ($ID)，正在部署语言包与预编译 nano..."

    # 5.1 解压中文翻译字典 (.mo 文件)
    $FETCH_CMD "$GLIBC_PACK_URL" | tar -zx -C / > /dev/null 2>&1
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

    # 5.2 注入预编译的 Debian 版中文 nano 二进制
    $FETCH_OUT /usr/bin/nano "$DEBIAN_NANO_URL" > /dev/null 2>&1
    chmod +x /usr/bin/nano

    # 5.3 检查并自动补全 locales 基础组件
    if ! command -v locale-gen &> /dev/null; then
        echo "正在补全 locales 组件..."
        apt-get update -qq && apt-get install -y -qq locales > /dev/null 2>&1
    fi

    # 5.4 注册 zh_CN.UTF-8 到 Glibc 本地数据库
    if [ -f /etc/locale.gen ]; then
        sed -i 's/# zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen 2>/dev/null
        locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    else
        localedef -i zh_CN -f UTF-8 zh_CN.UTF-8 > /dev/null 2>&1
    fi

    # 5.5 写入 PAM 与系统级默认 Locale 配置
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    cat << 'EOF' > /etc/environment
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    # 5.6 彻底清除主配置与 sshd_config.d 子配置文件中的 AcceptEnv
    sed -i 's/^[[:space:]]*AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config 2>/dev/null
    if [ -d /etc/ssh/sshd_config.d ]; then
        sed -i 's/^[[:space:]]*AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config.d/*.conf 2>/dev/null
    fi

    # 5.7 写入 SSHD 级别的 SetEnv 变量强制锁定
    mkdir -p /etc/ssh/sshd_config.d
    cat << 'EOF' > /etc/ssh/sshd_config.d/99-zh-env.conf
SetEnv LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null

elif [[ "$ID" == "alpine" ]]; then
    echo "检测到 Alpine (musl)，正在部署语言包与预编译 nano..."

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

# 6. 写入全局 profile.d
cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

# 7. 绑定到所有可能的 Login Shell 入口 (解决 SSH 重连跳过 .bashrc 的问题)
for f in ~/.profile ~/.bash_profile /etc/profile /etc/bash.bashrc ~/.bashrc; do
    if [ -f "$f" ]; then
        sed -i '/zh_CN.sh/d' "$f" 2>/dev/null
        echo '[ -f /etc/profile.d/zh_CN.sh ] && . /etc/profile.d/zh_CN.sh' >> "$f"
    fi
done

# 8. 刷新当前 Shell 环境变量
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ 部署完成！中文环境与 nano 界面已永久锁定\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 查看效果\033[0m"
echo "------------------------------------------------------------"

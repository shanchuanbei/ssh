#!/bin/bash

# =========================================================
# 系统语言一键极速切换脚本 (zh_CN.UTF-8)
# 支持：Debian / Ubuntu / Armbian / Alpine
# 特点：解压预制语言包，免 apt/localedef 编译，秒级生效
# =========================================================

# 1. 检查 root 权限
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 2. 识别操作系统类型
[ -f /etc/os-release ] && . /etc/os-release || ID="unknown"

# 3. 语言包预设直链
PACKAGE_URL="https://github.com/shanchuanbei/ssh/raw/refs/heads/main/zh_cn_pack.tar.gz"

echo "正在极速切换系统语言为 zh_CN.UTF-8..."

# 4. 核心处理逻辑 (Debian / Ubuntu / Armbian)
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "armbian" ]]; then
    
    # 检查网络下载工具
    FETCH_CMD=""
    if command -v curl &> /dev/null; then
        FETCH_CMD="curl -sL"
    elif command -v wget &> /dev/null; then
        FETCH_CMD="wget -qO-"
    else
        echo "错误：系统缺少 curl 和 wget，请先安装网络工具" && exit 1
    fi

    echo "正在拉取并部署语言包 (几秒内完成)..."
    
    # 管道流式解压至根目录，并检测是否执行成功
    if ! $FETCH_CMD "$PACKAGE_URL" | tar -zx -C / > /dev/null 2>&1; then
        echo "错误：语言包下载或解压失败，请检查网络是否能连接 GitHub" && exit 1
    fi

    # 清除极简系统的 dpkg 排除限制 (以防影响后续软件)
    [ -f /etc/dpkg/dpkg.cfg.d/excludes ] && rm -f /etc/dpkg/dpkg.cfg.d/excludes > /dev/null 2>&1

    # 写入系统默认 Locale 配置文件
    cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

    # 写入全局环境变量，确保 SSH 登录后自动加载
    cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

elif [[ "$ID" == "alpine" ]]; then
    # Alpine Linux 专门处理
    apk add --no-cache musl-locales musl-locales-lang > /dev/null 2>&1
    echo "export LANG=zh_CN.UTF-8" > /etc/profile.d/lang.sh
else
    echo "警告：未识别的系统类型 ($ID)，尝试强制应用环境变量..."
fi

# 5. 强制刷新当前 Shell 临时生效
export LANG=zh_CN.UTF-8 > /dev/null 2>&1
export LANGUAGE=zh_CN:zh > /dev/null 2>&1
export LC_ALL=zh_CN.UTF-8 > /dev/null 2>&1

echo "------------------------------------------------------------"
echo -e "\033[1;32m✅ yes配置完成！已成功注入中文环境与 nano/vim 字典\033[0m"
echo -e "\033[1;33m📢 请重新连接 SSH 或运行 'source /etc/profile' 即可看效果\033[0m"
echo "------------------------------------------------------------"

#!/usr/bin/env bash
# =================================================================
# 全系统通用中文环境一键配置脚本 (秒级检测 / 自动补全 / SSH抗覆盖)
# 支持: Debian/Ubuntu, CentOS/RHEL/Rocky, Alpine, Arch
# =================================================================

set -e

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误: 请使用 root 权限运行此脚本！"
    exit 1
fi

echo -e "\n[1/4] 🔍 识别系统架构与环境..."

# 1. 识别操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
else
    OS_ID="unknown"
fi

# 2. 检测系统 Locale 是否存在
HAS_ZH_LOCALE=false
if command -v locale >/dev/null 2>&1; then
    if locale -a 2>/dev/null | grep -iq "zh_CN"; then
        HAS_ZH_LOCALE=true
    fi
fi

# 3. 按需补充系统 Locale 依赖（已存在则 0 秒跳过）
echo "[2/4] 📦 校验系统 Locale 语言包..."
if [ "$HAS_ZH_LOCALE" = false ]; then
    echo "   └─ 未检测到中文 Locale，正在按需安装..."
    case "$OS_ID" in
        alpine)
            apk add --no-cache musl-locales musl-locales-lang >/dev/null 2>&1 || true
            ;;
        ubuntu|debian|raspbian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq locales >/dev/null 2>&1
            sed -i '/^# *zh_CN.UTF-8/s/^# *//' /etc/locale.gen 2>/dev/null || true
            locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y -q glibc-langpack-zh >/dev/null 2>&1 || true
            elif command -v yum >/dev/null 2>&1; then
                yum install -y -q kde-l10n-Chinese glibc-common >/dev/null 2>&1 || true
                localedef -c -i zh_CN -f UTF-8 zh_CN.UTF-8 >/dev/null 2>&1 || true
            fi
            ;;
        arch|manjaro)
            sed -i '/^# *zh_CN.UTF-8/s/^# *//' /etc/locale.gen 2>/dev/null || true
            locale-gen >/dev/null 2>&1 || true
            ;;
    esac
else
    echo "   └─ 系统中文 Locale 已就绪（⚡ 0 秒跳过）"
fi

# 4. 软件专属语言包检测（专门解决 Alpine 等系统 nano/vim 依然显示英文的问题）
echo "[3/4] 🧩 校验常用软件语言包..."
if [ "$OS_ID" = "alpine" ]; then
    # Alpine 将 nano 核心与 nano-lang 拆分，需单独检测
    if command -v nano >/dev/null 2>&1; then
        if ! apk info -e nano-lang >/dev/null 2>&1; then
            echo "   └─ 检测到 nano 但缺少 nano-lang，正在补全..."
            apk add --no-cache nano-lang >/dev/null 2>&1 || true
        else
            echo "   └─ nano-lang 语言包已存在（⚡ 0 秒跳过）"
        fi
    fi
else
    echo "   └─ 当前系统无需额外软件独立语言包（⚡ 0 秒跳过）"
fi

# 5. 写入配置并强行覆盖 SSH 客户端传入的环境变量
echo "[4/4] ⚙️ 强行锁死全局与用户环境变量..."

# Systemd 写入
if command -v localectl >/dev/null 2>&1 && systemctl status >/dev/null 2>&1; then
    localectl set-locale LANG=zh_CN.UTF-8 2>/dev/null || true
fi

# 系统全局配置
echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
echo "LC_ALL=zh_CN.UTF-8" >> /etc/locale.conf

if [ -d /etc/default ]; then
    echo "LANG=zh_CN.UTF-8" > /etc/default/locale
    echo "LC_ALL=zh_CN.UTF-8" >> /etc/default/locale
fi

# 全局 profile 脚本
mkdir -p /etc/profile.d
cat << 'EOF' > /etc/profile.d/locale.sh
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
EOF
chmod +x /etc/profile.d/locale.sh

# 强行清理旧配置并追加到当前用户 Profile，彻底击碎 SSH 客户端 SendEnv 传递的英文变量
PROFILES=( "/root/.profile" "/root/.bashrc" "$HOME/.profile" "$HOME/.bashrc" "/etc/bash.bashrc" )
for p in "${PROFILES[@]}"; do
    if [ -f "$p" ]; then
        sed -i '/export LANG=/d' "$p" 2>/dev/null || true
        sed -i '/export LC_ALL=/d' "$p" 2>/dev/null || true
        echo "export LANG=zh_CN.UTF-8" >> "$p"
        echo "export LC_ALL=zh_CN.UTF-8" >> "$p"
    fi
done

echo -e "\n✅ 终极中文环境配置成功！"
echo "👉 请运行以下命令让当前终端立刻生效："
echo "source /etc/profile.d/locale.sh && source ~/.profile"

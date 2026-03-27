#!/bin/bash

# 1. 权限检查
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 2. 核心加速：跳过不必要的更新
# 检查 locales 是否已安装，如果已安装，绝对不跑 apt-get update
if ! command -v locale-gen &> /dev/null; then
    echo "正在安装基础语言包 (仅首次运行需等待)..."
    # 只更新必要的索引，不更新全部
    apt-get update -o Dir::Etc::sourcelist="sources.list" -o APT::Get::List-Cleanup="0" -qq
    apt-get install -y locales -qq
fi

# 3. 强制写入配置 (耗时 0.01s)
echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen

# 4. 关键：预生成 Locale 文件 (跳过完整的 locale-gen 扫描)
# 如果系统已经有编译好的 zh_CN，直接跳过生成
if [[ $(locale -a) != *"zh_CN.utf8"* ]]; then
    echo "正在生成语言环境..."
    # 强制只生成中文，不加载其他逻辑
    /usr/sbin/locale-gen --purge zh_CN.UTF-8 > /dev/null 2>&1
fi

# 5. 直接修改环境变量文件 (耗时 0.01s)
# 使用最底层的配置方式，不调用 update-locale 命令
cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

# 6. 立即刷新当前会话
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

echo "------------------------------------------------------------"
echo "✅ 语言切换成功！当前语言已设为: $LANG"
echo "提示：如果部分界面仍显示英文，请断开 SSH 重新连接即可。"
echo "------------------------------------------------------------"

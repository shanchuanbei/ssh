#!/bin/bash
[ "$EUID" -ne 0 ] && echo "错误：请以 root 权限运行" && exit 1

# 1. 创建中文语言目录
mkdir -p /usr/share/locale/zh_CN/LC_MESSAGES/

# 2. 写入全局环境变量配置文件
cat << 'EOF' > /etc/profile.d/zh_CN.sh
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
EOF

chmod +x /etc/profile.d/zh_CN.sh

# 3. 实时生效当前会话
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

echo "✅ 环境变量与语言路径已注入完成 (耗时 < 0.1s)"

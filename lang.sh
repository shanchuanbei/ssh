#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请使用 sudo 或 root 权限运行此脚本！"
  exit 1
fi

echo "==> 1. 正在更新软件源并安装 locales 语言包工具..."
apt update && apt install -y locales

echo "==> 2. 正在启用 zh_CN.UTF-8 编码..."
sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen

echo "==> 3. 正在生成系统语言包..."
locale-gen

echo "==> 4. 正在更新系统默认区域设置..."
update-locale LANG=zh_CN.UTF-8

echo "==> 5. 正在临时刷新当前终端的环境变量..."
export LANG=zh_CN.UTF-8

echo "=========================================="
echo "✨ 中文环境配置完成！"
echo "请执行 'locale' 命令查看生效状态。"
echo "=========================================="

#!/bin/bash
if [[ $(locale -a) != *"zh_CN.utf8"* ]]; then
    echo "检测到非中文环境，正在快速切换..."
    apt-get update -qq && apt-get install -y locales -qq
    echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen zh_CN.UTF-8 > /dev/null 2>&1
    echo -e "LANG=zh_CN.UTF-8\nLANGUAGE=zh_CN:zh\nLC_ALL=zh_CN.UTF-8" > /etc/default/locale
    export LANG=zh_CN.UTF-8
fi

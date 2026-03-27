#!/bin/bash

# 1. 快速检查并静默安装 locales (如果缺失)
if ! command -v locale-gen &> /dev/null; then
    echo "正在快速修复环境..."
    apt-get update -qq && apt-get install -y locales -qq
fi

# 2. 暴力覆盖配置 (跳过扫描，直接告诉系统我们要什么)
echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen

# 3. 核心加速：只生成我们需要的语言 (避免生成所有语言)
# 使用 -j 参数（如果支持）或直接定向生成
locale-gen zh_CN.UTF-8 > /dev/null 2>&1

# 4. 直接写入环境变量文件 (最快生效方式)
cat << 'EOF' > /etc/default/locale
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_ALL=zh_CN.UTF-8
EOF

# 5. 立即对当前会话生效 (无需重新登录即可看到部分效果)
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

echo "✅ 系统语言已切换为中文 (zh_CN.UTF-8)"

#!/bin/bash

if [ "$(id -u)" -ne "0" ]; then
    echo "请以 root 用户运行此脚本。"
    exit 1
fi

dae_path="./dae-0.8.0rc1-1-x86_64.pkg.tar.zst"
dae_config_path="./config.dae"

echo "正在安装透明代理dae..."

for file in "${dae_path}" "${dae_config_path}" "./sub_links"; do
    if [ ! -e "$file" ]; then
        echo "$file 不存在。"
        exit 1
    fi
done

pacman -U --noconfirm "${dae_path}"

cat "${dae_config_path}" >/etc/dae/config.dae

sub_links=$(sed ':a;N;$!ba; s/\n/\\n/g' ./sub_links)

sed -i '/subscription {/!b; :a; /}/!{n; b a}; /}/i'"${sub_links}"'' /etc/dae/config.dae

echo "dae安装完成"

if systemctl enable dae_service && systemctl start dae_service; then
    echo "dae.service 已成功启用并启动。"
else
    echo "无法启用或启动 dae.service"
    exit 1
fi

max_retries=5
attempt=0
dae_success=0

while [ $attempt -lt $max_retries ]; do
    echo "检测梯子是否正常..."
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 www.google.com)
    if [ "$response" -eq 200 ]; then
        echo "梯子正常"
        dae_success=1
        break
    else
        attempt=$((attempt + 1))
        sleep 5
    fi
done

if [ $dae_success == 0 ]; then
    echo "梯子连不上"
    exit 1
fi

echo "安装node & npm..."

pacman -S --noconfirm nodejs npm

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "node & npm 已安装"
else
    echo "node & npm 安装失败"
    exit 1
fi

echo "安装zx..."

npm install -g zx

if command -v zx >/dev/null 2>&1; then
    echo "zx 已安装"
else
    echo "zx 安装失败"
    exit 1
fi

./index.mjs

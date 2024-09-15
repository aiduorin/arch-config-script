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

yes | pacman -U --noconfirm "${dae_path}"

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

echo "安装node..."

if ! command -v nvm &>/dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    if [ -n "$ZSH_VERSION" ]; then
        source ~/.zshrc
    elif [ -n "$BASH_VERSION" ]; then
        source ~/.bashrc
    else
        echo "无法检测到合适的 shell，手动 source 配置文件。"
        exit 1
    fi
fi

nvm install --lts && nvm alias default lts/* && nvm use --lts

if ! command -v node &>/dev/null; then
    echo "Node安装失败。"
    exit 1
fi

echo "安装node成功"

if npm install -g pnpm; then
    echo "pnpm 安装成功，版本: $(pnpm -v)"
else
    echo "pnpm 安装失败。"
    exit 1
fi

if pnpm install; then
    echo "项目依赖安装成功。"
else
    echo "项目依赖安装失败。"
    exit 1
fi

#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
export SCRIPT_DIR

if [ "$(id -u)" -ne "0" ]; then
    echo "please run script in root"
    exit 1
fi

dae_path="${SCRIPT_DIR}/lib/dae-0.8.0rc1-1-x86_64.pkg.tar.zst"
dae_config_path="${SCRIPT_DIR}/lib/config.dae"
sub_links_path="${SCRIPT_DIR}/lib/sub_links"

echo "install dae..."

for file in "${dae_path}" "${dae_config_path}" "${sub_links_path}"; do
    if [ ! -e "$file" ]; then
        echo "$file not exists。"
        exit 1
    fi
done

pacman -U --noconfirm "${dae_path}"

cat "${dae_config_path}" >/etc/dae/config.dae

sub_links=$(sed ':a;N;$!ba; s/\n/\\n/g' "${sub_links_path}")

sed -i '/subscription {/!b; :a; /}/!{n; b a}; /}/i'"${sub_links}"'' /etc/dae/config.dae

echo "dae installed"

if systemctl enable dae.service && systemctl start dae.service; then
    echo "dae.service started"
else
    echo "can't run dae.service"
    exit 1
fi

max_retries=5
attempt=0
dae_success=0

while [ $attempt -lt $max_retries ]; do
    echo "check dae..."
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 www.google.com)
    if [ "$response" -eq 200 ]; then
        echo "dae is normal"
        dae_success=1
        break
    else
        attempt=$((attempt + 1))
        sleep 5
    fi
done

if [ $dae_success == 0 ]; then
    echo "dae is error"
    exit 1
fi

echo "install node & npm..."

pacman -S --noconfirm nodejs npm

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "node & npm installed"
else
    echo "node & npm install failed"
    exit 1
fi

echo "install zx..."

npm install -g zx

if command -v zx >/dev/null 2>&1; then
    echo "zx installed"
else
    echo "zx install failed"
    exit 1
fi

"${SCRIPT_DIR}"/index.mjs

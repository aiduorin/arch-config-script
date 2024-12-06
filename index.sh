#!/bin/bash

readonly SCRIPT_DIR=$(dirname "$(realpath "$0")")
readonly USER="aiduorin"
readonly USER_HOME="/home/aiduorin"
readonly GIT_USER="aiduorin"
readonly GIT_EMAIL="aiduorin@outlook.com"

function service_check {
  local service=$1
  local times=${2:-5}
  for ((i = 1; i <= times; i++)); do
    if $service; then
      return 0
    fi
    sleep 2
  done
  echo "check ${service} failed"
  return 1
}

function install_pkg {
  pacman -S --noconfirm "$1" || return 1
}

function in_temp_dir {
  if [ -z "$1" ]; then return 1; fi
  local pre tmp func params
  pre="$(pwd)"
  tmp="$(mktemp -d)"
  func="$1"
  shift
  params=("$@")
  chmod 777 "${tmp}"
  cd "${tmp}" || return 1
  $func "${params[@]}"
  local exit_status="$?"
  cd "${pre}" || return 1
  rm -rf "${tmp}"
  return "${exit_status}"
}

function install_aur {
  if [ -z "$1" ]; then return 1; fi
  git clone "$1" || return 1
  local repo
  repo="$(basename "$1" .git)"
  chmod 777 "./${repo}"
  cd "${repo}" || return 1
  sudo -u "${USER}" bash -c "makepkg -si" || return 1
}

function run_config {
  if [ -z "$1" ]; then return 1; fi
  local config_func="$1"
  printf "\n------------%s------------\n" "${config_func}"
  if $config_func; then
    printf "\n------------%s OK------------\n" "${config_func}"
  else
    printf "\n------------%s FAILED------------\n" "${config_func}"
    return 1
  fi
}

function check_dae {
  local response
  response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 www.google.com)
  if [ "$response" -eq 200 ]; then
    return 0
  else
    return 1
  fi
}

function config_dae {
  local dae_path="${SCRIPT_DIR}/lib/dae-0.8.0rc1-1-x86_64.pkg.tar.zst"
  local dae_config_path="${SCRIPT_DIR}/lib/config.dae"
  local sub_links_path="${SCRIPT_DIR}/lib/sub_links"

  for file in "${dae_path}" "${dae_config_path}" "${sub_links_path}"; do
    if [ ! -e "$file" ]; then
      echo "$file not exists。"
      return 1
    fi
  done

  pacman -U --noconfirm "${dae_path}" || return 1

  cat "${dae_config_path}" >/etc/dae/config.dae || return 1
  sub_links=$(sed ':a;N;$!ba; s/\n/\\n/g' "${sub_links_path}")
  if [ $? -ne 0 ]; then return 1; fi
  sed -i '/subscription {/!b; :a; /}/!{n; b a}; /}/i'"${sub_links}"'' /etc/dae/config.dae || return 1

  if systemctl enable dae.service && systemctl start dae.service; then
    echo "dae.service started"
  else
    echo "can't run dae.service"
    return 1
  fi

  if ! service_check "check_dae"; then return 1; fi
}

function config_mirror {
  install_pkg "reflector" || return 1
  reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || return 1
  pacman -Syu --noconfirm || return 1
}

function config_ssh {
  install_pkg "openssh less" || return 1
  sudo -u "${USER}" bash -c "ssh-keygen -t rsa -C ${GIT_EMAIL}" || return 1
  cat "${SCRIPT_DIR}/lib/ssh-agent.conf" >>"${USER_HOME}/.bashrc" || return 1
}

function config_git {
  install_pkg "git lazygit" || return 1
  printf "\nalias lg='lazygit'\n" >>"${USER_HOME}/.bashrc" || return 1
  sudo -u "${USER}" bash -c "git config --global user.name ${GIT_USER}" || return 1
  sudo -u "${USER}" bash -c "git config --global user.email ${GIT_EMAIL}" || return 1
  cat "${SCRIPT_DIR}/lib/ssh.conf" >>"${USER_HOME}/.ssh/config" || return 1
}

function update_dae {
  in_temp_dir install_aur "https://aur.archlinux.org/dae.git" || return 1
  systemctl restart dae
  if ! service_check "check_dae"; then return 1; fi
}

function config_yay {
  install_pkg "base-devel" || return 1
  in_temp_dir install_aur "https://aur.archlinux.org/yay.git" || return 1
}

function config_font {
  install_pkg "noto-fonts noto-fonts-cjk unzip" || return 1
  # shellcheck disable=SC2317
  function install_geist_mono {
    curl -L -o GeistMono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/GeistMono.zip || return 1
    test -e ./GeistMono.zip || return 1
    mkdir GeistMono
    unzip ./GeistMono.zip -d ./GeistMono
    mv ./GeistMono /usr/share/fonts/
  }
  in_temp_dir install_geist_mono || return 1
  mkdir -p "${USER_HOME}/.config/fontconfig/" && cat "${SCRIPT_DIR}/lib/fonts.conf" >"${USER_HOME}/.config/fontconfig/fonts.conf" || return 1
}

function config_fnm {
  sudo -u "${USER}" bash -c "curl -fsSL https://fnm.vercel.app/install | bash" || return 1
}

function config_starship {
  install_pkg "starship" || return 1
  printf '\neval "$(starship init bash)"\n' | tee -a ${USER_HOME}/.bashrc >/dev/null
  cp -f "${SCRIPT_DIR}/lib/starship.toml" "${USER_HOME}/.config/starship.toml" || return 1
}

function config_bluetooth {
  install_pkg "bluez bluez-utils" || return 1
  modprobe btusb || return 1
  systemctl enable bluetooth.service && systemctl start bluetooth.service
}

function config_input_method {
  in_temp_dir install_aur "https://aur.archlinux.org/fcitx5-pinyin-moegirl.git" || return 1
  install_pkg "fcitx5-im fcitx5-chinese-addons fcitx5-qt fcitx5-gtk fcitx5-pinyin-zhwiki" || return 1
}

function config_grub_theme {
  # shellcheck disable=SC2317
  function install_grub_theme {
    tar -xvf "${SCRIPT_DIR}/lib/grub-theme.tar.xz" || return 1
    cd "./grub-theme" || return 1
    ./install.sh || return 1
  }
  in_temp_dir install_grub_theme || return 1
}

function config_vim {
  {
    printf '\ninoremap jk <Esc>'
    printf '\ninoremap kj <Esc>'
    printf '\nset nu rnu'
    printf '\nlet &t_SI = "\\e[5 q"'
    printf '\nlet &t_EI = "\\e[1 q"'
  } >>/etc/vimrc || return 1
  cat "${SCRIPT_DIR}/lib/.inputrc" >>"${USER_HOME}/.inputrc" || return 1
}

function config_docker {
  install_pkg "docker docker-compose" || return 1
  systemctl enable docker.socket && systemctl start docker.socket
  usermod -aG docker "${USER}"
}

function config_tlp {
  if [ -d "/sys/class/power_supply/BAT0" ] || [ -d "/sys/class/power_supply/BAT1" ]; then
    install_pkg "tlp tlp-rdw" || return 1
    systemctl enable tlp.service
    systemctl enable NetworkManager-dispatcher.service
    systemctl enable mask systemd-rfkill.service
    systemctl enable mask systemd-rfkill.socket
    tlp start
  fi
}

function config_common {
  install_pkg "telegram-desktop okular flameshot gwenview kamoso thunderbird libreoffice-fresh libreoffice-fresh-zh-cn dragon dbeaver"
  in_temp_dir install_aur "https://aur.archlinux.org/google-chrome.git"
  in_temp_dir install_aur "https://aur.archlinux.org/visual-studio-code-bin.git"
}

function config_eza {
  install_pkg "eza"
  echo -e "\nalias el=\"eza -al --icons --git --git-repos --time-style '+%y/%m/%d'\"\n" >>"${USER_HOME}/.bashrc" || return 1
}

run_config config_dae || exit 1
run_config config_mirror || exit 1
run_config config_ssh
run_config config_git
run_config update_dae
run_config config_yay
run_config config_font
run_config config_fnm
run_config config_starship
run_config config_bluetooth
run_config config_input_method
run_config config_grub_theme
run_config config_vim
run_config config_docker
run_config config_tlp
run_config config_common
run_config config_eza

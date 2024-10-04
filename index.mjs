#!/usr/bin/env zx

const getOutput = async (res) => {
  const output = (await res).stdout;
  return output.endsWith("\n") ? output.slice(0, output.length - 1) : output;
};

const USER = "bsx";
const USER_HOME = "/home/bsx";
const SCRIPT_DIR = await getOutput($`echo $SCRIPT_DIR`);

if (typeof SCRIPT_DIR !== "string" || SCRIPT_DIR.length === 0) {
  console.error('please run "run.sh"');
  process.exit(1);
}

const isLaptop = getOutput($`ls /sys/class/power_supply/`).includes("BAT0");

const installPKG = async (name, commandCheck = false) => {
  await $`pacman -S --noconfirm ${name}`;
  if (commandCheck) {
    try {
      if (Array.isArray(name)) {
        for (const n of name) await $`command -v ${n} >/dev/null 2>&1`;
      } else await $`command -v ${name} >/dev/null 2>&1`;
    } catch (e) {
      console.error(`${name} install failed`);
      process.exit(e.exitCode);
    }
  }
  if (Array.isArray(name)) for (const n of name) console.log(`${n} installed`);
  else console.log(`${name} installed`);
};

const inTmpDir = async (fn) => {
  const pre = await $`pwd`;
  const tmp = await $`mktemp -d`;
  await $`chmod 777 ${await getOutput(tmp)}`;
  await cd(tmp);
  await fn();
  await cd(pre);
  await $`rm -rf ${await getOutput(tmp)}`;
};

const installAUR = async (url, afterInstall) => {
  await inTmpDir(async () => {
    await $`git clone ${url}`;
    const dir = url.split("/").at(-1).replace(".git", "");
    await $`chmod 777 ${dir}`;
    cd(dir);
    await $`sudo -u ${USER} bash -c 'makepkg --syncdeps'`;
    const p = await getOutput(
      $`ls *.pkg.tar.zst 2>/dev/null | grep -v 'debug'`,
    );
    await $`pacman -U --noconfirm ${p}`;
    afterInstall && (await afterInstall());
  });
};

//mirror
await installPKG("reflector", true);
await $`reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist`;
await $`pacman -Syu --noconfirm`;
console.log("mirror OK");

//git
await installPKG(["git", "less", "lazygit"], true);
const gitConfigResp = await $`cat ${SCRIPT_DIR}/lib/git.conf`;
const [gitUser, gitEmail] = gitConfigResp.stdout.split("\n");
await $`sudo -u ${USER} bash -c 'git config --global user.name "${gitUser}"'`;
await $`sudo -u ${USER} bash -c 'git config --global user.email "${gitEmail}"'`;

await $`sudo -u ${USER} bash -c 'ssh-keygen -t rsa -C "${gitEmail}"'`;
await $`sudo -u ${USER} bash -c 'cat ${SCRIPT_DIR}/lib/ssh.conf > ${USER_HOME}/.ssh/config'`;
console.log("git OK");

//update dae
await installAUR(
  "https://aur.archlinux.org/dae.git",
  async () => await $`systemctl restart dae.service`,
);
console.log("dae OK");

//font
await installPKG(["noto-fonts", "noto-fonts-cjk"]);
await installPKG("unzip", true);

await inTmpDir(async () => {
  await $`curl -L -o GeistMono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/GeistMono.zip`;
  await $`test -e ./GeistMono.zip`;
  await $`mkdir GeistMono`;
  await $`unzip ./GeistMono.zip -d ./GeistMono`;
  await $`mv ./GeistMono /usr/share/fonts/`;
});

await $`sudo -u ${USER} bash -c 'mkdir -p ${USER_HOME}/.config/fontconfig/ && cat ${SCRIPT_DIR}/lib/fonts.conf > ${USER_HOME}/.config/fontconfig/fonts.conf'`;
console.log("font OK");

//nvm
await $`sudo -u ${USER} bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'`;
console.log("nvm OK");

//starship
await installPKG("starship");
await $`printf '\neval "$(starship init bash)"\n' | sudo -u ${USER} bash -c 'tee -a ${USER_HOME}/.bashrc > /dev/null'`;
await $`sudo -u ${USER} bash -c 'cp -f ${SCRIPT_DIR}/lib/starship.toml ${USER_HOME}/.config/starship.toml'`;
console.log("starship OK");

//bluetooth
await installPKG(["bluez", "bluez-utils"]);
await $`modprobe btusb`;
await $`systemctl enable bluetooth.service && systemctl start bluetooth.service`;
console.log("bluetooth OK");

//input method
await installPKG([
  "fcitx5-im",
  "fcitx5-chinese-addons",
  "fcitx5-qt",
  "fcitx5-gtk",
  "fcitx5-pinyin-zhwiki",
]);
await installAUR("https://aur.archlinux.org/fcitx5-pinyin-moegirl.git");
console.log("input method OK");

//grub theme
await inTmpDir(async () => {
  await $`tar -xvf ${SCRIPT_DIR}/lib/Vimix-2k.tar.xz`;
  cd("Vimix-2k");
  await $`./install.sh`;
});
console.log("grub OK");

//vim
await $`echo -e '\ninoremap jk <Esc>' >> /etc/vimrc`;
await $`echo -e '\ninoremap kj <Esc>' >> /etc/vimrc`;
console.log("vim OK");

//docker
await installPKG(["docker", "docker-compose"]);
await $`systemctl enable docker`;
await $`systemctl start docker`;
await $`usermod -aG docker ${USER}`;
console.log("docker OK");

if (isLaptop) {
  //battery
  await installPKG(["tlp", "tlp-rdw"]);
  await $`systemctl enable tlp.service`;
  await $`systemctl enable NetworkManager-dispatcher.service`;
  await $`systemctl enable mask systemd-rfkill.service`;
  await $`systemctl enable mask systemd-rfkill.socket`;
  await $`tlp start`;
  console.log("battery OK");
}

//common
await installAUR("https://aur.archlinux.org/google-chrome.git");
await installAUR("https://aur.archlinux.org/visual-studio-code-bin.git");
await installPKG([
  "telegram-desktop",
  "okular",
  "flameshot",
  "gwenview",
  "kamoso",
  "thunderbird",
  "libreoffice-fresh",
  "libreoffice-fresh-zh-cn",
  "dragon",
  "dbeaver",
]);

#!/usr/bin/env zx

const installPKG = async (name, commandCheck = false) => {
  await $`pacman -S --noconfirm ${name}`;
  if (commandCheck) {
    try {
      if (Array.isArray(name)) {
        for (const n of name) await $`command -v ${n} >/dev/null 2>&1`;
      } else await $`command -v ${name} >/dev/null 2>&1`;
    } catch (e) {
      console.log(`${name} install failed`);
      process.exit(e.exitCode);
    }
  }
  if (Array.isArray(name)) for (const n of name) console.log(`${n} installed`);
  else console.log(`${name} installed`);
};

const inTmpDir = async (fn) => {
  const pre = await $`pwd`;
  const tmp = await $`mktemp -d`;
  await $`chmod 777 ${tmp.stdout.slice(0, tmp.stdout.length - 1)}` 
  await cd(tmp);
  await fn();
  await cd(pre);
  const tmpPath = tmp.stdout;
  await $`rm -rf ${tmpPath.endsWith("\n") ? tmpPath.slice(0, tmpPath.length - 1) : tmpPath}`;
};

const installAUR = async (url, afterInstall) => {
  await inTmpDir(async () => {
    await $`git clone ${url}`;
    const dir = url.split("/").at(-1).replace(".git", "");
    await $`chmod 777 ${dir}` 
    cd(dir);
    await $`sudo -u bsx bash -c 'yes | makepkg --syncdeps'`;
    const p = (await $`ls *.pkg.tar.zst 2>/dev/null | grep -v 'debug'`).stdout;
    await $`pacman -U --noconfirm ${p.slice(0, p.length - 1)}`;
    afterInstall && (await afterInstall());
  });
};

//mirror
await installPKG("reflector", true);
await $`reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist`;
console.log("镜像配置完成");
await $`pacman -Syu --noconfirm`;

//git
await installPKG("git", true);
const gitConfigResp = await $`cat ./git.conf`;
const [gitUser, gitEmail] = gitConfigResp.stdout.split("\n");
await $`git config --global user.name "${gitUser}"`;
await $`git config --global user.email "${gitEmail}"`;

await $`ssh-keygen -t rsa -C "${gitEmail}"`;

//update dae
await installAUR(
  "https://aur.archlinux.org/dae.git",
  async () => await $`systemctl restart dae.service`,
);

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

await $`sudo -u bsx bash -c 'mkdir -p ~/.config/fontconfig/ && cat ./fonts.conf > ~/.config/fontconfig/fonts.conf'`;

//nvm
await $`sudo -u bsx bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'`;

//starship
installPKG("starship");
await $`sudo -u bsx bash -c 'printf '\neval "$(starship init bash)"\n' >> ~/.bashrc'`;

//bluetooth
installPKG(["bluez", "bluez-utils"]);
await $`modprobe btusb`;
await $`systemctl enable bluetooth.service && systemctl start bluetooth.service`;

//input method
installPKG([
  "fcitx5-im",
  "fcitx5-chinese-addons",
  "fcitx5-qt",
  "fcitx5-gtk",
  "fcitx5-pinyin-zhwiki",
]);
installAUR("https://aur.archlinux.org/fcitx5-pinyin-moegirl.git");

//common
installAUR("https://aur.archlinux.org/google-chrome.git");
installAUR("https://aur.archlinux.org/visual-studio-code-bin.git");
installAUR("https://aur.archlinux.org/telegram-desktop-bin.git");

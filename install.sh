#!/usr/bin/env bash

# # Check if a configuration file is provided as a command line argument
# if [ -z "$1" ]; then
#     echo "Usage: $0 <config_file>"
#     exit 1
# fi

# CONFIG_FILE="$1"

DEVICE=
BASE_SYSTEM_PKG=(base base-devel linux linux-headers linux-firmware vim nano dhcpcd openssh zsh man-db man-pages btrfs-progs sudo networkmanager amd-ucode intel-ucode)
EXTRA_PKG=(git wget curl aria2 axel rsync htop neofetch fish neovim wezterm plasma-nm plasma dolphin ark dolphin-plugins kate)
HOSTNAME_INSTALL=
USER_NAME=

# VERIFY BOOT MODE
efi_boot_mode(){
    [[ -d /sys/firmware/efi/efivars ]] && return 0
    return 1
}

echo 'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo "Change mirror to USTC successfully!"
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 16/g" /etc/pacman.conf
echo "Config pacman conf successfully!"

systemctl is-active --quiet reflector.service && systemctl stop reflector.service
echo "Stop reflector service successfully!"

echo "Checking internet connectivity..."
if ! ping -c 3 archlinux.org &>/dev/null; then
    echo "Not Connected to Network! Please connect to the internet and try again."
    exit 1
fi
echo "Internet connection is available."

pacman-key --init
pacman-key --populate archlinux
echo "Init pacman key successfully!"

timedatectl set-ntp true
echo && echo "Date/Time service Status is . . . "
timedatectl status

# if ! command -v yq &>/dev/null; then
#     echo "yq not found. Installing yq..."
#     pacman -S yq
#     if [ $? -ne 0 ]; then
#         echo "Failed to install yq."
#         exit 1
#     fi
#     echo "yq installed successfully."
# else
#     echo "yq exists. Skipping installation."
# fi

parted -s "$DEVICE" mklabel gpt
echo "Create gpt label successfully!"
parted -s "$DEVICE" mkpart primary fat32 1M 512M
echo "Create efi partition successfully!"
parted -s "$DEVICE" mkpart primary btrfs 512M 100%
echo "Create btrfs partition successfully!"
# mkfs.fat -F32

ROOT_PART="$DEVICE"p2
mount /dev/"$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@srv
btrfs subvolume create /mnt/@logs
btrfs subvolume create /mnt/@pkgs
umount /mnt
echo "Create btrfs subvolume successfully!"

mount -o compress=zstd:3,subvol=@ /dev/"$ROOT_PART" /mnt
mkdir -p /mnt/{boot,home,root,srv,var/log,var/cache/pacman/pkg}
mount -o compress=zstd:3,subvol=@home /dev/"$ROOT_PART" /mnt/home
mount -o compress=zstd:3,subvol=@root /dev/"$ROOT_PART" /mnt/root
mount -o compress=zstd:3,subvol=@srv /dev/"$ROOT_PART" /mnt/srv
mount -o compress=zstd:3,subvol=@logs /dev/"$ROOT_PART" /mnt/var/log
mount -o compress=zstd:3,subvol=@pkgs /dev/"$ROOT_PART" /mnt/var/cache/pacman/pkg
echo "Mount btrfs subvolume successfully!"
mount /dev/"$ROOT_PART" /mnt/boot
echo "Mount boot partition successfully!"

# BASE_SYSTEM_PKG=$(yq eval ".packages.base_system | join(" ")" "$CONFIG_FILE")
# EXTRA_PKG=$(yq eval ".packages.extra | join(" ")" "$CONFIG_FILE")
pacstrap /mnt "${BASE_SYSTEM_PKG[@]}" "${EXTRA_PKG[@]}"
echo "Install base system successfully!"

genfstab -U /mnt > /mnt/etc/fstab
echo "Generate fstab successfully!"

arch-chroot /mnt
echo "Chroot to /mnt successfully!"

ln -s /usr/bin/vim /usr/bin/vi
echo "Create vi link to vim successfully!"

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
echo "Set timezone successfully!"

cat > /etc/locale.gen << EOF
en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8" 
EOF
locale-gen
echo "Generate locale successfully!"

# HOSTNAME_INSTALL=$(yq eval ".hostname" "$CONFIG_FILE")
echo "$HOSTNAME_INSTALL" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME_INSTALL.localdomain $HOSTNAME_INSTALL
EOF
echo "Set hostname and host successfully!"

systemctl enable NetworkManager
echo "Enable NetworkManager successfully!"

echo 'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo "Change mirror to USTC successfully!"
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 16/g" /etc/pacman.conf
cat >> /etc/pacman.conf << EOF
[Clansty]
SigLevel = Never
Server = https://repo.lwqwq.com/archlinux/\$arch
Server = https://pacman.ltd/archlinux/\$arch
Server = https://repo.clansty.com/archlinux/\$arch

[menci]
SigLevel = Never
Server = https://aur.men.ci/archlinux/\$arch
EOF
echo "Config pacman conf successfully!"

systemctl enable sshd
systemctl enable dhcpcd.service
systemctl enable NetworkManager.service
# systemctl enable sddm
echo "Enable sshd successfully!"
# echo "Enable sshd and sddm successfully!"

# USER_NAME=$(yq eval ".user.name" "$CONFIG_FILE")
useradd -m -G wheel -s /bin/bash "$USER_NAME"
echo "Add user successfully!"
passwd "$USER_NAME"
echo "Set user password successfully!"
# visudo
# echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
sed -i "s/# %wheel/%wheel/g" /etc/sudoers
sed -i "s/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
echo "Set sudoers successfully!"

boorctl --path=/boot install
boorctl --path=/boot update
echo "Install and update systemd-boot successfully!"
lsblk -f
echo "Press anykey to continue..."
read empty
vim /boot/loader/entries/arch.conf
systemctl enable systemd-boot-update.service
echo "Enable systemd-boot-update.service successfully!"

pacman -Syyu --noconfirm
pacman -S --noconfirm opendesktop-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-sarasa-gothic
echo "Install fonts successfully!"
pacman -S --noconfirm fcitx5-im fcitx5-rime fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-material-color
echo "Install fcitx5 successfully!"

su "$USER_NAME"
echo "Switch to user successfully!"
echo "Start customizing your system!"
cat >> ~/.bashrc << EOF
export QT_IM_MODULE=fcitx
export GTK_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export LANG=zh_CN.UTF-8
export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on"
export PATH=\$HOME/.config/yarn/global/node_modules/.bin/:\$HOME/.yarn/bin:\$HOME/.local/bin:\$PATH'
EOF
cat >> ~/.config/fish/config.fish << EOF
alias open=dolphin
alias :q=exit
alias reboot2efi=systemctl reboot --firmware-setup
EOF
cat >> ~/.pam_environment << EOF
GTK_IM_MODULE DEFAULT=fcitx
QT_IM_MODULE  DEFAULT=fcitx
XMODIFIERS    DEFAULT=@im=fcitx
SDL_IM_MODULE DEFAULT=fcitx
EOF
echo "Successfully set environment variables!"
echo "Successfully set PATH!"
echo "Successfully set alias!"

echo "Your system is installed.  Type anykey now to shutdown system and remove bootable media, then restart"
read empty
shutdown now
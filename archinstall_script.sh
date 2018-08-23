#!/bin/bash
# extend with this
# https://wiki.archlinux.org/index.php/Microcode#Enabling_Intel_microcode_updates

# cat /proc/partitions
# Clear out by writing zeros over GPT and MBR data:
# dd if=/dev/zero of=/dev/sda bs=1M count=5000
# Reread partition table:
# hdparm -z /dev/sda
# Now sda should not have partitions
# cat /proc/partitions
# or sudo parted /dev/sda print

# gdisk for partitioning (fdisk in EFIvars are not loaded: ls /sys/firmware/efi/efivars)
# for non-uefi bios not suppporting GPT no EFI partition needed and use GRUB as bootloader see archwiki
# partitions
# 1 512MB a EFI boot partition, ef00 fat32
# 2 8GB swap: 8200 (btrfs does not support swap file yet)
# 3 rest linux fs partition: 8300, btrfs
# tmpfs is used so no need to have separate subvolume for /tmp

installfor='laco'  # 'hajni', 'up2', 'raspi', 'laco'

case $installfor in
    hajni)
        HOSTNAME="hajnipc"
        USERNAME="hajni"
        FULL_NAME="Hajni Molnar"
        ;;
    up2)
        HOSTNAME="up2"
        USERNAME="laco"
        FULL_NAME="Laszlo Molnar"
        ;;
    raspi)
        HOSTNAME="raspi"
        USERNAME="laco"
        FULL_NAME="Laszlo Molnar"
        ;;
    laco)
        HOSTNAME="lacopc"
        USERNAME="laco"
        FULL_NAME="Laszlo Molnar"
        ;;
    *)
        echo "Please give a valid option for installfor"
        exit 1
esac

ZONEINFO="Europe/Berlin"
EFI_MOUNTOPTS="rw,nosuid,nodev,noatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro,discard"
BTRFS_LABEL="arch64"
# check with "hdparm -I /dev/sda | grep TRIM" to see if the ssd supports trim, only then use the discard mount option:
BTRFS_MOUNTOPTS="rw,noatime,discard,ssd,compress=lzo,space_cache"
BTRFS_MOUNTOPTS_NOEXEC="rw,noatime,noexec,discard,ssd,compress=lzo,space_cache"


if [$installfor = 'hajni']
then
    EFI_DEVICE="/dev/sda1"
    BTRFS_DEVICE="/dev/sdb"
if [$installfor = 'up2']
then
    EFI_DEVICE="/dev/mmcblk0p1"
    BTRFS_DEVICE="/dev/mmcblk0p3"
else
    EFI_DEVICE="/dev/sda1"
    BTRFS_DEVICE="/dev/sda3"
fi

# formats
mkfs.vfat -F32 -n "EFI" $EFI_DEVICE
fatlabel $EFI_DEVICE BOOT
mkfs.btrfs -L "$BTRFS_LABEL" $BTRFS_DEVICE -f
# swap
mkswap /dev/sda2
swapon /dev/sda2
# add with uuid to fstab
# /dev/sda2 none swap defaults,discard 0 0
reduce swapiness 0..100
/etc/sysctl.d/99-sysctl.conf
vm.swappiness=10
# only at hajni
mkfs.ext4 /dev/sda3 -L CUCC
lsblk -f

BTRFS_DEVICE_UUID=`blkid $BTRFS_DEVICE -o value -s UUID` # = at the end!!!
EFI_DEVICE_UUID=`blkid $EFI_DEVICE -o value -s UUID`

mkdir /mnt/btrfs-root
mount -o $BTRFS_MOUNTOPTS $BTRFS_DEVICE /mnt/btrfs-root
cd /mnt/btrfs-root
1;  # used this
btrfs subvolume create ROOT
btrfs subvolume create home
btrfs subvolume create opt
btrfs subvolume create pacpkg
btrfs subvolume create builds
btrfs subvolume create _snaps

mkdir -p /mnt/root
mount -o $BTRFS_MOUNTOPTS,subvol=ROOT $BTRFS_DEVICE /mnt/root
cd /mnt/root
mkdir -p home
mkdir -p opt
mkdir -p var/cache/pacman/pkg
mkdir -p var/abs
mkdir -p .snapshots

mount -o $BTRFS_MOUNTOPTS,subvol=home $BTRFS_DEVICE /mnt/root/home
mount -o $BTRFS_MOUNTOPTS,subvol=opt $BTRFS_DEVICE /mnt/root/opt
mount -o $BTRFS_MOUNTOPTS,subvol=pacpkg $BTRFS_DEVICE /mnt/root/var/cache/pacman/pkg
mount -o $BTRFS_MOUNTOPTS,subvol=builds $BTRFS_DEVICE /mnt/root/var/abs
mount -o $BTRFS_MOUNTOPTS,subvol=_snaps $BTRFS_DEVICE /mnt/root/.snapshots

mkdir -p /mnt/root/boot
mount -o $EFI_MOUNTOPTS $EFI_DEVICE /mnt/root/boot

# to chroot again:
mkdir /mnt/root
mount -o $BTRFS_MOUNTOPTS,subvol=ROOT $BTRFS_DEVICE /mnt/root
mount -o $BTRFS_MOUNTOPTS,subvol=home $BTRFS_DEVICE /mnt/root/home
mount -o $BTRFS_MOUNTOPTS,subvol=opt $BTRFS_DEVICE /mnt/root/opt
mount -o $BTRFS_MOUNTOPTS,subvol=pacpkg $BTRFS_DEVICE /mnt/root/var/cache/pacman/pkg
mount -o $BTRFS_MOUNTOPTS,subvol=builds $BTRFS_DEVICE /mnt/root/var/abs
mount -o $BTRFS_MOUNTOPTS,subvol=_snaps $BTRFS_DEVICE /mnt/root/.snapshots

mkdir -p /mnt/root/boot
mount -o $EFI_MOUNTOPTS $EFI_DEVICE /mnt/root/boot

arch-chroot /mnt/root /bin/bash

umount /mnt/root
############

2;
mkdir -p /mnt/btrfs-root/__snapshot
mkdir -p /mnt/btrfs-root/__active
btrfs subvolume create /mnt/btrfs-root/__active/ROOT
btrfs subvolume create /mnt/btrfs-root/__active/home
btrfs subvolume create /mnt/btrfs-root/__active/opt
btrfs subvolume create /mnt/btrfs-root/__active/var


mkdir -p /mnt/btrfs-active
mount -o $BTRFS_MOUNTOPTS,subvol=__active/ROOT $BTRFS_DEVICE /mnt/btrfs-active
mkdir -p /mnt/btrfs-active/{home,opt}
mkdir -p /mnt/btrfs-active/var/lib
mount -o $BTRFS_MOUNTOPTS,subvol=__active/home $BTRFS_DEVICE /mnt/btrfs-active/home
mount -o $BTRFS_MOUNTOPTS,subvol=__active/opt $BTRFS_DEVICE /mnt/btrfs-active/opt
mount -o $BTRFS_MOUNTOPTS_NOEXEC,subvol=__active/var $BTRFS_DEVICE /mnt/btrfs-active/var
mkdir -p /mnt/btrfs-active/var/lib
mount --bind /mnt/btrfs-root/__active/ROOT/var/lib /mnt/btrfs-active/var/lib

mkdir -p /mnt/btrfs-active/boot
mount -o $EFI_MOUNTOPTS $EFI_DEVICE /mnt/btrfs-active/boot

# to chroot again:
mkdir /mnt/btrfs-root
mount -o $BTRFS_MOUNTOPTS $BTRFS_DEVICE /mnt/btrfs-root
mkdir -p /mnt/btrfs-active
mount -o $BTRFS_MOUNTOPTS,subvol=__active/ROOT $BTRFS_DEVICE /mnt/btrfs-active
mount -o $BTRFS_MOUNTOPTS,subvol=__active/home $BTRFS_DEVICE /mnt/btrfs-active/home
mount -o $BTRFS_MOUNTOPTS,subvol=__active/opt $BTRFS_DEVICE /mnt/btrfs-active/opt
mount -o $BTRFS_MOUNTOPTS_NOEXEC,subvol=__active/var $BTRFS_DEVICE /mnt/btrfs-active/var
mount --bind /mnt/btrfs-root/__active/ROOT/var/lib /mnt/btrfs-active/var/lib

mount -o $EFI_MOUNTOPTS $EFI_DEVICE /mnt/btrfs-active/boot
arch-chroot /mnt/btrfs-active
############

1;
pacstrap /mnt/root base base-devel btrfs-progs sudo dosfstools vim
genfstab -U -p /mnt/root >> /mnt/root/etc/fstab
arch-chroot /mnt/root /bin/bash

2;
pacstrap /mnt/btrfs-active base base-devel btrfs-progs sudo
genfstab -U -p /mnt/btrfs-active >> /mnt/btrfs-active/etc/fstab
vi /mnt/btrfs-active/etc/fstab

 * add "tmpfs /tmp tmpfs nodev,nosuid 0 0"
 * add "tmpfs /dev/shm tmpfs nodev,nosuid,noexec 0 0"
 * copy the partition info for / and mount it on /run/btrfs-root (remember to remove subvol parameter! and add nodev,nosuid,noexec parameters)
 * remove the /var/lib entry (we will bind it)
 * add "/run/btrfs-root/__current/ROOT/var/lib	/var/lib none bind 0 0" (to bind the /var/lib on the var subvolume to the /var/lib on the ROOT subvolume)
mkdir -p /mnt/btrfs-active/run/btrfs-root
arch-chroot /mnt/btrfs-active


# configuration
cp /etc/pacman.d/mirrorlist{,.backup}
rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
#
echo $HOSTNAME > /etc/hostname
/etc/hosts
127.0.0.1       localhost.localdomain   localhost
::1             localhost.localdomain   localhost
127.0.1.1	lacopc.localdomain	lacopc

#
# loadkeys uk
sed -i "s/#hu_HU/hu_HU/" /etc/locale.gen
sed -i "s/#en_GB/en_GB/" /etc/locale.gen
locale-gen
echo LANG=en_GB.UTF-8 > /etc/locale.conf
echo LANGUAGE=en_GB:en_US:en >> /etc/locale.conf
export LANG=en_GB.UTF-8
# font vconsole
echo KEYMAP=uk > /etc/vconsole.conf
echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf
echo "FONT_MAP=8859-2" >> /etc/vconsole.conf

ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc --utc
pacman -S ntp
systemctl enable ntpd

# zsh shell but modify it to python shells
# pacman -S zsh grml-zsh-config

#add user
groupadd $USERNAME
useradd -m -g $USERNAME -G users,wheel,storage,power,network,disk,audio,video,sys,lp -s /bin/bash -c "$FULL_NAME" $USERNAME
chfn --full-name "$FULL_NAME" $USERNAME
# userdel -r username
passwd $USERNAME

pacman -S sudo vim dosfstools wget unzip dialog wpa_supplicant ppp dialog
visudo

# uncomment %wheel ALL=(ALL:ALL) ALL or %wheel ALL=(ALL:ALL) NOPASSWD: ALL if you don’t want to enter your password again when using sudo.

# Now remove the root password so that root cannot login (don’t lock the account with passwd -l because than then recovery root login doesn’t work anymore):
passwd -d root
# or set root passwd
# passwd

#generate initramfs
# pacman -S btrfs-progs
vim /etc/mkinitcpio.conf
 * Remove fsck and add btrfs consolefont resume to HOOKS
# Early KMS start
# MODULES="... intel_agp i915 ... nvidia"
mkinitcpio -p linux
# PREVENT FSCK:
mv /sbin/fsck.btrfs /sbin/fsck.btrfs.REM
ln -s /sbin/true /sbin/fsck.btrfs

# blacklist nouveau for proprietary driver
vim /etc/modprobe.d/blacklist.conf
blacklist nouveau
blacklist rivafb
blacklist nvidiafb
blacklist rivatv
blacklist nv
blacklist uvcvideo

#install refind from zip
cd /tmp
pacman -S wget unzip
wget  http://sourceforge.net/projects/refind/files/0.10.1/refind-bin-0.10.1.zip/download
unzip download
# install refind with pacman
pacman -S refind-efi
# check boot is mounted
refind-install --usedefault /dev/sda1 --alldrivers

# trick motherboard UEFI
mkdir -p /boot/EFI/microsoft/boot/
mv /boot/EFI/refind/* /boot/EFI/microsoft/boot/
rm -fr /boot/EFI/refind/
mv /boot/EFI/microsoft/boot/refind_x64.efi /boot/EFI/microsoft/boot/bootmgfw.efi

vim /boot/EFI/microsoft/boot/refind.conf
# blkid /dev/sda3 to get PARTUUID
# kernel parameters at the end of options remove nomodeset!
timeout 5
hideui banner

# PARTUUID OF THE ROOT SUBVOLUME!!!!! blkid /dev/sda3
# at resume UUID of swap partition!!! blkid /dev/sda2
menuentry "archlinux64" {
        icon     /EFI/microsoft/boot/icons/os_arch.png
        volume   BOOT
        loader   /vmlinuz-linux
        initrd   /initramfs-linux.img
        options  "root=PARTUUID=98d44137-8b4a-4ff6-87fe-5cb9603260e4 rw rootflags=subvol=ROOT i915.preliminary_hw_support=1"
    options  "root=PARTUUID=91d0cd39-9980-4f96-ab11-66b348c15335 rw rootflags=subvol=ROOT resume=UUID=f2e83f5b-a526-439e-89c0-112ddc5aeb76"
        submenuentry "Boot using fallback initramfs" {
                initrd /initramfs-linux-fallback.img
        }
}


# You can sometimes pass special options to a specific boot by pressing the F2 or Insert key once it's highlighted
# the automatic menuentries can be removed
rm /boot/refind_linux.conf

#
exit

umount /mnt/btrfs-active/*
umount /mnt/btrfs-root
umount /mnt/btrfs-root/*

reboot

# https://wiki.archlinux.org/index.php/Fonts#Console_fonts
setfont ter-132n -m 8859-2
sudo pacman -S terminus-font
/etc/vconsole.conf FONT=ter-132n
/etc/mkinitcpio.conf consolefont to HOOKS
mkinitcpio -p linux

# check network devices
ip a
rfkill list all
/etc/netctl/my_dhcp_profile
Interface=enp8s0
Connection=ethernet
IP=dhcp
or sudo systemctl enable dhcpcd@enp8s0.service
pacman -S openssh xorg-xauth

# possibly missing fw for module wd719 aic94xx
# 1st way to install yaourt
wget https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz
tar -zvxf package-query.tar.gz && cd package-query && makepkg -sri
cd .. && rm -fr package-query*
wget https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz
# 2nd way
sudo vim /etc/pacman.conf
[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/$arch
#
sudo pacman -Sy yaourt
#
sudo vim /etc/yaourtrc
DEVELSRCDIR="/var/abs/local/yaourtbuild"
# Build
EXPORT=2
#
sudo mkdir -p /var/abs/local/yaourtbuild
sudo chmod -R a+rwX /var/abs/local
#
sudo pacman -S rsync git colordiff
yaourt -S customizepkg-git
yaourt -S wd719x-firmware aic94xx-firmware
sudo mkinitcpio -p linux

# check suspend or ignore at https://wiki.archlinux.org/index.php/Power_management
sudo vim /etc/systemd/logind.conf
sudo systemctl status systemd-logind.service
restart reenable

cd /lib/firmware/ath10k/QCA6174/hw3.0/
sudo ln -s firmware-4.bin firmware-5.bin 

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo vim /etc/systemd/system/getty@tty1.service.d/noclear.conf
[Service]
TTYVTDisallocate=no
Shift+PgUp/PgDown to scroll
ctrL UP/DOWN
OR journalctl -b

# num lock
sudo vim /etc/systemd/system/numlock1to6.service
[Unit]
Description=Switch on numlock from tty1 to tty6

[Service]
ExecStart=/bin/bash -c 'for tty in /dev/tty{1..6};do /usr/bin/setleds -D +num < \"$tty\";done'

[Install]
WantedBy=multi-user.target

sudo systemctl enable numlock1to6

# snapperA
sudo pacman -S snapper
snapper does not like /.snapshots to already exist when you run snapper -c root create-config /, do this:
sudo umount /.snapshots
sudo rm -fr /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume list /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo chmod 750 /.snapshots
sudo mount /.snapshots
sudo vim /etc/snapper/configs/root

# browser psd
https://wiki.archlinux.org/index.php/profile-sync-daemon

# install nvidia with bumblebee
gpasswd -a user bumblebee audio video
sudo systemctl enable bumblebeed
# remove nvidia
sudo pacman -Rs xorg-server xorg-server-devel xorg-server-utils xorg-apps xorg-xinit nvidia nvidia-utils bumblebee mesa xf86-video-intel lib32-virtualgl  lib32-nvidia-utils lib32-mesa-libgl bbswitch bbswitch-dkms
sudo rm -fr /etc/X11/xorg.conf.d/
sudo vim /etc/modprobe.d/blacklist.conf


# after dtop env
sudo pacman -S gnome gnome-extra gnome-tweak-tool
sudo systemctl enable gdm.services
yaourt -S gnome-software

rfkill list all
sudo pacman -S bluez bluez-utils rfkill
sudo systemctl enable bluetooth
sudo systemctl disable dhcpcd@
sudo systemctl enable NetworkManager

https://wiki.archlinux.org/index.php/microcode

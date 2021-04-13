#!/bin/bash

#
# Build script for Ubuntu Japanese Remix ISO
#
# This script based and inspired by:
#   - https://help.ubuntu.com/community/LiveCDCustomization
#   - https://bazaar.launchpad.net/~timo-jyrinki/ubuntu-fi-remix/main/files
#   - https://github.com/estobuntu/ubuntu-estonian-remix 
#   - https://code.launchpad.net/~ubuntu-cdimage/debian-cd/ubuntu
#
# Author: Jun Kobayashi <jkbys@ubuntu.com>
#
# License CC-BY-SA 3.0: http://creativecommons.org/licenses/by-sa/3.0/
#

INPUT_ISO="ubuntu-20.10-desktop-amd64.iso"
OUTPUT_ISO="ubuntu-ja-20.10-desktop-amd64-$(date '+%Y%m%d').iso"
VOLUME_ID="Ubuntu 20.10 ja amd64"
NAMESERVER="1.1.1.1"
RELEASE_NOTES_URL="https://wiki.ubuntu.com/GroovyGorilla/ReleaseNotes/Ja"
UBUNTU_VERSION="20.10"
CODE_NAME="Groovy Gorilla"
CODE_NAME_SHORT="groovy"
TIMEZONE="Asia/Tokyo"
ZONEINFO_FILE="/usr/share/zoneinfo/Asia/Tokyo"
ARCHIVE_MIRROR="http://ftp.naist.jp/pub/Linux/ubuntu/"
ARCHIVE_MIRROR_RELEASE="http://jp.archive.ubuntu.com/ubuntu/"
SECURITY_MIRROR="http://ftp.naist.jp/pub/Linux/ubuntu/"
SECURITY_MIRROR_RELEASE="http://security.ubuntu.com/ubuntu/"

log() {
  echo "$(date -Iseconds) [info ] $*"
}

log_error() {
  echo "$(date -Iseconds) [error] $*" >&2
}

# only root can run
if [[ "$(id -u)" != "0" ]]; then
  log_error "This script must be run as root"
  exit 1
fi

# check existence of input iso
if [[ ! -f $INPUT_ISO ]]; then
  log_error "No Input ISO file: $INPUT_ISO"
  exit 1
fi

# install packages
apt-get install -y squashfs-tools xorriso cd-boot-images-amd64

# remove directories
log "Removing previously created directories ..."
umount squashfs/
umount mnt/
rm -rf edit/ extract-cd/ mnt/ squashfs/
log "Done."

# mount and copy
log "Mount ISO and copy files ..."
mkdir mnt
mount -o loop ${INPUT_ISO} mnt/
mkdir extract-cd
rsync -a --exclude=/casper/filesystem.squashfs mnt/ extract-cd/
chmod +rw -R extract-cd/
log "Done."

# extract squashfs
log "Extracting squashfs ..."
mkdir squashfs
mount -t squashfs -o loop mnt/casper/filesystem.squashfs squashfs
mkdir edit
cp -a squashfs/* edit/
log "Done."

# .disk/
echo "$RELEASE_NOTES_URL" > extract-cd/.disk/release_notes_url
echo "Ubuntu $UBUNTU_VERSION \"$CODE_NAME\" - Release amd64($(date '+%Y%m%d'))" > extract-cd/.disk/info

# preseed/ubuntu.seed
cat <<EOT >> extract-cd/preseed/ubuntu.seed
d-i	debian-installer/language	string	ja
d-i	debian-installer/locale	string	ja_JP.UTF-8
d-i	keyboard-configuration/layoutcode	string	jp
d-i	keyboard-configuration/modelcode	string	pc105
EOT

# boot/grub/grub.cfg
sed -i 's#splash ---#splash --- debian-installer/language=ja debian-installer/locale=ja_JP.UTF-8 keyboard-configuration/layoutcode?=jp keyboard-configuration/modelcode?=pc105#' extract-cd/boot/grub/grub.cfg

# casper/filesystem.manifest-remove
sed -i '/\(^ibus-mozc$\|^mozc-data$\|^mozc-server$\|^tegaki-zinnia-japanese$\)/d' extract-cd/casper/filesystem.manifest-remove
echo "ubuntu-ja-live-fix" >> extract-cd/casper/filesystem.manifest-remove

# casper/filesystem.manifest-minimal-remove
cat <<EOT >> extract-cd/casper/filesystem.manifest-minimal-remove
libreoffice-help-common
libreoffice-help-ja
libreoffice-l10n-ja
thunderbird-locale-ja
EOT

mount --bind /dev/ edit/dev

# chroot start
log "Execute commands inside chroot"
chroot edit/ <<EOT
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

echo "nameserver $NAMESERVER" > /run/systemd/resolve/stub-resolv.conf

rm -f /etc/localtime
ln -s "$ZONEINFO_FILE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone

if [[ -f /etc/apt/apt.conf.d/90_zsys_system_autosnapshot ]]; then
  sed -i 's/^/## /' /etc/apt/apt.conf.d/90_zsys_system_autosnapshot
fi

apt-get --purge remove -y firefox-locale-de firefox-locale-es firefox-locale-fr firefox-locale-it firefox-locale-pt firefox-locale-ru firefox-locale-zh-hans fonts-arphic-ukai fonts-arphic-uming gnome-getting-started-docs-de gnome-getting-started-docs-es gnome-getting-started-docs-fr gnome-getting-started-docs-it gnome-getting-started-docs-pt gnome-getting-started-docs-ru gnome-user-docs-de gnome-user-docs-es gnome-user-docs-fr gnome-user-docs-it gnome-user-docs-pt gnome-user-docs-ru gnome-user-docs-zh-hans hunspell-de-at-frami hunspell-de-ch-frami hunspell-de-de-frami hunspell-es hunspell-fr hunspell-fr-classical hunspell-it hunspell-pt-br hunspell-pt-pt hunspell-ru hyphen-de hyphen-es hyphen-fr hyphen-it hyphen-pt-br hyphen-pt-pt hyphen-ru ibus-chewing ibus-hangul ibus-libpinyin ibus-m17n ibus-table ibus-table-cangjie ibus-table-cangjie-big ibus-table-cangjie3 ibus-table-cangjie5 ibus-table-quick-classic ibus-table-wubi ibus-unikey language-pack-de language-pack-de-base language-pack-es language-pack-es-base language-pack-fr language-pack-fr-base language-pack-gnome-de language-pack-gnome-de-base language-pack-gnome-es language-pack-gnome-es-base language-pack-gnome-fr language-pack-gnome-fr-base language-pack-gnome-it language-pack-gnome-it-base language-pack-gnome-pt language-pack-gnome-pt-base language-pack-gnome-ru language-pack-gnome-ru-base language-pack-gnome-zh-hans language-pack-gnome-zh-hans-base language-pack-it language-pack-it-base language-pack-pt language-pack-pt-base language-pack-ru language-pack-ru-base language-pack-zh-hans language-pack-zh-hans-base libreoffice-help-de libreoffice-help-es libreoffice-help-fr libreoffice-help-it libreoffice-help-pt libreoffice-help-pt-br libreoffice-help-ru libreoffice-help-zh-cn libreoffice-help-zh-tw libreoffice-l10n-de libreoffice-l10n-es libreoffice-l10n-fr libreoffice-l10n-it libreoffice-l10n-pt libreoffice-l10n-pt-br libreoffice-l10n-ru libreoffice-l10n-zh-cn libreoffice-l10n-zh-tw mythes-de mythes-de-ch mythes-es mythes-fr mythes-it mythes-pt-pt mythes-ru thunderbird-locale-de thunderbird-locale-es thunderbird-locale-es-ar thunderbird-locale-es-es thunderbird-locale-fr thunderbird-locale-it thunderbird-locale-pt thunderbird-locale-pt-br thunderbird-locale-pt-pt thunderbird-locale-ru thunderbird-locale-zh-cn thunderbird-locale-zh-hans thunderbird-locale-zh-hant thunderbird-locale-zh-tw wbrazilian wfrench witalian wngerman wogerman wportuguese wspanish wswiss

wget https://www.ubuntulinux.jp/ubuntu-jp-ppa-keyring.gpg -P /etc/apt/trusted.gpg.d/
wget https://www.ubuntulinux.jp/ubuntu-ja-archive-keyring.gpg -P /etc/apt/trusted.gpg.d/
wget https://www.ubuntulinux.jp/sources.list.d/${CODE_NAME_SHORT}.list -O /etc/apt/sources.list.d/ubuntu-ja.list

sed -i 's/restricted/restricted universe/' /etc/apt/sources.list
sed -i 's#http://archive.ubuntu.com/ubuntu/ ${CODE_NAME_SHORT} #${ARCHIVE_MIRROR} ${CODE_NAME_SHORT} #' /etc/apt/sources.list
sed -i 's#http://archive.ubuntu.com/ubuntu/ ${CODE_NAME_SHORT}-updates #${ARCHIVE_MIRROR} ${CODE_NAME_SHORT}-updates #' /etc/apt/sources.list
sed -i 's#http://security.ubuntu.com/ubuntu/ ${CODE_NAME_SHORT}-security #${SECURITY_MIRROR} ${CODE_NAME_SHORT}-security #' /etc/apt/sources.list

apt-get update
apt-get install -y ubuntu-defaults-ja ubuntu-ja-live-fix gnome-getting-started-docs-ja gnome-user-docs-ja libreoffice-help-ja libreoffice-l10n-ja thunderbird-locale-ja
apt-get upgrade -y firefox firefox-locale-en firefox-locale-ja thunderbird thunderbird-gnome-support thunderbird-locale-en thunderbird-locale-en-gb thunderbird-locale-en-us thunderbird-locale-ja ubiquity ubiquity-frontend-gtk ubiquity-ubuntu-artwork

update-locale LANG=ja_JP.UTF-8
sed -i 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
locale-gen --keep-existing

apt-get clean
umount /proc
umount /sys
umount /dev/pts

if [[ "${ARCHIVE_MIRROR}" != "${ARCHIVE_MIRROR_RELEASE}" ]]; then
  sed -i 's#${ARCHIVE_MIRROR} ${CODE_NAME_SHORT} #${ARCHIVE_MIRROR_RELEASE} ${CODE_NAME_SHORT} #' /etc/apt/sources.list
  sed -i 's#${ARCHIVE_MIRROR} ${CODE_NAME_SHORT}-updates #${ARCHIVE_MIRROR_RELEASE} ${CODE_NAME_SHORT}-updates #' /etc/apt/sources.list
fi
if [[ "${SECURITY_MIRROR}" != "${SECURITY_MIRROR_RELEASE}" ]]; then
  sed -i 's#${SECURITY_MIRROR} ${CODE_NAME_SHORT}-security #${SECURITY_MIRROR_RELEASE} ${CODE_NAME_SHORT}-security #' /etc/apt/sources.list
fi

if [[ -f /etc/apt/apt.conf.d/90_zsys_system_autosnapshot ]]; then
  sed -i 's/^## //' /etc/apt/apt.conf.d/90_zsys_system_autosnapshot
fi

echo -n "" > /run/systemd/resolve/stub-resolv.conf
EOT
# chroot end

# extract-cd/casper/filesystem.manifest
log "Making filesystem.manifest ..."
chroot edit/ dpkg-query -W --showformat='${binary:Package}\t${Version}\n' > extract-cd/casper/filesystem.manifest
grep "^snap:" mnt/casper/filesystem.manifest >> extract-cd/casper/filesystem.manifest
log "Done."

# cleanup
rm -rf edit/root/.bash_history
rm -rf edit/tmp/*
rm -rf edit/var/lib/apt/lists/*
rm -rf edit/var/cache/debconf/*-old
umount edit/dev/

# make squashfs
log "Making filesystem.squashfs ..."
sh -c 'du -B 1 -s edit/ | cut -f1 > extract-cd/casper/filesystem.size'
mksquashfs edit/ extract-cd/casper/filesystem.squashfs -xattrs -comp xz
rm extract-cd/casper/filesystem.squashfs.gpg
log "Done."

# make md5sum.txt
log "Making md5sum ..."
rm -f extract-cd/boot.catalog
cd extract-cd/ || exit
find . -type f -not -name 'md5sum.txt' -not -path './boot/*' -not -path './EFI/*' -print0 | xargs -0 md5sum > md5sum.txt
md5sum ./boot/memtest86+.bin >> md5sum.txt
md5sum ./boot/grub/*.cfg >> md5sum.txt
cd ../
log "Done."

# make iso
log "Making $OUTPUT_ISO ..." 
xorriso \
  -as mkisofs  \
  -volid "$VOLUME_ID" \
  -o "$OUTPUT_ISO" \
  -J -joliet-long -l  \
  -b boot/grub/i386-pc/eltorito.img  \
  -no-emul-boot  \
  -boot-load-size 4  \
  -boot-info-table  \
  --grub2-boot-info  \
  --grub2-mbr /usr/share/cd-boot-images-amd64/images/boot/grub/i386-pc/boot_hybrid.img \
  -append_partition 2 0xef /usr/share/cd-boot-images-amd64/images/boot/grub/efi.img  \
  -appended_part_as_gpt  \
  --mbr-force-bootable  \
  -eltorito-alt-boot  \
  -e --interval:appended_partition_2:all::  \
  -no-emul-boot \
  -partition_offset 16 \
  -r \
  extract-cd/
log "Done."

# umount
umount squashfs/
umount mnt/

#!/bin/bash

set -e

NEW_KERNEL="$1"
KERNEL_IMAGE="$2"
NEW_INITRD="nondracut-initramfs-${NEW_KERNEL}.img"
NEW_TITLE="Fedora ${NEW_KERNEL} dracut FREE"

[ -f /etc/initrd.conf ] && readarray PACKAGES < <(grep "^[^#]" /etc/initrd.conf)

INITRD_DIR=$(mktemp -d) # better would be /var/tmp

mkdir -p "${INITRD_DIR}"/etc/rpm && \
echo "%_install_langs C:en:en_US:en_US.UTF-8" >> "${INITRD_DIR}"/etc/rpm/macros.image-language-conf

dnf -y -q update
dnf -y -q install --setopt=install_weak_deps=False --installroot="$INITRD_DIR" --releasever=31 --setopt=tsflags=nodocs \
  systemd \
  passwd \
  fedora-release \
  vim-minimal \
  lvm2 \
  systemd-udev \
  kernel-modules \
  "${PACKAGES[@]}"

touch "${INITRD_DIR}/etc/initrd-release"
ln -s /lib/systemd/systemd "${INITRD_DIR}/init"
systemctl -q --root "$INITRD_DIR" set-default initrd.target

sed -i "/^root/d" "${INITRD_DIR}/etc/shadow" && grep "^root" /etc/shadow >> "${INITRD_DIR}/etc/shadow" # Add root password

if [ -e /etc/selinux/config ] && [ -x /usr/sbin/setfiles ] ; then
  . /etc/selinux/config
  /usr/sbin/setfiles -v -r "${INITRD_DIR}" /etc/selinux/${SELINUXTYPE}/contexts/files/file_contexts "${INITRD_DIR}" > /dev/null
fi

# build initrd
cd "$INITRD_DIR" || exit 1
find . | cpio --quiet -o -c | gzip -q -9 > "/boot/${NEW_INITRD}"
cd && rm -rf "$INITRD_DIR"

# generate grup config
grubby --add-kernel="$KERNEL_IMAGE" --initrd="/boot/${NEW_INITRD}" --grub2 --title="${NEW_TITLE}"

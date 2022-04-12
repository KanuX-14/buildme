#!/bin/bash

OLD_VERSION=$(uname -r)
VERSION=$(make -s kernelversion)

# Copying the old config

cp -v /boot/config-$OLD_VERSION .config

# Making sure you own every file in the kernel

sudo chown -R $USER:$USER ./*

# Start building

make olddefconfig
make -j$(nproc)
make -j$(nproc) modules
make -j$(nproc) headers
make -j$(nproc) bzImage

# Installing the kernel

sudo make modules_install
sudo make headers_install
sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-linux-$VERSION
printf "# mkinitcpio preset file for the 'linux-$VERSION' package\n\
\n\
ALL_config=\"/etc/mkinitcpio.conf\"\n\
ALL_kver=\"/boot/vmlinuz-linux-$VERSION\"\n\
\n\
PRESETS=('default' 'fallback')\n\
\n\
#default_config=\"/etc/mkinitcpio.conf\"\n\
default_image=\"/boot/initramfs-linux-$VERSION.img\"\n\
#default_options=\"\"\n\
\n\
#fallback_config=\"/etc/mkinitcpio.conf\"\n\
fallback_image=\"/boot/initramfs-linux-fallback-$VERSION.img\"\n\
fallback_options=\"-S autodetect\"\n" | sudo tee /etc/mkinitcpio.d/linux-$VERSION.preset
sudo mkinitcpio -p linux-$VERSION
sudo cp -v System.map /boot/System.map-$VERSION
sudo ln -sf /boot/System.map-$VERSION /boot/System.map
sudo cp -v .config /boot/config-$VERSION

# Uncomment if you want to remove the old kernel

# sudo rm -f /boot/*`uname -r`*
# sudo rm -f /etc/mkinitcpio.d/*`uname -r`*

# Finish installation and prompt reboot

sudo grub-mkconfig -o /boot/grub/grub.cfg
read -p "Press [ENTER] to reboot..." key
sudo reboot

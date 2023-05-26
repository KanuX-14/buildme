#!/bin/bash

OLD_VERSION=$(uname -r)
VERSION=$(make -s kernelversion)
CORE=1 # $(nproc)
current_user="$USER"
remove_kernel="N"

# Colours
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
PURPLE="\e[1;35m"
CYAN="\e[1;36m"
RESET_COLOUR="\e[0m"

MAKE_PACKAGES()
{
    if ! ls .config; then
        if type dpkg &>/dev/null; then
            cp -v /boot/config-$OLD_VERSION .config
        else
            zcat -v /proc/config > .config
        fi
    fi

    make olddefconfig
    make -j$CORE
    make -j$CORE modules
    make -j$CORE headers
    make -j$CORE bzImage
}

# Mostly used in Debian-based distributions
AUTOMATED_INSTALL()
{
    sudo make modules_install
    sudo make headers_install
    sudo make install
    sudo update-initramfs -u
}

MANUAL_INSTALL()
{
    sudo make modules_install
    sudo make headers_install
    VERSION=$(ls /lib/modules | grep "$VERSION" | sort --reverse - | head -n 1)
    sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-linux-$VERSION
    sudo mkinitcpio -k $VERSION -g /boot/initramfs-linux-$VERSION.img
    sudo cp -v System.map /boot/System.map-$VERSION
    sudo ln -sfv /boot/System.map-$VERSION /boot/System.map
    sudo cp -v .config /boot/config-$VERSION
}

# Making sure you own every file in the kernel

sudo chown -R $current_user:$current_user ./*

# Start building

MAKE_PACKAGES

# Installing the kernel

if type dpkg &>/dev/null; then
    AUTOMATED_INSTALL
else
    MANUAL_INSTALL
fi

# Prompt to remove old kernel

read -p "Remove the $OLD_VERSION kernel? [N/y] " remove_kernel
case $remove_kernel in
    "Y"|"y"|"Yes"|"yes")
        sudo rm -fv /boot/*$OLD_VERSION*
        sudo rm -rfv /lib/modules/*$OLD_VERSION*
        sudo rm -fv /etc/mkinitcpio.d/*$OLD_VERSION*
        printf "$YELLOW""Warning: $OLD_VERSION kernel has been removed.""$RESET_COLOUR""\n"
        ;;
    *)
        printf "$YELLOW""Warning: $OLD_VERSION kernel will be skipped.""$RESET_COLOUR""\n"
        ;;
esac
printf "\n"

# Finish installation and prompt reboot

if type dpkg &>/dev/null; then
    sudo update-grub
else
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

printf "Reboot in order to apply the changes.\n"

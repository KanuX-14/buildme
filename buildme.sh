#!/bin/bash

OLD_VERSION=$(uname -r)
VERSION=$(make -s kernelversion)
current_user="$USER"
remove_kernel="N"

function make_packages()
{
    if type dpkg &>/dev/null; then
        cp -v /boot/config-$OLD_VERSION .config
    else
        zcat -v /proc/config > .config

    make olddefconfig
    make -j$(nproc)
    make -j$(nproc) modules
    make -j$(nproc) headers
    make -j$(nproc) bzImage
}

# Mostly used in Debian-based distributions
function automated_install()
{
    sudo make modules_install
    sudo make headers_install
    sudo make install
    sudo update-initramfs -u
}

function manual_install()
{
    sudo make modules_install
    sudo make headers_install
    sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-linux-$VERSION
    sudo mkinitcpio -z $VERSION -g /boot/initramfs-$VERSION.img
    sudo mkinitcpio -p linux-$VERSION
    sudo cp -v System.map /boot/System.map-$VERSION
    sudo ln -sfv /boot/System.map-$VERSION /boot/System.map
    # sudo cp -v .config /boot/config-$VERSION
}


# Making sure you own every file in the kernel

sudo chown -R $current_user:$current_user ./*

# Start building

make_packages()

# Installing the kernel

if type dpkg &>/dev/null; then
    automated_install()
else
    manual_install()

# Prompt to remove old kernel

read -p "Remove the $OLD_VERSION kernel? [N/y]" remove_kernel
case remove_kernel in
    Y | y)
        sudo rm -fv /boot/*`uname -r`*
        sudo rm -fv /etc/mkinitcpio.d/*`uname -r`*
        ;;
    *)
        printf "Skipping...\n"
        ;;
esac

# Finish installation and prompt reboot

if type dpkg &>/dev/null; then
    sudo update-grub
else
    sudo grub-mkconfig -o /boot/grub/grub.cfg

printf "\nReboot in order to apply the changes.\n"

#!/bin/bash

OLD_VERSION=$(uname -r)
VERSION=$(make -s kernelversion)
CORE=$(nproc)
current_user="$USER"
remove_kernel="N"

function make_packages()
{
    if type dpkg &>/dev/null; then
        cp -v /boot/config-$OLD_VERSION .config
    else
        zcat -v /proc/config > .config
    fi

    make olddefconfig
    make -j$CORE
    make -j$CORE modules
    make -j$CORE headers
    make -j$CORE bzImage
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
    VERSION=$(ls /lib/modules | grep "$VERSION" | head -n 1)
    sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-linux-$VERSION
    sudo mkinitcpio -k $VERSION -g /boot/initramfs-linux-$VERSION.img
    sudo cp -v System.map /boot/System.map-$VERSION
    sudo ln -sfv /boot/System.map-$VERSION /boot/System.map
    # sudo cp -v .config /boot/config-$VERSION
}


# Making sure you own every file in the kernel

sudo chown -R $current_user:$current_user ./*

# Start building

make_packages

# Installing the kernel

if type dpkg &>/dev/null; then
    automated_install
else
    manual_install
fi

# Prompt to remove old kernel

read -p "Remove the $OLD_VERSION kernel? [N/y] " remove_kernel
case remove_kernel in
    "Y"|"y"|"Yes"|"yes")
        sudo rm -fv /boot/*$OLD_VERSION*
        sudo rm -rfv /lib/modules/*$OLD_VERSION*
        sudo rm -fv /etc/mkinitcpio.d/*$OLD_VERSION*
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
fi

printf "\nReboot in order to apply the changes.\n"

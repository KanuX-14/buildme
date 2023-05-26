#!/bin/bash

ROOT=""
OLD_VERSION=$(uname -r)
VERSION=$(make -s kernelversion)
CORE=1 # $(nproc)
CURRENT_USER="$USER"
REMOVE_KERNEL="N"

# Colours
RED="\x1b[1;31m"
GREEN="\x1b[1;32m"
YELLOW="\x1b[1;33m"
BLUE="\x1b[1;34m"
PURPLE="\x1b[1;35m"
CYAN="\x1b[1;36m"
RESET_COLOUR="\x1b[0m"

# int: Checks if script is running with root.
#      If not, no updates will happen.
#      The script will compile but will not install.
AM_I_ROOT()
{
  local user=$(whoami)

  case $user in
  root) return 0 ;;
  *) return 1 ;;
  esac
}

# void: Get the root manager name.
#       If no root manager is found, "sh -c" will be used.
#       Therefore the user will need to insert the password for every
#         root dependable command.
GET_ROOT_MANAGER()
{
  if type sudo &>/dev/null; then ROOT="sudo"
  elif type doas &>/dev/null; then ROOT="doas"
  else ROOT="su -c"
  fi
}

MAKE_PACKAGES()
{
  if ! ls .config
    then if type dpkg &>/dev/null
      then cp -v /boot/config-${OLD_VERSION} .config
    else zcat -v /proc/config > .config
    fi
  fi

  make olddefconfig
  make -j${CORE}
  make -j${CORE} modules
  make -j${CORE} headers
  make -j${CORE} bzImage
}

# Mostly used in Debian-based distributions
AUTOMATED_INSTALL()
{
  ${ROOT} make modules_install
  ${ROOT} make headers_install
  ${ROOT} make install
  ${ROOT} update-initramfs -u
}

MANUAL_INSTALL()
{
  ${ROOT} make modules_install
  ${ROOT} make headers_install
  VERSION=$(ls /lib/modules | grep "${VERSION}" | sort --reverse - | head -n 1)
  ${ROOT} cp -v arch/x86/boot/bzImage /boot/vmlinuz-linux-${VERSION}
  ${ROOT} mkinitcpio -k ${VERSION} -g /boot/initramfs-linux-${VERSION}.img
  ${ROOT} cp -v System.map /boot/System.map-${VERSION}
  ${ROOT} ln -sfv /boot/System.map-${VERSION} /boot/System.map
  ${ROOT} cp -v .config /boot/config-${VERSION}
}

# Check about root
if ! AM_I_ROOT
  then
    printf "${YELLOW}""Warning: Script running without root privileges. If no recognized root manager is found, the script will use \"su -c\" instead...""${RESET_COLOUR}""\n"
    GET_ROOT_MANAGER
fi


# Making sure you own every file in the kernel
${ROOT} chown -R ${CURRENT_USER}:${CURRENT_USER} ./*

# Start building
MAKE_PACKAGES

# Installing the kernel
if type dpkg &>/dev/null
  then AUTOMATED_INSTALL
  else MANUAL_INSTALL
fi

# Prompt to remove old kernel
read -p "Remove the ${OLD_VERSION} kernel? [N/y] " REMOVE_KERNEL
case ${REMOVE_KERNEL} in
  "Y"|"y"|"Yes"|"yes")
    ${ROOT} rm -fv /boot/*${OLD_VERSION}*
    ${ROOT} rm -rfv /lib/modules/*${OLD_VERSION}*
    ${ROOT} rm -fv /etc/mkinitcpio.d/*${OLD_VERSION}*
    printf "${YELLOW}""Warning: ${OLD_VERSION} kernel has been removed.""${RESET_COLOUR}""\n"
    ;;
  *)
    printf "${YELLOW}""Warning: ${OLD_VERSION} kernel will be skipped.""${RESET_COLOUR}""\n"
    ;;
esac
printf "\n"

# Finish installation and prompt reboot
if type dpkg &>/dev/null
  then ${ROOT} update-grub
  else ${ROOT} grub-mkconfig -o /boot/grub/grub.cfg
fi

printf "Reboot in order to apply the changes.\n"

#!/bin/bash

# New version of cleaner_script
# Made by @fernandomaroto and @manuel
# Modified by Anil404 for ArcticOS
# Any failed command will just be skiped, error message may pop up but won't crash the install process
# Net-install creates the file /tmp/run_once in live environment (need to be transfered to installed system) so it can be used to detect install option

# Get new user's username
NEW_USER=`cat /etc/passwd | grep "/home" | cut -d: -f1 | head -1`
echo "[+] New User -- ${NEW_USER}"

_check_internet_connection(){
    #ping -c 1 8.8.8.8 >& /dev/null   # ping Google's address
    curl --silent --connect-timeout 8 https://8.8.8.8 > /dev/null
}

_is_pkg_installed() {
    # returns 0 if given package name is installed, otherwise 1
    local pkgname="$1"
    pacman -Q "$pkgname" >& /dev/null
}

_remove_a_pkg() {
    local pkgname="$1"
    pacman -Rsn --noconfirm "$pkgname"
    echo "[+] Removed ${pkgname}"
}

_remove_pkgs_if_installed() {
    # removes given package(s) and possible dependencies if the package(s) are currently installed
    local pkgname
    for pkgname in "$@" ; do
        _is_pkg_installed "$pkgname" && _remove_a_pkg "$pkgname" && echo "[+] Removed ${pkgname}"
    done
}

_pacman_update() {
    pacman -Sy
}

## -------- Remove VM Drivers --------------------

_vbox(){

    # Detects if running in vbox
    # packages must be in this order otherwise guest-utils pulls dkms, which takes longer to be installed
    local _vbox_guest_packages=(
        # virtualbox-guest-dkms
        virtualbox-guest-utils
    )
    local pkg

    if [[ $(systemd-detect-virt --vm) != "oracle" ]]
    then
        echo "[+] Detected virtual box"
        # If using net-install detect VBox and install the packages
        for pkg in ${_vbox_guest_packages[@]} ; do
            _is_pkg_installed "$pkg" && pacman -Rnsdd "$pkg" --noconfirm
        done
        #rm -f /usr/lib/modules-load.d/virtualbox-guest-dkms.conf   # not nedded
    fi
}

_vmware() {
    local vmware_guest_packages=(
        open-vm-tools
        xf86-input-vmmouse
        xf86-video-vmware
    )
    local pkg

    if [[ $(systemd-detect-virt --vm) != "vmware" ]]
    then
        echo "[+] Detected VMware"
        for pkg in "${vmware_guest_packages[@]}" ; do
            _is_pkg_installed "$pkg" && pacman -Rnsdd "$xx" --noconfirm
        done
    fi
}


_qemu() {
    local qemu_packages=(
        qemu-guest-agent
    )
    local pkg
    if [[ $(systemd-detect-virt --vm) != "qemu" ]]
    then
        echo "[+] Detected qemu"
        for pkg in "${qemu_packages[@]}" ; do
            _is_pkg_installed "$pkg" && pacman -Rnsdd "$pkg" --noconfirm
        done
    fi
}

_clean_target_system(){

    local _files_to_remove=(
        /etc/sudoers.d/g_wheel
        /etc/systemd/system/{etc-pacman.d-gnupg.mount,getty@tty1.service.d}
        /etc/systemd/scripts/choose-mirror
        /etc/systemd/system/getty@tty1.service.d/autologin.conf
        /root/{.automated_script.sh,.zlogin}
        /etc/mkinitcpio-archiso.conf
        /etc/{group-,gshadow-,passwd-,shadow-}
        /etc/initcpio
        /etc/udev/rules.d/81-dhcpcd.rules
        /home/$NEW_USER/.config/qt5ct
        /home/$NEW_USER/{.xinitrc,.xsession,.xprofile,.wget-hsts,.screenrc,.zshrc,.ICEauthority}
        /root/{.xinitrc,.xsession,.xprofile}
        /etc/skel/{.xinitrc,.xsession,.xprofile}
        /etc/motd
        /usr/local/bin/{Installation_guide}
        /{gpg.conf,gpg-agent.conf,pubring.gpg,secring.gpg}
    )

    local xx

    for xx in ${_files_to_remove[*]}; do rm -rf $xx; done

    find /usr/lib/initcpio -name archiso* -type f -exec rm '{}' \;

}

_manage_systemd_services(){
    local _systemd_enable=(NetworkManager cups avahi-daemon systemd-timesyncd)
    local _systemd_disable=()
    local srv

    for srv in ${_systemd_enable[*]};  do systemctl enable  -f $srv; done
    for srv in ${_systemd_disable[*]}; do systemctl disable -f $srv; done
}

_os_lsb_release(){

    # Check if offline is still copying the files, sed is the way to go!
    # same as os-release hook
    sed -i -e s'|^NAME=.*$|NAME=\"ArcticOS\"|' -e s'|^PRETTY_NAME=.*$|PRETTY_NAME=\"ArcticOS\"|' -e s'|^HOME_URL=.*$|HOME_URL=\"https://arcticos.com\"|' -e s'|^DOCUMENTATION_URL=.*$|DOCUMENTATION_URL=\"https://arcticos.com/wiki/\"|' -e s'|^SUPPORT_URL=.*$|SUPPORT_URL=\"https://forum.arcticos.com\"|' -e s'|^BUG_REPORT_URL=.*$|BUG_REPORT_URL=\"https://github.com/arctic-os\"|' -e s'|^LOGO=.*$|LOGO=arcticos|' /usr/lib/os-release

    # same as lsb-release hook
    sed -i -e s'|^DISTRIB_ID=.*$|DISTRIB_ID=ArcticOS|' -e s'|^DISTRIB_DESCRIPTION=.*$|DISTRIB_DESCRIPTION=\"ArcticOS Linux\"|' /etc/lsb-release

}

_remove_ucode(){
    local ucode="$1"
    pacman -Q $ucode >& /dev/null && {
        pacman -Rsn $ucode --noconfirm >/dev/null
    }
}

_remove_other_graphics_drivers() {
    local graphics="$(lspci -mm | awk -F '\"|\" \"|\\(' \ '/"Display|"3D|"VGA/ {a[$0] = $1 " " $3 " " $4}END {for(i in a) {if(!seen[a[i]]++) print a[i]}}')"
    local amd=no

    echo "[+] local variable graphics value is ${graphics}"
    # remove Intel graphics driver if it is not needed
    if [ -z "$(echo "$graphics" | grep "Intel Corporation")" ] ; then
        echo "[+] Didn't Detected intel Graphics"
        _remove_pkgs_if_installed xf86-video-intel
    fi

    # remove AMD graphics driver if it is not needed
    if [ -n "$(echo "$graphics" | grep "Advanced Micro Devices")" ] ; then
        amd=yes
    elif [ -n "$(echo "$graphics" | grep "AMD/ATI")" ] ; then
        amd=yes
    elif [ -n "$(echo "$graphics" | grep "Radeon")" ] ; then
        amd=yes
    fi
    if [ "$amd" = "no" ] ; then
        echo "[+] Didn't Detected amd Graphics"
        _remove_pkgs_if_installed xf86-video-amdgpu xf86-video-ati
    fi
}

_remove_broadcom_wifi_driver() {
    local pkgname=broadcom-wl-dkms
    local wifi_pci
    local wifi_driver

    _is_pkg_installed $pkgname && {
        wifi_pci="$(lspci -k | grep -A4 " Network controller: ")"
        if [ -n "$(lsusb | grep " Broadcom ")" ] || [ -n "$(echo "$wifi_pci" | grep " Broadcom ")" ] ; then
            return
        fi
        wifi_driver="$(echo "$wifi_pci" | grep "Kernel driver in use")"
        if [ -n "$(echo "$wifi_driver" | grep "in use: wl$")" ] ; then
            return
        fi
        _remove_a_pkg $pkgname
    }
}

# Remove un-wanted ucode package
_remove_unwanted_ucode() {
	cpu="`grep -w "^vendor_id" /proc/cpuinfo | head -n 1 | awk '{print $3}'`"

	case "$cpu" in
		GenuineIntel)	echo "+---------------------->>" && echo "[*] Removing amd-ucode from target system..."
						_remove_pkgs_if_installed amd-ucode
						;;
		*)            	echo "+---------------------->>" && echo "[*] Removing intel-ucode from target system..."
						_remove_pkgs_if_installed intel-ucode
						;;
	esac
}


#####################################
######### SCRIPT STARTS HERE ########
#####################################

_manage_systemd_services
_os_lsb_release
_vbox
_vmware
_qemu
_remove_other_graphics_drivers
_remove_unwanted_ucode
_clean_target_system

rm -rf /usr/bin/{post_install.sh,chroo_post_install.sh}

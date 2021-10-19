#!/bin/bash

# Modified by Anil404 for ArcticOS
# Adapted from AIS. An excellent bit of code!

if [ -f /tmp/chrootpath.txt ]
then
    chroot_path=$(cat /tmp/chrootpath.txt |sed 's/\/tmp\///')
else
    chroot_path=$(lsblk |grep "calamares-root" |awk '{ print $NF }' |sed -e 's/\/tmp\///' -e 's/\/.*$//' |tail -n1)
fi

if [ -z "$chroot_path" ] ; then
    echo "[!] Fatal error: `basename $0`: chroot_path is empty!"
fi


arch_chroot(){
# Use chroot not arch-chroot because of the way calamares mounts partitions
    chroot /tmp/$chroot_path /bin/bash -c "${1}"
}


## Detect drivers in use in live session
gpu_file="$chroot_path"/var/log/gpu-card-info.bash

_detect_vga_drivers() {
    local card=no
    local driver=no

    if [[ -n "`lspci -k | grep -P 'VGA|3D|Display' | grep -w "${2}"`" ]]; then
        card=yes
        if [[ -n "`lsmod | grep -w ${3}`" ]]; then
			driver=yes
		fi
        if [[ -n "`lspci -k | grep -wA2 "${2}" | grep 'Kernel driver in use: ${3}'`" ]]; then
			driver=yes
		fi
    fi
    echo "${1}_card=$card"     >> ${gpu_file}
    echo "${1}_driver=$driver" >> ${gpu_file}
}

echo "+---------------------->>"
echo "[*] Detecting GPU card & drivers used in live session..."

# Detect AMD
_detect_vga_drivers 'amd' 'AMD' 'amdgpu'

# Detect Intel
_detect_vga_drivers 'intel' 'Intel Corporation' 'i915'

# Detect Nvidia
_detect_vga_drivers 'nvidia' 'NVIDIA' 'nvidia'

# For logs
echo "+---------------------->>"
echo "[*] Content of $gpu_file :"
cat ${gpu_file}

##--------------------------------------------------------------------------------


## Run the final Script inside calamares chroot (target system)
if [[ `pidof calamares` ]]
then
    echo "+-------------------------->>"
    echo "[+] Running chroot post installation script in target system..."

    # For chrooted commands edit the script bellow directly
    arch_chroot "/usr/bin/chroot_post_install.sh"
fi


#!/usr/bin/env bash

PKGDIR="$(pwd)/chaotic"

## Script Termination
exit_on_signal_SIGINT () {
    { printf "\n\n%s\n" "Script interrupted." 2>&1; echo; }
    exit 0
}

exit_on_signal_SIGTERM () {
    { printf "\n\n%s\n" "Script terminated." 2>&1; echo; }
    exit 0
}

trap exit_on_signal_SIGINT SIGINT
trap exit_on_signal_SIGTERM SIGTERM

# Get Chaotic Packages

if [[ ! -d "$PKGDIR" ]]; then
    mkdir -p "$PKGDIR"
fi

echo -e "\nDownloading chaotic Packages\n"
cd "$PKGDIR" && wget 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

echo "Packages Downloaded"

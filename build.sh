#!/usr/bin/env bash


rm -rf packages 2>/dev/null

DIR="$(pwd)"
PKGS=(`ls -d */ | cut -f1 -d'/'`)
PKGDIR="$DIR/packages"

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

# Build packages
build_pkgs () {
	local pkg
        RDIR=$1

	if [[ ! -d "$PKGDIR" ]]; then
		mkdir -p "$PKGDIR"
	fi

	echo -e "\nBuilding Packages - \n"
	for pkg in "${PKGS[@]}"; do
		echo -e "Building ${pkg}..."
		cd ${pkg} && updpkgsums && makechrootpkg -c -r $CHROOT && mv *.pkg.tar.zst "$PKGDIR"


		# Verify
		while true; do
			set -- "$PKGDIR"/${pkg}-*
			if [[ -e "$1" ]]; then
				echo -e "\nPackage '${pkg}' generated successfully.\n"
				break
			else
				echo -e "\nFailed to build '${pkg}', Exiting...\n"
				exit 1;
			fi
		done
		cd "$DIR"
	done

	if [[ -d "$RDIR" ]]; then
		mv -f "$PKGDIR"/*.pkg.tar.zst "$RDIR" && rm -r "$PKGDIR"
		echo -e "Packages moved to Repository.\n[!] Don't forget to update the database.\n"
        else
                echo $RDIR
                exit 1
	fi
}


if (( $# < 1 ))
then
  echo "Usage: $0 Repository Path"
  exit 1
fi

build_pkgs $1

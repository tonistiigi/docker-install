#!/bin/sh

# This script is meant for quick & easy install via:
#   $ curl -fsSL https://rootless.docker.com -o get-docker.sh
#   $ sh get-docker.sh
#
# NOTE: Make sure to verify the contents of the script
#       you downloaded matches the contents of install.sh
#       located at https://github.com/docker/docker-install
#       before executing.
#
# Git commit from https://github.com/docker/docker-install when
# the script was uploaded (Should only be modified by upload job):
SCRIPT_COMMIT_SHA=UNKNOWN

# This script should be run with an unprivileged user and install/setup Docker under $HOME/bin/.


# TODO:

BIN="$HOME/bin"
DAEMON=dockerd

checks() {
	# OS verification: Linux only, point osx/win to helpful locations
	case "$(uname)" in
	Linux)
		;;
	*)
		>&2 echo "Rootless Docker cannot be installed on $(uname)"; exit 1
		;;
	esac

	# User verification: deny running as root (unless forced?)
	if [ "$(id -u)" = "0" ]; then
		>&2 echo "Refusing to install rootless Docker as the root user"; exit 1
	fi

	# HOME verification
	if [ ! -d "$HOME" ]; then
		>&2 echo "Aborting because HOME directory $HOME does not exist"; exit 1
	fi

	# Already installed verification (unless force?). Only having docker cli binary previously shouldn't fail the build.
	if [ -f "$BIN/$DAEMON" ]; then
		# If rootless installation is detected print out the modified PATH and DOCKER_HOST that needs to be set.
		echo "# Existing rootless Docker detected at $BIN/$DAEMON"
		if [ "$(which $DAEMON)" != "$BIN/$DAEMON" ]; then
			echo "PATH=$BIN:$PATH"
		fi
		echo "DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock"
		exit 0
	fi

	# Existing rootful docker verification
	ROOTFUL="$(which $DAEMON)"
	#if [ -n "$ROOTFUL" ]; then
	#	UID=$(ls -lnd "$ROOTFUL" | cut -d' ' -f4)
	#	if [ "$UID" = "0" ]; then
	#		>&2 echo "Existing rootful Docker detected"
	#		exit 1
	#	fi
	#fi

	# Verify kernel
	# Verify newuidmap/newgidmap
	# Verify /etc/subuid
	# Verify /proc/sys/kernel/unprivileged_userns_clone

	# On errors print the commands that user needs to run (ideally together). The commands need to be run with sudo.
}

do_install() {
	checks
	set -e


	tmp=$(mktemp -d)
	trap "rm -rf $tmp" EXIT
	# TODO: Find latest nightly release from https://download.docker.com/linux/static/nightly/ . Later we can provide different channels.
	# Test locations:
	STATIC_RELEASE_URL="https://www.dropbox.com/s/tczf5n5m7v1ku2k/docker-0.0.0-20190205170806-273aef0a90.tgz"
	STATIC_RELEASE_ROOTLESS_URL="https://www.dropbox.com/s/gkvw3gxwlpnxl6f/docker-rootless-extras-0.0.0-20190205170806-273aef0a90.tgz"

	# Download tarballs docker-* and docker-rootless-extras=*
	(
		cd "$tmp"
		curl -sSL -o docker.tgz "$STATIC_RELEASE_URL"
		curl -sSL -o rootless.tgz "$STATIC_RELEASE_ROOTLESS_URL"
	)
	# Extract under $HOME/bin/
	(
		mkdir -p "$BIN"
		cd "$BIN"
		tar zxf "$tmp/docker.tgz"
		tar zxf "$tmp/rootless.tgz"
	)


# If user has systemd setup a `docker.service` with `systemctl --user` and start it.
# If not then print the command for launching the daemon and putting it on background.
# Test that the daemon works with `docker info`

# If $HOME/bin is not in PATH print out command for changing it.
# Print out instructions for $DOCKER_HOST and recommendation for adding it to bashrc
# Print out the location for storage/graphdriver that is being used

	echo "not implemented yet"
	exit 1
}

do_install

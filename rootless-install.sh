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

init_vars() {
	BIN="$HOME/bin"
	DAEMON=dockerd
	driver="vfs"
	if lsb_release -ds | grep -qi ubuntu 2>&1 2>/dev/null; then
		driver="overlay2"
	fi
	SYSTEMD="$(which systemd 2>&1 2>/dev/null)"
}

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

	if [ -d "$BIN" ]; then
		if [ ! -w "$BIN" ]; then
			>&2 echo "Aborting because $BIN is not writable"; exit 1
		fi
	else
		if [ ! -w "$HOME" ]; then
			>&2 echo "Aborting because HOME (\"$HOME\") is not writable"; exit 1
		fi
	fi

	# Existing rootful docker verification
	if [ -w /var/run/docker.sock ]; then
		>&2 echo "Aborting because rootful Docker is running and accessible"; exit 1
	fi


	if [ ! -w "$XDG_RUNTIME_DIR" ]; then
		if [ -n "$SYSTEMD" ]; then
			>&2 echo "Aborting because systemd was detected but XDG_RUNTIME_DIR (\"$XDG_RUNTIME_DIR\") does not exist or is not writable"
			>&2 echo "Hint: this could happen if you changed users with 'su' or 'sudo'. To work around this:"
			>&2 echo "- try again by first running with root privileges 'loginctl enable-linger <user>' where <user> is the unprivileged user and export XDG_RUNTIME_DIR to the value of RuntimePath as shown by 'loginctl show-user <user>'"
			>&2 echo "- or simply log back in as the desired unprivileged user (ssh works for remote machines)"
			exit 1
		fi
		export XDG_RUNTIME_DIR="/tmp/docker-rootless-$(id -u)"
		mkdir -p "$XDG_RUNTIME_DIR"
	fi

	# Already installed verification (unless force?). Only having docker cli binary previously shouldn't fail the build.
	if [ -x "$BIN/$DAEMON" ]; then
		# If rootless installation is detected print out the modified PATH and DOCKER_HOST that needs to be set.
		echo "# Existing rootless Docker detected at $BIN/$DAEMON"
		print_instructions
	fi



	# Verify kernel
	# Verify newuidmap/newgidmap
	# Verify /etc/subuid
	# Verify /proc/sys/kernel/unprivileged_userns_clone
	

# cat <<EOF | sudo sh -x
# 	cat <<EOT > /etc/sysctl.d/50-rootless.conf
# 	kernel.unprivileged_userns_clone = 1
# EOT
# 	sysctl --system
# EOF

	# On errors print the commands that user needs to run (ideally together). The commands need to be run with sudo.
}

start_docker() {
	if [ -z "$SYSTEMD" ]; then
		start_docker_nonsystemd
		return
	fi
	
	mkdir -p $HOME/.config/systemd/user
	
	if [ ! -f $HOME/.config/systemd/user/docker.service ]; then
		cat <<EOT > $HOME/.config/systemd/user/docker.service
[Unit]
Description=Docker Application Container Engine (Rootless)
Documentation=https://docs.docker.com

[Service]
Environment=PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$HOME/bin/dockerd-rootless.sh --experimental --iptables=false --storage-driver $driver
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes

[Install]
WantedBy=default.target
EOT
	systemctl --user daemon-reload
	fi
	if ! systemctl --user status docker 2>&1 >/dev/null; then
		echo "# starting systemd service"
		systemctl --user start docker
	fi
	systemctl --user status docker
}

service_instructions() {
	if [ -z "$SYSTEMD" ]; then
		return
	fi
	cat <<EOT
#
# To control docker service run:
# systemctl --user (start|stop|restart) docker
#
EOT
}


start_docker_nonsystemd() {
	echo <<EOT
# systemd not detected, dockerd daemon needs to be started manually
#
$BIN/dockerd-rootless.sh --experimental --iptables=false --storage-driver $driver
#
EOT
}

print_instructions() {
	echo "# Docker binaries are installed in $BIN"
	if [ "$(which $DAEMON)" != "$BIN/$DAEMON" ]; then
		echo "# WARN: dockerd is not in your current PATH or pointing to $BIN/$DAEMON"
	fi
	echo "# Please make sure following environment variables are set (or put them to ~/.bashrc):\n"
	
	case :$PATH: in
	*:$BIN:*) ;;
		    *) echo "export PATH=$BIN:\$PATH" ;;
	esac

	echo "export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock"
	echo
	service_instructions
	exit 0
}

do_install() {
	init_vars
	checks

	set -e
	tmp=$(mktemp -d)
	trap "rm -rf $tmp" EXIT INT TERM
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
		tar zxf "$tmp/docker.tgz" --strip-components=1
		tar zxf "$tmp/rootless.tgz" --strip-components=1
	)

	start_docker

# If user has systemd setup a `docker.service` with `systemctl --user` and start it.
# If not then print the command for launching the daemon and putting it on background.
# Test that the daemon works with `docker info`

	docker info

# If $HOME/bin is not in PATH print out command for changing it.
# Print out instructions for $DOCKER_HOST and recommendation for adding it to bashrc
# Print out the location for storage/graphdriver that is being used

	print_instructions
}

do_install

#!/bin/sh
# Luke's Auto Rice Boostrapping Script (YARBS)
# by Luke Smith <luke@lukesmith.xyz>
# and edited by yurisuki <yurisuki@waifu.club>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":a:r:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	p) progsfile=${OPTARG} ;;
	d) yuridot=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

# DEFAULTS:
[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/lukesmithxyz/voidrice.git"
[ -z "$yuridot" ] && yuridot="https://github.com/yurisuki/yuririce.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/yurisuki/YARBS/master/voidlinux/yurgs.csv"

### FUNCTIONS ###

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Welcome to Luke's Auto-Rice Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured i3wm Void Linux desktop, which I use as my main machine.\\n\\n-Luke\\n\\nBut then it continues and downloads my dotfiles and needed progs\\n\\n-yuri" 16 60
	}
getuser() { \
	name=$(dialog --inputbox "First, please enter a name for the user account for which you'd like to install YARBS." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	! (id -u "$name" >/dev/null) 2>&1 &&
		dialog --title "Create user first then re-run script" --msgbox "Please create your user and password before running YARBS. Note that you can use the user you created in the Void Linux installation process.\\n\\nIf you want to make a new user, you will want to run a command like this, adding your user to all the needed groups and creating a home directory:\\n\\n$ useradd -m -G wheel,users,audio,video,cdrom,input -s /bin/bash <user>\\n$ passwd <user>" 14 75 && exit
	return 0 ;}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
	}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#YARBS/d" /etc/sudoers
	echo "$* #YARBS" >> /etc/sudoers ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "YARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	xbps-install -y "$1" >/dev/null 2>&1
	}

gitmakeinstall() {
	dir=$(mktemp -d)
	dialog --title "YARBS Installation" --infobox "Installing \`$(basename "$1")\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	git clone --depth 1 "$1" "$dir" >/dev/null 2>&1
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}

npminstall() { \
	dialog --title "YARBS Installation" --infobox "Installing the npm package \`$1\` ($n of $total). $1 $2" 5 70
	command -v npm || xbps-install nodejs >/dev/null 2>&1
	npm install "$1"
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"") maininstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"N") npminstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}

putgitrepo() { # Downlods a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 60
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2" && chown -R "$name:wheel" "$2"
	chown -R "$name:wheel" "$dir"
	sudo -u "$name" git clone --depth 1 "$1" "$dir/gitrepo" >/dev/null 2>&1 &&
	sudo -u "$name" cp -rfT "$dir/gitrepo" "$2"
	}

serviceinit() { for service in "$@"; do
	dialog --infobox "Enabling \"$service\"..." 4 40
	ln -s "/etc/sv/$service" /var/service/
	sv start "$service"
	done ;}

systembeepoff() { dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

resetlock() { # Refresh lock picture for betterlockscreen
	dialog --infobox "Refreshing lock screen picture..." 4 50
	sudo -u "$name" betterlockscreen -u /home/$name/.config/walllock.png >/dev/null
}

ryu-login() { # Download and install xer0's login art
	dialog --infobox "Downloading ryu-login art..." 4 35
	curl -s https://raw.githubusercontent.com/xero/dotfiles/master/ryu-login/etc/issue >/etc/issue
}

figlet() { # Download and install some figlet fonts.
	dialog --infobox "Downloading some figlet fonts..." 4 40
	rm -rf figlet-fonts >/dev/null 2>&1
	git clone https://github.com/xero/figlet-fonts.git >/dev/null 2>&1
	cp figlet-fonts/* /usr/share/figlet/. >/dev/null 2>&1
	mv -f figlet-fonts/* /usr/share/figlet/fonts/. >/dev/null 2>&1
}

vim() { # Install vim `plugged` plugins.
	dialog --infobox "Downloading vim \`plugged\` plugins..." 4 50
	sudo -u "$name" mkdir -p "/home/$name/.config/nvim/autoload"
	curl "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" > "/home/$name/.config/nvim/autoload/plug.vim"
	dialog --infobox "Installing (neo)vim plugins..." 4 50
	(sleep 30 && killall nvim) &
	sudo -u "$name" nvim -E -c "PlugUpdate|visual|q|q" >/dev/null 2>&1
}

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Luke" 12 80
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
xbps-install -Syu dialog

# Welcome user.
welcomemsg || error "User exited."

# Get and verify username and password.
getuser || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

dialog --title "YARBS Installation" --infobox "Installing all needed packages." 5 70
xbps-install -y curl base-devel git libXinerama-devel libX11 libX11-devel libXft libXft-devel fontconfig fontconfig-devel void-repo-nonfree >/dev/null 2>&1

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name"
putgitrepo "$yuridot" "/home/$name"
rm -f "/home/$name/README.md" "/home/$name/click.png"

# Pulseaudio, if/when initially installed, often needs a restart to work immediately.
[ -f /usr/bin/pulseaudio ] && resetpulse

# Refresh lock screen picture, so you can lock the screen.
resetlock || error "Failed to refresh lock screen picture."

# Download ryu-login made by xero and install it.
ryu-login

# Download some figlet fonts and install them.
figlet

# Install vim `plugged` plugins.
vim

# Enable services here..
serviceinit NetworkManager dbus pulseaudio

# Most important command! Get rid of the beep!
systembeepoff

# This line, overwriting the `newperms` command above will allow the user to run
# all commands without the password prompt
newperms "%wheel ALL=(ALL) NOPASSWD:ALL"

# Last message! Install complete!
finalize
clear

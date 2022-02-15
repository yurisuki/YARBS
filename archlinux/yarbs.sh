#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# and edited by yurisuki <adam@adamnvrtil.fun>
# License: GNU GPLv3

# DEFAULTS:
#[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/lukesmithxyz/voidrice.git"
[ -z "$yuridot" ] && yuridot="https://github.com/yurisuki/yuririce.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/yurisuki/YARBS/master/archlinux/yurgs.csv"
[ -z "$aurhelper" ] && aurhelper="trizen"
[ -z "$shell" ] && shell="zsh"

### FUNCTIONS ###

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Welcome to Luke's Auto-Rice Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured i3wm Arch Linux desktop, which I use as my main machine.\\n\\n-Luke\\n\\nBut then it continues and downloads my dotfiles and needed progs\\n\\n-yuri" 16 60
	}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. YARBS can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nYARBS will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that YARBS will change $name's password to the one you just gave." 14 70
	}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

refreshkeys() { \
	dialog --infobox "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
	}

installshell() { \
	dialog --infobox "Installing $shell shell..." 4 30
	pacman --noconfirm -S --needed "$shell" >/dev/null 2>&1
	}

newperms() { # Set special sudoers settings for install (or after).
	# Basic sudo
	sed -i "/#YARBS/d" /etc/sudoers
	echo "$* #YARBS" >> /etc/sudoers

	# doas
	mkdir /usr/etc
	! [ -f "/usr/etc/doas.conf" ] && ln -sf /etc/doas.conf /usr/etc/doas.conf
	echo "permit nopass $name as root #YARBS" >> /etc/doas.conf ;}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "YARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
	}

mainuninstall() { # Removes needed programs from local system.
	dialog --title "YARBS Installation" --infobox "Uninstalling \`$1\` ($n of $total). $1 $2" 5 70
	pacman --noconfirm --needed -R "$1" >/dev/null 2>&1
	}

gitmakeinstall() {
	dir=$(mktemp -d)
	dialog --title "YARBS Installation" --infobox "Installing \`$(basename "$1")\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	git clone --depth 1 "$1" "$dir" >/dev/null 2>&1
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}

aurinstall() { \
	dialog --title "YARBS Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep "^$1$" >/dev/null 2>&1 && return
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	}

pipinstall() { \
	dialog --title "YARBS Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || pacman -S --noconfirm --needed python-pip >/dev/null 2>&1
	yes | pip install "$1"
	}

npminstall() { \
	dialog --title "YARBS Installation" --infobox "Installing the node.js package \`$1\` ($n of $total). $1 $2" 5 70
	command -v npm || pacman -S --noconfirm --needed npm >/dev/null 2>&1
	yes | npm install -g "$1" >/dev/null 2>&1
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qm | awk '{print $1}')
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"") maininstall "$program" "$comment" ;;
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			"N") npminstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}

fontinstall() { # Downloads some fonts.
	fonts="ttf-anonymous-pro
	ttf-bitstream-vera
	ttf-dejavu
	ttf-droid
	ttf-gentium
	ttf-liberation
	ttf-ubuntu-font-family
	noto-fonts" && echo "$fonts" > /tmp/fonts
	totalfonts=$(wc -l < /tmp/fonts)
	fontsn=1
	for currentfont in $(cat /tmp/fonts); do
		dialog --title "YARBS Installation" --infobox "Installing font \`$currentfont\` ($fontsn of $totalfonts)." 4 70
		fontsn=$((fontsn+1))
		pacman -S "$currentfont" --noconfirm --needed >/dev/null 2>&1;
	done ;}

putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 60
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2" && chown -R "$name:wheel" "$2"
	chown -R "$name:wheel" "$dir"
	sudo -u "$name" git clone --depth 1 "$1" "$dir/gitrepo" >/dev/null 2>&1 &&
	sudo -u "$name" cp -rfT "$dir/gitrepo" "$2"
	}

serviceinit() { for service in "$@"; do
	dialog --infobox "Enabling \"$service\"..." 4 40
	systemctl enable "$service"
	systemctl start "$service"
	done ;}


pipeenable() { # Enable and start pipewire.
	dialog --infobox "Enabling pipewire..." 4 50
	sudo -u "$name" systemctl enable --user --now pipewire pipewire-pulse >/dev/null 2>&1
}
systembeepoff() { dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

figlet() { # Download and install some figlet fonts.
	dialog --infobox "Downloading some figlet fonts..." 4 40
	rm -rf figlet-fonts >/dev/null 2>&1
	git clone https://github.com/xero/figlet-fonts.git >/dev/null 2>&1
	cp figlet-fonts/* /usr/share/figlet/. >/dev/null 2>&1
	mv -f figlet-fonts/* /usr/share/figlet/fonts/. >/dev/null 2>&1
}

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Luke" 12 80
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
pacman -Syu --noconfirm --needed dialog ||  error "Are you sure you're running this as the root user? Are you sure you're using an Arch-based distro? ;-) Are you sure you have an internet connection? Are you sure your Arch keyring is updated?"

# Welcome user.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

adduserandpass || error "Error adding username and/or password."

# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."

dialog --title "YARBS Installation" --infobox "Installing \`basedevel\` and \`git\` for installing other software." 5 70
pacman --noconfirm --needed -S base-devel git >/dev/null 2>&1
[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman and trizencolorful and adds eye candy on the progress bar because why not.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

manualinstall $aurhelper || error "Failed to install AUR helper."

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the fonts
fontinstall

# Install the shell
installshell

# Install the dotfiles in the user's home directory
#putgitrepo "$dotfilesrepo" "/home/$name"
putgitrepo "$yuridot" "/home/$name"
rm -f "/home/$name/README.md" "/home/$name/click.png" "/home/$name/LICENSE"

# Download some figlet fonts and install them.
figlet

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# Enable services here.
serviceinit NetworkManager cronie

# Enable pipewire.
pipeenable

# Most important command! Get rid of the beep!
systembeepoff

# Make zsh the default shell for the user.
command -v zsh || pacman -S --noconfirm --needed zsh >/dev/null 2>&1
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# This line, overwriting the `newperms` command above will allow the user to run
# all commands without the password prompt
newperms "%wheel ALL=(ALL) NOPASSWD:ALL"

# Last message! Install complete!
finalize
clear

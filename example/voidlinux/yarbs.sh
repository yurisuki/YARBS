#!/bin/sh
# TEMPLATE
# Luke's Auto Rice Boostrapping Script (YARBS)
# by Luke Smith <luke@lukesmith.xyz>
# and edited by yurisuki <adam@adamnvrtil.fun>
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
# Here you add your dotfiles' link to GitHub repository (cloning URL) as a variable.
[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/lukesmithxyz/voidrice.git"
[ -z "$yuridot" ] && yuridot="https://github.com/yurisuki/yuririce.git"
# Here you add link to your programs you want to have installed by YARBS.
# See `yurgs.csv` as a example and upload it somewhere and take its raw link and put it here.
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/yurisuki/YARBS/master/voidlinux/yurgs.csv"

### FUNCTIONS ###

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	# You can change text inside quotes.
	dialog --title "Welcome!" --msgbox "This is template edition of YARBS. You can change this message inside these quotes." 16 60
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

###### Here you can create custom commands inside functions.
#### But don't forget to execute it later down.
### You can scroll down to see how to do it.

example-command() { # You can add some comment here.
dialog --title "Example" --msgbox "Hello" 5 50
} # Don't forget to close the function using curly brackets, otherwise whole script won't work.

kermit-login() { # Download and install Kermit login art...
	dialog --infobox "Downloading Kermit login art... <3" 4 35
	curl -s https://puu.sh/DJEJC/260246d0ad >/etc/issue
}

###### End of custom category.

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	dialog --title "All done!" --msgbox "All done. Insert some cool message." 12 80
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

# Here you can install some programs you'll use within installation.
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

#### Here you pull git repositories
### Format: putgitrepo "$variable" "DirectoryWhereYouWantToDeployThem"
## If you want to clone more than one repository, then use `putgitrepo` command multiple times.
# You can actually use an actual link instead of a variable.
putgitrepo "$dotfilesrepo" "/home/$name"
putgitrepo "$yuridot" "/home/$name"
# You can remove some junk (e.g. README)
rm -f "/home/$name/README.md" "/home/$name/click.png" "/home/$name/LICENSE"

# Pulseaudio, if/when initially installed, often needs a restart to work immediately.
[ -f /usr/bin/pulseaudio ] && resetpulse

### Custom category.

# Download Kermit login art and install it.
kermit-login

# Cool comment.
example-command || error "Command has failed for some stupid reason."
# In case you want to have error message, then do `command || error "Error message"`.

### End of custom category.

## Enable services here..
# You can enable some service which will be linked to that folder with all services.
serviceinit NetworkManager dbus pulseaudio

# Most important command! Get rid of the beep!
systembeepoff

# This line, overwriting the `newperms` command above will allow the user to run
# all commands without the password prompt
newperms "%wheel ALL=(ALL) NOPASSWD:ALL"

# Last message! Install complete!
finalize
clear

#!/bin/bash
	  
OSARCH=$(uname -m)
METABOX_DIR=/mb
METABOX_LOGS="$METABOX_DIR"/logs
METABOX_PANEL="$METABOX_DIR"/panel
METABOX_CACHE="$METABOX_DIR"/cache
METABOX_BUILD="$METABOX_DIR"/build
METABOX_MOUNTS="$METABOX_DIR"/mounts
METABOX_CONFIG="$METABOX_DIR"/config
METABOX_TRAKTARR="$METABOX_DIR"/traktarr
METABOX_IF=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
IP_ADDR=$(curl -s https://api.ipify.org)

	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	group_name="nogroup"
	add-apt-repository main 2>&1 >> /dev/null
	add-apt-repository universe 2>&1 >> /dev/null
	add-apt-repository restricted 2>&1 >> /dev/null
	add-apt-repository multiverse 2>&1 >> /dev/null

if [[ "$os" == "ubuntu" && "$os_version" -lt 1804 ]]; then
	echo "Ubuntu 18.04 or higher is required to use this installer. This version of Ubuntu is too old and unsupported."
	exit
fi
if [[ "$EUID" -ne 0 ]]; then
	echo "This installer needs to be run with superuser privileges."
	exit
fi
clear;
echo "Adding Repos"
echo "...... Docker Repo ....."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -;
sudo apt-key fingerprint 0EBFCD88;
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
echo "Updating OS (apt-get update)"
apt-get -qy update > /dev/null;
echo "Updating OS (apt-get upgrade)"
apt-get -qy upgrade > /dev/null;
echo "Installing Dependancies... "
apt-get -qy install htop iftop vnstat curl nano python3 python3-pip screen software-properties-common apt-transport-https ca-certificates git zip unzip dialog iotop ioping dsniff tcpdump lsb-release > /dev/null;
echo "Auto Remove non-required installs (apt-get autoremove)"
apt-get -qy autoremove > /dev/null;
echo "Set VNSTAT Default Interface to '"$METABOX_IF"'"
sed -i 's/eth0/$METABOX_IF/g' /etc/vnstat.conf;
echo "Install Docker"
apt-get -qy install docker-ce docker-ce-cli containerd.io > /dev/null;
echo "Set non-requirement of \"Sudo\" for docker commands"
sudo groupadd docker;
sudo usermod -aG docker $USER;
sudo usermod -aG www-data $USER;
sudo systemctl enable docker;

echo "Create metaBox Directories"
mkdir -p "$METABOX_CACHE"; 
echo "$METABOX_CACHE Created.."
mkdir -p "$METABOX_MOUNTS"; 
echo "$METABOX_MOUNTS Created.."
mkdir -p "$METABOX_DIR"; 
echo "$METABOX_DIR Created.."
mkdir -p "$METABOX_LOGS";
echo "$METABOX_LOGS Created.."
mkdir -p "$METABOX_PANEL";
echo "$METABOX_PANEL Created.."
echo "Pulling metaBox Panel from Repo"
git clone https://github.com/metabox-cloud/metabox-panel.git "$METABOX_PANEL";
mkdir -p "$METABOX_TRAKTARR";
echo "$METABOX_TRAKTARR Created.."
mkdir -p "$METABOX_TRAKTARR"/config;
echo "$METABOX_TRAKTARR/config Created.."
chown -R www-data:www-data /mb/traktarr/config;
echo "Setting Owner of $METABOX_TRAKTARR/config"
mkdir -p "$METABOX_TRAKTARR"/list;
echo "$METABOX_TRAKTARR/list Created.."
chown -R www-data:www-data /mb/traktarr/list;
echo "Setting Owner of $METABOX_TRAKTARR/list"
mkdir -p "$METABOX_CONFIG";
echo "$METABOX_CONFIG Created.."
echo "Install Traktarr"
sudo git clone https://github.com/l3uddz/traktarr "$METABOX_TRAKTARR"/app;
cd "$METABOX_TRAKTARR"/app;
python3 -m pip install -r requirements.txt
sudo ln -s "$METABOX_TRAKTARR"/app/traktarr.py /usr/local/bin/traktarr;
echo "Traktarr Installed - Edit Config/List's in the WebUI"

echo "Pull Container Setups :)"
git clone https://www.github.com/metabox-cloud/metabox-containers.git "$METABOX_CONFIG";
rm -rf "$METABOX_CONFIG"/LICENSE;
rm -rf "$METABOX_CONFIG"/README.md;

echo "Creating Default Docker Containers (Watchtower, Portainer, rClone)"
/usr/bin/docker create --name metaBox_Panel  --restart=always -v "$METABOX_DIR":/mb -v /var/run/docker.sock:/var/run/docker.sock -p 9999:9999 metaboxcloud/metabox.panel.docker:latest
echo "metaBox Panel Created"
/usr/bin/docker create --name Watchtower --restart=always -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower;
echo "Watchtower Created"
/usr/bin/docker create --name Portainer -p 9000:9000 --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v "$METABOX_CONFIG"/portainer:/data portainer/portainer-ce
echo "Portainer Created"
echo "Starting Containers"
/usr/bin/docker start $(docker ps -a -q)


echo "Pulling Docker Templates for rClone, this is only for testing.. because cbf"
/usr/bin/docker pull metaboxcloud/rclone-mega.docker
/usr/bin/docker pull metaboxcloud/rclone-gdrive.docker
INSTALLER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

echo "METABOX_WEBNAME=metaBox" > "$METABOX_CONFIG"/config.dat;
echo "METABOX_DIR=$METABOX_DIR" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_LOGS=$METABOX_DIR/logs" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_PANEL=$METABOX_DIR/panel" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_PANEL_TEMPLATES=$METABOX_DIR/panel/templates" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_PANEL_ASSETS=$METABOX_DIR/panel/assets" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_PANEL_INCLUDES=$METABOX_DIR/panel/includes" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_BUILD=$METABOX_DIR/build" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_CONFIG=$METABOX_DIR/config" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_TRAKTARR=$METABOX_DIR/traktarr" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_IF=$METABOX_IF" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_LANGUAGE=en" >> "$METABOX_CONFIG"/config.dat;
echo "METABOX_INSTALLER=$INSTALLER" >> "$METABOX_CONFIG"/config.dat;


clear
echo " ███▄ ▄███▓▓█████▄▄▄█████▓ ▄▄▄       ▄▄▄▄    ▒█████  ▒██   ██▒"
echo "▓██▒▀█▀ ██▒▓█   ▀▓  ██▒ ▓▒▒████▄    ▓█████▄ ▒██▒  ██▒▒▒ █ █ ▒░"
echo "▓██    ▓██░▒███  ▒ ▓██░ ▒░▒██  ▀█▄  ▒██▒ ▄██▒██░  ██▒░░  █   ░"
echo "▒██    ▒██ ▒▓█  ▄░ ▓██▓ ░ ░██▄▄▄▄██ ▒██░█▀  ▒██   ██░ ░ █ █ ▒ "
echo "▒██▒   ░██▒░▒████▒ ▒██▒ ░  ▓█   ▓██▒░▓█  ▀█▓░ ████▓▒░▒██▒ ▒██▒"
echo "░ ▒░   ░  ░░░ ▒░ ░ ▒ ░░    ▒▒   ▓▒█░░▒▓███▀▒░ ▒░▒░▒░ ▒▒ ░ ░▓ ░"
echo "░  ░      ░ ░ ░  ░   ░      ▒   ▒▒ ░▒░▒   ░   ░ ▒ ▒░ ░░   ░▒ ░"
echo "░      ░      ░    ░        ░   ▒    ░    ░ ░ ░ ░ ▒   ░    ░  "
echo "       ░      ░  ░              ░  ░ ░          ░ ░   ░    ░  "
echo "                                          ░                   "
echo ""
echo "=============================================================="
echo ""

echo ""
echo "Access Web-Installer: http://potato-jamba.metabox.me:9999"
echo "OR (Direct IP Access)"
echo "Access Web-Installer: http://$IP_ADDR:9999"
echo "One-Time Password for Installer: $INSTALLER"
echo ""
echo "You can now use our web installer to configure your cloud drives, and applications"
echo "Please note; that metaBox is currently in ALPHA, and is under heavy development,"
echo "Please report any bugs"
echo ""
echo "Also, feel free to support development by donating at https://www.paypal.me/fusedit"
echo ""
echo "Enjoy!"
echo "=============================================================="
echo ""


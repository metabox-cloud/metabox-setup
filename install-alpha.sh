#!/bin/bash
	  
OSARCH=$(uname -m)
METABOX_DIR=/mb
METABOX_LOGS="$METABOX_DIR"/logs
METABOX_PANEL="$METABOX_DIR"/panel
METABOX_BUILD="$METABOX_DIR"/build
METABOX_CONFIG="$METABOX_DIR"/config
METABOX_TRAKTARR="$METABOX_DIR"/traktarr
METABOX_IF=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

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
echo "..... Google Cloud SDK ......"
echo "deb http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list;
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -;
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
echo "Install Apache and stuff (WILL BE REPLACED OUT FOR NGINX IN FUTURE AFTER DEV COMPLETE"
sudo apt-get -qy install apache2 apache2-doc libexpat1 > /dev/null;
sudo apt-get -qy install php php-common libapache2-mod-php php-curl php-dev php-gd php-gettext php-imagick php-intl php-mbstring php-mysql php-pear php-pspell php-recode php-xml php-zip > /dev/null;
echo "Install Google Cloud SDK"
sudo apt-get -qy install google-cloud-sdk;
echo "Create metaBox Directories"
mkdir -p "$METABOX_DIR"; 
echo "$METABOX_DIR Created.."
mkdir -p "$METABOX_LOGS";
echo "$METABOX_LOGS Created.."
mkdir -p "$METABOX_PANEL";
echo "$METABOX_PANEL Created.."
echo "Pulling metaBox Panel from Repo"
git clone --branch dev https://www.github.com/metabox-cloud/metabox-panel.git "$METABOX_PANEL";
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
echo "Setting Apache2 Config"
rm -rf /etc/apache2/apache2.conf;
mv "$METABOX_PANEL"/apache2/apache2.conf /etc/apache2/;
rm -rf /etc/apache2/sites-available/000-default.conf;
mv "$METABOX_PANEL"/apache2/000-default.conf /etc/apache2/sites-available/;
echo "enable mod_rewrite"
a2enmod rewrite;
echo "Restarting Apache2"
service apache2 restart;

echo "Adding Sudoer for Docker Access (Not uber secure.. but we shall work something out later)"
echo "www-data   ALL = NOPASSWD: ALL" >> /etc/sudoers;

echo "Install Traktarr"
sudo git clone https://github.com/l3uddz/traktarr "$METABOX_TRAKTARR"/app;
cd "$METABOX_TRAKTARR"/app;
python3 -m pip install -r requirements.txt
sudo ln -s "$METABOX_TRAKTARR"/app/traktarr.py /usr/local/bin/traktarr;
echo "Traktarr Installed - Edit Config/List's in the WebUI"

echo "Pull Container Setups :)"
git clone --branch dev https://www.github.com/metabox-cloud/metabox-containers.git "$METABOX_CONFIG";
rm -rf "$METABOX_CONFIG"/LICENSE;
rm -rf "$METABOX_CONFIG"/README.md;
echo "Pulled :) "

echo "Creating Default Docker Containers (Watchtower, Portainer, rClone)"

/usr/bin/docker create --name Watchtower -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower;
echo "Watchtower Created"
/usr/bin/docker create --name Portainer -p 8000:8000 -p 9000:9000 --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v "$METABOX_CONFIG"/portainer:/data portainer/portainer-ce
echo "Portainer Created"
echo "Starting Containers"
/usr/bin/docker start $(docker ps -a -q)
echo "Building base Dockerized RClone Image (metabox-rclone:1.0)"
mkdir -p "$METABOX_TRAKTARR"/tempBuild;
echo "Pulling Docker Templates for rClone, this is only for testing.. because cbf"
/usr/bin/docker pull metaboxcloud/rclone-mega.docker
/usr/bin/docker pull metaboxcloud/rclone-gdrive.docker
docker run -p 9999:8080 -v $(METABOX_PANEL):/var/www/html trafex/alpine-nginx-php7



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
echo "METABOX_IMAGE=metaboxcloud/rclone-mega" >> "$METABOX_CONFIG"/config.dat;
clear;
	echo
	echo "Your Username to access metaBox..."
	read -p "Username: " mbun
	echo "METABOX_USERNAME=$mbun" >> "$METABOX_CONFIG"/config.dat;
clear;
	echo
	echo "Your Password to access metaBox.."
	read -p "New Password: " mbpw
UPASS=$(echo "$mbpw" | md5sum | awk '{print $1}')
    echo "METABOX_PASSWORD=$UPASS" >> "$METABOX_CONFIG"/config.dat;
clear;

echo "Base install Complete..."
echo "Access VIA port 9999"

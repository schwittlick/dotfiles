sudo sed -i 's/#Color/Color/' /etc/pacman.conf
sudo pacman --needed --noconfirm -Sy git openssh base-devel

# install yay if not installed
if ! command -v yay; then
	# install yay
	git clone https://aur.archlinux.org/yay.git
	cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
	yay -Y --gendb
fi

sudo pacman -S --needed - < pacman.txt
yay - < yay.txt

sudo systemctl enable sshd.service
sudo systemctl start --now sshd.service
sudo systemctl enable avahi-daemon.service
sudo systemctl start --now avahi-daemon.service

# now edit /etc/nsswitch.conf and add this
# mdns_minimal [NOTFOUND=return]
# between "files" and "resolve" in the line with "hosts:"

curl -LsSf https://astral.sh/uv/install.sh | sh

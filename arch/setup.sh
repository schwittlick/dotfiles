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
yay - < pacman.txt

sudo systemctl enable sshd.service
sudo systemctl start --now sshd.service

curl -LsSf https://astral.sh/uv/install.sh | sh

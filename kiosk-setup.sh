#!/bin/bash

set -e  # Stop script bij fouten

# Controleer of een URL is meegegeven
if [ -z "$1" ]; then
  echo "Gebruik: $0 <KIOSK_URL>"
  exit 1
fi

KIOSK_URL="$1"

# Systeem updaten en vereiste pakketten installeren
echo "Updating system and installing required packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y xserver-xorg x11-xserver-utils xinit openbox chromium-browser unclutter

# Autostart-script voor X11 en Chromium maken
echo "Creating X startup script..."
cat << EOF > ~/.xinitrc
xset s off
xset -dpms
xset s noblank
unclutter -idle 0 &
while true; do
  chromium-browser --noerrdialogs --disable-infobars --kiosk $KIOSK_URL || echo "Chromium crashed, restarting..."
  sleep 5
done
EOF
chmod +x ~/.xinitrc

# Automatisch X en Chromium starten bij inloggen
echo "Configuring auto-start on login..."
cat << EOF >> ~/.bash_profile
if [[ -z \$DISPLAY ]] && [[ \$(tty) == /dev/tty1 ]]; then
  startx
fi
EOF

# Automatisch inloggen als gebruiker 'pi'
echo "Setting up auto-login for user pi..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOF

# Herstarten om wijzigingen toe te passen
echo "Installation complete! Rebooting in 5 seconds..."
sleep 5
sudo reboot

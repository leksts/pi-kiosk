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
sudo apt install -y xserver-xorg x11-xserver-utils xinit openbox chromium-browser unclutter python3-xdg cec-utils

# Autostart-script voor X11 en Chromium maken
echo "Creating X startup script..."
cat << EOF > ~/.xinitrc
xset s off
xset -dpms
xset s noblank
unclutter -idle 0 &
while true; do
  chromium-browser --window-size=1920,1080 --start-fullscreen --noerrdialogs --disable-infobars --kiosk $KIOSK_URL || echo "Chromium crashed, restarting..."
  sleep 5
done
EOF
chmod +x ~/.xinitrc

# Configure auto-start on login
echo "Configuring auto-start on login..."
if [ -f ~/.bash_profile ]; then
  PROFILE_FILE=~/.bash_profile
else
  PROFILE_FILE=~/.profile
fi

if ! grep -q 'startx' "$PROFILE_FILE"; then
  cat << EOF >> "$PROFILE_FILE"

# Start X at login on tty1
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF
fi

# Create scripts to turn TV on and off
echo "Creating HDMI CEC control scripts..."
cat << EOF | sudo tee /usr/local/bin/tv_on.sh
#!/bin/bash
echo "on 0" | cec-client -s -d 1
EOF

cat << EOF | sudo tee /usr/local/bin/tv_off.sh
#!/bin/bash
echo "standby 0" | cec-client -s -d 1
EOF

sudo chmod +x /usr/local/bin/tv_on.sh /usr/local/bin/tv_off.sh

# Schedule cron jobs to turn TV on at 8:30 AM on weekdays and off at 5:30 PM every day
echo "Scheduling cron jobs for TV control..."
(crontab -l 2>/dev/null; echo "30 8 * * 1-5 /usr/local/bin/tv_on.sh") | crontab -
(crontab -l 2>/dev/null; echo "30 17 * * * /usr/local/bin/tv_off.sh") | crontab -

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

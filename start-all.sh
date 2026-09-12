#!/data/data/com.termux/files/usr/bin/bash

# Prevent CPU sleep
termux-wake-lock

# 1. OpenSSH Daemon (Port 8022)
pgrep -x sshd > /dev/null || sshd

# 2. Mosquitto Broker (Port 1883)
if ! pgrep -x mosquitto > /dev/null; then
mosquitto -c ~/.config/mosquitto/mosquitto.conf -d
fi

# 3. File Browser Instances
# External 1TB Drive (Port 8080)
if ! pgrep -f "filebrowser.db" > /dev/null; then
nohup filebrowser -d ~/.config/filebrowser/filebrowser.db > /dev/null 2>&1 &
fi
# Internal Storage (Port 8082)
if ! pgrep -f "fb_internal.db" > /dev/null; then
nohup filebrowser -d ~/.config/filebrowser/fb_internal.db > /dev/null 2>&1 &
fi

# 4. AdGuard Home via PRoot Debian (Ports 3000 & 5353)
if ! pgrep -f "AdGuardHome -c AdGuardHome.yaml" > /dev/null; then
nohup proot-distro login debian -- bash -c "cd /root/AdGuardHome && ./AdGuardHome -c AdGuardHome.yaml" > /dev/null 2>&1 &
fi

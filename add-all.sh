cat << 'EOF' > ~/setup-cluster.sh
#!/data/data/com.termux/files/usr/bin/bash
set -e


echo "=== [1/6] Base System Dependencies & Wakelock ==="
termux-wake-lock
pkg update -y && pkg upgrade -y
pkg install -y curl wget net-tools openssh git proot-distro


echo "=== [2/6] Configuring OpenSSH Daemon ==="
# Ensure password exists so remote connections are not rejected
if ! passwd -S 2>/dev/null | grep -q "P"; then
  echo -e "admin123qwerty\nadmin123qwerty" | passwd > /dev/null 2>&1 || true
fi
# Start sshd immediately if not running
pgrep -x sshd > /dev/null || sshd


echo "=== [3/6] Configuring Mosquitto MQTT ==="
pkg install -y mosquitto
mkdir -p ~/.config/mosquitto
cat << 'MCONF' > ~/.config/mosquitto/mosquitto.conf
listener 1883
allow_anonymous true
MCONF


echo "=== [4/6] Setting Up Storage & File Browser ==="
termux-setup-storage || true
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash


mkdir -p ~/.config/filebrowser
filebrowser config init --database ~/.config/filebrowser/filebrowser.db > /dev/null 2>&1 || true
filebrowser users add admin admin123qwerty --perm.admin --database ~/.config/filebrowser/filebrowser.db > /dev/null 2>&1 || \
filebrowser users update admin -p admin123qwerty --database ~/.config/filebrowser/filebrowser.db > /dev/null 2>&1 || true


echo "=== [5/6] Provisioning PRoot Debian & AdGuard Home ==="
if ! proot-distro list | grep -q "debian (installed)"; then
  proot-distro install debian
fi


proot-distro login debian -- bash -c '
apt update && apt install -y curl tar
mkdir -p /root/AdGuardHome
if [ ! -f /root/AdGuardHome/AdGuardHome ]; then
  curl -s -L https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz -o /root/AdGuardHome.tar.gz
  tar -xzvf /root/AdGuardHome.tar.gz -C /root/
  rm -f /root/AdGuardHome.tar.gz
fi


cat << "AGCONF" > /root/AdGuardHome/AdGuardHome.yaml
bind_host: 0.0.0.0
bind_port: 3000
users: []
dns:
  bind_hosts:
  - 0.0.0.0
  port: 5353
schema_version: 34
AGCONF
'


echo "=== [6/6] Building Persistent Background Daemon Script ==="
mkdir -p ~/.termux/boot
cat << 'DAEMON' > ~/.termux/boot/start-all.sh
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock


# 1. OpenSSH Daemon (Port 8022)
pgrep -x sshd > /dev/null || sshd


# 2. Mosquitto Broker (Port 1883)
if ! pgrep -x mosquitto > /dev/null; then
  mosquitto -c ~/.config/mosquitto/mosquitto.conf -d
fi


# 3. File Browser (Port 8080)
if ! pgrep -x filebrowser > /dev/null; then
  nohup filebrowser -r ~/storage/shared -a 0.0.0.0 -p 8080 -d ~/.config/filebrowser/filebrowser.db > /dev/null 2>&1 &
fi


# 4. AdGuard Home inside PRoot Debian (Port 3000 & 5353)
if ! pgrep -f "AdGuardHome -c AdGuardHome.yaml" > /dev/null; then
  nohup proot-distro login debian -- bash -c "cd /root/AdGuardHome && ./AdGuardHome -c AdGuardHome.yaml" > /dev/null 2>&1 &
fi
DAEMON


chmod +x ~/.termux/boot/start-all.sh


# Fallback hook into interactive shell
if ! grep -q "start-all.sh" ~/.bashrc 2>/dev/null; then
  echo "~/.termux/boot/start-all.sh" >> ~/.bashrc
fi


# Launch all daemons now
~/.termux/boot/start-all.sh


echo "All services deployed and running."
EOF
chmod +x ~/setup-cluster.sh
~/setup-cluster.sh


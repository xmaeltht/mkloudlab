#!/bin/bash
# Run this script inside each VM via VirtualBox console to restore Vagrant SSH access
#
# Instructions:
# 1. Open VirtualBox GUI
# 2. Double-click on kcontroller VM to open console
# 3. Login with your credentials
# 4. Run this script as root or with sudo
#
# This script adds the Vagrant insecure public key to authorized_keys

VAGRANT_USER="vagrant"
VAGRANT_HOME="/home/$VAGRANT_USER"
SSH_DIR="$VAGRANT_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# Vagrant insecure public key
VAGRANT_PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"

echo "=== Fixing Vagrant SSH Access ==="
echo "Creating/updating SSH directory..."
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

echo "Adding Vagrant insecure public key to authorized_keys..."
echo "$VAGRANT_PUB_KEY" > "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
chown -R $VAGRANT_USER:$VAGRANT_USER "$SSH_DIR"

echo "Ensuring SSH service is running..."
systemctl restart sshd || systemctl restart ssh || service ssh restart

echo "✓ SSH access configured successfully!"
echo "You can now exit the console and use 'vagrant ssh' from your host machine."

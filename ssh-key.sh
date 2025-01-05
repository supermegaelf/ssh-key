#!/bin/bash

check_command() {
  if ! "$@"; then
    echo "FAILED"
    exit 1
  fi
}

echo "Generate SSH key:" ssh-keygen -t ed25519 -C "server_name" -f "C:\Users\your_username\.ssh\server_name"

echo "Setting up SSH on server..."

check_command mkdir -p ~/.ssh

read -p "Insert public key and press Enter: " public_key
echo "$public_key" >> ~/.ssh/authorized_keys

check_command chmod 700 ~/.ssh
check_command chmod 600 ~/.ssh/authorized_keys

echo "Setting up SSH configuration file..."

config_file="/etc/ssh/sshd_config"

update_config() {
  local param="$1"
  local value="$2"
  if grep -q "^$param" "$config_file"; then
    sed -i "s/^$param.*/$param $value/" "$config_file"
  else
    echo "$param $value" >> "$config_file"
  fi
}

check_command update_config "PubkeyAuthentication" "yes"
check_command update_config "PasswordAuthentication" "no"

check_command systemctl restart ssh

echo "Check your connection using new SSH-key. Do not close current session!"

read -p "Подключение успешно? (y/n): " success
if [[ "$success" == "y" ]]; then
    echo "Done."
else
    echo "Failed. Check your settings."
    exit 1
fi

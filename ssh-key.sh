#!/bin/bash

check_command() {
  if ! "$@"; then
    echo "FAILED"
    exit 1
  fi
}

echo "Generate SSH key on your local machine using following command:"
echo 'ssh-keygen -t ed25519 -C "server_name" -f "C:\Users\your_username\.ssh\server_name"'

check_command mkdir -p ~/.ssh

read -p "Insert public key and press Enter: " public_key
echo "$public_key" >> ~/.ssh/authorized_keys

check_command chmod 700 ~/.ssh
check_command chmod 600 ~/.ssh/authorized_keys

config_file="/etc/ssh/sshd_config"

update_or_uncomment_config() {
  local param="$1"
  local value="$2"
  if grep -q "^#$param" "$config_file"; then
    sed -i "s/^#$param.*/$param $value/" "$config_file"
  elif grep -q "^$param" "$config_file"; then
    sed -i "s/^$param.*/$param $value/" "$config_file"
  else
    echo "$param $value" >> "$config_file"
  fi
}

check_command update_or_uncomment_config "PubkeyAuthentication" "yes"
check_command update_or_uncomment_config "PasswordAuthentication" "no"

check_command systemctl restart ssh

echo "Check your connection using new SSH key. Do not close current session!"

read -p "Connection successful? (y/n): " success
if [[ "$success" == "y" ]]; then
    echo "Done."
else
    echo "Failed. Check your settings."
    exit 1
fi

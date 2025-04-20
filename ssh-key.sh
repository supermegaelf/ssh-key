#!/bin/bash

SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP_CONFIG="${SSH_CONFIG}.bak.$(date +%F_%T)"
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

check_command() {
    if ! "$@"; then
        echo "FAILED: $1"
        exit 1
    fi
}

if ! systemctl is-active ssh &> /dev/null; then
    echo "Error: SSH service is not running or not installed."
    exit 1
fi

echo "Generate SSH key on your local machine with one of these commands:"
echo "For Windows: ssh-keygen -t ed25519 -C \"server_name\" -f \"C:\\Users\\your_username\\.ssh\\server_name\""
echo "For Linux/Mac: ssh-keygen -t ed25519 -C \"server_name\" -f \"~/.ssh/server_name\""
echo "After generating, copy the PUBLIC key (e.g., from server_name.pub) below."

check_command mkdir -p "${SSH_DIR}"

read -p "Insert public key and press Enter: " public_key
touch "${AUTHORIZED_KEYS}"
if ! echo "$public_key" >> "${AUTHORIZED_KEYS}"; then
    echo "FAILED: Adding public key to ${AUTHORIZED_KEYS}"
    exit 1
fi
echo "Adding public key to ${AUTHORIZED_KEYS} Done."

check_command chmod 700 "${SSH_DIR}"
check_command chmod 600 "${AUTHORIZED_KEYS}"

check_command cp "${SSH_CONFIG}" "${BACKUP_CONFIG}"

update_or_uncomment_config() {
    local param="$1"
    local value="$2"
    if grep -q "^#*$param" "$SSH_CONFIG"; then
        sed -i "s/^#*$param.*/$param $value/" "$SSH_CONFIG"
    else
        echo "$param $value" >> "$SSH_CONFIG"
    fi
}

check_command update_or_uncomment_config "PubkeyAuthentication" "yes"
check_command update_or_uncomment_config "PasswordAuthentication" "no"

if ! sshd -t; then
    echo "FAILED: SSH config syntax check failed. Reverting changes..."
    cp "${BACKUP_CONFIG}" "${SSH_CONFIG}"
    exit 1
fi

check_command systemctl restart ssh

echo "Test SSH connection using the new key in a new terminal."
echo "Example: ssh -i ~/.ssh/server_name user@<server-ip>"
echo "Do not close this session until you confirm connectivity!"
read -p "Connection successful? (y/n): " success

if [[ "$success" =~ ^[Yy]$ ]]; then
    echo "Done. SSH configured to use key-based authentication."
else
    echo "Connection failed. Reverting changes..."
    cp "${BACKUP_CONFIG}" "${SSH_CONFIG}"
    systemctl restart ssh
    echo "Reverted to original SSH config. Check your key and settings."
    exit 1
fi

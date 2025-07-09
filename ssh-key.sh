#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Status symbols
CHECK="✓"
CROSS="✗"
WARNING="!"
INFO="*"
ARROW="→"

# SSH Key Authentication Setup Script
echo
echo -e "${PURPLE}=============================${NC}"
echo -e "${WHITE}SSH KEY AUTHENTICATION SETUP${NC}"
echo -e "${PURPLE}=============================${NC}"

SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP_CONFIG="${SSH_CONFIG}.bak.$(date +%F_%T)"
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

check_command() {
    if ! "$@"; then
        echo -e "${RED}${CROSS}${NC} FAILED: $1"
        exit 1
    fi
}

echo
echo -e "${GREEN}Service Verification${NC}"
echo -e "${GREEN}====================${NC}"
echo

echo -e "${CYAN}${INFO}${NC} Checking SSH service status..."
if ! systemctl is-active ssh &> /dev/null; then
    echo -e "${RED}${CROSS}${NC} SSH service is not running or not installed."
    exit 1
fi
echo -e "${GRAY}  ${ARROW}${NC} SSH service is active and running"
echo -e "${GREEN}${CHECK}${NC} SSH service verification completed!"

echo
echo -e "${GREEN}───────────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} Service verification completed successfully!"
echo -e "${GREEN}───────────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}Key Generation Instructions${NC}"
echo -e "${GREEN}===========================${NC}"
echo

echo -e "${CYAN}${INFO}${NC} Generate SSH key on your local machine with one of these commands:"
echo
echo -e "${YELLOW}For Windows:${NC}"
echo -e "${WHITE}ssh-keygen -t ed25519 -C \"server_name\" -f \"C:\\Users\\your_username\\.ssh\\server_name\"${NC}"
echo
echo -e "${YELLOW}For Linux/Mac:${NC}"
echo -e "${WHITE}ssh-keygen -t ed25519 -C \"server_name\" -f \"~/.ssh/server_name\"${NC}"
echo
echo -e "${YELLOW}${WARNING}${NC} After generating, copy the PUBLIC key (e.g., from server_name.pub) below."

echo
echo -e "${GREEN}──────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} Key generation instructions completed successfully!"
echo -e "${GREEN}──────────────────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}SSH Directory Setup${NC}"
echo -e "${GREEN}===================${NC}"
echo

echo -e "${CYAN}${INFO}${NC} Setting up SSH directory structure..."
echo -e "${GRAY}  ${ARROW}${NC} Creating SSH directory ${BLUE}${SSH_DIR}${NC}"
check_command mkdir -p "${SSH_DIR}"
echo -e "${GREEN}${CHECK}${NC} SSH directory setup completed!"

echo
echo -e "${GREEN}──────────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} SSH directory setup completed successfully!"
echo -e "${GREEN}──────────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}Public Key Input${NC}"
echo -e "${GREEN}================${NC}"
echo

echo -ne "${CYAN}Insert public key and press Enter: ${NC}"
read public_key

echo -e "${CYAN}${INFO}${NC} Adding public key to authorized keys..."
echo -e "${GRAY}  ${ARROW}${NC} Creating authorized_keys file"
touch "${AUTHORIZED_KEYS}"
if ! echo "$public_key" >> "${AUTHORIZED_KEYS}"; then
    echo -e "${RED}${CROSS}${NC} FAILED: Adding public key to ${BLUE}${AUTHORIZED_KEYS}${NC}"
    exit 1
fi
echo -e "${GRAY}  ${ARROW}${NC} Public key added successfully"
echo -e "${GREEN}${CHECK}${NC} Public key configuration completed!"

echo
echo -e "${GREEN}───────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} Public key input completed successfully!"
echo -e "${GREEN}───────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}File Permissions${NC}"
echo -e "${GREEN}================${NC}"
echo

echo -e "${CYAN}${INFO}${NC} Setting secure file permissions..."
echo -e "${GRAY}  ${ARROW}${NC} Setting SSH directory permissions (700)"
check_command chmod 700 "${SSH_DIR}"
echo -e "${GRAY}  ${ARROW}${NC} Setting authorized_keys permissions (600)"
check_command chmod 600 "${AUTHORIZED_KEYS}"
echo -e "${GREEN}${CHECK}${NC} File permissions configured!"

echo
echo -e "${GREEN}───────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} File permissions completed successfully!"
echo -e "${GREEN}───────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}Configuration Backup${NC}"
echo -e "${GREEN}====================${NC}"
echo

echo -e "${CYAN}${INFO}${NC} Creating SSH configuration backup..."
echo -e "${GRAY}  ${ARROW}${NC} Backing up to ${BLUE}${BACKUP_CONFIG}${NC}"
check_command cp "${SSH_CONFIG}" "${BACKUP_CONFIG}"
echo -e "${GREEN}${CHECK}${NC} Configuration backup created!"

echo
echo -e "${GREEN}───────────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} Configuration backup completed successfully!"
echo -e "${GREEN}───────────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}SSH Configuration Update${NC}"
echo -e "${GREEN}========================${NC}"
echo

update_or_uncomment_config() {
    local param="$1"
    local value="$2"
    if grep -q "^#*$param" "$SSH_CONFIG"; then
        sed -i "s/^#*$param.*/$param $value/" "$SSH_CONFIG"
    else
        echo "$param $value" >> "$SSH_CONFIG"
    fi
}

echo -e "${CYAN}${INFO}${NC} Updating SSH configuration parameters..."
echo -e "${GRAY}  ${ARROW}${NC} Enabling PubkeyAuthentication"
check_command update_or_uncomment_config "PubkeyAuthentication" "yes"
echo -e "${GRAY}  ${ARROW}${NC} Disabling PasswordAuthentication"
check_command update_or_uncomment_config "PasswordAuthentication" "no"
echo -e "${GREEN}${CHECK}${NC} SSH configuration updated!"

echo
echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} SSH configuration update completed successfully!"
echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}Configuration Validation${NC}"
echo -e "${GREEN}========================${NC}"
echo

echo -e "${CYAN}${INFO}${NC} Validating SSH configuration syntax..."
echo -e "${GRAY}  ${ARROW}${NC} Running syntax check"
if ! sshd -t > /dev/null 2>&1; then
    echo -e "${RED}${CROSS}${NC} SSH config syntax check failed. Reverting changes..."
    echo -e "${GRAY}  ${ARROW}${NC} Restoring original configuration"
    cp "${BACKUP_CONFIG}" "${SSH_CONFIG}"
    exit 1
fi
echo -e "${GREEN}${CHECK}${NC} Configuration syntax validation passed!"

echo
echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} Configuration validation completed successfully!"
echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}Service Restart${NC}"
echo -e "${GREEN}===============${NC}"
echo

echo -e "${CYAN}${INFO}${NC} Restarting SSH service..."
echo -e "${GRAY}  ${ARROW}${NC} Applying new configuration"
check_command systemctl restart ssh
echo -e "${GREEN}${CHECK}${NC} SSH service restarted successfully!"

echo
echo -e "${GREEN}──────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} Service restart completed successfully!"
echo -e "${GREEN}──────────────────────────────────────────${NC}"
echo

echo -e "${GREEN}Connection Testing${NC}"
echo -e "${GREEN}==================${NC}"
echo

echo -e "${YELLOW}${WARNING}${NC} Test SSH connection using the new key in a new terminal!"
echo
echo -e "${CYAN}Connection Information:${NC}"
echo -e "${WHITE}• Example command: ssh -i ~/.ssh/server_name user@<server-ip>${NC}"
echo -e "${WHITE}• Use your private key file (without .pub extension)${NC}"
echo -e "${WHITE}• Do not close this session until you confirm connectivity!${NC}"
echo

echo -ne "${CYAN}Connection successful? (y/n): ${NC}"
read success

if [[ "$success" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}${CHECK}${NC} Connection test successful!"
else
    echo
    echo -e "${YELLOW}${WARNING}${NC} Connection failed. Reverting changes..."
    echo -e "${GRAY}  ${ARROW}${NC} Restoring original configuration"
    cp "${BACKUP_CONFIG}" "${SSH_CONFIG}"
    systemctl restart ssh > /dev/null 2>&1
    echo -e "${YELLOW}${WARNING}${NC} Reverted to original SSH config. Check your key and settings."
    exit 1
fi

echo
echo -e "${GREEN}─────────────────────────────────────────────${NC}"
echo -e "${GREEN}${CHECK}${NC} Connection testing completed successfully!"
echo -e "${GREEN}─────────────────────────────────────────────${NC}"
echo

echo -e "${PURPLE}===================${NC}"
echo -e "${GREEN}${CHECK}${NC} SETUP COMPLETED!"
echo -e "${PURPLE}===================${NC}"
echo
echo -e "${CYAN}Configuration Summary:${NC}"
echo -e "${WHITE}• SSH key-based authentication enabled${NC}"
echo -e "${WHITE}• Password authentication disabled${NC}"
echo -e "${WHITE}• Public key added to authorized_keys${NC}"
echo -e "${WHITE}• Original config backed up to: ${BACKUP_CONFIG}${NC}"
echo

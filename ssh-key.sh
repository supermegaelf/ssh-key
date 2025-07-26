#!/bin/bash

#====================
# SSH KEY AUTH SETUP
#====================

# Color constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'

# Status symbols
readonly CHECK="✓"
readonly CROSS="✗"
readonly WARNING="!"
readonly INFO="*"
readonly ARROW="→"

# Global variables
SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP_CONFIG="${SSH_CONFIG}.bak.$(date +%F_%T)"
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

#======================
# UTILITY FUNCTIONS
#======================

check_command() {
    if ! "$@"; then
        echo -e "${RED}${CROSS}${NC} FAILED: $1"
        echo
        exit 1
    fi
}

update_or_uncomment_config() {
    local param="$1"
    local value="$2"
    if grep -q "^#*$param" "$SSH_CONFIG"; then
        sed -i "s/^#*$param.*/$param $value/" "$SSH_CONFIG"
    else
        echo "$param $value" >> "$SSH_CONFIG"
    fi
}

#==========================
# SERVICE VERIFICATION
#==========================

verify_ssh_service() {
    echo -e "${GREEN}Service Verification${NC}"
    echo -e "${GREEN}====================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking SSH service status..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying SSH daemon is running"
    echo -e "${GRAY}  ${ARROW}${NC} Checking service availability"
    if ! systemctl is-active ssh &> /dev/null; then
        echo -e "${RED}${CROSS}${NC} SSH service is not running or not installed."
        echo
        exit 1
    fi
    echo -e "${GRAY}  ${ARROW}${NC} SSH service is active and running"
    echo -e "${GREEN}${CHECK}${NC} SSH service verification completed!"
    echo
}

#=============================
# KEY GENERATION INSTRUCTIONS
#=============================

display_key_generation_instructions() {
    echo -e "${GREEN}Key Generation Instructions${NC}"
    echo -e "${GREEN}===========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Generate SSH key on your local machine with one of these commands:"
    echo -e "${GRAY}  ${ARROW}${NC} Choose appropriate command for your operating system"
    echo -e "${GRAY}  ${ARROW}${NC} Replace 'server_name' with meaningful identifier"
    echo -e "${GRAY}  ${ARROW}${NC} Use ed25519 algorithm for enhanced security"
    echo -e "${GREEN}${CHECK}${NC} Key generation instructions completed!"
    echo
}

#==========================
# SSH DIRECTORY SETUP
#==========================

setup_ssh_directory() {
    echo -e "${GREEN}SSH Directory Setup${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Setting up SSH directory structure..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating SSH directory ${BLUE}${SSH_DIR}${NC}"
    echo -e "${GRAY}  ${ARROW}${NC} Ensuring proper directory structure"
    check_command mkdir -p "${SSH_DIR}"
    echo -e "${GRAY}  ${ARROW}${NC} SSH directory created successfully"
    echo -e "${GREEN}${CHECK}${NC} SSH directory setup completed!"
    echo
}

#=========================
# PUBLIC KEY INPUT
#=========================

input_public_key() {
    echo -e "${GREEN}Public Key Input${NC}"
    echo -e "${GREEN}================${NC}"
    echo

    echo -e "${YELLOW}Create for Windows:${NC}"
    echo -e "${WHITE}ssh-keygen -t ed25519 -C \"server_name\" -f \"C:\\Users\\your_username\\.ssh\\server_name\"${NC}"
    echo
    echo -e "${YELLOW}Create for Linux/Mac:${NC}"
    echo -e "${WHITE}ssh-keygen -t ed25519 -C \"server_name\" -f \"~/.ssh/server_name\"${NC}"

    echo
    echo -ne "${CYAN}Insert public key and press Enter: ${NC}"
    read public_key
    echo

    echo -e "${CYAN}${INFO}${NC} Adding public key to authorized keys..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating authorized_keys file"
    echo -e "${GRAY}  ${ARROW}${NC} Appending public key to file"
    touch "${AUTHORIZED_KEYS}"
    if ! echo "$public_key" >> "${AUTHORIZED_KEYS}"; then
        echo -e "${RED}${CROSS}${NC} FAILED: Adding public key to ${BLUE}${AUTHORIZED_KEYS}${NC}"
        echo
        exit 1
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Public key added successfully"
    echo -e "${GREEN}${CHECK}${NC} Public key configuration completed!"
    echo
}

#==========================
# FILE PERMISSIONS
#==========================

set_file_permissions() {
    echo -e "${GREEN}File Permissions${NC}"
    echo -e "${GREEN}================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Setting secure file permissions..."
    echo -e "${GRAY}  ${ARROW}${NC} Setting SSH directory permissions (700)"
    echo -e "${GRAY}  ${ARROW}${NC} Securing authorized_keys file (600)"
    check_command chmod 700 "${SSH_DIR}"
    check_command chmod 600 "${AUTHORIZED_KEYS}"
    echo -e "${GRAY}  ${ARROW}${NC} File permissions configured securely"
    echo -e "${GREEN}${CHECK}${NC} File permissions configured!"
    echo
}

#=============================
# CONFIGURATION BACKUP
#=============================

create_configuration_backup() {
    echo -e "${GREEN}Configuration Backup${NC}"
    echo -e "${GREEN}====================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Creating SSH configuration backup..."
    echo -e "${GRAY}  ${ARROW}${NC} Backing up to ${BLUE}${BACKUP_CONFIG}${NC}"
    echo -e "${GRAY}  ${ARROW}${NC} Creating timestamped backup file"
    check_command cp "${SSH_CONFIG}" "${BACKUP_CONFIG}"
    echo -e "${GRAY}  ${ARROW}${NC} Configuration backup created successfully"
    echo -e "${GREEN}${CHECK}${NC} Configuration backup created!"
    echo
}

#===============================
# SSH CONFIGURATION UPDATE
#===============================

update_ssh_configuration() {
    echo -e "${GREEN}SSH Configuration Update${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Updating SSH configuration parameters..."
    echo -e "${GRAY}  ${ARROW}${NC} Enabling PubkeyAuthentication"
    echo -e "${GRAY}  ${ARROW}${NC} Disabling PasswordAuthentication"
    check_command update_or_uncomment_config "PubkeyAuthentication" "yes"
    check_command update_or_uncomment_config "PasswordAuthentication" "no"
    echo -e "${GRAY}  ${ARROW}${NC} SSH security parameters updated"
    echo -e "${GREEN}${CHECK}${NC} SSH configuration updated!"
    echo
}

#==============================
# CONFIGURATION VALIDATION
#==============================

validate_ssh_configuration() {
    echo -e "${GREEN}Configuration Validation${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Validating SSH configuration syntax..."
    echo -e "${GRAY}  ${ARROW}${NC} Running syntax check"
    echo -e "${GRAY}  ${ARROW}${NC} Verifying configuration integrity"
    if ! sshd -t > /dev/null 2>&1; then
        echo -e "${RED}${CROSS}${NC} SSH config syntax check failed. Reverting changes..."
        echo -e "${GRAY}  ${ARROW}${NC} Restoring original configuration"
        cp "${BACKUP_CONFIG}" "${SSH_CONFIG}"
        echo
        exit 1
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Configuration syntax is valid"
    echo -e "${GREEN}${CHECK}${NC} Configuration syntax validation passed!"
    echo
}

#====================
# SERVICE RESTART
#====================

restart_ssh_service() {
    echo -e "${GREEN}Service Restart${NC}"
    echo -e "${GREEN}===============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Restarting SSH service..."
    echo -e "${GRAY}  ${ARROW}${NC} Applying new configuration"
    echo -e "${GRAY}  ${ARROW}${NC} Reloading SSH daemon"
    check_command systemctl restart ssh
    echo -e "${GRAY}  ${ARROW}${NC} SSH service restarted with new settings"
    echo -e "${GREEN}${CHECK}${NC} SSH service restarted successfully!"
    echo
}

#========================
# CONNECTION TESTING
#========================

test_ssh_connection() {
    echo -e "${GREEN}Connection Testing${NC}"
    echo -e "${GREEN}==================${NC}"
    echo

    echo -e "${YELLOW}${WARNING}${NC} Test SSH connection using the new key in a new terminal!"
    echo
    echo -ne "${CYAN}Connection successful? (y/n): ${NC}"
    read success

    if [[ "$success" =~ ^[Yy]$ ]]; then
        :
    else
        echo
        echo -e "${YELLOW}${WARNING}${NC} Connection failed. Reverting changes..."
        echo -e "${GRAY}  ${ARROW}${NC} Restoring original configuration"
        cp "${BACKUP_CONFIG}" "${SSH_CONFIG}"
        systemctl restart ssh > /dev/null 2>&1
        echo -e "${YELLOW}${WARNING}${NC} Reverted to original SSH config. Check your key and settings."
        echo
        exit 1
    fi

    echo
}

#===========================
# COMPLETION DISPLAY
#===========================

display_completion_info() {
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
}

#==================
# MAIN ENTRY POINT
#==================

main() {
    echo
    echo -e "${PURPLE}===================${NC}"
    echo -e "${WHITE}SSH KEY AUTH SETUP${NC}"
    echo -e "${PURPLE}===================${NC}"
    echo

    verify_ssh_service
    display_key_generation_instructions
    setup_ssh_directory
    input_public_key
    set_file_permissions
    create_configuration_backup
    update_ssh_configuration
    validate_ssh_configuration
    restart_ssh_service
    test_ssh_connection
    display_completion_info
}

main

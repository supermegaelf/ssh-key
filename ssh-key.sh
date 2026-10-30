#!/bin/bash

#=================
# SSH KEY MANAGER
#=================

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
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
STATE_DIR="${SSH_DIR}/ssh-key-manager"
BACKUP_CONFIG="${STATE_DIR}/sshd_config.bak"
TRANSACTION_DIR=""
KEY_LINES=()
KEY_LABELS=()

#===================
# UTILITY FUNCTIONS
#===================

check_command() {
    if ! "$@"; then
        echo -e "${RED}${CROSS}${NC} FAILED: $1"
        echo
        exit 1
    fi
}

begin_transaction() {
    check_command mkdir -p "${STATE_DIR}"
    check_command chmod 700 "${STATE_DIR}"
    TRANSACTION_DIR=$(mktemp -d "${STATE_DIR}/operation.XXXXXX") || exit 1
    check_command cp -p "${SSH_CONFIG}" "${TRANSACTION_DIR}/sshd_config"
    if [[ -f "$AUTHORIZED_KEYS" ]]; then
        check_command cp -p "$AUTHORIZED_KEYS" "${TRANSACTION_DIR}/authorized_keys"
    fi
    trap rollback_transaction EXIT
    trap 'exit 1' HUP INT TERM
}

finish_transaction() {
    trap - EXIT HUP INT TERM
    check_command rm -f -- "${TRANSACTION_DIR}/sshd_config" "${TRANSACTION_DIR}/authorized_keys" \
        "${TRANSACTION_DIR}/config.new" "${TRANSACTION_DIR}/key" "${TRANSACTION_DIR}/keys.new"
    check_command rmdir "${TRANSACTION_DIR}"
    TRANSACTION_DIR=""
}

rollback_transaction() {
    local result=$?
    trap - EXIT HUP INT TERM
    echo
    echo -e "${YELLOW}${WARNING}${NC} Operation cancelled or failed. Restoring SSH configuration and keys..."
    if ! cp -p "${TRANSACTION_DIR}/sshd_config" "$SSH_CONFIG"; then
        echo -e "${RED}${CROSS}${NC} Restore failed. Backup saved in ${BLUE}${TRANSACTION_DIR}${NC}"
        exit 1
    fi
    if [[ -f "${TRANSACTION_DIR}/authorized_keys" ]]; then
        cp -p "${TRANSACTION_DIR}/authorized_keys" "$AUTHORIZED_KEYS" || exit 1
    else
        rm -f -- "$AUTHORIZED_KEYS" || exit 1
    fi
    if ! sshd -t -f "$SSH_CONFIG" || ! systemctl reload ssh; then
        echo -e "${RED}${CROSS}${NC} SSH reload failed. Backup saved in ${BLUE}${TRANSACTION_DIR}${NC}"
        exit 1
    fi
    finish_transaction
    echo -e "${YELLOW}${WARNING}${NC} Previous SSH configuration and keys restored."
    echo
    [[ $result -ne 0 ]] || result=1
    exit "$result"
}

load_ssh_keys() {
    KEY_LINES=()
    KEY_LABELS=()
    [[ -f "$AUTHORIZED_KEYS" ]] || return 0
    local line label key_file
    key_file=$(mktemp) || exit 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        printf '%s\n' "$line" > "$key_file"
        if label=$(ssh-keygen -lf "$key_file" 2>/dev/null); then
            KEY_LINES+=("$line")
            KEY_LABELS+=("$label")
        fi
    done < "$AUTHORIZED_KEYS"
    check_command rm -- "$key_file"
}

select_ssh_key() {
    echo -e "${GREEN}SSH Key Selection${NC}"
    echo -e "${GREEN}=================${NC}"
    echo
    echo -e "${CYAN}${INFO}${NC} Select the key to $1; all other keys will be preserved."
    local i selection
    for i in "${!KEY_LABELS[@]}"; do
        printf '%s. %s\n' "$((i + 1))" "${KEY_LABELS[$i]}"
    done
    echo
    echo -ne "${CYAN}Enter key number: ${NC}"
    read -r selection
    if [[ ! "$selection" =~ ^[1-9][0-9]*$ || ${#selection} -gt 6 ]] || (( selection > ${#KEY_LINES[@]} )); then
        echo -e "${RED}${CROSS}${NC} Invalid key number."
        echo
        exit 1
    fi
    SELECTED_KEY="${KEY_LINES[$((selection - 1))]}"
    echo
}

remove_selected_key() {
    printf '%s\n' "$SELECTED_KEY" > "${TRANSACTION_DIR}/key" || exit 1
    check_command awk 'NR == FNR { key = $0; next } $0 != key' \
        "${TRANSACTION_DIR}/key" "$AUTHORIZED_KEYS" > "${TRANSACTION_DIR}/keys.new"
    check_command cp "${TRANSACTION_DIR}/keys.new" "$AUTHORIZED_KEYS"
}

effective_ssh_configuration() {
    local client_ip client_port server_ip server_port
    local context=(user=root)
    if [[ -n "$SSH_CONNECTION" ]]; then
        read -r client_ip client_port server_ip server_port <<< "$SSH_CONNECTION"
        context+=("addr=$client_ip" "host=$client_ip" "laddr=$server_ip" "lport=$server_port")
    fi
    local args=() item
    for item in "${context[@]}"; do
        args+=(-C "$item")
    done
    sshd -T -f "$SSH_CONFIG" "${args[@]}"
}

verify_authentication_settings() {
    local mode="$1" config method=publickey
    [[ "$mode" != yes ]] || method=password
    config=$(effective_ssh_configuration) || exit 1
    if ! grep -qx 'pubkeyauthentication yes' <<< "$config" ||
        ! grep -qx "passwordauthentication $mode" <<< "$config" ||
        ! grep -qx 'kbdinteractiveauthentication no' <<< "$config" ||
        { [[ "$mode" = yes ]] && ! grep -qx 'permitrootlogin yes' <<< "$config"; } ||
        ! grep -Eq "^authenticationmethods (any|$method)$" <<< "$config"; then
        echo -e "${RED}${CROSS}${NC} Effective SSH settings do not allow the requested login method. Check Include and Match rules."
        echo
        exit 1
    fi
}

#======================
# SERVICE VERIFICATION
#======================

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

#=====================
# SSH DIRECTORY SETUP
#=====================

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

#==================
# PUBLIC KEY INPUT
#==================

input_public_key() {
    echo -e "${GREEN}Public Key Input${NC}"
    echo -e "${GREEN}================${NC}"
    echo

    echo -e "${YELLOW}Create for Windows:${NC}"
    echo -e "${WHITE}ssh-keygen -t ed25519 -C \"server_name\" -f \"C:\\Users\\your_username\\.ssh\\server_name\"${NC}"
    echo
    echo -e "${YELLOW}Create for Linux/Mac:${NC}"
    echo -e "${WHITE}ssh-keygen -t ed25519 -C \"server_name\" -f \"\$HOME/.ssh/server_name\"${NC}"

    echo
    echo -ne "${CYAN}Insert public key and press Enter: ${NC}"
    IFS= read -r public_key
    public_key="${public_key#"${public_key%%[![:space:]]*}"}"
    public_key="${public_key%"${public_key##*[![:space:]]}"}"
    echo

    printf '%s\n' "$public_key" > "${TRANSACTION_DIR}/key" || exit 1
    local label fingerprint installed
    if [[ ! "$public_key" =~ ^(ssh-|ecdsa-|sk-) ]] ||
        ! label=$(ssh-keygen -lf "${TRANSACTION_DIR}/key" 2>/dev/null); then
        echo -e "${RED}${CROSS}${NC} Invalid public key."
        echo
        exit 1
    fi
    fingerprint=$(awk '{print $2}' <<< "$label")
    for installed in "${KEY_LABELS[@]}"; do
        if [[ "$(awk '{print $2}' <<< "$installed")" = "$fingerprint" ]]; then
            echo -e "${RED}${CROSS}${NC} This public key is already installed. Use a new key."
            echo
            exit 1
        fi
    done

    echo -e "${CYAN}${INFO}${NC} Adding public key to authorized keys..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating authorized_keys file"
    echo -e "${GRAY}  ${ARROW}${NC} Appending public key to file"
    if ! printf '\n%s\n' "$public_key" >> "${AUTHORIZED_KEYS}"; then
        echo -e "${RED}${CROSS}${NC} FAILED: Adding public key to ${BLUE}${AUTHORIZED_KEYS}${NC}"
        echo
        exit 1
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Public key added successfully"
    echo -e "${GREEN}${CHECK}${NC} Public key configuration completed!"
    echo
}

#==================
# FILE PERMISSIONS
#==================

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

#======================
# CONFIGURATION BACKUP
#======================

create_configuration_backup() {
    echo -e "${GREEN}Configuration Backup${NC}"
    echo -e "${GREEN}====================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Creating SSH configuration backup..."
    echo -e "${GRAY}  ${ARROW}${NC} Backing up to ${BLUE}${BACKUP_CONFIG}${NC}"
    echo -e "${GRAY}  ${ARROW}${NC} Saving original configuration for removal"
    if [[ ! -f "$BACKUP_CONFIG" ]]; then
        check_command cp -p "${SSH_CONFIG}" "${BACKUP_CONFIG}"
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Configuration backup created successfully"
    echo -e "${GREEN}${CHECK}${NC} Configuration backup created!"
    echo
}

#==========================
# SSH CONFIGURATION UPDATE
#==========================

update_ssh_configuration() {
    local mode="${1:-no}"
    echo -e "${GREEN}SSH Configuration Update${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Updating SSH configuration parameters..."
    echo -e "${GRAY}  ${ARROW}${NC} Enabling PubkeyAuthentication"
    echo -e "${GRAY}  ${ARROW}${NC} Preserving provider configuration and Include files"
    {
        echo '# BEGIN SSH KEY MANAGER'
        echo 'PubkeyAuthentication yes'
        if [[ "$mode" = prepare ]]; then
            # Keep the previous authentication settings until the new key is tested.
            awk '/^# BEGIN SSH KEY MANAGER$/ { block = 1; next }
                /^# END SSH KEY MANAGER$/ { block = 0; next }
                block && $1 != "PubkeyAuthentication"' "$SSH_CONFIG"
        else
            echo "PasswordAuthentication $mode"
            echo 'KbdInteractiveAuthentication no'
            [[ "$mode" != yes ]] || echo 'PermitRootLogin yes'
        fi
        echo '# END SSH KEY MANAGER'
        awk '/^# BEGIN SSH KEY MANAGER$/ { block = 1; next }
            /^# END SSH KEY MANAGER$/ { block = 0; next }
            !block' "$SSH_CONFIG"
    } > "${TRANSACTION_DIR}/config.new" || exit 1
    check_command cp "${TRANSACTION_DIR}/config.new" "$SSH_CONFIG"
    echo -e "${GRAY}  ${ARROW}${NC} SSH security parameters updated"
    echo -e "${GREEN}${CHECK}${NC} SSH configuration updated!"
    echo
}

#==========================
# CONFIGURATION VALIDATION
#==========================

validate_ssh_configuration() {
    echo -e "${GREEN}Configuration Validation${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Validating SSH configuration syntax..."
    echo -e "${GRAY}  ${ARROW}${NC} Running syntax check"
    echo -e "${GRAY}  ${ARROW}${NC} Verifying configuration integrity"
    if ! sshd -t -f "$SSH_CONFIG"; then
        echo -e "${RED}${CROSS}${NC} SSH config syntax check failed. Reverting changes..."
        echo
        exit 1
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Configuration syntax is valid"
    echo -e "${GREEN}${CHECK}${NC} Configuration syntax validation passed!"
    echo
}

#=================
# SERVICE RELOAD
#=================

reload_ssh_service() {
    echo -e "${GREEN}Service Reload${NC}"
    echo -e "${GREEN}==============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Reloading SSH service..."
    echo -e "${GRAY}  ${ARROW}${NC} Applying new configuration"
    echo -e "${GRAY}  ${ARROW}${NC} Reloading SSH daemon"
    check_command systemctl reload ssh
    echo -e "${GRAY}  ${ARROW}${NC} SSH service reloaded with new settings"
    echo -e "${GREEN}${CHECK}${NC} SSH service reloaded successfully!"
    echo
}

#====================
# CONNECTION TESTING
#====================

test_ssh_connection() {
    local method="${1:-key}" success
    echo -e "${GREEN}Connection Testing${NC}"
    echo -e "${GREEN}==================${NC}"
    echo

    echo -e "${YELLOW}${WARNING}${NC} Keep this session open. Test a NEW connection in another terminal."
    local client_ip client_port server_ip server_port
    read -r client_ip client_port server_ip server_port <<< "$SSH_CONNECTION"
    server_ip="${server_ip:-SERVER_IP}"
    server_port="${server_port:-22}"
    if [[ "$method" = password ]]; then
        echo -e "${GRAY}  ${ARROW}${NC} Use the server password. Set one with passwd in this session if needed."
        echo -e "${WHITE}ssh -p ${server_port} -o PubkeyAuthentication=no -o PreferredAuthentications=password root@${server_ip}${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Use the private key matching the public key just added."
        echo -e "${WHITE}ssh -p ${server_port} -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -i \"PATH_TO_PRIVATE_KEY\" root@${server_ip}${NC}"
    fi
    echo
    echo -ne "${CYAN}Connection successful? (y/n): ${NC}"
    read -r success

    if [[ "$success" =~ ^[Yy]$ ]]; then
        :
    else
        echo
        echo -e "${YELLOW}${WARNING}${NC} Connection failed. Reverting changes..."
        echo
        exit 1
    fi

    echo
}

#====================
# COMPLETION DISPLAY
#====================

display_completion_info() {
    echo -e "${PURPLE}=========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Installation complete!"
    echo -e "${PURPLE}=========================${NC}"
    echo
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo -e "${WHITE}• SSH key-based authentication enabled${NC}"
    echo -e "${WHITE}• Password authentication disabled${NC}"
    echo -e "${WHITE}• Public key added to authorized_keys${NC}"
    echo -e "${WHITE}• Original config backed up to: ${BACKUP_CONFIG}${NC}"
    echo
}

#======================
# SSH KEY INSTALLATION
#======================

install_ssh_key() {
    verify_ssh_service
    display_key_generation_instructions
    setup_ssh_directory
    begin_transaction
    input_public_key
    set_file_permissions
    create_configuration_backup
    update_ssh_configuration prepare
    validate_ssh_configuration
    reload_ssh_service
    test_ssh_connection
    update_ssh_configuration
    validate_ssh_configuration
    verify_authentication_settings no
    reload_ssh_service
    # Check a fresh connection after applying the final authentication settings.
    test_ssh_connection
    if [[ -n "$SELECTED_KEY" ]]; then
        remove_selected_key
    fi
    finish_transaction
    display_completion_info
}

#================
# SSH KEY UPDATE
#================

update_ssh_key() {
    select_ssh_key update
    install_ssh_key
}

#=================
# SSH KEY REMOVAL
#=================

remove_ssh_key() {
    echo -e "${GREEN}SSH Key Removal${NC}"
    echo -e "${GREEN}===============${NC}"
    echo
    select_ssh_key remove
    echo -e "${YELLOW}${WARNING}${NC} This will enable root password login and remove only the selected key."
    echo -e "${YELLOW}${WARNING}${NC} The key will be kept until you confirm a new password login."
    echo -ne "${YELLOW}Are you sure? (y/n): ${NC}"
    local confirm
    read -r confirm
    echo
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}${WARNING}${NC} Cancelled"
        echo
        return 0
    fi

    verify_ssh_service
    begin_transaction
    create_configuration_backup

    echo -e "${GREEN}Configuration Restore${NC}"
    echo -e "${GREEN}=====================${NC}"
    echo
    echo -e "${CYAN}${INFO}${NC} Restoring password access..."
    echo -e "${GRAY}  ${ARROW}${NC} Preserving provider settings and all other keys"
    update_ssh_configuration yes
    validate_ssh_configuration
    verify_authentication_settings yes
    reload_ssh_service
    test_ssh_connection password
    echo -e "${GREEN}${CHECK}${NC} SSH configuration restored!"
    echo

    echo -e "${GREEN}Public Key Removal${NC}"
    echo -e "${GREEN}==================${NC}"
    echo
    echo -e "${CYAN}${INFO}${NC} Removing SSH key setup..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing the selected key and preserving all other keys"
    remove_selected_key
    finish_transaction
    echo -e "${GREEN}${CHECK}${NC} SSH key setup removed!"
    echo

    echo -e "${PURPLE}====================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Removal complete!"
    echo -e "${PURPLE}====================${NC}"
    echo
}

#=====================
# MAIN MENU FUNCTIONS
#=====================

show_main_menu() {
    load_ssh_keys
    echo
    echo -e "${PURPLE}================${NC}"
    echo -e "${WHITE}SSH KEY MANAGER${NC}"
    echo -e "${PURPLE}================${NC}"
    echo
    echo -e "${CYAN}Please select an option:${NC}"
    echo
    if [[ ${#KEY_LINES[@]} -gt 0 ]]; then
        echo -e "${GREEN}1.${NC} Update SSH key"
        echo -e "${RED}2.${NC} Remove SSH key"
        echo -e "${YELLOW}3.${NC} Exit"
    else
        echo -e "${GREEN}1.${NC} Setup SSH key"
        echo -e "${YELLOW}2.${NC} Exit"
    fi
    echo
    echo -ne "${CYAN}Enter your choice: ${NC}"
}

#==================
# MAIN ENTRY POINT
#==================

main() {
    exec < /dev/tty
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${CROSS}${NC} Script must be run as root."
        echo
        exit 1
    fi

    show_main_menu
    local choice
    read -r choice
    case "$choice" in
        1)
            if [[ ${#KEY_LINES[@]} -gt 0 ]]; then
                update_ssh_key
            else
                install_ssh_key
            fi
            ;;
        2)
            if [[ ${#KEY_LINES[@]} -gt 0 ]]; then
                remove_ssh_key
                return
            fi
            echo
            echo -e "${YELLOW}${WARNING}${NC} Exiting..."
            echo
            return 0
            ;;
        3)
            if [[ ${#KEY_LINES[@]} -gt 0 ]]; then
                echo
                echo -e "${YELLOW}${WARNING}${NC} Exiting..."
                echo
                return 0
            fi
            echo -e "${RED}${CROSS}${NC} Invalid option. Please enter 1-2."
            exit 1
            ;;
        *)
            echo
            echo -e "${RED}${CROSS}${NC} Invalid option. Please select one of the listed options."
            echo
            exit 1
            ;;
    esac
}

# Execute main function
main

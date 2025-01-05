#!/bin/bash

check_command() {
  if ! "$@"; then
    echo "FAILED"
    exit 1
  fi
}

echo "Сгенерируйте SSH-ключ:" ssh-keygen -t ed25519 -C "server_name" -f "C:\Users\your_username\.ssh\server_name"
read -p "Скопируйте публичный ключ и нажмите Enter."

echo "Настройка SSH на сервере..."

check_command mkdir -p ~/.ssh

read -p "Вставьте публичный ключ: " public_key
echo "$public_key" >> ~/.ssh/authorized_keys

check_command chmod 700 ~/.ssh
check_command chmod 600 ~/.ssh/authorized_keys

echo "Настройка файла конфигурации SSH..."

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

echo "Проверьте подключение с использованием нового SSH-ключа. Не закрывайте текущую сессию!"

read -p "Подключение успешно? (y/n): " success
if [[ "$success" == "y" ]]; then
    echo "Подключение с использованием SSH-ключа успешно подтверждено. DONE."
else
    echo "FAILED. Проверьте настройки подключения и повторите попытку."
    exit 1
fi

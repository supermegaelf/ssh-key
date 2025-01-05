#!/bin/bash

check_command() {
  if ! "$@"; then
    echo "FAILED"
    exit 1
  fi
}

echo "Сгенерируйте SSH-ключ на вашей машине с помощью команды:" ssh-keygen -t ed25519 -C "server_name" -f "C:\Users\Ваше_имя_пользователя\.ssh\server_name"
read -p "Cкопируйте публичный ключ и нажмите Enter."

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

echo "Отключитесь от сервера и попробуйте подключиться с использованием SSH-ключа."
echo "Пример команды:"
echo "ssh -i /path/to/private_key -p порт user@server_ip"

echo "DONE"
exit 0

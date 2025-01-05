#!/bin/bash

# Функция для проверки выполнения команды
check_command() {
  if ! "$@"; then
    echo "FAILED"
    exit 1
  fi
}

# Создание SSH-ключа на локальном клиенте (инструкция предоставлена отдельно)
echo "Сгенерируйте SSH-ключ на вашей машине с помощью команды:"
echo 'ssh-keygen -t ed25519 -C "server_name" -f "C:\Users\Ваше_имя_пользователя\.ssh\server_name"'
echo "Откройте публичный ключ с помощью notepad и скопируйте его содержимое."
read -p "Нажмите Enter после копирования публичного ключа."

# Подготовка сервера
echo "Настройка SSH на сервере..."

# Создать .ssh директорию, если её нет
check_command mkdir -p ~/.ssh

# Вставить публичный ключ в authorized_keys
read -p "Вставьте публичный ключ: " public_key
echo "$public_key" >> ~/.ssh/authorized_keys

# Установка разрешений
check_command chmod 700 ~/.ssh
check_command chmod 600 ~/.ssh/authorized_keys

# Автоматическое редактирование sshd_config
echo "Настройка файла конфигурации SSH..."

config_file="/etc/ssh/sshd_config"

# Функция для добавления/обновления параметра
update_config() {
  local param="$1"
  local value="$2"
  if grep -q "^$param" "$config_file"; then
    sed -i "s/^$param.*/$param $value/" "$config_file"
  else
    echo "$param $value" >> "$config_file"
  fi
}

# Настройка необходимых параметров
check_command update_config "PubkeyAuthentication" "yes"
check_command update_config "PasswordAuthentication" "no"

# Перезапуск службы SSH
check_command systemctl restart ssh

# Инструкция по тестированию
echo "Отключитесь от сервера и попробуйте подключиться с использованием SSH-ключа."
echo "Пример команды:"
echo "ssh -i /path/to/private_key -p порт user@server_ip"

# Финальное сообщение
echo "DONE"
exit 0

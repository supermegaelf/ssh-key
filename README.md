![#c5f015](https://placehold.co/10x10/c5f015/c5f015.png) **СКРИПТ** ![#c5f015](https://placehold.co/10x10/c5f015/c5f015.png)

```
bash <(curl -s https://raw.githubusercontent.com/supermegaelf/ssh-key/main/ssh-key.sh)
```

![#1589F0](https://placehold.co/10x10/1589F0/1589F0.png) **РУЧНАЯ НАСТРОЙКА** ![#1589F0](https://placehold.co/10x10/1589F0/1589F0.png)

Сгенерировать SSH-ключ на клиенте:

```
ssh-keygen -t ed25519 -C "server_name" -f "C:\Users\Ваше_имя_пользователя\.ssh\server_name"
```

На сервере:

```
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
```

Вставить публичный ключ, затем:

```
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
nano /etc/ssh/sshd_config
```

Раскомментировать и изменить:

`PubkeyAuthentication yes`

`PasswordAuthentication no`

Перезапустить:

```
systemctl restart ssh
```

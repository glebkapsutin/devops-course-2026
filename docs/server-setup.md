# Конфигурация виртуальной машины devops-vm

Этот документ задаёт целевую конфигурацию для восстановления после снимка `01-clean-install`. Значения адресов, групп и снимков следует заменить результатами команд на собственной Ubuntu-машине. До установки Ubuntu фактическая конфигурация не подтверждена.

## 1. Параметры машины

| Параметр | Целевое значение |
| --- | --- |
| Гостевая ОС | Ubuntu Server 24.04 LTS, ARM64 для Mac с Apple Silicon |
| ОЗУ | 2048 МБ |
| Процессоры | 2 |
| Диск | 25 ГБ, динамически расширяемый |
| Имя машины | `devops-vm` |

Методичка задаёт VirtualBox. На данном Mac обнаружена UTM, а не VirtualBox; тип виртуализации и снимки необходимо согласовать с преподавателем, если работа будет выполняться в UTM.

## 2. Сетевые интерфейсы

| Интерфейс | Тип | Адрес | Назначение |
| --- | --- | --- | --- |
| 1 | NAT или UTM Shared | `10.0.2.15` в VirtualBox; в UTM уточнить | Выход в Интернет |
| 2 | Host-only или UTM Host Only | `192.168.56.101` в примере; записать фактический | Доступ хоста к гостю |

Проверка: `ip -brief address`. Фактические имена и адреса интерфейсов: **не измерены**.

## 3. Правило проброса портов

На этапе установки: TCP `127.0.0.1:2222` на гостевой порт `22`. После изменения SSH: TCP `127.0.0.1:2222` на гостевой порт `2222`. Проверка с хоста: `ssh -p 2222 devops@127.0.0.1`.

## 4. Учётные записи

`student`: создан при установке, в группе `sudo`, применяется для начальной настройки. `devops`: отдельная учётная запись в группе `sudo`, вход по ключу Ed25519. После `AllowUsers devops` вход `student` через SSH закрыт, но консольный вход остаётся. Группы проверить командой `groups devops`.

Закрытый ключ остаётся на хосте в `~/.ssh/devops_vm` с правами 600; открытый ключ размещён в `/home/devops/.ssh/authorized_keys` с правами 600; каталог `.ssh` имеет права 700. Отпечаток ключа сервера сверяется в консоли с `sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` до первого SSH-подключения.

## 5. Служба SSH

Основной файл: `/etc/ssh/sshd_config`; резервная копия: `/etc/ssh/sshd_config.backup`; дополнение: `/etc/ssh/sshd_config.d/99-hardening.conf`.

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

Проверить более ранние файлы: `grep -ri PasswordAuthentication /etc/ssh/sshd_config.d/ /etc/ssh/sshd_config`. Если значение `yes` задано раньше, убрать конфликтующую строку. Далее `sudo sshd -t`, `sudo sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication|maxauthtries|allowusers)'`. Для Ubuntu 24.04 отключить `ssh.socket`, включить `ssh.service`, перезапустить SSH и проверить `sudo ss -tlnp | grep sshd`. Действующую сессию сохранять до проверки нового соединения.

Конфигурация клиента `~/.ssh/config`:

```text
Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes
```

## 6. Правила межсетевого экрана

Политики: `sudo ufw default deny incoming` и `sudo ufw default allow outgoing`. До `sudo ufw enable` добавить `sudo ufw allow 2222/tcp comment 'SSH'`, а также 80/tcp и 443/tcp для следующей работы. После подтверждения нового SSH-подключения заменить правило 2222/tcp на `sudo ufw limit 2222/tcp comment 'SSH rate-limited'`; старое `allow` удалить. Проверить `sudo ufw status verbose` и `sudo ufw status numbered`. Для записи блокировок: `sudo ufw logging medium`.

## 7. Снимки состояния

| Имя | Момент создания | Подтверждение |
| --- | --- | --- |
| `01-clean-install` | После установки и обновления Ubuntu, до настройки SSH | Не создано |
| `02-keys-configured` | После проверки входа по ключу | Не создано |
| `03-ssh-hardened` | После усиления SSH и проверки нового подключения | Не создано |

## Восстановление после снимка 01-clean-install

1. Проверить оба адреса командой `ip -brief address` и службу `systemctl status ssh --no-pager`.
2. Войти как `student`, создать `devops`, добавить в `sudo`, установить открытый ключ и проверить права.
3. С хоста проверить вход `ssh -i ~/.ssh/devops_vm -p 2222 devops@127.0.0.1`.
4. Сохранить копию `sshd_config`, создать `99-hardening.conf`, убрать конфликтующие ранние значения.
5. Проверить `sshd -t` и `sshd -T`, переключить `ssh.socket` на `ssh.service`, убедиться в прослушивании 2222.
6. Изменить гостевой порт в пробросе на 2222, открыть новое SSH-соединение, не закрывая старое.
7. Добавить правила UFW до включения экрана; включить UFW, снова проверить SSH; включить `limit` и журналирование.
8. Добавить фактический Host-only IP в hosts хоста, задать FQDN через `hostnamectl` и `/etc/hosts`; проверить `hostname -f`.

Фактические параметры и скриншоты нужно внести после выполнения на Ubuntu-машине. Учебный репозиторий `devops-course-2026` найден; этот файл и `scripts/audit.sh` добавлены в него как материалы подготовки.

# Практическая работа № 5 — конфигурация devops-vm

Дата проверки: 02.11.2026. Гостевая ОС — Ubuntu Server 24.04.1 ARM64 в UTM на Mac. Виртуальная машина оставлена для последующих работ.

## Машина и сеть

| Параметр | Фактическое значение |
| --- | --- |
| ОЗУ / процессоры / диск | 2 ГБ / 2 / 25 ГБ |
| NAT | `enp0s1`, `10.0.2.15/24` |
| Host-only | `enp0s2`, `192.168.128.2/24` |
| Проброс TCP | `127.0.0.1:2222` → гостевой `2222` |
| Host-only адрес хоста | `192.168.128.1` |

Проверка адресов: `ip -brief address`. После перезагрузки проброс и вход `ssh devops` проверены.

## Учётные записи и ключ

`student` (UID 1000) и `devops` (UID 1001) входят в группу `sudo`. Для `devops` создана отдельная ключевая пара Ed25519 на хосте: `~/.ssh/devops_vm` (закрытый ключ, 600) и `~/.ssh/devops_vm.pub`. На госте ключ находится в `/home/devops/.ssh/authorized_keys` (600); каталог `.ssh` имеет права 700. Проверены вход по ключу и `sudo whoami` → `root`. Пароль в этом документе не сохраняется.

`~/.ssh/config` хоста:

```text
Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes
```

Дополнительно задан проверенный `UserKnownHostsFile` в рабочем каталоге. Отпечаток ключа хоста: `SHA256:BUn0HEdShFl4BeoPXWnbUBjmlZMiLRAlRWNV27LjLP4`.

## SSH

Основной `/etc/ssh/sshd_config` не изменён, сохранена копия `/etc/ssh/sshd_config.backup`. Конфликтующий файл `50-cloud-init.conf` с `PasswordAuthentication yes` переименован в `.disabled`. Создан `/etc/ssh/sshd_config.d/99-hardening.conf`:

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

`sshd -t` прошёл; `sshd -T` подтвердил значения. `ssh.socket` отключён, `ssh.service` включён и активен. `ss -lnt` показал `0.0.0.0:2222` и `[::]:2222`. Вход по ключу после перезагрузки успешен; вход `root` и вход без открытого ключа отклонены с `Permission denied (publickey)`. Журнал SSH показал `User root ... not allowed because not listed in AllowUsers`.

## UFW

Состояние `active`; политика `deny (incoming), allow (outgoing)`; `2222/tcp LIMIT IN`, `80/tcp ALLOW IN`, `443/tcp ALLOW IN` для IPv4 и IPv6; журналирование `medium`. После включения UFW повторный SSH-вход прошёл.

Проверка `curl -m 3 http://192.168.128.2:8080` завершилась тайм-аутом. В `/var/log/ufw.log` есть `[UFW BLOCK]`: `SRC=192.168.128.1`, `DST=192.168.128.2`, `PROTO=TCP`, `DPT=8080`.

## SSH-туннель

Временный HTTP-сервер слушал только `127.0.0.1:8080` на госте. Прямой доступ к `192.168.128.2:8080` не прошёл. Команда `ssh -L 9090:127.0.0.1:8080 -N devops` открыла туннель; `curl http://127.0.0.1:9090/` вернул тестовую страницу. Трафик передавался по SSH через порт 2222. После проверки временные процессы остановлены.

## Имя и DNS

На госте `hostname -f` → `devops-vm.devops.local`; в `/etc/hosts` запись `127.0.1.1 devops-vm.devops.local devops-vm`. NAT DNS от DHCP — `10.0.2.3`. На Mac в `/etc/hosts` добавлена строка `192.168.128.2 devops.local`. Проверены `dscacheutil -q host -a name devops.local`, `ping -c 1 devops.local` (1/1 получен) и `ssh -p 2222 devops@devops.local` по ключу. Проверенный ключ хоста для имени сохранён в `~/.ssh/known_hosts`.

## Проверка скрипта

`scripts/audit.sh` запущен на VM: 6 проверок пройдено, 0 ошибок, код 0. При временном `MaxAuthTries 10` выдал 5 успешных и 1 ошибку, код 1; затем значение восстановлено на 3 и `sshd -t` выполнен повторно.

## Снимки и восстановление

Установленная UTM 4.7.5 не имеет интерфейса снимков; функция появилась в UTM 5. Снимки `01-clean-install` и `02-keys-configured` не создавались до следующих этапов, поэтому задним числом их создать нельзя. После завершения настройки в UTM создана полная остановленная копия `03-ssh-hardened-backup`, содержащая готовую Ubuntu. Она остаётся в библиотеке UTM рядом с основной `devops-vm`; одновременно запускать их нельзя из-за одинаковых MAC, IP и проброса порта. Основная VM после копирования повторно запущена, доступ по имени и SSH проверен.

Для восстановления установить Ubuntu Server 24.04 ARM64 с указанными параметрами UTM, создать `student`, добавить `devops` в группу `sudo`, разместить открытый ключ с правами 700/600, создать `99-hardening.conf`, устранить конфликт `50-cloud-init.conf`, проверить `sshd -t`, отключить `ssh.socket`, включить `ssh.service`, выставить проброс 2222→2222, добавить правила UFW до включения экрана и внести запись имени в `/etc/hosts`. После каждого этапа проверять новое SSH-соединение.

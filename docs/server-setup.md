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

## 8. Веб-сервер

На Ubuntu установлен пакет `nginx` версии 1.24.0. Ресурс `devops.local` описан в `/etc/nginx/sites-available/devops-site` и активирован символьной ссылкой в `sites-enabled`; стандартный ресурс отключён. HTTP на порту 80 возвращает `301` на HTTPS, а порт 443 обслуживает статические файлы и позднее `/app/` через обратный прокси.

Каталог `/var/www/devops-site` принадлежит `devops:devops` и имеет права 755; файлы после доставки `rsync --chmod=D755,F644` имеют права 644. Процессы `www-data` читают ресурс, но не могут изменять его. Содержимое доставляется из `site/` сценарием `scripts/deploy.sh`; сценарий требует чистого Git-дерева, проверяет TLS через `~/devops.crt`, не запрашивает пароль и открывает не более одного SSH-соединения.

Сертификат создан командой `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'`. Срок действия: 02.11.2026–02.11.2027. Закрытый ключ `/etc/ssl/private/devops.key` принадлежит root и имеет права 600; открытый сертификат `/etc/ssl/certs/devops.crt` имеет права 644. На Mac открытый сертификат расположен в `~/devops.crt`; curl с `--cacert` проверяет его и имя `devops.local`. Из-за особенностей разрешения `.local` на данном Mac в curl используется `-4`.

Перед доставкой сайта в UTM 4.7.5 создана полная остановленная копия `04-nginx-https-backup` (эквивалент контрольной точки для восстановления; снимки в установленной версии UTM недоступны). Копию не запускать одновременно с основной VM из-за совпадающих сетевых параметров.

## 9. Контейнеризация

Docker Engine 29.9.3 и Compose v5.7.0 установлены из официального APT-репозитория Docker (`/etc/apt/sources.list.d/docker.sources`, ключ `/etc/apt/keyrings/docker.asc`). Служба `docker` активна. В группе `docker` находится `devops`, который уже имеет право `sudo`; `docker run --rm hello-world` работает без `sudo`.

Проект размещён на сервере в `/home/devops/app`. Исходники приходят из каталога `app/` репозитория через `rsync --exclude=.env`, чтобы доставка с `--delete` не удалила секрет. Файл `/home/devops/app/.env` существует только на VM, принадлежит `devops`, имеет права 600 и содержит случайный пароль PostgreSQL. В репозитории хранится только `.env.example`; `.env` исключён через `.gitignore` и `.dockerignore`.

Сервис `db` использует образ `postgres:16-alpine`, сеть `app_backend` и именованный том `app_db_data` в `/var/lib/postgresql/data`. Порт 5432 на узле не опубликован. Сервис `app` собирается по Dockerfile на базе `python:3.12-slim`, запускается от непривилегированного пользователя `app` (UID 999), ожидает `db: healthy` и публикует только `127.0.0.1:5000`. Имя `db` разрешается внутри сети Compose. Обычный `docker compose down` сохраняет том и счётчик, а `down -v` удаляет том и сбрасывает счётчик; последняя команда применялась только к учебным данным.

В HTTPS-блоке `/etc/nginx/sites-available/devops-site` добавлено `location /app/` с `proxy_pass http://127.0.0.1:5000/` и заголовками `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`. Статический ресурс `/` остаётся. `https://devops.local/app/health` возвращает `ok`, `/app/` увеличивает счётчик. При остановке контейнера приложения Nginx вернул 502 и записал `connect() failed (111: Connection refused) while connecting to upstream`; после запуска приложения ресурс восстановился.

Проверка публикации `-p 5001:5000` показала доступ к `http://devops.local:5001/health` с Mac при отсутствии правила 5001 в UFW: Docker создал правило DNAT в цепочке DOCKER. Тестовый контейнер остановлен. Для постоянного приложения оставлена только loopback-публикация 5000, поэтому обхода UFW извне нет.

#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        printf ' [OK] %s\n' "$desc"
        ((PASS+=1))
    else
        printf " [FAIL] %s (ожидалось: '%s', получено: '%s')\n" "$desc" "$expected" "$actual"
        ((FAIL+=1))
    fi
}

sshd_config="$(sudo sshd -T 2>/dev/null)" || {
    echo 'Не удалось прочитать действующую конфигурацию sshd.' >&2
    exit 2
}
ufw_verbose="$(sudo ufw status verbose 2>/dev/null)" || {
    echo 'Не удалось прочитать состояние ufw.' >&2
    exit 2
}

sshd_value() {
    awk -v key="$1" '$1 == key { print $2; exit }' <<< "$sshd_config"
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"
echo '[1] Служба SSH'
check 'Вход от имени root запрещён' 'no' "$(sshd_value permitrootlogin)"
check 'Парольная аутентификация отключена' 'no' "$(sshd_value passwordauthentication)"

ports="$(awk '$1 == "port" {print $2}' <<< "$sshd_config")"
check 'SSH слушает только порт 2222, не 22' '2222' "$ports"
check 'MaxAuthTries равен 3' '3' "$(sshd_value maxauthtries)"

echo '[2] Межсетевой экран'
status="$(awk '$1 == "Status:" {print $2; exit}' <<< "$ufw_verbose")"
check 'Межсетевой экран активен' 'active' "$status"
incoming="$(sed -nE 's/^Default: ([^ ]+) \(incoming\).*/\1/p' <<< "$ufw_verbose" | head -n 1)"
check 'Политика входящего трафика deny' 'deny' "$incoming"

echo '[3] Учётные записи'
awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ "$FAIL" -eq 0 ]]

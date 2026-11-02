#!/usr/bin/env bash
set -euo pipefail

usage() { echo 'Использование: scripts/deploy.sh [--dry-run]' >&2; exit 1; }
[[ $# -le 1 ]] || usage
DRY_RUN=()
if [[ $# -eq 1 ]]; then
    [[ $1 == --dry-run ]] || usage
    DRY_RUN=(--dry-run)
fi
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
LOCAL_DIR="$ROOT/site/"
REMOTE='devops'
REMOTE_DIR='/var/www/devops-site/'
CERT="${HOME}/devops.crt"
[[ -f "${LOCAL_DIR}index.html" ]] || { echo 'Ошибка: site/index.html отсутствует' >&2; exit 1; }
[[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] || { echo 'Ошибка: в репозитории есть незафиксированные изменения' >&2; exit 1; }
[[ -r "$CERT" ]] || { echo "Ошибка: сертификат не найден: $CERT" >&2; exit 1; }
rsync -avz --delete --chmod=D755,F644 "${DRY_RUN[@]}" \
    -e 'ssh -o BatchMode=yes -o ConnectTimeout=5' \
    "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}"
if [[ ${#DRY_RUN[@]} -gt 0 ]]; then
    echo 'Пробный запуск завершён'
    exit 0
fi
curl -4 --fail --silent --show-error --max-time 8 --cacert "$CERT" https://devops.local/ >/dev/null || {
    echo 'Ошибка: ресурс недоступен после доставки' >&2
    exit 1
}
printf 'Доставлен коммит %s\n' "$(git -C "$ROOT" rev-parse --short HEAD)"

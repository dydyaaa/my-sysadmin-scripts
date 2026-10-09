#!/bin/bash
readonly INTERVAL=60
readonly LOG_FILE="./monitor.log"
readonly MAX_LOG_SIZE=$((10 * 1024 * 1024))
readonly DATE_FMT='+%Y-%m-%d %H:%M:%S'

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_dependencies() {
    local missing=()
    for cmd in free df uptime date; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if (( ${#missing[@]} > 0 )); then
        log_error "Не найдены утилиты: ${missing[*]}"
        log_error "Установите их и запустите скрипт снова."
        exit 1
    fi
}

rotate_log_if_needed() {
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if (( size > MAX_LOG_SIZE )); then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log_warn "Лог превысил $((MAX_LOG_SIZE / 1024 / 1024)) МБ, ротация в ${LOG_FILE}.old"
        fi
    fi
}

write_block() {
    local timestamp
    timestamp=$(date "$DATE_FMT")

    {
        echo "--- ${timestamp} ---"
        echo "### free -h ###"
        free -h 2>&1 || echo "[ошибка выполнения free -h]"
        echo "### df -h ###"
        df -h 2>&1 || echo "[ошибка выполнения df -h]"
        echo "### uptime ###"
        uptime 2>&1 || echo "[ошибка выполнения uptime]"
        echo ""   # пустая строка-разделитель между блоками
    } >> "$LOG_FILE"
}

cleanup() {
    log_info "Получен сигнал завершения. Выходим..."
    exit 0
}
trap cleanup SIGINT SIGTERM

main() {
    check_dependencies

    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    [[ -d "$log_dir" ]] || mkdir -p "$log_dir" || {
        log_error "Не удалось создать директорию $log_dir"
        exit 1
    }

    log_info "Мониторинг запущен. Интервал: ${INTERVAL}с. Лог: $(realpath "$LOG_FILE")"
    log_info "Для остановки нажмите Ctrl+C."

    while true; do
        rotate_log_if_needed
        write_block
        sleep "$INTERVAL"
    done
}

main "$@"
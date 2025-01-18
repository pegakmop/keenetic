#!/bin/sh

# URL проекта на GitHub, содержащего список сайтов
GITHUB_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-raw.lst"

# Локальные файлы
OUTPUT_FILE="/opt/etc/AdGuardHome/ipset.conf"
LOCAL_FILE="/opt/etc/AdGuardHome/my-domains-list.conf"
DUPLICATES_LOG="/opt/etc/AdGuardHome/duplicates.log"
SUBDOMAINS_LOG="/opt/etc/AdGuardHome/subdomains.log"
LOG_FILE="/opt/etc/AdGuardHome/script.log"

# Создаем временные файлы
TEMP_FILE=$(mktemp)
UNIQUE_TMP_FILE=$(mktemp)

# Очистка файлов
> "$OUTPUT_FILE"
> "$DUPLICATES_LOG"
> "$SUBDOMAINS_LOG"
> "$LOG_FILE"

# Логирование
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Извлечение домена первого уровня
get_root_domain() {
    echo "$1" | awk -F'.' '{
        if (NF >= 2) {
            print $(NF-1) "." $NF
        } else {
            print $0
        }
    }'
}

# Проверка на ошибки
check_error() {
    if [ $? -ne 0 ]; then
        log "Ошибка на этапе: $1"
        exit 1
    fi
}

# Загрузка списка сайтов из GITHUB_URL
log "Загрузка списка сайтов из $GITHUB_URL"
curl -fsSL "$GITHUB_URL" -o "$TEMP_FILE"
check_error "Загрузка списка сайтов"

# Обработка файла
process_file() {
    local file="$1"
    log "Обработка файла: $file"

    if [ ! -f "$file" ]; then
        log "Файл $file не найден"
        return
    fi

    # Используем параллельную обработку
    cat "$file" | xargs -P 4 -I {} sh -c '
        site=$(echo "{}" | tr -d "\r")
        [ -z "$site" ] && exit 0

        root_domain=$(echo "$site" | awk -F"." '"'"'{ print $(NF-1) "." $NF }'"'"')

        # Если это поддомен
        if [ "$root_domain" != "$site" ]; then
            echo "$site" >> "'$SUBDOMAINS_LOG'"
        fi

        # Проверка уникальности
        if grep -qx "$root_domain" "'$UNIQUE_TMP_FILE'"; then
            echo "$site" >> "'$DUPLICATES_LOG'"
        else
            echo "$root_domain" >> "'$UNIQUE_TMP_FILE'"
        fi
    '
}

# Обработка локального и загруженного файлов
process_file "$LOCAL_FILE"
process_file "$TEMP_FILE"

# Формируем итоговый файл
log "Формирование итогового файла: $OUTPUT_FILE"
sort "$UNIQUE_TMP_FILE" | uniq | while IFS= read -r unique_site || [ -n "$unique_site" ]; do
    echo "$unique_site/bypass,bypass6" >> "$OUTPUT_FILE"
done
check_error "Формирование итогового файла"

# Удаление временных файлов
rm -f "$TEMP_FILE" "$UNIQUE_TMP_FILE"

log "Скрипт завершён. Файл $OUTPUT_FILE успешно обновлён"
log "Обнаруженные дубли сохранены в $DUPLICATES_LOG"
log "Обнаруженные поддомены сохранены в $SUBDOMAINS_LOG"

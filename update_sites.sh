#!/bin/sh

# Путь к папке с логами скрипта
SCRIPT_LOG_DIR="/opt/etc/AdGuardHome/script_logs"

# Проверка и создание директории для логов, если она отсутствует
mkdir -p "$SCRIPT_LOG_DIR"

# URL проекта на GitHub, содержащего список сайтов
GITHUB_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-raw.lst"

# Локальные файлы
OUTPUT_FILE="/opt/etc/AdGuardHome/ipset.conf"
OUTPUT_FILE_OLD="$SCRIPT_LOG_DIR/ipset.conf.old"  # Предыдущая версия файла (в папке script_logs)
LOCAL_FILE="/opt/etc/AdGuardHome/my-domains-list.conf"
DUPLICATES_LOG="$SCRIPT_LOG_DIR/duplicates.log"
SUBDOMAINS_LOG="$SCRIPT_LOG_DIR/subdomains.log"
LOG_FILE="$SCRIPT_LOG_DIR/script.log"

# Настройки Telegram
BOT_TOKEN="YOUR_BOT_TOKEN"  # Замените на токен вашего бота
CHAT_ID="YOUR_CHAT_ID"      # Замените на ваш chat_id

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
    local MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo "$MESSAGE" >> "$LOG_FILE"  # Запись в лог-файл
    echo "$MESSAGE"                 # Вывод в терминал
}

# Отправка сообщения в Telegram
send_telegram_message() {
    local MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$CHAT_ID\",
            \"text\": \"$MESSAGE\",
            \"parse_mode\": \"Markdown\"
        }" >> "$LOG_FILE"
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
        ERROR_MESSAGE="❌ *Ошибка на этапе:* $1"
        send_telegram_message "$ERROR_MESSAGE"
        exit 1
    fi
}

# Сохраняем предыдущую версию файла
if [ -f "$OUTPUT_FILE" ]; then
    cp "$OUTPUT_FILE" "$OUTPUT_FILE_OLD"
    log "Предыдущая версия файла сохранена: $OUTPUT_FILE_OLD"
else
    log "Предыдущая версия файла отсутствует. Создаём новый файл."
fi

# Загрузка списка сайтов из GITHUB_URL
log "Загрузка списка сайтов из $GITHUB_URL"
curl -fsSL "$GITHUB_URL" -o "$TEMP_FILE"
check_error "Загрузка списка сайтов"
log "Список доменов успешно загружен."

# Обработка файла
process_file() {
    local file="$1"
    log "Обработка файла: $file"

    if [ ! -f "$file" ]; then
        log "Файл $file не найден"
        return
    fi

    # Используем параллельную обработку
    cat "$file" | xargs -P 4 -I {} sh -c "
        site=\$(echo '{}' | tr -d '\r')
        [ -z \"\$site\" ] && exit 0

        root_domain=\$(echo \"\$site\" | awk -F'.' '{ if (NF >= 2) { print \$(NF-1) \".\" \$NF } else { print \$0 } }')

        # Если это поддомен
        if [ \"\$root_domain\" != \"\$site\" ]; then
            echo \"\$site\" >> \"$SUBDOMAINS_LOG\"
        fi

        # Проверка уникальности
        if grep -qx \"\$root_domain\" \"$UNIQUE_TMP_FILE\"; then
            echo \"\$site\" >> \"$DUPLICATES_LOG\"
        else
            echo \"\$root_domain\" >> \"$UNIQUE_TMP_FILE\"
        fi
    "
}

# Обработка локального и загруженного файлов
log "Обработка локального файла: $LOCAL_FILE"
process_file "$LOCAL_FILE"
log "Обработка загруженного файла: $TEMP_FILE"
process_file "$TEMP_FILE"

# Формируем итоговый файл
log "Формирование итогового файла: $OUTPUT_FILE"
sort "$UNIQUE_TMP_FILE" | uniq | while IFS= read -r unique_site || [ -n "$unique_site" ]; do
    echo "$unique_site/hr2" >> "$OUTPUT_FILE"
done
check_error "Формирование итогового файла"
log "Итоговый файл успешно сформирован."

# Подсчет количества уникальных доменов, дубликатов и поддоменов
UNIQUE_COUNT=$(wc -l < "$UNIQUE_TMP_FILE")
DUPLICATES_COUNT=$(wc -l < "$DUPLICATES_LOG")
SUBDOMAINS_COUNT=$(wc -l < "$SUBDOMAINS_LOG")

# Сравнение с предыдущей версией
if [ -f "$OUTPUT_FILE_OLD" ]; then
    DIFF_OUTPUT=$(diff "$OUTPUT_FILE_OLD" "$OUTPUT_FILE" || true)  # Игнорируем код выхода diff
    if [ -n "$DIFF_OUTPUT" ]; then
        # Подсчет добавленных и удаленных строк
        ADDED_COUNT=$(echo "$DIFF_OUTPUT" | grep -c '^>')
        REMOVED_COUNT=$(echo "$DIFF_OUTPUT" | grep -c '^<')
    else
        ADDED_COUNT=0
        REMOVED_COUNT=0
    fi
else
    ADDED_COUNT=0
    REMOVED_COUNT=0
    log "Предыдущая версия файла отсутствует. Сравнение невозможно."
fi

# Формируем итоговое сообщение
FINAL_MESSAGE="🔄 *Скрипт обновления доменов завершён.*\n\n"
FINAL_MESSAGE="$FINAL_MESSAGE""📥 *Загрузка данных:*\n"
FINAL_MESSAGE="$FINAL_MESSAGE""- Список доменов успешно загружен с GitHub.\n\n"
FINAL_MESSAGE="$FINAL_MESSAGE""📊 *Итоговый отчет:*\n"
FINAL_MESSAGE="$FINAL_MESSAGE""- Уникальных доменов: $UNIQUE_COUNT\n"
FINAL_MESSAGE="$FINAL_MESSAGE""- Дубликатов: $DUPLICATES_COUNT\n"
FINAL_MESSAGE="$FINAL_MESSAGE""- Поддоменов: $SUBDOMAINS_COUNT\n\n"
FINAL_MESSAGE="$FINAL_MESSAGE""🔄 *Изменения в файле ipset.conf:*\n"
FINAL_MESSAGE="$FINAL_MESSAGE""- Добавлено доменов: $ADDED_COUNT\n"
FINAL_MESSAGE="$FINAL_MESSAGE""- Удалено доменов: $REMOVED_COUNT\n\n"
FINAL_MESSAGE="$FINAL_MESSAGE""✅ *Файл $OUTPUT_FILE успешно обновлён.*\n"

# Отправка итогового сообщения в Telegram
send_telegram_message "$FINAL_MESSAGE"

# Удаление временных файлов
rm -f "$TEMP_FILE" "$UNIQUE_TMP_FILE"

log "Скрипт завершён. Файл $OUTPUT_FILE успешно обновлён."
log "Обнаруженные дубли сохранены в $DUPLICATES_LOG."
log "Обнаруженные поддомены сохранены в $SUBDOMAINS_LOG."

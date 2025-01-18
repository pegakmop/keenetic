#!/bin/bash
set -e

# Переменные
BASE_DIR="/opt/etc/AdGuardHome/scripts"
CONFIG_FILE="$BASE_DIR/config.sh"
SCRIPT_FILE="$BASE_DIR/update_sites.sh"
LOG_FILE="$BASE_DIR/script.log"
OUTPUT_FILE="/opt/etc/AdGuardHome/ipset.conf"
LOCAL_FILE="$BASE_DIR/my-domains-list.conf"
DUPLICATES_FILE="$BASE_DIR/duplicates.log"
SUBDOMAINS_FILE="$BASE_DIR/subdomains.log"

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Создание директорий
echo "Создаём директории..."
mkdir -p "$BASE_DIR"
log "Созданы директории: $BASE_DIR"

# Создание файла config.sh
echo "Создаём файл конфигурации config.sh..."
cat > "$CONFIG_FILE" <<EOL
#!/bin/bash

# URL проекта на GitHub, содержащего список сайтов
GITHUB_URL="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-raw.lst"

# Локальный файл для сохранения результатов
OUTPUT_FILE="$OUTPUT_FILE"

# Локальный файл с вашим списком сайтов
LOCAL_FILE="$LOCAL_FILE"

# Файл для записи дублей
DUPLICATES_FILE="$DUPLICATES_FILE"

# Файл для записи поддоменов
SUBDOMAINS_FILE="$SUBDOMAINS_FILE"

# Лог-файл скрипта
LOG_FILE="$LOG_FILE"
EOL
chmod 644 "$CONFIG_FILE"
log "Создан файл конфигурации: $CONFIG_FILE"

# Создание файла update_sites.sh
echo "Создаём основной скрипт update_sites.sh..."
cat > "$SCRIPT_FILE" <<'EOL'
#!/bin/bash
set -e

# Подключение файла конфигурации
CONFIG_FILE="/opt/etc/AdGuardHome/scripts/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Ошибка: файл конфигурации $CONFIG_FILE не найден!"
    exit 1
fi

# Логирование
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Функция для загрузки списка сайтов
download_sites() {
    log "Загрузка списка сайтов из $GITHUB_URL"
    curl -s "$GITHUB_URL" -o "$TEMP_FILE"
    if [ $? -ne 0 ]; then
        log "Ошибка при загрузке списка сайтов"
        rm -f "$TEMP_FILE"
        exit 1
    fi
}

# Функция для извлечения домена первого уровня
get_root_domain() {
    echo "$1" | awk -F'.' '{
        if (NF >= 2) {
            print $(NF-1) "." $NF
        } else {
            print $0
        }
    }'
}

# Функция для обработки файлов
process_file() {
    local file="$1"
    log "Обработка файла: $file"
    if [ -f "$file" ]; then
        while IFS= read -r site || [ -n "$site" ]; do
            # Удаляем символы CR (возврат каретки)
            site=$(echo "$site" | tr -d '\r')
            # Пропускаем пустые строки
            [ -z "$site" ] && continue
            # Определяем домен первого уровня
            root_domain=$(get_root_domain "$site")
            if [ "$root_domain" != "$site" ]; then
                # Если это поддомен, записываем в файл subdomains.log
                echo "$site" >> "$SUBDOMAINS_FILE"
            fi
            # Проверяем уникальность домена первого уровня
            if grep -qx "$root_domain" "$UNIQUE_TMP_FILE"; then
                echo "$site" >> "$DUPLICATES_FILE"
            else
                echo "$root_domain" >> "$UNIQUE_TMP_FILE"
            fi
        done < "$file"
    else
        log "Файл $file не найден"
    fi
}

# Формирование итогового файла
generate_output() {
    log "Формирование итогового файла: $OUTPUT_FILE"
    while IFS= read -r unique_site || [ -n "$unique_site" ]; do
        echo "$unique_site/bypass,bypass6"
    done < "$UNIQUE_TMP_FILE" > "$OUTPUT_FILE"
}

# Очистка временных файлов
cleanup() {
    log "Очистка временных файлов"
    rm -f "$TEMP_FILE" "$UNIQUE_TMP_FILE"
}

# Основной код скрипта
TEMP_FILE=$(mktemp)
UNIQUE_TMP_FILE=$(mktemp)

# Очищаем старые файлы
> "$DUPLICATES_FILE"
> "$SUBDOMAINS_FILE"
> "$LOG_FILE"

# Шаги выполнения
download_sites
process_file "$LOCAL_FILE"
process_file "$TEMP_FILE"
generate_output
cleanup

# Итоговый отчёт
log "Скрипт завершён"
echo "Файл $OUTPUT_FILE успешно обновлён"
if [ -s "$DUPLICATES_FILE" ]; then
    echo "Обнаружены дубли. Они сохранены в $DUPLICATES_FILE"
else
    echo "Дубликатов не найдено"
    rm -f "$DUPLICATES_FILE"
fi

if [ -s "$SUBDOMAINS_FILE" ]; then
    echo "Обнаружены поддомены. Они сохранены в $SUBDOMAINS_FILE"
else
    echo "Поддоменов не найдено"
    rm -f "$SUBDOMAINS_FILE"
fi
EOL
chmod +x "$SCRIPT_FILE"
log "Создан основной скрипт: $SCRIPT_FILE"

# Сообщение об успешной установке
echo "Установка завершена! Основной скрипт находится по адресу: $SCRIPT_FILE"
echo "Для запуска выполните: $SCRIPT_FILE"

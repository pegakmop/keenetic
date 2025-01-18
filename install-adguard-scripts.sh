#!/bin/sh

# Переменные
BASE_DIR="/opt/etc/AdGuardHome/scripts"
ADGUARD_BINARY="/opt/etc/AdGuardHome/AdGuardHome"  # Новый путь к AdGuardHome
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

# Функция для проверки установки AdGuardHome
check_adguardhome() {
    if [ -f "$ADGUARD_BINARY" ]; then
        echo "AdGuardHome установлен: $ADGUARD_BINARY"
        log "AdGuardHome установлен: $ADGUARD_BINARY"
    else
        echo "Ошибка: AdGuardHome не найден!"
        echo "Убедитесь, что AdGuardHome установлен и доступен по пути $ADGUARD_BINARY"
        exit 1
    fi
}

# Функция для проверки, что AdGuardHome работает
check_adguardhome_running() {
    if pgrep -f "$ADGUARD_BINARY" >/dev/null 2>&1; then
        echo "AdGuardHome работает."
        log "AdGuardHome работает."
    else
        echo "Ошибка: AdGuardHome установлен, но не запущен!"
        echo "Убедитесь, что AdGuardHome запущен."
        exit 1
    fi
}

# Создание директорий
create_directories() {
    echo "Создаём директории..."
    mkdir -p "$BASE_DIR" || { echo "Ошибка: не удалось создать директорию $BASE_DIR"; exit 1; }
    log "Созданы директории: $BASE_DIR"
}

# Создание файла config.sh
create_config_file() {
    echo "Создаём файл конфигурации config.sh..."
    echo '#!/bin/sh' > "$CONFIG_FILE"
    echo "GITHUB_URL=\"https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-raw.lst\"" >> "$CONFIG_FILE"
    echo "OUTPUT_FILE=\"$OUTPUT_FILE\"" >> "$CONFIG_FILE"
    echo "LOCAL_FILE=\"$LOCAL_FILE\"" >> "$CONFIG_FILE"
    echo "DUPLICATES_FILE=\"$DUPLICATES_FILE\"" >> "$CONFIG_FILE"
    echo "SUBDOMAINS_FILE=\"$SUBDOMAINS_FILE\"" >> "$CONFIG_FILE"
    echo "LOG_FILE=\"$LOG_FILE\"" >> "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    log "Создан файл конфигурации: $CONFIG_FILE"
}

# Создание файла update_sites.sh
create_update_script() {
    echo "Создаём основной скрипт update_sites.sh..."
    echo '#!/bin/sh' > "$SCRIPT_FILE"
    echo "CONFIG_FILE=\"$CONFIG_FILE\"" >> "$SCRIPT_FILE"
    echo 'if [ -f "$CONFIG_FILE" ]; then' >> "$SCRIPT_FILE"
    echo '    . "$CONFIG_FILE"' >> "$SCRIPT_FILE"
    echo 'else' >> "$SCRIPT_FILE"
    echo '    echo "Ошибка: файл конфигурации $CONFIG_FILE не найден!"' >> "$SCRIPT_FILE"
    echo '    exit 1' >> "$SCRIPT_FILE"
    echo 'fi' >> "$SCRIPT_FILE"

    # Логирование
    echo 'log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"; }' >> "$SCRIPT_FILE"

    # Загрузка сайтов
    echo 'TEMP_FILE="/tmp/tempfile.$RANDOM"; UNIQUE_TMP_FILE="/tmp/uniquefile.$RANDOM"; touch "$TEMP_FILE" "$UNIQUE_TMP_FILE"' >> "$SCRIPT_FILE"
    echo 'log "Загрузка списка сайтов из $GITHUB_URL"' >> "$SCRIPT_FILE"
    echo 'wget -q -O "$TEMP_FILE" "$GITHUB_URL" || { log "Ошибка при загрузке списка"; exit 1; }' >> "$SCRIPT_FILE"

    # Очистка временных файлов
    echo 'log "Очистка временных файлов"; rm -f "$TEMP_FILE" "$UNIQUE_TMP_FILE"' >> "$SCRIPT_FILE"
    chmod +x "$SCRIPT_FILE"
    log "Создан основной скрипт: $SCRIPT_FILE"
}

# Основная установка
main() {
    log "Запуск скрипта установки"

    # Проверки
    check_adguardhome       # Проверяем наличие AdGuardHome
    check_adguardhome_running  # Проверяем, что AdGuardHome запущен

    # Установка
    create_directories      # Создание директорий
    create_config_file      # Создание файла конфигурации
    create_update_script    # Создание основного скрипта

    echo "Установка завершена! Основной скрипт находится по адресу: $SCRIPT_FILE"
    echo "Для запуска выполните: $SCRIPT_FILE"
}

main

#!/bin/sh

# Функция для проверки наличия утилит
check_dependencies() {
    local missing=0
    for cmd in curl jq; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            echo "❌ Утилита $cmd не установлена."
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        echo "Установите необходимые утилиты и повторите попытку."
        exit 1
    fi
}

# Функция для запроса ввода данных
ask_for_input() {
    local prompt="$1"
    local default="$2"
    local input

    if [ -n "$default" ]; then
        prompt="$prompt (по умолчанию: $default): "
    else
        prompt="$prompt: "
    fi

    read -r -p "$prompt" input
    if [ -z "$input" ] && [ -n "$default" ]; then
        input="$default"
    fi
    echo "$input"
}

# Остановка текущего процесса бота
stop_bot() {
    PID=$(pidof domain_bot.sh)
    if [ -n "$PID" ]; then
        kill "$PID"
        echo "✅ Процесс domain_bot.sh остановлен."
    else
        echo "❌ Процесс domain_bot.sh не найден."
    fi
}

# Установка бота
install_bot() {
    echo "=== Установка Telegram-бота для управления доменами ==="

    # Запрос необходимой информации
    BOT_TOKEN=$(ask_for_input "Введите токен вашего бота")
    CHAT_ID=$(ask_for_input "Введите ваш chat_id")
    LOCAL_FILE=$(ask_for_input "Введите путь к файлу доменов" "/opt/etc/AdGuardHome/my-domains-list.conf")
    LOG_DIR=$(ask_for_input "Введите путь к папке для логов" "/opt/etc/AdGuardHome/script_logs")

    # Создание папки для логов
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/bot.log"

    # Создание файла скрипта бота
    BOT_SCRIPT="/opt/bin/domain_bot.sh"
    cat <<EOF > "$BOT_SCRIPT"
#!/bin/sh

# Конфигурация
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
LOCAL_FILE="$LOCAL_FILE"
LOG_FILE="$LOG_FILE"

# Логирование
log() {
    local MESSAGE="\$(date '+%Y-%m-%d %H:%M:%S') - \$*"
    echo "\$MESSAGE" >> "\$LOG_FILE"  # Запись в лог-файл
    echo "\$MESSAGE"                 # Вывод в терминал
}

# Отправка сообщения в Telegram
send_telegram_message() {
    local MESSAGE="\$1"
    curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"\$CHAT_ID\",
            \"text\": \"\$MESSAGE\",
            \"parse_mode\": \"Markdown\"
        }" >> "\$LOG_FILE"
}

# Добавление домена
add_domain() {
    local DOMAIN="\$1"
    if grep -qxF "\$DOMAIN" "\$LOCAL_FILE"; then
        send_telegram_message "❌ Домен *\$DOMAIN* уже существует в списке."
    else
        echo "\$DOMAIN" >> "\$LOCAL_FILE"
        send_telegram_message "✅ Домен *\$DOMAIN* успешно добавлен."
    fi
}

# Удаление домена
remove_domain() {
    local DOMAIN="\$1"
    if grep -qxF "\$DOMAIN" "\$LOCAL_FILE"; then
        sed -i "/^\$DOMAIN\$/d" "\$LOCAL_FILE"
        send_telegram_message "✅ Домен *\$DOMAIN* успешно удалён."
    else
        send_telegram_message "❌ Домен *\$DOMAIN* не найден в списке."
    fi
}

# Показать список доменов
list_domains() {
    if [ -s "\$LOCAL_FILE" ]; then
        DOMAINS=\$(cat "\$LOCAL_FILE" | tr '\n' ', ' | sed 's/, \$/\n/')
        send_telegram_message "📋 Список доменов:\n\$DOMAINS"
    else
        send_telegram_message "📋 Список доменов пуст."
    fi
}

# Обработка входящих сообщений
process_message() {
    local MESSAGE="\$1"
    local COMMAND=\$(echo "\$MESSAGE" | awk '{print \$1}')
    local ARG=\$(echo "\$MESSAGE" | awk '{print \$2}')

    case "\$COMMAND" in
        /start)
            send_telegram_message "👋 Привет! Я бот для управления доменами.\n\nДоступные команды:\n/add <domain> - добавить домен\n/remove <domain> - удалить домен\n/list - показать список доменов"
            ;;
        /add)
            if [ -z "\$ARG" ]; then
                send_telegram_message "❌ Укажите домен для добавления: /add <domain>"
            else
                add_domain "\$ARG"
            fi
            ;;
        /remove)
            if [ -z "\$ARG" ]; then
                send_telegram_message "❌ Укажите домен для удаления: /remove <domain>"
            else
                remove_domain "\$ARG"
            fi
            ;;
        /list)
            list_domains
            ;;
        *)
            # Игнорируем неизвестные команды
            return
            ;;
    esac
}

# Основной цикл бота
log "Бот запущен."
OFFSET=0
while true; do
    UPDATES=\$(curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/getUpdates" \
        -d "offset=\$OFFSET" \
        -d "timeout=60")

    # Обработка каждого обновления
    echo "\$UPDATES" | jq -r '.result[] | @base64' | while read -r UPDATE; do
        UPDATE=\$(echo "\$UPDATE" | base64 -d)
        OFFSET=\$(echo "\$UPDATE" | jq '.update_id')
        MESSAGE=\$(echo "\$UPDATE" | jq -r '.message.text')
        CHAT_ID=\$(echo "\$UPDATE" | jq -r '.message.chat.id')

        if [ "\$CHAT_ID" = "\$CHAT_ID" ]; then
            process_message "\$MESSAGE"
        fi

        # Увеличиваем OFFSET, чтобы избежать повторной обработки
        OFFSET=\$((OFFSET + 1))
    done

    sleep 1
done
EOF

    # Установка прав на выполнение
    chmod +x "$BOT_SCRIPT"

    # Добавление в автозагрузку
    if ! grep -q "$BOT_SCRIPT" /etc/rc.local; then
        sed -i "/exit 0/i $BOT_SCRIPT &" /etc/rc.local
        echo "✅ Скрипт добавлен в автозагрузку."
    else
        echo "ℹ️ Скрипт уже добавлен в автозагрузку."
    fi

    # Запуск бота
    echo "Запуск бота..."
    "$BOT_SCRIPT" &

    echo "=== Установка завершена ==="
    echo "Бот запущен и добавлен в автозагрузку."
    echo "Логи будут сохраняться в файл: $LOG_FILE"
}

# Обновление бота
update_bot() {
    echo "=== Обновление Telegram-бота ==="

    # Проверка, установлен ли бот
    if [ ! -f "/opt/bin/domain_bot.sh" ]; then
        echo "❌ Бот не установлен. Сначала выполните установку."
        return
    fi

    # Остановка текущего процесса бота
    stop_bot

    # Удаление старого скрипта
    rm -f "/opt/bin/domain_bot.sh" && echo "✅ Старый скрипт бота удалён."

    # Установка новой версии
    install_bot
}

# Удаление бота
remove_bot() {
    echo "=== Удаление Telegram-бота ==="

    # Проверка, установлен ли бот
    if [ ! -f "/opt/bin/domain_bot.sh" ]; then
        echo "❌ Бот не установлен."
        return
    fi

    # Остановка текущего процесса бота
    stop_bot

    # Удаление скрипта
    rm -f "/opt/bin/domain_bot.sh" && echo "✅ Скрипт бота удалён."

    # Удаление из автозагрузки
    sed -i '/domain_bot.sh/d' /etc/rc.local && echo "✅ Бот удалён из автозагрузки."

    echo "=== Удаление завершено ==="
}

# Основное меню
main_menu() {
    while true; do
        echo "=== Меню управления ботом ==="
        echo "1. Установить"
        echo "2. Обновить"
        echo "3. Удалить"
        echo "4. Выход"
        read -r -p "Выберите действие (1-4): " choice

        case "$choice" in
            1)
                install_bot
                ;;
            2)
                update_bot
                ;;
            3)
                remove_bot
                ;;
            4)
                echo "Выход."
                exit 0
                ;;
            *)
                echo "❌ Неверный выбор. Попробуйте снова."
                ;;
        esac
    done
}

# Проверка зависимостей
check_dependencies

# Запуск основного меню
main_menu

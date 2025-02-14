---

### **Документация для скрипта `update_sites.sh`**

---

## **Описание**

Этот скрипт предназначен для автоматического обновления списка доменов в AdGuardHome. Скрипт загружает список доменов из удаленного репозитория GitHub и объединяет его с локальным списком, удаляя дублирующиеся записи и поддомены. Результат сохраняется в формате, пригодном для использования в AdGuardHome.

---

## **Особенности**

1. **Формирование итогового файла**:  
   Итоговый файл содержит только уникальные домены первого уровня с добавлением `/hr2`.

2. **Логирование**:
   - **`duplicates.log`**: сохраняет дублирующиеся записи.
   - **`subdomains.log`**: сохраняет поддомены.
   - **`script.log`**: журнал выполнения скрипта.

3. **Поддержка локального файла**:  
   Локальный файл `my-domains-list.conf` используется для ручного добавления доменов, которые могут отсутствовать в основном списке с GitHub.

4. **Многопоточность**:  
   Используется для ускорения обработки большого количества доменов.

5. **Уведомления в Telegram**:  
   Скрипт отправляет итоговый отчет в Telegram, включая количество добавленных и удаленных доменов.

6. **Сравнение с предыдущей версией**:  
   Скрипт сохраняет предыдущую версию файла `ipset.conf` и выводит разницу между текущим и предыдущим обновлением.

---

## **Требования**

- Установленный **AdGuardHome**.
- Доступ к командам `curl`, `awk`, `xargs` и `diff`.
- Директории `/opt/etc/AdGuardHome/` для хранения файлов.
- Токен бота Telegram и chat_id для отправки уведомлений.

---

## **Установка**

1. **Скачивание скрипта**:  
   ```bash
   curl -o /opt/etc/AdGuardHome/update_sites.sh https://raw.githubusercontent.com/pegakmop/keenetic/main/update_sites.sh
   ```

2. **Настройка прав доступа**:  
   Сделайте скрипт исполняемым:
   ```bash
   chmod +x /opt/etc/AdGuardHome/update_sites.sh
   ```

3. **Создание локального файла (если отсутствует)**:  
   ```bash
   vim /opt/etc/AdGuardHome/my-domains-list.conf
   ```

4. **Проверка структуры директорий**:  
   Убедитесь, что структура выглядит следующим образом:
   ```
   /opt/etc/AdGuardHome/
       update_sites.sh
       my-domains-list.conf
       ipset.conf
       script_logs/
           duplicates.log
           subdomains.log
           script.log
           ipset.conf.old
   ```

5. **Настройка Telegram**:
   - Замените `YOUR_BOT_TOKEN` и `YOUR_CHAT_ID` в скрипте на реальные значения.
   - Убедитесь, что бот имеет доступ к отправке сообщений в указанный чат.

---

## **Использование**

1. **Ручной запуск**:  
   Запустите скрипт:
   ```bash
   /opt/etc/AdGuardHome/update_sites.sh
   ```

2. **Результаты выполнения**:
   - **`ipset.conf`**: основной файл с обновленным списком доменов.
   - **`duplicates.log`**: дублирующиеся записи.
   - **`subdomains.log`**: поддомены.
   - **`script.log`**: лог выполнения скрипта.
   - **`ipset.conf.old`**: предыдущая версия файла `ipset.conf`.
   - **Уведомление в Telegram**: итоговый отчет о выполнении.

---

## **Настройка автоматического обновления**

Для автоматического обновления списка доменов каждый день в 6 утра выполните следующие шаги:

### **1. Установка и настройка `cron`**
Если `cron` ещё не установлен, выполните:
```bash
opkg update
opkg install cron
```

Запустите службу `cron`:
```bash
/opt/etc/init.d/S10cron start
```

### **2. Настройка задачи в `cron`**
Откройте файл `crontab`:
```bash
nano /opt/etc/crontab
```

Добавьте строку:
```bash
0 6 * * * root /opt/etc/AdGuardHome/update_sites.sh
```

- **`0 6 * * *`**: задача запускается ежедневно в 6:00 утра.
- **`root`**: задача выполняется от имени пользователя `root`.
- **`/opt/etc/AdGuardHome/update_sites.sh`**: путь к скрипту.

Сохраните изменения (`Ctrl+O`, затем `Enter` и `Ctrl+X`).

Перезапустите `cron`:
```bash
/opt/etc/init.d/S10cron restart
```

---

## **Формат файлов**

### **1. Локальный файл: `my-domains-list.conf`**
Этот файл предназначен для **ручного добавления доменов**, которые могут отсутствовать в основном списке, загружаемом с GitHub. Каждый домен должен быть указан на отдельной строке. Пример:

```
example.com
test.com
sub.example.com
```

- **Важно**: Домены из этого файла будут объединены с основным списком, загруженным с GitHub.
- Если домен уже присутствует в основном списке, он будет обработан как дубликат и сохранен в `duplicates.log`.

---

### **Пример использования:**
1. Добавьте домен `example.com` в файл `my-domains-list.conf`:
   ```bash
   echo "example.com" >> /opt/etc/AdGuardHome/my-domains-list.conf
   ```

2. Запустите скрипт:
   ```bash
   /opt/etc/AdGuardHome/update_sites.sh
   ```

3. Проверьте результат:
   - Если `example.com` отсутствовал в основном списке, он будет добавлен в `ipset.conf`.
   - Если `example.com` уже был в основном списке, он будет записан в `duplicates.log`.

---

### **2. Итоговый файл: `ipset.conf`**
Формат итогового файла:
```
example.com/hr2
test.com/hr2
```

---

## **Результаты**

### **Лог выполнения: `script.log`**
Пример:
```
2025-01-18 14:00:00 - Загрузка списка сайтов из https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-raw.lst
2025-01-18 14:00:01 - Обработка файла: /opt/etc/AdGuardHome/my-domains-list.conf
2025-01-18 14:00:02 - Обработка файла: /tmp/tempfile.12345
2025-01-18 14:00:03 - Формирование итогового файла: /opt/etc/AdGuardHome/ipset.conf
2025-01-18 14:00:03 - Скрипт завершён. Файл /opt/etc/AdGuardHome/ipset.conf успешно обновлён.
```

### **Лог дублей: `duplicates.log`**
Содержит дублирующиеся записи:
```
duplicate1.com
duplicate2.com
```

### **Лог поддоменов: `subdomains.log`**
Содержит поддомены, которые были исключены из итогового файла:
```
sub.example.com
test.sub.example.com
```

### **Уведомление в Telegram**
Пример итогового сообщения:
```
🔄 *Скрипт обновления доменов завершён.*

📥 *Загрузка данных:*
- Список доменов успешно загружен с GitHub.

📊 *Итоговый отчет:*
- Уникальных доменов: 930
- Дубликатов: 238
- Поддоменов: 363

🔄 *Изменения в файле ipset.conf:*
- Добавлено доменов: 5
- Удалено доменов: 2

✅ *Файл /opt/etc/AdGuardHome/ipset.conf успешно обновлён.*
```

---

## **Отладка**

1. **Проверка прав доступа**:
   ```bash
   chmod 755 /opt/etc/AdGuardHome/
   chmod 644 /opt/etc/AdGuardHome/*
   ```

2. **Проверка работы `cron`**:
   ```bash
   ps | grep cron
   ```

3. **Просмотр логов выполнения**:
   ```bash
   tail -n 20 /opt/etc/AdGuardHome/script_logs/script.log
   ```

4. **Проверка Telegram-уведомлений**:
   Убедитесь, что бот имеет доступ к чату и токен/chat_id указаны верно.

---

## **Лицензия**
---

## **Контакты**

---

### **Изменения в документации:**
1. **Уточнение о локальном файле `my-domains-list.conf`**:
   - Файл используется для ручного добавления доменов, которые могут отсутствовать в основном списке с GitHub.
   - Добавлен пример использования.

2. **Добавлен раздел "Уведомления в Telegram"**:
   - Описана возможность отправки уведомлений в Telegram.
   - Добавлен пример итогового сообщения.

3. **Добавлен раздел "Сравнение с предыдущей версией"**:
   - Описана возможность сравнения текущего и предыдущего обновлений.
   - Добавлен пример вывода изменений.

4. **Обновлена структура директорий**:
   - Логи и предыдущая версия файла `ipset.conf` теперь хранятся в папке `script_logs`.

5. **Добавлены примеры**:
   - Примеры вывода логов и сообщений в Telegram.

6. **Уточнены шаги настройки**:
   - Добавлены инструкции по настройке Telegram и автоматического обновления через `cron`.

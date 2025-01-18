### **Документация для скрипта `update_sites.sh`**

---

## **Описание**

Этот скрипт предназначен для автоматического обновления списка доменов в AdGuardHome. Скрипт загружает список доменов из удаленного репозитория GitHub и объединяет его с локальным списком, удаляя дублирующиеся записи и поддомены. Результат сохраняется в формате, пригодном для использования в AdGuardHome.

---

## **Особенности**

1. **Формирование итогового файла**:  
   Итоговый файл содержит только уникальные домены первого уровня с добавлением `/bypass,bypass6`.

2. **Логирование**:
   - **`duplicates.log`**: сохраняет дублирующиеся записи.
   - **`subdomains.log`**: сохраняет поддомены.
   - **`script.log`**: журнал выполнения скрипта.

3. **Поддержка локального файла**:  
   Локальный файл `my-domains-list.conf` объединяется с удаленным списком.

4. **Многопоточность**:  
   Используется для ускорения обработки большого количества доменов.

---

## **Требования**

- Установленный **AdGuardHome**.
- Доступ к командам `curl`, `awk` и `xargs`.
- Директории `/opt/etc/AdGuardHome/` для хранения файлов.

---

## **Установка**

1. **Скачивание скрипта**:  
   ```bash
   curl -o /opt/etc/AdGuardHome/update_sites.sh https://raw.githubusercontent.com/mdxl/keenetic/main/update_sites.sh
   ```

2. **Настройка прав доступа**:  
   Сделайте скрипт исполняемым:
   ```bash
   chmod +x /opt/etc/AdGuardHome/update_sites.sh
   ```

3. **Создание локального файла (если отсутствует)**:  
   ```bash
   touch /opt/etc/AdGuardHome/my-domains-list.conf
   ```

4. **Проверка структуры директорий**:  
   Убедитесь, что структура выглядит следующим образом:
   ```
   /opt/etc/AdGuardHome/
       update_sites.sh
       my-domains-list.conf
       ipset.conf
       duplicates.log
       subdomains.log
       script.log
   ```

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
Файл должен содержать домены, которые нужно добавить в итоговый список, по одному на строку:
```
example.com
test.com
sub.example.com
```

### **2. Итоговый файл: `ipset.conf`**
Формат итогового файла:
```
example.com/bypass,bypass6
test.com/bypass,bypass6
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
   tail -n 20 /opt/etc/AdGuardHome/script.log
   ```

---

## **Лицензия**

Проект распространяется под лицензией MIT. Подробности см. в файле [LICENSE](LICENSE).

---

## **Контакты**

Если у вас есть предложения или возникли проблемы, создайте [issue](https://github.com/mdxl/keenetic/issues) в репозитории.

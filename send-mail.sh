#!/bin/bash

# Параметры
LOG_FILE="/var/log/nginx/access.log"   # Путь к вашему логу
ERROR_LOG_FILE="/var/log/nginx/error.log" # Путь к логу ошибок
EMAIL="example@example.com"         # Email для отправки
LOCK_FILE="/tmp/cron_email_report.lock"
TEMP_DIR="/tmp/cron_email_report"
PREV_LOG_CHECKPOINT="$TEMP_DIR/last_position"

# Создание временной директории
mkdir -p "$TEMP_DIR"

# Проверка на существование файла блокировки
if [ -f "$LOCK_FILE" ]; then
  echo "Скрипт уже запущен. Завершение." >&2
  exit 1
fi

# Создаем файл блокировки
trap "rm -f $LOCK_FILE" EXIT
trap "exit 1" INT TERM

touch "$LOCK_FILE"

# Получаем текущую позицию в логах
CURRENT_LOG_SIZE=$(wc -c < "$LOG_FILE")
PREV_LOG_SIZE=$(cat "$PREV_LOG_CHECKPOINT" 2>/dev/null || echo 0)

echo "$CURRENT_LOG_SIZE" > "$PREV_LOG_CHECKPOINT"

# Извлечение новых записей
NEW_LOG_ENTRIES=$(tail -c +$((PREV_LOG_SIZE + 1)) "$LOG_FILE")
NEW_ERROR_ENTRIES=$(tail -c +$((PREV_LOG_SIZE + 1)) "$ERROR_LOG_FILE")

# Анализ логов
TOP_IPS=$(echo "$NEW_LOG_ENTRIES" | awk '{print $1}' | sort | uniq -c | sort -nr | head -10)
TOP_URLS=$(echo "$NEW_LOG_ENTRIES" | awk '{print $7}' | sort | uniq -c | sort -nr | head -10)
HTTP_CODES=$(echo "$NEW_LOG_ENTRIES" | awk '{print $9}' | sort | uniq -c | sort -nr)
ERRORS="$NEW_ERROR_ENTRIES"

# Формируем письмо
REPORT="Subject: Hourly Web Server Report

Top IPs with most requests:
$TOP_IPS

Top URLs:
$TOP_URLS

HTTP Response Codes:
$HTTP_CODES

Web Server Errors:
$ERRORS"

# Отправка письма
echo -e "$REPORT" | sendmail -t "$EMAIL"

# Удаляем файл блокировки
rm -f "$LOCK_FILE"

exit 0
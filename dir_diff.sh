#!/bin/bash
#
# Использование:
# ./dir_diff <путь к проекту> '<команды для сборки>' 
# 
# Также возможно использование с флагом -o DIR или --output DIR
# ./dir_diff.sh <путь_к_проекту> '<команда_сборки>' <-o или --output> <DIR>
#
#
# Пример с nginx:
# 	sudo ./dir_diff.sh nginx "./configure && make"
#
set -e

# Проверка аргументов
if [ "$#" -lt 2 ]; then
	echo "Использование: $0 <путь_к_проекту> <\"команда_сборки\"> [-o <выходная_директория>]" >&2
	echo "Пример: $0 ./myapp \"echo 'text' > file.txt\"" >&2
	exit 1
fi

PROJECT_DIR_RAW="$1"
BUILD_CMD="$2"
OUTPUT_DIR=""

if [ "$#" -ge 4 ] && { [ "$3" = "-o" ] || [ "$3" = "--output" ]; }; then
	OUTPUT_DIR="$4"
fi

# Подготовка названий директорий
PROJECT_DIR="$(realpath "$PROJECT_DIR_RAW")"
if [ -z "$OUTPUT_DIR" ]; then
	PROJECT_NAME="$(basename "$PROJECT_DIR")"
	OUTPUT_DIR="${PROJECT_NAME}-diff"
fi

if [ ! -d "$PROJECT_DIR" ]; then
	echo "Ошибка: директория не существует: $PROJECT_DIR" >&2
	exit 1
fi

# Создание копии 
TEMP_CLON=$(mktemp -d)
echo "Создание копии проекта"
cp -r "$PROJECT_DIR"/. "$TEMP_CLON/"

# Запуск сборки
echo "Запуск сборки: $BUILD_CMD"
(cd "$PROJECT_DIR" && bash -c "$BUILD_CMD")

# Подготовка diff директории
rm -rf "$OUTPUT_DIR" 2>/dev/null || true
mkdir -p "$OUTPUT_DIR"

# Сравнение файлов напрямую 
echo "Поиск изменений"

while IFS= read -r -d '' file_after; do
	# Относительный путь
	rel_path="${file_after#$PROJECT_DIR}"
	rel_path="${rel_path#/}"  # убираем начальный слеш если есть
	rel_path="./$rel_path"    # добавляем ./ для совместимости с путями из копии
  
	# Путь в оригинальной копии (до сборки)
	file_before="$TEMP_CLON/$rel_path"
  
	# Целевой путь в diff
	target_file="$OUTPUT_DIR/$rel_path"
  
	# Создаём целевую директорию
	mkdir -p "$(dirname "$target_file")"
  
	# Проверяем: новый файл или изменённый?
	if [ ! -f "$file_before" ]; then
	# Новый файл
	echo "Новый: ${rel_path#.}"
	cp -p "$file_after" "$target_file"
	elif ! cmp -s "$file_before" "$file_after"; then
	# Изменённый файл
	echo "Изменён: ${rel_path#.}"
	cp -p "$file_after" "$target_file"
	fi
done < <(find "$PROJECT_DIR" -type f -print0)

# Очистка
rm -rf "$TEMP_CLON"

echo "Готово! Изменения сохранены в: $(realpath "$OUTPUT_DIR")"

#!/usr/bin/env python3
"""
Генерирует SQL через OpenAI Codex CLI на основе схемы таблиц и запроса пользователя.
Использует установленный codex с твоей подпиской.
"""
import sys
import os
import json
import subprocess
import tempfile


def find_codex():
    """Ищем codex CLI."""
    candidates = [
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
        os.path.expanduser("~/.local/bin/codex"),
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    
    # Попробуем через which
    try:
        result = subprocess.run(["which", "codex"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except:
        pass
    
    return None


def generate_sql(user_query: str, tables_json: str, history_json: str = "[]") -> str:
    """Генерирует SQL через Codex CLI."""
    
    codex_path = find_codex()
    if not codex_path:
        return json.dumps({
            "error": "Codex CLI не найден. Установи его: https://openai.com/codex"
        })
    
    tables = json.loads(tables_json)
    history = json.loads(history_json) if history_json else []
    
    # Формируем промпт со схемой и примерами данных
    schema_text = ""
    for table in tables:
        tname = table['name']
        schema_text += f"\n-- Таблица \"{tname}\" ({table['rowCount']} строк)\n"
        schema_text += f"-- Колонки:\n"
        columns = table["columns"]
        for c in columns:
            schema_text += f'--   \"{c["name"]}\" ({c["type"]})\n'
        
        # Добавляем примеры данных если есть
        sample_rows = table.get("sampleRows", [])
        if sample_rows and columns:
            schema_text += f"-- Примеры данных (первые {len(sample_rows)} строк):\n"
            col_names = [c["name"] for c in columns]
            # Форматируем как табличку
            for i, row in enumerate(sample_rows):
                schema_text += f"--   Строка {i+1}:\n"
                for j, val in enumerate(row):
                    if j < len(col_names):
                        # Обрезаем длинные значения
                        val_str = str(val) if val else "NULL"
                        if len(val_str) > 50:
                            val_str = val_str[:47] + "..."
                        schema_text += f'--     \"{col_names[j]}\": {val_str}\n'
    
    # Формируем историю чата
    history_text = ""
    if history:
        history_text = "\n\nИстория диалога:\n"
        for msg in history:
            role = "Пользователь" if msg["role"] == "user" else "Ассистент"
            history_text += f"{role}: {msg['content']}\n"
    
    prompt = f"""Ты — SQL-ассистент. Сгенерируй SQL-запрос для DuckDB (диалект PostgreSQL).

ВАЖНЫЕ ПРАВИЛА:
1. ВСЕГДА используй двойные кавычки для ВСЕХ имён таблиц и колонок: "table_name", "column_name"
2. Если в запросе одна таблица, можно не указывать префикс таблицы для колонок
3. Для строковых значений используй одинарные кавычки: 'value'
4. Выдай ТОЛЬКО SQL-код без объяснений и без markdown-обёрток

Доступные таблицы:
{schema_text}
{history_text}
Текущий запрос пользователя: {user_query}

SQL:"""

    try:
        # Создаём временный файл для вывода
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            output_file = f.name
        
        # Запускаем codex exec
        result = subprocess.run(
            [
                codex_path, "exec",
                "--ephemeral",  # Не сохранять сессию
                "--skip-git-repo-check",  # Не требовать git-репозиторий
                "-o", output_file,  # Записать ответ в файл
                prompt
            ],
            capture_output=True,
            text=True,
            timeout=120  # 2 минуты таймаут
        )
        
        # Читаем результат
        if os.path.exists(output_file):
            with open(output_file, 'r') as f:
                sql = f.read().strip()
            os.unlink(output_file)
            
            if sql:
                # Убираем markdown-обёртку если есть
                if sql.startswith("```"):
                    lines = sql.split("\n")
                    # Убираем первую строку (```sql или ```) и последнюю (```)
                    if lines[-1].strip() == "```":
                        lines = lines[1:-1]
                    else:
                        lines = lines[1:]
                    sql = "\n".join(lines)
                
                return json.dumps({"sql": sql.strip()})
        
        # Если файл пустой, проверяем stderr
        if result.stderr:
            return json.dumps({"error": result.stderr})
        
        return json.dumps({"error": "Codex не вернул ответ"})
            
    except subprocess.TimeoutExpired:
        return json.dumps({"error": "Таймаут: codex не ответил за 2 минуты"})
    except Exception as e:
        return json.dumps({"error": str(e)})
    finally:
        # Чистим временный файл если остался
        try:
            if 'output_file' in locals() and os.path.exists(output_file):
                os.unlink(output_file)
        except:
            pass


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: generate_sql.py <query> <tables_json> [history_json]"}))
        sys.exit(1)
    
    history = sys.argv[3] if len(sys.argv) > 3 else "[]"
    result = generate_sql(sys.argv[1], sys.argv[2], history)
    print(result)

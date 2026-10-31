---
subject: programming
lesson_id: programming.application_security_injection_and_secrets
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Безопасность приложений: инъекции и секреты / Application Security: Injection and Secrets

## Русский

### Цель

Видеть границу доверия в программе, показать на работающем примере, как SQL-инъекция обходит проверку, защититься плейсхолдерами, правильно создавать токены и хранить ключи вне кода.

### Идея и механизм

Безопасность начинается с вопроса: какие данные приходят из-за границы доверия? Всё, что вводит пользователь или присылает сеть, — недоверенные данные. Опасно, когда их вставляют прямо в команду, которую выполнит другая система, например в SQL-запрос.

```python
import sqlite3
import secrets

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE users (name TEXT, role TEXT)")
db.executemany("INSERT INTO users VALUES (?, ?)", [("ana", "student"), ("admin", "owner")])

user_input = "nobody' OR '1'='1"

unsafe = db.execute(f"SELECT name FROM users WHERE name = '{user_input}'").fetchall()
safe = db.execute("SELECT name FROM users WHERE name = ?", (user_input,)).fetchall()
print(len(unsafe), len(safe))

token = secrets.token_hex(16)
print(len(token))
```

Программа печатает 2 и 0, а затем 32. В первом запросе ввод склеен со строкой, кавычка из ввода закрыла строку SQL, и условие OR '1'='1' стало истинным для всех: запрос вернул всех пользователей, включая admin. Во втором запросе значение передано через плейсхолдер ?: база считает его просто текстом, и такого имени нет. Документация Python прямо советует всегда использовать плейсхолдеры вместо форматирования строк.

Секреты — отдельная тема. Токены и пароли создают модулем secrets, а не random: random предназначен для моделирования, а не для защиты. Ключи нельзя писать в код и коммитить в git. ColiDev так и устроен: ключи ИИ-сервисов он берёт из Связки ключей macOS, а запасной файл .env исключён из git через .gitignore.

### Исследуй и потренируйся

Запусти программу и попробуй другой ввод для небезопасного запроса, например "admin' --". Объясни, что произошло. Затем перепиши функцию поиска пользователя так, чтобы она принимала имя и всегда использовала плейсхолдер, и проверь её на тех же опасных строках.

### Вопрос

Что вернёт небезопасный запрос из примера при вводе "nobody' OR '1'='1"?

### Варианты

- Всех пользователей — 2 строки: кавычка закрыла строку SQL, и условие OR '1'='1' истинно для каждой записи.
- Ни одной строки: пользователя с именем nobody нет.
- Ошибку: база данных сама отклоняет подозрительный ввод.

### Ответ

1

### Разбор

При склейке строк ввод становится частью кода запроса: WHERE name = 'nobody' OR '1'='1'. Второе условие истинно всегда, поэтому вернулись обе записи. Ноль строк даёт только безопасный запрос с плейсхолдером, а сама база ничего не отклоняет — защищать запрос должен программист.

### Границы модели

Урок показывает одну уязвимость и одну защиту. Настоящая безопасность шире: проверка прав доступа, обновления зависимостей, шифрование, журналы и разбор угроз для каждой части системы. Пример с инъекцией запускай только в своей учебной базе — испытывать чужие системы без разрешения нельзя.

## English

### Goal

See the trust boundary in a program, show with working code how SQL injection bypasses a check, defend with placeholders, generate tokens correctly, and keep keys out of code.

### Idea and mechanism

Security starts with a question: which data come from across the trust boundary? Everything a user types or the network sends is untrusted. It is dangerous when such data are inserted directly into a command another system will run, such as an SQL query.

```python
import sqlite3
import secrets

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE users (name TEXT, role TEXT)")
db.executemany("INSERT INTO users VALUES (?, ?)", [("ana", "student"), ("admin", "owner")])

user_input = "nobody' OR '1'='1"

unsafe = db.execute(f"SELECT name FROM users WHERE name = '{user_input}'").fetchall()
safe = db.execute("SELECT name FROM users WHERE name = ?", (user_input,)).fetchall()
print(len(unsafe), len(safe))

token = secrets.token_hex(16)
print(len(token))
```

The program prints 2 and 0, then 32. In the first query the input is glued into the string, the quote from the input closed the SQL string, and the condition OR '1'='1' became true for everyone: the query returned all users, including admin. In the second query the value is passed through the ? placeholder: the database treats it as plain text, and no such name exists. The Python documentation explicitly advises always using placeholders instead of string formatting.

Secrets are a separate matter. Tokens and passwords are generated with the secrets module, not random: random is designed for modelling, not for security. Keys must not be written into code or committed to git. ColiDev works this way: it takes AI service keys from the macOS Keychain, and the fallback .env file is excluded from git by .gitignore.

### Explore and practise

Run the program and try another input for the unsafe query, such as "admin' --". Explain what happened. Then rewrite a user lookup function so that it takes a name and always uses a placeholder, and test it on the same dangerous strings.

### Question

What does the unsafe query in the example return for the input "nobody' OR '1'='1"?

### Options

- All users, 2 rows: the quote closed the SQL string, and the condition OR '1'='1' is true for every record.
- No rows: there is no user named nobody.
- An error: the database itself rejects suspicious input.

### Answer

1

### Explanation

When strings are glued together the input becomes part of the query's code: WHERE name = 'nobody' OR '1'='1'. The second condition is always true, so both records came back. Zero rows come only from the safe query with a placeholder, and the database itself rejects nothing: the programmer must protect the query.

### Limits

The lesson shows one vulnerability and one defence. Real security is broader: access checks, dependency updates, encryption, logging, and threat analysis for every part of a system. Run the injection example only on your own practice database: testing other people's systems without permission is not allowed.

## Sources

- Python Software Foundation, *The Python Standard Library*, “sqlite3 — DB-API 2.0 interface for SQLite databases” (consulted 2026-10-31): ? placeholders bind values, and placeholders should always be used instead of string formatting to avoid SQL injection attacks: [docs.python.org, sqlite3](https://docs.python.org/3/library/sqlite3.html)
- Python Software Foundation, *The Python Standard Library*, “secrets — Generate secure random numbers for managing secrets” (consulted 2026-10-31): cryptographically strong random numbers for passwords and tokens, token_hex, and preferring secrets over the random module, which is designed for modelling and simulation: [docs.python.org, secrets](https://docs.python.org/3/library/secrets.html)
- ColiDev source code: provider keys loaded from the macOS Keychain service “ColiDev” with a .env fallback (`01_Projects/orchestrator.py`), and `.env` listed in `.gitignore`.
- The lesson paraphrases the documentation and does not copy its text.

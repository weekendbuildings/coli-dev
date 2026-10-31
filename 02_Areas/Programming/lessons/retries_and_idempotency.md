---
subject: programming
lesson_id: programming.retries_and_idempotency
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Отказоустойчивость: повторы запросов и идемпотентность / Resilience: Retries and Idempotency

## Русский

### Цель

Понимать, почему в сети запросы приходится повторять, отличать идемпотентные операции, которые можно безопасно повторить, от неидемпотентных и защищать неидемпотентные операции уникальным ключом запроса.

### Идея и механизм

В распределённой системе ответ может потеряться: клиент отправил запрос, сервер его выполнил, но ответ не дошёл. Клиент не знает, выполнилась ли операция, и повторяет запрос. Безопасно ли это?

Метод называют идемпотентным, если несколько одинаковых запросов дают на сервере тот же результат, что и один. В HTTP все безопасные методы вроде GET идемпотентны, а также PUT и DELETE; POST и PATCH идемпотентность не гарантируют. Идемпотентный запрос клиент может спокойно повторить, если не уверен, дошёл ли он. А повтор POST может, например, записать одну и ту же попытку дважды. Для таких операций предложен заголовок Idempotency-Key: клиент посылает уникальный ключ, и сервер выполняет операцию с этим ключом только один раз.

```python
class Server:
    def __init__(self):
        self.attempts = []
        self.progress = {}
        self.seen_keys = set()

    def post_attempt(self, lesson):
        self.attempts.append(lesson)

    def put_progress(self, lesson, value):
        self.progress[lesson] = value

    def post_attempt_with_key(self, key, lesson):
        if key in self.seen_keys:
            return
        self.seen_keys.add(key)
        self.attempts.append(lesson)

server = Server()
for _ in range(2):  # the first reply was lost, so the client sends the request again
    server.post_attempt("pH")
for _ in range(2):
    server.put_progress("pH", "done")
print(len(server.attempts), server.progress)

before = len(server.attempts)
for _ in range(2):
    server.post_attempt_with_key("attempt-42", "pH")
print(len(server.attempts) - before)
```

Программа печатает 2 {'pH': 'done'} и затем 1: повтор POST записал попытку дважды, повтор PUT оставил то же состояние, а с ключом повторённый POST записался один раз.

### Исследуй и потренируйся

Добавь в класс метод delete_progress и проверь, что двойной вызов даёт тот же результат, что и одинарный. Затем подумай, какой ключ должен прислать клиент, чтобы две разные настоящие попытки не склеились в одну.

### Вопрос

Клиент записывает попытку ответа запросом POST, но ответ потерялся, и клиент повторил запрос. Сколько попыток окажется на сервере, если ключа идемпотентности нет?

### Варианты

- Две: POST не идемпотентен, и повторный запрос выполнился ещё раз.
- Одна: сервер сам понимает, что это повтор.
- Ни одной: потерянный ответ отменяет операцию.

### Ответ

1

### Разбор

Сервер выполнил оба запроса, потому что для него это два обычных POST, — потерялся только ответ, а не сама операция. Без ключа сервер не может отличить повтор от новой попытки. PUT с тем же значением или POST с одним и тем же ключом идемпотентности дали бы одну запись.

### Границы модели

Пример упрощён: настоящему серверу нужно хранить ключи ограниченное время и защищать их от гонок, когда два одинаковых запроса приходят почти одновременно. Заголовок Idempotency-Key пока предложение IETF, а не окончательный стандарт. Повторять запросы нужно с паузами и ограничением числа попыток, чтобы не перегрузить сервер.

## English

### Goal

Understand why requests have to be retried over a network, distinguish idempotent operations that can be safely repeated from non-idempotent ones, and protect non-idempotent operations with a unique request key.

### Idea and mechanism

In a distributed system a reply can be lost: the client sent a request, the server carried it out, but the reply never arrived. The client does not know whether the operation happened and sends the request again. Is that safe?

A method is called idempotent if several identical requests have the same effect on the server as one. In HTTP all safe methods such as GET are idempotent, as are PUT and DELETE; POST and PATCH are not guaranteed to be. A client can safely retry an idempotent request when unsure whether it arrived. Retrying a POST, however, can record the same attempt twice. For such operations the Idempotency-Key header has been proposed: the client sends a unique key, and the server carries out the operation with that key only once.

```python
class Server:
    def __init__(self):
        self.attempts = []
        self.progress = {}
        self.seen_keys = set()

    def post_attempt(self, lesson):
        self.attempts.append(lesson)

    def put_progress(self, lesson, value):
        self.progress[lesson] = value

    def post_attempt_with_key(self, key, lesson):
        if key in self.seen_keys:
            return
        self.seen_keys.add(key)
        self.attempts.append(lesson)

server = Server()
for _ in range(2):  # the first reply was lost, so the client sends the request again
    server.post_attempt("pH")
for _ in range(2):
    server.put_progress("pH", "done")
print(len(server.attempts), server.progress)

before = len(server.attempts)
for _ in range(2):
    server.post_attempt_with_key("attempt-42", "pH")
print(len(server.attempts) - before)
```

The program prints 2 {'pH': 'done'} and then 1: the retried POST recorded the attempt twice, the retried PUT left the same state, and with a key the retried POST was recorded once.

### Explore and practise

Add a delete_progress method to the class and check that calling it twice has the same effect as once. Then think about which key the client should send so that two genuinely different attempts are not merged into one.

### Question

A client records an answer attempt with a POST request, but the reply was lost and the client sent the request again. How many attempts end up on the server if there is no idempotency key?

### Options

- Two: POST is not idempotent, and the repeated request ran again.
- One: the server recognises the repeat by itself.
- None: a lost reply cancels the operation.

### Answer

1

### Explanation

The server carried out both requests, because to it they are two ordinary POSTs; only the reply was lost, not the operation. Without a key the server cannot tell a retry from a new attempt. A PUT with the same value, or a POST with the same idempotency key, would give one record.

### Limits

The example is simplified: a real server must keep keys for a limited time and guard against races when two identical requests arrive almost at once. The Idempotency-Key header is still an IETF proposal, not a final standard. Retries should use pauses and a limit on attempts so as not to overload the server.

## Sources

- MDN Web Docs, “Idempotent” (consulted 2026-10-31): the definition of an idempotent HTTP method, safe methods plus PUT and DELETE as idempotent, POST and PATCH not guaranteed to be, and safe retries of idempotent requests: [MDN, Idempotent](https://developer.mozilla.org/en-US/docs/Glossary/Idempotent)
- R. Fielding, M. Nottingham, J. Reschke, “HTTP Semantics”, RFC 9110, IETF, 2022, section 9.2.2 “Idempotent Methods” (consulted 2026-10-31): the normative definition of idempotent methods and automatic retries after connection failures: [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html)
- J. Jena, S. Dalal, D. Tishkin, “The Idempotency-Key HTTP Header Field”, IETF Internet-Draft draft-ietf-httpapi-idempotency-key-header-08 (consulted 2026-10-31): a request header to make non-idempotent methods such as POST or PATCH fault-tolerant: [IETF Datatracker](https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/)
- The lesson paraphrases these sources and does not copy their text.

---
subject: programming
lesson_id: programming.http_and_apis
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 365
---

# HTTP и API: запросы, ответы и коды состояния / HTTP and APIs: Requests, Responses, and Status Codes

## Русский

### Цель

Описывать обмен по HTTP как запрос клиента и ответ сервера, различать методы и пять классов кодов состояния и понимать, как приложение Cause & Course говорит со своим backend.

### Идея и механизм

HTTP — протокол обмена данными в вебе, построенный по схеме «клиент — сервер». Клиент, например браузер или приложение, отправляет запрос; сервер отвечает. Запрос содержит метод, путь и заголовки: `GET` просит получить ресурс, `POST` отправляет данные на сервер. Ответ начинается со строки состояния, например `HTTP/1.1 200 OK`, затем идут заголовки и тело — HTML, изображение или JSON.

HTTP не хранит состояние: между двумя запросами по одному соединению нет связи, и сервер сам по себе не помнит предыдущий запрос. Если нужно продолжение — вход в аккаунт, корзина, — это добавляют поверх, например через cookie.

Код состояния — трёхзначное число, и первая цифра задаёт класс ответа: 1xx — информационные, 2xx — успешные (`200 OK`), 3xx — перенаправления, 4xx — ошибки клиента (`404 Not Found`: сервер не нашёл ресурс), 5xx — ошибки сервера (`500 Internal Server Error`: сервер столкнулся с ситуацией, которую не умеет обработать). По первой цифре сразу видно, чья ошибка: 4xx — исправлять запрос, 5xx — исправлять сервер.

API — это набор адресов и правил, по которым одна программа обращается к другой. Приложение Cause & Course так и работает: интерфейс на Swift отправляет HTTP-запросы локальному backend на Python, например `GET /api/status`, чтобы проверить, что backend запущен и совместим, и получает ответ в JSON.

### Исследуй и потренируйся

Для каждого кода определи класс и чья это ошибка: 201, 301, 403, 404, 503. Затем напиши, какой метод и какой путь ты бы использовал, чтобы получить список уроков, а какой — чтобы отправить ответ на вопрос.

### Вопрос

Приложение запросило урок по адресу, а сервер ответил кодом 404. Что это значит?

### Варианты

- Ошибка клиента: сервер не нашёл запрошенный ресурс — скорее всего, неверный адрес.
- Ошибка сервера: сервер упал и не может обработать ни один запрос.
- Успех: сервер нашёл урок и вернул его в теле ответа.

### Ответ

1

### Разбор

Коды 4xx означают ошибки клиента, и 404 Not Found говорит, что сервер не нашёл ресурс по этому адресу: в браузере это обычно неверный URL, в API — неверный путь или несуществующая запись. Ошибки самого сервера — это коды 5xx, например 500, а успешные ответы — 2xx, например 200 OK.

### Границы модели

Урок описывает HTTP/1.1 в упрощённом виде; HTTP/2 и HTTP/3 передают сообщения в другом формате, но с тем же смыслом запросов, ответов и кодов. Значение кода зависит и от метода, и от договорённостей конкретного API. Не отправляй пароли и личные данные по незашифрованному HTTP — для этого есть HTTPS.

## English

### Goal

Describe an HTTP exchange as a client request and a server response, distinguish methods and the five classes of status codes, and understand how the Cause & Course app talks to its backend.

### Idea and mechanism

HTTP is the protocol for exchanging data on the Web, built on a client-server model. A client, such as a browser or an app, sends a request; the server sends a response. A request contains a method, a path, and headers: `GET` asks to fetch a resource, `POST` sends data to the server. A response starts with a status line, for example `HTTP/1.1 200 OK`, followed by headers and a body: HTML, an image, or JSON.

HTTP is stateless: there is no link between two requests on the same connection, and the server by itself does not remember the previous request. When continuity is needed, such as a login or a shopping cart, it is added on top, for example with cookies.

A status code is a three-digit number, and its first digit sets the class of response: 1xx informational, 2xx successful (`200 OK`), 3xx redirection, 4xx client errors (`404 Not Found`: the server cannot find the resource), and 5xx server errors (`500 Internal Server Error`: the server has hit a situation it does not know how to handle). The first digit shows at once whose fault it is: fix the request for 4xx, fix the server for 5xx.

An API is a set of addresses and rules by which one program calls another. The Cause & Course app works this way: the Swift interface sends HTTP requests to the local Python backend, for example `GET /api/status` to check that the backend is running and compatible, and receives a JSON response.

### Explore and practise

For each code, name its class and whose fault it is: 201, 301, 403, 404, 503. Then write which method and path you would use to get a list of lessons, and which to submit an answer to a question.

### Question

The app requested a lesson at an address, and the server answered with code 404. What does that mean?

### Options

- A client error: the server could not find the requested resource, most likely a wrong address.
- A server error: the server has crashed and cannot handle any request.
- Success: the server found the lesson and returned it in the response body.

### Answer

1

### Explanation

4xx codes mean client errors, and 404 Not Found says the server could not find a resource at that address: in a browser this is usually a wrong URL, in an API a wrong path or a record that does not exist. Errors of the server itself are 5xx codes, such as 500, and successful responses are 2xx, such as 200 OK.

### Limits

The lesson describes HTTP/1.1 in simplified form; HTTP/2 and HTTP/3 carry messages in a different format but with the same meaning of requests, responses, and codes. A code's meaning also depends on the method and on the conventions of a particular API. Do not send passwords or personal data over unencrypted HTTP; HTTPS exists for that.

## Sources

- MDN Web Docs, “Overview of HTTP” (consulted 2026-10-26): HTTP as a client-server protocol of requests and responses, an example `GET` request and `200 OK` response, and statelessness: [MDN, Overview of HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Overview)
- MDN Web Docs, “HTTP response status codes” (consulted 2026-10-26): the five classes of status codes defined by RFC 9110, and the meanings of 200 OK, 404 Not Found, and 500 Internal Server Error: [MDN, HTTP response status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status)
- ColiDev source code: the app checks its local backend with `GET /api/status` (`macOS/ColiDev/App/AppModels.swift`, `orchestratorResponds`).
- The lesson paraphrases the documentation and does not copy its text.

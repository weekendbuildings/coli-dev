---
subject: programming
lesson_id: programming.concurrency_async_await
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Конкурентность: async и await в Python / Concurrency: async and await in Python

## Русский

### Цель

Понимать, как асинхронная программа выполняет несколько ожиданий одновременно, запускать сопрограммы через asyncio.run и asyncio.gather и отличать задачи, которые ускоряет asyncio, от тех, которые оно не ускоряет.

### Идея и механизм

Многие программы большую часть времени ждут: ответа сервера, чтения файла, модели ИИ. Последовательная программа ждёт по очереди, и ожидания складываются. Асинхронная программа, пока одна задача ждёт, отдаёт управление другим.

В Python для этого есть сопрограммы — функции, объявленные как async def. Просто вызвать сопрограмму недостаточно: вызов только создаёт объект, а выполнение начинается, когда её запускает asyncio.run или когда её ожидают через await. Функция asyncio.gather запускает несколько сопрограмм конкурентно и возвращает список результатов в том же порядке, в каком их передали. А await asyncio.sleep(...) приостанавливает текущую задачу и даёт поработать другим.

```python
import asyncio
import time

async def fetch(name, delay):
    await asyncio.sleep(delay)
    return name

async def main():
    start = time.perf_counter()
    results = await asyncio.gather(fetch("lesson", 0.2), fetch("progress", 0.2), fetch("sources", 0.2))
    print(results, round(time.perf_counter() - start, 1))

asyncio.run(main())
```

Программа печатает ['lesson', 'progress', 'sources'] 0.2: три ожидания по 0,2 с прошли вместе за 0,2 с, а не за 0,6. Так устроен и backend ColiDev: его функции объявлены как async def, чтобы, пока один запрос ждёт модель ИИ, сервер мог отвечать на другие.

### Исследуй и потренируйся

Запусти программу, затем замени asyncio.gather на три последовательных await fetch(...) и сравни время. После этого сделай в одной из задач долгий цикл вычислений без await и посмотри, что станет с остальными задачами.

### Вопрос

Три сопрограммы ждут по 0,2 секунды через await asyncio.sleep и запущены вместе через asyncio.gather. Сколько примерно займёт вся программа?

### Варианты

- Около 0,2 с: пока одна задача ждёт, работают остальные, и ожидания идут одновременно.
- Около 0,6 с: задачи всё равно выполняются по очереди.
- Мгновенно: асинхронный код не ждёт вовсе.

### Ответ

1

### Разбор

asyncio.gather запускает три задачи конкурентно. Каждая доходит до await asyncio.sleep и отдаёт управление, поэтому все три ожидания идут в одно и то же время и заканчиваются примерно через 0,2 с. Последовательные await дали бы 0,6 с, а ожидание само по себе никуда не исчезает — оно просто перекрывается.

### Границы модели

asyncio ускоряет ожидание — сеть, диск, ответы других программ, — но не тяжёлые вычисления: долгий расчёт без await занимает цикл событий и задерживает все остальные задачи. Для вычислений используют потоки или процессы. Асинхронный код сложнее отлаживать: задачи могут завершаться в неожиданном порядке, и ошибки в одной задаче нужно обрабатывать явно.

## English

### Goal

Understand how an asynchronous program carries out several waits at once, run coroutines with asyncio.run and asyncio.gather, and tell which tasks asyncio speeds up and which it does not.

### Idea and mechanism

Many programs spend most of their time waiting: for a server's reply, for a file to be read, for an AI model. A sequential program waits for each in turn, and the waits add up. An asynchronous program, while one task waits, hands control to others.

Python provides coroutines for this: functions declared with async def. Simply calling a coroutine is not enough: the call only creates an object, and execution starts when asyncio.run runs it or when it is awaited. The function asyncio.gather runs several coroutines concurrently and returns a list of results in the same order they were passed. And await asyncio.sleep(...) suspends the current task and lets others run.

```python
import asyncio
import time

async def fetch(name, delay):
    await asyncio.sleep(delay)
    return name

async def main():
    start = time.perf_counter()
    results = await asyncio.gather(fetch("lesson", 0.2), fetch("progress", 0.2), fetch("sources", 0.2))
    print(results, round(time.perf_counter() - start, 1))

asyncio.run(main())
```

The program prints ['lesson', 'progress', 'sources'] 0.2: three waits of 0.2 s together took 0.2 s, not 0.6. The ColiDev backend works this way too: its functions are declared async def so that while one request waits for an AI model, the server can answer others.

### Explore and practise

Run the program, then replace asyncio.gather with three sequential await fetch(...) calls and compare the time. Then add a long computation loop without await to one of the tasks and see what happens to the others.

### Question

Three coroutines each wait 0.2 seconds with await asyncio.sleep and are started together with asyncio.gather. About how long does the whole program take?

### Options

- About 0.2 s: while one task waits, the others run, and the waits happen at the same time.
- About 0.6 s: the tasks still run one after another.
- Instantly: asynchronous code does not wait at all.

### Answer

1

### Explanation

asyncio.gather runs the three tasks concurrently. Each reaches await asyncio.sleep and hands over control, so all three waits happen at the same time and finish after about 0.2 s. Sequential awaits would take 0.6 s, and the waiting itself does not disappear; it just overlaps.

### Limits

asyncio speeds up waiting, on the network, the disk, or other programs, but not heavy computation: a long calculation without await occupies the event loop and delays every other task. Computation uses threads or processes instead. Asynchronous code is harder to debug: tasks can finish in unexpected orders, and errors in one task must be handled explicitly.

## Sources

- Python Software Foundation, *The Python Standard Library*, “Coroutines and Tasks” (consulted 2026-10-31): simply calling a coroutine does not schedule it, asyncio.run as the top-level entry point, asyncio.gather running awaitables concurrently with results in the order of the awaitables, and asyncio.sleep suspending the current task so others can run: [docs.python.org, Coroutines and Tasks](https://docs.python.org/3/library/asyncio-task.html)
- ColiDev source code: backend functions in `01_Projects/orchestrator.py` are declared with `async def`.
- The lesson paraphrases the documentation and does not copy its text.

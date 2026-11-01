---
subject: programming
lesson_id: programming.logging_and_measuring_performance
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Наблюдаемость и производительность: логи и измерение времени / Observability and Performance: Logging and Timing

## Русский

### Цель

Видеть, что делает программа, через журнал событий с уровнями важности, понимать, какие сообщения попадают в журнал по умолчанию, и измерять время кода через timeit, прежде чем что-то оптимизировать.

### Идея и механизм

Программу, которая работает у пользователя, нельзя остановить отладчиком. Поэтому она пишет журнал — лог. В модуле logging у каждого события есть уровень важности: DEBUG — подробности для диагностики, INFO — подтверждение, что всё идёт как надо, WARNING — случилось что-то неожиданное, но программа работает, ERROR — из-за серьёзной проблемы что-то не удалось, CRITICAL — программа, возможно, не сможет продолжать. По умолчанию уровень WARNING: записываются только события этого уровня и выше, пока логирование не настроят иначе.

Производительность тоже не угадывают, а измеряют. Модуль timeit выполняет фрагмент кода много раз и возвращает общее время в секундах; по умолчанию он считает время через time.perf_counter. Измерение показывает, где на самом деле узкое место, и не даёт тратить силы на ускорение того, что и так быстро.

```python
import logging
import timeit

logging.basicConfig(format="%(levelname)s %(message)s")
log = logging.getLogger("colidev")
log.info("lesson opened")
log.warning("source not checked for 400 days")

numbers_list = list(range(10_000))
numbers_set = set(numbers_list)
in_list = timeit.timeit(lambda: 9_999 in numbers_list, number=1_000)
in_set = timeit.timeit(lambda: 9_999 in numbers_set, number=1_000)
print(in_set < in_list)
```

Программа выводит в поток ошибок WARNING source not checked for 400 days, а затем печатает True. Сообщение уровня INFO не попало в журнал: уровень по умолчанию — WARNING. Измерение показало, что проверка числа во множестве быстрее, чем в списке: список проверяется элемент за элементом, а множество в Python как раз предназначено для быстрой проверки принадлежности. На Mac, где писался урок, разница была примерно в 2000 раз. Backend ColiDev тоже пишет журнал через logging.getLogger("colidev").

### Исследуй и потренируйся

Добавь в basicConfig аргумент level=logging.INFO и убедись, что сообщение INFO появилось. Затем напечатай отношение in_list / in_set, запусти программу несколько раз и посмотри, насколько меняется число от запуска к запуску. Поменяй искомое число на 0 — в начале списка — и объясни, почему разница почти исчезла.

### Вопрос

Логирование не настраивали, кроме формата сообщений. Программа вызывает log.info("lesson opened") и log.warning("source not checked"). Что появится в журнале?

### Варианты

- Только предупреждение: по умолчанию записываются события уровня WARNING и выше.
- Оба сообщения: в журнал пишется всё, что программа передала логгеру.
- Ничего: без настройки уровня журнал пуст.

### Ответ

1

### Разбор

Уровень по умолчанию — WARNING, поэтому событие INFO, менее важное, отбрасывается, а WARNING записывается. Чтобы увидеть INFO, уровень нужно явно понизить, например через basicConfig(level=logging.INFO).

### Границы модели

Время в timeit зависит от компьютера, нагрузки и версии Python, поэтому сравнивать можно только измерения на одной машине, и одно измерение — не доказательство. Измерение маленького фрагмента не заменяет профилирования всей программы: для этого есть профилировщик cProfile из стандартной библиотеки. В журнал нельзя писать ключи, пароли и личные данные. Метрики и трассировка — следующие инструменты наблюдаемости, урок их не разбирает.

## English

### Goal

See what a program is doing through an event log with severity levels, understand which messages reach the log by default, and measure code time with timeit before optimising anything.

### Idea and mechanism

A program running on a user's machine cannot be stopped in a debugger. So it writes a log. In the logging module every event has a severity level: DEBUG for detailed diagnostic information, INFO to confirm that things are working as expected, WARNING when something unexpected happened but the program still works, ERROR when a more serious problem made something fail, and CRITICAL when the program itself may be unable to continue. The default level is WARNING: only events of this level and above are recorded unless logging is configured otherwise.

Performance is not guessed either; it is measured. The timeit module runs a code fragment many times and returns the total time in seconds; by default it measures time with time.perf_counter. Measuring shows where the real bottleneck is and stops you spending effort speeding up what is already fast.

```python
import logging
import timeit

logging.basicConfig(format="%(levelname)s %(message)s")
log = logging.getLogger("colidev")
log.info("lesson opened")
log.warning("source not checked for 400 days")

numbers_list = list(range(10_000))
numbers_set = set(numbers_list)
in_list = timeit.timeit(lambda: 9_999 in numbers_list, number=1_000)
in_set = timeit.timeit(lambda: 9_999 in numbers_set, number=1_000)
print(in_set < in_list)
```

The program writes WARNING source not checked for 400 days to the error stream and then prints True. The INFO message did not reach the log: the default level is WARNING. The measurement showed that checking for a number in a set is faster than in a list: a list is checked element by element, while a Python set is designed for fast membership testing. On the Mac where this lesson was written the difference was about 2000 times. The ColiDev backend also writes its log through logging.getLogger("colidev").

### Explore and practise

Add the argument level=logging.INFO to basicConfig and check that the INFO message appears. Then print the ratio in_list / in_set, run the program several times, and see how much the number changes between runs. Change the number being searched for to 0, at the start of the list, and explain why the difference nearly disappears.

### Question

Logging has not been configured apart from the message format. The program calls log.info("lesson opened") and log.warning("source not checked"). What appears in the log?

### Options

- Only the warning: by default events of level WARNING and above are recorded.
- Both messages: the log records everything the program passes to the logger.
- Nothing: without setting a level the log is empty.

### Answer

1

### Explanation

The default level is WARNING, so the less severe INFO event is dropped and the WARNING is recorded. To see INFO, the level has to be lowered explicitly, for example with basicConfig(level=logging.INFO).

### Limits

timeit results depend on the computer, its load, and the Python version, so only measurements on the same machine can be compared, and a single measurement proves nothing. Timing a small fragment does not replace profiling the whole program: the standard library's cProfile profiler is meant for that. Keys, passwords, and personal data must never be written to a log. Metrics and tracing are the next observability tools; this lesson does not cover them.

## Sources

- Python Software Foundation, *Logging HOWTO* (consulted 2026-10-31): the levels DEBUG, INFO, WARNING, ERROR, and CRITICAL with when to use each, and WARNING as the default level so that only events of that severity and higher are tracked unless configured otherwise: [docs.python.org, Logging HOWTO](https://docs.python.org/3/howto/logging.html)
- Python Software Foundation, *The Python Standard Library*, “timeit — Measure execution time of small code snippets” (consulted 2026-10-31): timeit.timeit running a statement a given number of times and time.perf_counter as the default timer: [docs.python.org, timeit](https://docs.python.org/3/library/timeit.html)
- Python Software Foundation, *The Python Standard Library*, “Built-in Types”, section “Set Types” (consulted 2026-10-31): sets as collections of distinct hashable objects whose common uses include membership testing: [docs.python.org, Set Types](https://docs.python.org/3/library/stdtypes.html#set-types-set-frozenset)
- ColiDev source code: `01_Projects/orchestrator.py` creates its logger with `logging.getLogger("colidev")`.
- The lesson paraphrases the documentation and does not copy its text.

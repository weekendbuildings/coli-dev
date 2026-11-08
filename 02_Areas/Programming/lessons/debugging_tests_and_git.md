---
subject: programming
lesson_id: programming.debugging_tests_and_git
level: foundations
languages: ru, en
source_checked: 2026-10-13
source_review_interval_days: 90
---

# Отладка, тесты и Git / Debugging, Tests, and Git

## Русский

### Цель

Научиться сужать место дефекта по сообщению об ошибке, проверять причину маленьким примером и убеждаться тестом, что исправление работает.

### Идея и механизм

Сначала воспроизведи проблему теми же входными данными. В traceback найди тип и текст исключения внизу, затем строку и вызванные функции выше. Это подсказки, а не готовая правка: отмеченная строка может лишь обнаружить ошибку, созданную раньше. Ошибки синтаксиса и исключения времени выполнения показываются по-разному.

```python
def double(n):
    return n * 2

assert double(3) == 6
```

У проверки есть конкретное ожидание. Сравни ожидаемое с фактическим, проверь само требование и добавь граничный случай (например, ноль или пустой список), когда он важен. Если тест упал, не удаляй его и не меняй ожидаемое на фактическое, пока не выяснил, какая сторона противоречит требованиям.

`assert` в этом примере — короткая проверка для изучения поведения. В Python оптимизированный запуск может убрать `assert`, поэтому для постоянного набора тестов используй тестовый фреймворк, а не полагайся только на эти выражения.

### Рабочий цикл

1. Повтори ошибку и сохрани точный вход.
2. Прочитай тип исключения, сообщение и соответствующую строку traceback.
3. Сформулируй проверяемую гипотезу; меняй за раз только одну причину.
4. Запусти узкий тест и связанные проверки.
5. Посмотри diff и зафиксируй понятное изменение в Git.

#### Git: небольшой проверяемый цикл

После теста посмотри состояние и конкретное изменение. Для этого учебного сценария изменены `lesson.py` и `tests/test_lesson.py`, а `debug.log` — случайный неотслеживаемый файл:

```console
git status
git diff
git add lesson.py tests/test_lesson.py
git diff --cached
git commit -m "Improve lesson input checks"
git status
```

`git add` помещает выбранные версии файлов в staging area — снимок будущего коммита. `git diff --cached` проверяет именно подготовленный снимок. Добавляй только нужные пути: `git add .` захватил бы и `debug.log`. После коммита повторный `git status` подтверждает сохранение изменений в локальной истории; случайный файл остаётся неотслеживаемым, пока ты отдельно не решишь, что с ним делать. Если файл изменился после `git add`, снова проверь и добавь новую версию.

#### Командная работа: отдельная ветка и pull request

После локального коммита начинай отдельную задачу в своей ветке, чтобы не менять основную ветку напрямую:

```console
git switch -c feature/add-lesson-check
git status
git diff
git add lesson.py tests/test_lesson.py
git diff --cached
git commit -m "Add lesson check"
git push -u origin feature/add-lesson-check
```

`git switch -c` создаёт ветку от текущего коммита и сразу переключает на неё; команда `git switch -C` может сбросить существующую ветку, поэтому не используй её как обычное создание. Изучай изменения и готовь к коммиту только нужные файлы. После проверки коммита отправь feature-ветку на сервер. `-u` задаёт для неё upstream, чтобы следующие операции `push` и `pull` знали связанную удалённую ветку. В GitHub открой pull request в целевую ветку, коротко опиши изменение и попроси коллегу посмотреть diff. Обсуди замечания и проверь CI. Если в репозитории настроены обязательные проверки или одобрения, дождись их; слияй по правилам команды. Сам факт открытия pull request ничего не сливает.

В приложении этот путь проигрывается на фиксированном учебном примере. Оно не создаёт ветку, не подключается к GitHub, не отправляет файлы и не открывает pull request.

### Исследуй и потренируйся

В тренажёре выбери диагностический шаг для `NameError`, `IndexError` или упавшего `assert`. Сначала определи симптом и границу, затем сверь объяснение. Это заранее заданные фрагменты; приложение не запускает произвольный код.

В Git-тренажёре пройди два связанных сценария по одному действию: безопасный локальный коммит, затем feature-ветка, проверка staging, публикация ветки и передача изменения команде через pull request. Он не выполняет Git-команды, не обращается к сети и не меняет реальный репозиторий.

На бумаге добавь к функции `double` тест для `double(0)` и поясни ожидаемое значение. Затем представь, что тест не проходит: перечисли, какие вход, строку и требование проверишь до правки.

### Вопрос

Последняя строка traceback говорит `NameError: name 'totel' is not defined`; выше есть `total = 12` и `print(totel)`. Какой первый полезный шаг?

### Варианты

- Сверить имя в `print` с объявленным и проверить гипотезу об опечатке.
- Обернуть `print` в `try/except Exception`, чтобы программа не падала.
- Удалить строку печати: если ошибки больше нет, проблема решена.

### Ответ

1

### Разбор

В коде объявлено `total`, а читается `totel`. `NameError` указывает на имя, которого нет в текущей области видимости. Исправление нужно проверить повторным запуском воспроизводимого случая.

### Границы и безопасный запуск

Одна ошибка иногда маскирует следующую. Исправление одного случая не доказывает корректность всей программы; нужны тесты по требованию, граничным случаям и регрессии. Текст исключения и строка traceback могут указывать место проявления, а не исходную причину. Git сохраняет историю изменений, но сам по себе не доказывает правильность кода.

## English

### Goal

Use an error message to narrow down a defect, check its cause with a small example, and verify a fix with a test.

### Idea and mechanism

First reproduce the problem with the same input. In a traceback, inspect the exception type and message at the bottom, then the relevant source line and callers above it. These are clues, not an automatic fix: the highlighted line may only reveal an earlier mistake. Syntax errors and runtime exceptions are reported differently.

```python
def double(n):
    return n * 2

assert double(3) == 6
```

A test has a concrete expectation. Compare expected and actual values, check the requirement itself, and add a boundary case such as zero or an empty list when relevant. If a test fails, do not delete it or change its expected value to match the result until you know which side conflicts with the requirement.

The `assert` here is a short check for learning. Python's optimized mode can remove `assert` statements, so use a test framework for a durable test suite instead of relying on these expressions alone.

### A practical loop

1. Reproduce the failure and keep the exact input.
2. Read the exception type, message, and relevant traceback line.
3. Form a testable hypothesis; change one cause at a time.
4. Run the focused test and related checks.
5. Review the diff and record a clear change in Git.

#### Git: a small, verifiable workflow

After a test, inspect the repository state and the exact changes. In this teaching scenario, `lesson.py` and `tests/test_lesson.py` are modified, while `debug.log` is an unrelated untracked file:

```console
git status
git diff
git add lesson.py tests/test_lesson.py
git diff --cached
git commit -m "Improve lesson input checks"
git status
```

`git add` puts the selected file versions in the staging area—the snapshot for the next commit. `git diff --cached` reviews that prepared snapshot. Add only intended paths: `git add .` would also capture `debug.log`. After the commit, run `git status` again to confirm the changes are in local history; the unrelated file stays untracked until you decide what to do with it. If a file changes after `git add`, review and stage its new version again.

### Explore and practise

Choose a diagnostic step for a `NameError`, `IndexError`, or failed `assert` in the trainer. Identify the symptom and boundary before checking the explanation. The examples are fixed; the app does not run arbitrary code.

In the Git trainer, follow two connected scenarios one action at a time: make a safe local commit, then use a feature branch, review its staged snapshot, publish that branch, and hand the change to the team through a pull request. The trainer runs no Git commands, makes no network request, and does not modify a real repository.

#### Team workflow: a separate branch and pull request

After the local commit, start a separate task on your own branch so you do not change the base branch directly:

```console
git switch -c feature/add-lesson-check
git status
git diff
git add lesson.py tests/test_lesson.py
git diff --cached
git commit -m "Add lesson check"
git push -u origin feature/add-lesson-check
```

`git switch -c` creates a branch from the current commit and switches to it; `git switch -C` can reset an existing branch, so do not use it as the normal create command. Inspect changes and stage only the intended files. After reviewing the commit, publish the feature branch. `-u` sets its upstream so later `push` and `pull` operations know which remote branch is connected. On GitHub, open a pull request into the intended base branch, describe the change briefly, and ask a teammate to review the diff. Discuss feedback and check CI. If the repository requires status checks or approvals, wait for them; merge according to the team's policy. Opening a pull request does not merge it.

The app simulates this workflow with a fixed teaching example. It does not create a branch, connect to GitHub, upload files, or open a pull request.

Add a test for `double(0)` on paper and state the expected result. Then imagine that it fails: list the input, line, and requirement you would inspect before editing the code.

### Question

The last traceback line says `NameError: name 'totel' is not defined`; above it are `total = 12` and `print(totel)`. What is a useful first step?

### Options

- Compare the name in `print` with the declared one and test the typo hypothesis.
- Wrap `print` in `try/except Exception` so the program stops crashing.
- Delete the print line: if the error is gone, the problem is solved.

### Answer

1

### Explanation

The code defines `total` but reads `totel`. `NameError` means the name is not defined in the current scope. Re-run the reproducible case to verify the correction.

### Limits and safe execution

One error can hide another. Fixing one case does not prove the entire program correct; test the requirement, boundaries, and regressions. The exception text and traceback line may show where a problem surfaced rather than its original cause. Git records change history but does not prove that code is correct.

## Sources

- Python Tutorial, “Errors and Exceptions”: <https://docs.python.org/3/tutorial/errors.html>
- Python Language Reference, “The `assert` statement”: <https://docs.python.org/3/reference/simple_stmts.html#the-assert-statement>
- [Pro Git: Recording Changes to the Repository — Git Project / Pro Git: сохранение изменений в репозитории — проект Git](https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository)
- [Pro Git: Branches in a Nutshell — Git Project / Pro Git: ветки вкратце — проект Git](https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell)
- [git-switch — Git documentation / git-switch — документация Git](https://git-scm.com/docs/git-switch)
- [git-push — Git documentation / git-push — документация Git](https://git-scm.com/docs/git-push)
- [Creating a pull request — GitHub Docs / Создание pull request — документация GitHub](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-a-pull-request)
- [Writing code for a project — GitHub Docs / Написание кода для проекта — документация GitHub](https://docs.github.com/en/pull-requests/concepts/writing-code-for-a-project)

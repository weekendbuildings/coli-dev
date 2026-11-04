---
subject: programming
lesson_id: programming.virtual_environments_and_dependencies
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 365
---

# Виртуальные окружения, зависимости и настройки / Virtual Environments, Dependencies, and Configuration

## Русский

### Цель

Создавать виртуальное окружение Python, фиксировать зависимости в файле требований, воспроизводить окружение одной командой и выносить настройки из кода в переменные окружения.

### Идея и механизм

Проекту нужны сторонние пакеты, и у разных проектов могут быть несовместимые версии одного пакета. Виртуальное окружение решает это: модуль `venv` создаёт лёгкое окружение поверх установленного Python со своим независимым набором пакетов. По умолчанию оно изолировано от пакетов основной установки, поэтому в нём доступно только то, что поставили именно туда.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Окружение не переносят между компьютерами и не хранят в git — вместо этого хранят простой способ его пересоздать. Это файл требований `requirements.txt`: список пакетов, который `pip install -r requirements.txt` ставит одной командой. В Cause & Course так и устроено: в корне проекта лежат `requirements.txt`, `requirements-test.txt` и другие файлы требований для разных задач.

Настройки, которые меняются от запуска к запуску или не должны попасть в код, — порт, путь к файлу, ключи — передают через переменные окружения. Например, приложение Cause & Course сообщает своему backend номер своего процесса через переменную `COLIDEV_PARENT_PID`, а тот читает её через `os.environ`. Ключи доступа никогда не записывают прямо в код и не коммитят в git.

### Исследуй и потренируйся

Создай в учебной папке виртуальное окружение, поставь в него один пакет и проверь командой `python -m pip list`, что он есть внутри окружения, но не в основной установке. Затем запиши этот пакет в `requirements.txt`, удали окружение и пересоздай его одной командой.

### Вопрос

Зачем каждому проекту отдельное виртуальное окружение?

### Варианты

- Чтобы пакеты и их версии одного проекта не мешали другому: у каждого окружения свой изолированный набор.
- Чтобы Python работал быстрее: в окружении код выполняется оптимизированно.
- Без виртуального окружения Python вообще не запускает скрипты.

### Ответ

1

### Разбор

Виртуальное окружение — это отдельный набор пакетов поверх общего Python. Если проекту A нужна одна версия библиотеки, а проекту B — другая, у каждого будет своё окружение, и они не столкнутся. Скорость кода от окружения не зависит, а скрипты Python прекрасно работают и без него — просто тогда все проекты делят один набор пакетов.

### Границы модели

`venv` изолирует пакеты Python, но не системные библиотеки и не саму версию Python — для этого есть другие инструменты. Файл требований без точных версий может со временем поставить другие версии пакетов; для воспроизводимости версии фиксируют. Команды даны для macOS и Linux; в Windows активация окружения выглядит иначе.

## English

### Goal

Create a Python virtual environment, record dependencies in a requirements file, recreate the environment with one command, and move settings out of code into environment variables.

### Idea and mechanism

A project needs third-party packages, and different projects may need incompatible versions of the same package. A virtual environment solves this: the `venv` module creates a lightweight environment on top of an installed Python with its own independent set of packages. By default it is isolated from the packages of the base installation, so only what was installed into it is available.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

An environment is not copied between computers or stored in git; instead you keep a simple way to recreate it. That is the requirements file `requirements.txt`: a list of packages that `pip install -r requirements.txt` installs in one command. Cause & Course is set up this way: the project root holds `requirements.txt`, `requirements-test.txt`, and other requirements files for different tasks.

Settings that change between runs or must not end up in the code, such as a port, a file path, or keys, are passed through environment variables. For example, the Cause & Course app tells its backend its own process number through the `COLIDEV_PARENT_PID` variable, and the backend reads it through `os.environ`. Access keys are never written into code or committed to git.

### Explore and practise

In a practice folder, create a virtual environment, install one package into it, and check with `python -m pip list` that it is inside the environment but not in the base installation. Then write that package into `requirements.txt`, delete the environment, and recreate it with one command.

### Question

Why does each project get its own virtual environment?

### Options

- So that one project's packages and versions do not interfere with another's: each environment has its own isolated set.
- To make Python run faster: code runs optimised inside an environment.
- Without a virtual environment Python cannot run scripts at all.

### Answer

1

### Explanation

A virtual environment is a separate set of packages on top of a shared Python. If project A needs one version of a library and project B another, each gets its own environment and they do not clash. Code speed does not depend on the environment, and Python scripts run perfectly well without one; then all projects simply share one set of packages.

### Limits

`venv` isolates Python packages, but not system libraries or the Python version itself; other tools exist for that. A requirements file without exact versions may install different package versions over time; for reproducibility, versions are pinned. The commands are for macOS and Linux; on Windows activating an environment looks different.

## Sources

- Python Software Foundation, *The Python Standard Library*, “venv — Creation of virtual environments” (consulted 2026-10-26): lightweight environments with their own independent set of packages, isolated by default from the base environment, not to be moved but recreated, for example with `pip install -r requirements.txt`: [docs.python.org, venv](https://docs.python.org/3/library/venv.html)
- pip documentation, “User Guide”, section “Requirements Files” (consulted 2026-10-26): requirements files as lists of items installed with `python -m pip install -r requirements.txt`: [pip User Guide](https://pip.pypa.io/en/stable/user_guide/)
- ColiDev source code: requirements files in the project root and the `COLIDEV_PARENT_PID` variable read by `01_Projects/parent_watchdog.py`.
- The lesson paraphrases the documentation and does not copy its text.

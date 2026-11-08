# Собери и проверь сам / Build and check it yourself

Здесь семь заготовок к ключевым урокам пути ИИ. В каждой не хватает главного шага алгоритма, и его
пишешь ты. К каждой заготовке есть строгая проверка: она сверяет твой код с численной производной,
граничными случаями и свойствами, которые обязаны выполняться всегда.

| Урок | Заготовка | Проверка | Что пишешь сам |
|---|---|---|---|
| `attention_mechanism` | `attention_blank.py` | `check_attention_mechanism.py` | softmax без переполнения, маска будущего, обратный проход через softmax |
| `autograd_engine` | `autograd_blank.py` | `check_autograd_engine.py` | градиент умножения и tanh, обратный проход в верном порядке |
| `tokenizer_bpe` | `tokenizer_blank.py` | `check_tokenizer_bpe.py` | подсчёт пар, слияние без перекрытий, кодирование |
| `rl_policy_gradient` | `policy_gradient_blank.py` | `check_rl_policy_gradient.py` | градиент log π, шаг REINFORCE с базовой линией |
| `finetuning_and_lora` | `lora_blank.py` | `check_finetuning_and_lora.py` | выход с адаптером, градиенты по A и B, слияние |
| `interp_probes` | `probe_blank.py` | `check_interp_probes.py` | логистическая ошибка зонда и её градиент, контроль на случайных метках |
| `consciousness_integrated_information` | `phi_blank.py` | `check_consciousness_integrated_information.py` | все разрезы для n узлов и потеря при разрезе |

**Как работать.**

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_autograd_engine.py
```

`cp -Rn` не перезаписывает уже существующие файлы, поэтому твой код не пропадёт. Нужен только
обычный `python3` этого Mac, пакеты не нужны. Своё решение можно положить в отдельный файл и
передать проверке: `python3 check_autograd_engine.py my_autograd.py`.

**Честно.** В файлах проверок есть ответы, иначе нечем сверять. Открывай их только после своей
попытки. Эталонные решения лежат в `01_Projects/test_creator_labs.py`: там же видно, какие типичные
ошибки ловит каждая проверка.

---

Seven blanks for the key AI path lessons. Each is missing the main step of its algorithm, and you
write it. Each has a strict check that compares your code with numerical derivatives, edge cases
and invariants. Copy the folder with the command above (`cp -Rn` keeps files you already wrote),
open a blank, fill in the functions that raise `NotImplementedError`, and rerun its check until
every line shows ✓. Plain `python3` is enough. The check files contain the answers, so open them
only after your own attempt; reference solutions and the mistakes each check catches are in
`01_Projects/test_creator_labs.py`.

---
subject: programming
lesson_id: programming.consciousness_indicators_checklist
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Индикаторы: проверка настоящей системы / Indicators: checking a real system

## Русский

### Цель

Применить 14 индикаторов из отчёта Butlin и соавторов к своей маленькой модели и к большой локальной, обосновать каждую строку и увидеть, почему итоговое число почти ничего не доказывает. Урок не утверждает, что какая-то система сознательна. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Откуда индикаторы.** В 2023 году 19 авторов из нейронауки, философии и ИИ сделали такой шаг: ни одну теорию нельзя считать доказанной, но можно взять то, что важно для **нескольких** научных теорий, и спросить, есть ли это в архитектуре системы. Отчёт исходит из условия: если функционализм верен, то такое устройство имеет значение. Это условие, и его принимают не все. Вывод отчёта: сильных кандидатов среди систем 2023 года нет, а очевидных технических препятствий тоже нет.

**Шаг 2. Что смотрят.** Теории дают группы.

- **RPT** (рекуррентная обработка): 2 индикатора.
- **GWT** (рабочее пространство): 4.
- **HOT** (высший порядок): 4.
- **AST** (схема внимания): 1.
- **PP** (предсказание): 1.
- **AE** (действие и тело): 2.

Важно: это вопросы об **устройстве**, а не о том, что система говорит.

**Шаг 3. Сами оценки.** Создай файл `nano ~/ai-path/indicators.py`, вставь и запусти. Оценки в программе мои: `1` есть, `0,5` частично или неясно, `0` нет. Это мнение одного автора урока, а не вывод отчёта.

```python
INDICATORS = ["RPT-1", "RPT-2", "GWT-1", "GWT-2", "GWT-3", "GWT-4", "HOT-1", "HOT-2", "HOT-3", "HOT-4", "AST-1", "PP-1", "AE-1", "AE-2"]
# My judgement: 1 yes, 0.5 partly or unclear, 0 no. Your judgement may differ.
TINY = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
LARGE = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0, 0.5, 0, 0, 0.5, 0]
GROUPS = {"RPT": 2, "GWT": 4, "HOT": 4, "AST": 1, "PP": 1, "AE": 2}


def by_theory(row):
    start = 0
    result = {}
    for name, size in GROUPS.items():
        result[name] = sum(row[start:start + size]) / size
        start += size
    return result


print("tiny model", sum(TINY), by_theory(TINY))
print("large local model", sum(LARGE), by_theory(LARGE))
print("if every 'partly' counts as yes", sum(1 for v in LARGE if v > 0))
print("if every 'partly' counts as no", sum(1 for v in LARGE if v == 1))
```

```output
tiny model 0 {'RPT': 0.0, 'GWT': 0.0, 'HOT': 0.0, 'AST': 0.0, 'PP': 0.0, 'AE': 0.0}
large local model 5.0 {'RPT': 0.5, 'GWT': 0.5, 'HOT': 0.375, 'AST': 0.0, 'PP': 0.0, 'AE': 0.25}
if every 'partly' counts as yes 10
if every 'partly' counts as no 0
```

У маленькой модели курса `0` из 14: один проход вперёд, нет модулей и своей оценки надёжности. У `qwen3.5` мои оценки дают сумму `5`, почти везде «частично». Почему так расплывчато? Например, HOT-2, метапознание: Kadavath и соавторы показали, что большие модели неплохо оценивают, знают ли они ответ. Значит, частично есть. Но смотри следующие строки: если все «частично» считать за «да», выходит **10**, а если за «нет», то **0**. **Одна и та же модель даёт от 0 до 10 только из-за строгости чтения.**

**Шаг 4. Почему сумма не вероятность.** Не складывай и не говори «5 из 14, значит, 36 % сознания». Причины:

1. Индикаторы не равны, а теории спорят, какие из них важны.
2. Все они зависят от одного условия: что функции достаточно. Если нужна биология, вся таблица не имеет значения.
3. Наличие индикатора означает только сходство устройства. Простая программа тоже может пройти один пункт, как рабочее пространство в уроке выше.

Авторы и сами предлагают это как способ думать, а не как шкалу.

**Шаг 5. Что полезного отсюда.** Эта таблица заставляет говорить об устройстве, а не о впечатлении от разговора. Она показывает, чего явно нет: например, тела и постоянных целей у обычной языковой модели. И помогает заметить, как что-то меняется. В 2025 году часть тех же авторов уточнила подход, а работы вроде Gurnee и соавторов 2026 года делают некоторые строки предметом опытов, а не догадок.

**Учись у тех, кто это создаёт.** Сам отчёт [Consciousness in Artificial Intelligence](https://arxiv.org/abs/2308.08708): начни с таблицы индикаторов. Вопрос о языковых моделях: [Chalmers, 2023](https://arxiv.org/abs/2303.07103). Возражение против функционализма: статья Анила Сета о биологии в журнале Behavioral and Brain Sciences (2025).

### Исследуй и потренируйся

В тренажёре оцени `qwen3.5` по всем 14 индикаторам сам. Затем открой мой разбор каждой строки и посмотри, где мы расходимся, и как меняется сумма от строгости чтения.

В программе добавь веса к теориям по своему выбору. Сильно ли меняется порядок двух систем?

### Вопрос

Почему нельзя сказать «у модели 5 индикаторов из 14, значит, вероятность сознания 36 %»?

### Варианты

- Индикаторы не равны и опираются на спорное условие, поэтому сумма не становится вероятностью.
- Отчёт запрещает считать индикаторы, поскольку они написаны только для биологических систем.
- Сумма всегда равна нулю, поскольку ни одна система не обладает ни одним индикатором отчёта.

### Ответ

1

### Разбор

Считать можно, и отчёт писался как раз для систем ИИ. Сумма не всегда равна нулю: есть системы с отдельными чертами. Но сумма не вероятность: нет шкалы, нет общего согласия о весах, а всё держится на условии, что функции достаточно.

### Границы модели

Оценки в таблице мои, и я мог ошибиться: устройство большой модели известно мне только по общим сведениям. `qwen3.5` как конкретная модель описана в общих чертах. Индикаторы взяты из отчёта по памяти, поэтому их точные формулировки сверяй с ним. Обновление 2025 года я пересказываю без подробностей.

## English

### Goal

Apply the 14 indicators from the report by Butlin and co-authors to your small model and the large local one, justify each row, and see why the final number proves almost nothing. The lesson does not claim any system is conscious. It takes about 35 minutes.

### Idea and mechanism

**Step 1. Where the indicators come from.** In 2023, 19 authors from neuroscience, philosophy and AI took this step: no theory can be considered proved, but one can take what matters to **several** scientific theories and ask whether it is in a system's architecture. The report starts from a condition: if functionalism is true, such design matters. That is a condition, and not everyone accepts it. The report's conclusion: no strong candidates among systems of 2023, and no obvious technical barriers either.

**Step 2. What is looked at.** The theories give groups.

- **RPT** (recurrent processing): 2 indicators.
- **GWT** (workspace): 4.
- **HOT** (higher order): 4.
- **AST** (attention schema): 1.
- **PP** (prediction): 1.
- **AE** (agency and embodiment): 2.

Importantly, these are questions about **design**, not about what a system says.

**Step 3. The ratings themselves.** Create the file `nano ~/ai-path/indicators.py`, paste and run it. The ratings in the program are mine: `1` yes, `0.5` partly or unclear, `0` no. This is one lesson author's opinion, not the report's conclusion.

```python
INDICATORS = ["RPT-1", "RPT-2", "GWT-1", "GWT-2", "GWT-3", "GWT-4", "HOT-1", "HOT-2", "HOT-3", "HOT-4", "AST-1", "PP-1", "AE-1", "AE-2"]
# My judgement: 1 yes, 0.5 partly or unclear, 0 no. Your judgement may differ.
TINY = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
LARGE = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0, 0.5, 0, 0, 0.5, 0]
GROUPS = {"RPT": 2, "GWT": 4, "HOT": 4, "AST": 1, "PP": 1, "AE": 2}


def by_theory(row):
    start = 0
    result = {}
    for name, size in GROUPS.items():
        result[name] = sum(row[start:start + size]) / size
        start += size
    return result


print("tiny model", sum(TINY), by_theory(TINY))
print("large local model", sum(LARGE), by_theory(LARGE))
print("if every 'partly' counts as yes", sum(1 for v in LARGE if v > 0))
print("if every 'partly' counts as no", sum(1 for v in LARGE if v == 1))
```

```output
tiny model 0 {'RPT': 0.0, 'GWT': 0.0, 'HOT': 0.0, 'AST': 0.0, 'PP': 0.0, 'AE': 0.0}
large local model 5.0 {'RPT': 0.5, 'GWT': 0.5, 'HOT': 0.375, 'AST': 0.0, 'PP': 0.0, 'AE': 0.25}
if every 'partly' counts as yes 10
if every 'partly' counts as no 0
```

The course's small model has `0` of 14: one forward pass, no modules and no estimate of its own reliability. For `qwen3.5` my ratings sum to `5`, "partly" nearly everywhere. Why so vague? For example HOT-2, metacognition: Kadavath and co-authors showed large models estimate rather well whether they know an answer. So it partly exists. But look at the next rows: counting all "partly" as "yes" gives **10**, and as "no" gives **0**. **The same model gives from 0 to 10 merely through strictness of reading.**

**Step 4. Why a sum is no probability.** Do not add up and say "5 of 14, so 36 % consciousness". The reasons:

1. Indicators are not equal, and theories argue over which matter.
2. All depend on one condition: that function suffices. If biology is needed, the whole table is irrelevant.
3. Having an indicator means only a resemblance of design. A simple program can pass one item too, like the workspace in the earlier lesson.

The authors themselves offer this as a way to think, not as a scale.

**Step 5. What is useful here.** The table forces talk about design rather than the impression from a conversation. It shows what is clearly absent: for instance, a body and lasting goals in an ordinary language model. And it helps notice change. In 2025 some of the same authors refined the approach, and work such as Gurnee and co-authors in 2026 makes some rows a matter of experiment rather than guesswork.

**Learn from the people who build this.** The report itself, [Consciousness in Artificial Intelligence](https://arxiv.org/abs/2308.08708): start with the indicator table. On language models: [Chalmers, 2023](https://arxiv.org/abs/2303.07103). An objection to functionalism: Anil Seth's paper on biology in Behavioral and Brain Sciences (2025).

### Explore and practise

In the lab, rate `qwen3.5` on all 14 indicators yourself. Then open my reasoning on each row, see where we differ, and how the sum changes with strictness of reading.

In the program, add weights to theories by your own choice. Does the order of the two systems change much?

### Question

Why can you not say "the model has 5 indicators of 14, so its chance of consciousness is 36 %"?

### Options

- Indicators are unequal and rest on a disputed condition, so a sum does not become a probability.
- The report forbids counting indicators, since they were written only for biological systems.
- A sum always equals zero, since no system has even a single indicator from the report.

### Answer

1

### Explanation

Counting is allowed, and the report was written precisely for AI systems. A sum is not always zero: some systems have individual traits. But a sum is no probability: there is no scale, no general agreement on weights, and everything rests on the condition that function suffices.

### Limits

The table's ratings are mine, and I may err: I know the large model's design only in general terms. `qwen3.5` as a specific model is described in broad strokes. The indicators are taken from the report from memory, so check their exact wording against it. I retell the 2025 update without details.

## Sources

- Patrick Butlin et al., "Consciousness in Artificial Intelligence: Insights from the Science of Consciousness", arXiv:2308.08708 (2023), title read 2026-11-03: [arXiv:2308.08708](https://arxiv.org/abs/2308.08708)
- David J. Chalmers, "Could a Large Language Model be Conscious?", arXiv:2303.07103 (2023), title read 2026-11-03: [arXiv:2303.07103](https://arxiv.org/abs/2303.07103)
- Patrick Butlin et al., "Identifying indicators of consciousness in AI systems", Trends in Cognitive Sciences 30 (2026, online 2025), abstract read 2026-11-03: [DOI](https://doi.org/10.1016/j.tics.2025.10.011)
- Anil Seth, "Conscious artificial intelligence and biological naturalism", Behavioral and Brain Sciences 49 (2025), title and journal checked 2026-11-03; the paper itself not re-read.
- Saurav Kadavath et al., "Language Models (Mostly) Know What They Know", arXiv:2207.05221 (2022): [arXiv:2207.05221](https://arxiv.org/abs/2207.05221)
- Wes Gurnee et al., "Verbalizable Representations Form a Global Workspace in Language Models" (2026), title read 2026-11-03: [paper](https://transformer-circuits.pub/2026/workspace/index.html)
- The ratings and the program were written for this lesson and are my judgement, not an expert assessment. The lesson paraphrases these sources and does not copy their text.

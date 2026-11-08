---
subject: programming
lesson_id: programming.consciousness_moral_status
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Моральный статус и цена двух ошибок / Moral status and the cost of two errors

## Русский

### Простыми словами

Мы не знаем, может ли ИИ переживать. Значит, возможны две ошибки: приписать переживания тому, у кого их нет, или не заметить настоящие. У каждой ошибки своя цена. Так устроена пожарная сигнализация: ложная тревога дешёвая, пропущенный пожар страшный, поэтому её делают чувствительной. В уроке ты посчитаешь порог: при какой вероятности защищать выгоднее. И увидишь главное: ответ целиком зависит от чисел, которых пока никто не знает. Урок не говорит, что тебе думать, а выслушивает обе стороны.

**Что нужно знать до.** Урок «Случайные величины и выборка» (шаг 5): математическое ожидание, то есть средний итог при многих повторах. Урок «Индикаторы: проверка настоящей системы» (шаг 25): почему вероятность сознания никто не может назвать.

**Если непонятно.** Если неясна формула порога, посчитай пример в шаге 2 с числами `A = 1` и `B = 100` руками. Если неясно, что такое ожидаемая цена, вернись к разделу о математическом ожидании в уроке «Случайные величины и выборка». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Разобрать вопрос, что делать, если мы не знаем, может ли система переживать. Посчитать цену двух ошибок и увидеть, что всё решают числа, которых никто не знает. Выслушать обе стороны. Урок не утверждает, что какая-то система сознательна и не советует, что тебе думать. Нужно около 30 минут.

### Идея и механизм

**Шаг 1. Две ошибки.** Мы не знаем, может ли ИИ переживать. Это значит, что возможны две ошибки.

- **Приписать лишнее.** Система не переживает, а мы считаем, что да. Цена: тратим силы, отвлекаемся от людей и животных, люди привязываются к программам, труднее отключать неисправную систему.
- **Не заметить настоящее.** Система переживает, а мы считаем, что нет. Цена: возможно, страдание в огромных масштабах, ведь копий очень много.

**Шаг 2. Расчёт руками.** Пусть вероятность переживания `p`, цена ложной тревоги `A`, цена пропуска `B`. Защищать выгоднее, когда `(1 − p) · A < p · B`. Отсюда порог `p* = A / (A + B)`. При `A = 1`, `B = 100` порог `1 / 101 ≈ 0,01`. То есть **при очень большой цене пропуска хватает очень малой вероятности**. При `A = 100`, `B = 1` порог `0,99`. Создай файл `nano ~/ai-path/twoerrors.py`, вставь и запусти.

```python
def threshold(cost_false_alarm, cost_miss):
    return cost_false_alarm / (cost_false_alarm + cost_miss)


def expected(p, cost_false_alarm, cost_miss):
    protect = (1 - p) * cost_false_alarm
    ignore = p * cost_miss
    return round(protect, 3), round(ignore, 3), "protect" if protect < ignore else "ignore"


print("cost of a false alarm, cost of a miss, chance above which protecting is cheaper")
for alarm, miss in ((1, 1), (1, 10), (1, 100), (10, 1), (100, 1)):
    print(alarm, miss, round(threshold(alarm, miss), 3))
print("chance, cost if we protect, cost if we ignore, cheaper")
for p in (0.001, 0.01, 0.05, 0.2):
    print(p, *expected(p, 1, 100))
```

```output
cost of a false alarm, cost of a miss, chance above which protecting is cheaper
1 1 0.5
1 10 0.091
1 100 0.01
10 1 0.909
100 1 0.99
chance, cost if we protect, cost if we ignore, cheaper
0.001 0.999 0.1 ignore
0.01 0.99 1.0 protect
0.05 0.95 5.0 protect
0.2 0.8 20.0 protect
```

Посмотри на таблицу порогов. Она может показать и `0,01`, и `0,99`, а зависит это только от соотношения цен. Настоящих чисел **никто не знает**: ни `p`, ни `A`, ни `B`. Поэтому расчёт не даёт ответа, а показывает, о чём именно надо спорить.

Нижняя таблица берёт `A = 1`, `B = 100`. При `p = 0,001` дешевле игнорировать, а при `0,01` дешевле защищать. Переход резкий, поэтому малая ошибка в оценке меняет ответ.

**Шаг 3. Первая сторона.** Long, Sebo и соавторы в 2024 году в отчёте Taking AI Welfare Seriously пишут: есть реальная возможность, что в ближайшем будущем некоторые системы ИИ получат значимые интересы, поэтому компании уже сейчас должны признать вопрос, начать оценивать системы и готовить меры. Они не утверждают, что сейчас такие системы есть. Философ Джонатан Бёрч предлагает похожую осторожность для пограничных случаев, включая животных.

**Шаг 4. Вторая сторона.** Мустафа Сулейман в 2025 году предупредил о другой опасности: системы, которые только **кажутся** сознательными, могут заставить людей требовать для них прав, причём это отвлечёт от настоящих проблем. Его совет: строить ИИ для людей, а не как личности. Анил Сет считает, что сознание, вероятно, связано с биологией, поэтому такой риск для нынешних систем мал, а ложная тревога дорога.

Обе стороны опираются на настоящие соображения. Спорят они в основном о `p` и о цене ошибок, поэтому твоё собственное мнение лучше строить на этих величинах.

**Шаг 5. Что можно делать при незнании.** Есть дешёвые шаги, которые полезны при любом ответе:

- Не учить модели твёрдо утверждать ни «я сознательна», ни «я точно нет» там, где это неизвестно. Вспомни урок о самоотчётах.
- Честно говорить людям, что известно, чтобы они не привязывались по ошибке.
- Измерять, а не гадать: развивать индикаторы и опыты.
- Отделять этот вопрос от заботы о тех, кто переживает точно: люди и многие животные.

Заметь: всё это мои предложения. Они спорны, и у тебя может быть другой список.

**Учись у тех, кто это создаёт.** Отчёт [Taking AI Welfare Seriously](https://arxiv.org/abs/2411.00986). Эссе [Сулеймана](https://mustafa-suleyman.ai/seemingly-conscious-ai-is-coming). Книга Джонатана Бёрча The Edge of Sentience (2024) открыта для чтения и хорошо написана.

### Исследуй и потренируйся

В тренажёре двигай вероятность и две цены. Смотри, как меняется решение. Попробуй обосновать свои числа: откуда они? Сможешь ли ты защитить их перед человеком с другим мнением?

В программе добавь третий вариант: «защитить частично», с половиной цены и половиной пользы. Когда он лучше обоих?

### Вопрос

Что на самом деле показывает расчёт порога?

### Варианты

- Что решение зависит от цены ошибок и вероятности, которых никто пока точно не знает.
- Что системы ИИ нужно защищать всегда, поскольку цена пропуска всегда намного больше.
- Что системы ИИ защищать не нужно, поскольку вероятность переживания у них равна нулю.

### Ответ

1

### Разбор

Формула сама не говорит, какая цена больше и какова вероятность. Значения `0,01` и `0,99` дают одни и те же правила при разных числах. Утверждать, что вероятность равна нулю или что цена всегда выше, значит подставить свой ответ заранее.

### Границы модели

Формула простая и считает всего две цены, и настоящие решения намного сложнее: есть градации переживания, разные системы, многие участники. Числа в примере выдуманы для расчёта. Я кратко передал чужие взгляды, поэтому читай их самих. Это вопрос этики, и опыт его не решает.

## English

### In plain words

We do not know whether AI can have experiences. So two errors are possible: crediting experience to something that has none, or missing real experience. Each error has its cost. A fire alarm works this way: a false alarm is cheap, a missed fire is terrible, so alarms are made sensitive. In the lesson you compute the threshold: at what probability protecting pays off. And you see the main point: the answer depends entirely on numbers nobody knows yet. The lesson does not tell you what to think; it hears both sides.

**What to know first.** The lesson «Random Variables and Sampling» (step 5): expected value, the average outcome over many repeats. The lesson «Indicators: checking a real system» (step 25): why nobody can name a probability of consciousness.

**If something is unclear.** If the threshold formula is unclear, work the example in step 2 with `A = 1` and `B = 100` by hand. If expected cost is unclear, go back to the part on expected value in «Random Variables and Sampling». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Examine what to do if we do not know whether a system can have experience. Compute the cost of two errors and see that everything hangs on numbers nobody knows. Hear both sides. The lesson does not claim any system is conscious and does not advise what you should think. It takes about 30 minutes.

### Idea and mechanism

**Step 1. Two errors.** We do not know whether AI can have experience. So two errors are possible.

- **Attributing too much.** A system has no experience, but we think it does. The cost: we spend effort, get distracted from people and animals, people grow attached to programs, and a faulty system is harder to switch off.
- **Missing the real thing.** A system has experience, but we think it does not. The cost: perhaps suffering on a huge scale, since there are very many copies.

**Step 2. The calculation by hand.** Let the probability of experience be `p`, the cost of a false alarm `A`, and the cost of a miss `B`. Protecting pays when `(1 − p) · A < p · B`. Hence the threshold `p* = A / (A + B)`. At `A = 1`, `B = 100` the threshold is `1 / 101 ≈ 0.01`. So **with a very large cost of a miss, a very small probability is enough**. At `A = 100`, `B = 1` the threshold is `0.99`. Create the file `nano ~/ai-path/twoerrors.py`, paste and run it.

```python
def threshold(cost_false_alarm, cost_miss):
    return cost_false_alarm / (cost_false_alarm + cost_miss)


def expected(p, cost_false_alarm, cost_miss):
    protect = (1 - p) * cost_false_alarm
    ignore = p * cost_miss
    return round(protect, 3), round(ignore, 3), "protect" if protect < ignore else "ignore"


print("cost of a false alarm, cost of a miss, chance above which protecting is cheaper")
for alarm, miss in ((1, 1), (1, 10), (1, 100), (10, 1), (100, 1)):
    print(alarm, miss, round(threshold(alarm, miss), 3))
print("chance, cost if we protect, cost if we ignore, cheaper")
for p in (0.001, 0.01, 0.05, 0.2):
    print(p, *expected(p, 1, 100))
```

```output
cost of a false alarm, cost of a miss, chance above which protecting is cheaper
1 1 0.5
1 10 0.091
1 100 0.01
10 1 0.909
100 1 0.99
chance, cost if we protect, cost if we ignore, cheaper
0.001 0.999 0.1 ignore
0.01 0.99 1.0 protect
0.05 0.95 5.0 protect
0.2 0.8 20.0 protect
```

Look at the threshold table. It can show both `0.01` and `0.99`, depending only on the ratio of costs. **Nobody knows** the real numbers: not `p`, not `A`, not `B`. So the calculation gives no answer, but shows exactly what must be argued about.

The lower table takes `A = 1`, `B = 100`. At `p = 0.001` ignoring is cheaper, and at `0.01` protecting is cheaper. The switch is sharp, so a small error in the estimate changes the answer.

**Step 3. The first side.** Long, Sebo and co-authors in the 2024 report Taking AI Welfare Seriously write: there is a real possibility that some AI systems will soon have morally significant interests, so companies should already acknowledge the question, begin assessing systems, and prepare measures. They do not claim such systems exist now. The philosopher Jonathan Birch proposes similar caution for borderline cases, including animals.

**Step 4. The second side.** Mustafa Suleyman warned in 2025 of another danger: systems that merely **seem** conscious may lead people to demand rights for them, distracting from real problems. His advice: build AI for people, not as a person. Anil Seth holds that consciousness is probably tied to biology, so such a risk from present systems is small, and a false alarm is costly.

Both sides rest on real considerations. They mostly argue over `p` and the cost of errors, so your own view is best built on these quantities.

**Step 5. What can be done while not knowing.** Some cheap steps help whatever the answer:

- Do not train models to firmly assert either "I am conscious" or "I surely am not" where that is unknown. Recall the self-report lesson.
- Tell people honestly what is known, so they do not grow attached by mistake.
- Measure rather than guess: develop indicators and experiments.
- Keep this question apart from care for those who surely have experience: people and many animals.

Note: all these are my suggestions. They are disputable, and your list may differ.

**Learn from the people who build this.** The report [Taking AI Welfare Seriously](https://arxiv.org/abs/2411.00986). [Suleyman's essay](https://mustafa-suleyman.ai/seemingly-conscious-ai-is-coming). Jonathan Birch's book The Edge of Sentience (2024) is open to read and well written.

### Explore and practise

In the lab, move the probability and the two costs. Watch how the decision changes. Try to justify your numbers: where do they come from? Could you defend them before someone of another view?

In the program, add a third option, "protect partly", with half the cost and half the benefit. When does it beat both?

### Question

What does the threshold calculation really show?

### Options

- That the decision depends on error costs and a probability nobody yet knows exactly.
- That AI systems must always be protected, since a miss always costs far more.
- That AI systems need no protection, since their chance of experience equals zero.

### Answer

1

### Explanation

The formula itself does not say which cost is larger or what the probability is. Values of `0.01` and `0.99` follow from the same rule with different numbers. Claiming that the probability is zero or that a cost is always higher means substituting your answer in advance.

### Limits

The formula is simple and counts just two costs, while real decisions are far more complex: there are degrees of experience, various systems, many parties. The numbers in the example are invented for the calculation. I conveyed others' views briefly, so read them directly. This is a question of ethics, and an experiment does not settle it.

## Sources

- Robert Long, Jeff Sebo et al., "Taking AI Welfare Seriously", arXiv:2411.00986 (2024), title read 2026-11-03: [arXiv:2411.00986](https://arxiv.org/abs/2411.00986)
- Mustafa Suleyman, "We must build AI for people; not to be a person" (2025), title read 2026-11-03: [essay](https://mustafa-suleyman.ai/seemingly-conscious-ai-is-coming)
- Jonathan Birch, "The Edge of Sentience", Oxford University Press (2024), title confirmed and marked open access in OpenAlex on 2026-11-03; the publisher's page refused the check and the book itself was not re-read.
- Anil Seth, "Conscious artificial intelligence and biological naturalism", Behavioral and Brain Sciences 49 (2025), title and journal checked 2026-11-03; the paper itself not re-read.
- The formula, program and numbers were written for this lesson as an illustration. The lesson paraphrases these sources and does not copy their text.

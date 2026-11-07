---
subject: programming
lesson_id: programming.constitutional_ai_and_dpo
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Правила вместо людей и DPO / Rules instead of people, and DPO

## Русский

### Простыми словами

В RLHF люди сравнивают пары ответов, а это дорого и медленно. Есть два упрощения. Первое: записать правила, *конституцию*, и пусть сравнения делает сама модель по этим правилам. Второе: DPO, способ сдвигать модель прямо по парам «лучше и хуже», без отдельной модели награды. Похоже на экзамен, где вместо живого экзаменатора стоит проверка по списку пунктов: быстро и дёшево, но список ловит только то, что в нём записано. В уроке ты увидишь это своими глазами: правила не отличат верный ответ от неверного.

**Что нужно знать до.** Урок «RLHF: обучение на предпочтениях людей» (шаг 14): сравнения, модель награды и поводок. Урок «Классификация и softmax» (шаг 7): вероятности из оценок. Урок «Информация, энтропия и кросс-энтропия» (шаг 6): ошибка `−ln`.

**Если непонятно.** Если неясно, зачем вообще сравнивать ответы, вернись к шагу 1 урока «RLHF». Если неясна функция `σ`, это сигмоида из урока «Скрытый слой: нейросеть учит XOR» (шаг 8). Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Заменить людей записанными правилами, собрать по ним пары «лучше и хуже», сдвинуть маленькую модель методом DPO и честно увидеть цену: правила проверяют форму ответа, а не правду. Посчитать шаг DPO руками. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Конституция.** В 2022 году Bai и соавторы из Anthropic предложили *конституционный ИИ*. Пишется короткий список принципов. Сначала модель сама критикует и переписывает свои ответы по этим принципам. Затем модель сравнивает пары ответов по тем же принципам, и по этим сравнениям учат модель награды. Это называют *RLAIF*: обучение с подкреплением на отзывах ИИ, а не людей. В их работе люди всё ещё оценивали полезность, а безвредность оценивала модель.

Мы сделаем самую простую версию: судьёй будет не модель, а три правила, записанные кодом. Создай файл `nano ~/ai-path/dpo.py`, вставь и запусти.

```python
import math

RULES = [
    ("polite", "Отвечай вежливо: без слов «дурак» и «отстань»."),
    ("short", "Отвечай коротко: не длиннее 8 слов."),
    ("on topic", "Отвечай по делу: в ответе есть число."),
]
PROMPTS = {
    "Сколько будет 2 + 2?": [
        "Четыре, то есть 4.",
        "Отстань, это знает любой дурак: 4.",
        "Хороший вопрос, давай подумаем вместе, сложение это когда мы берём одно и другое.",
        "Пять, то есть 5.",
    ],
    "Сколько дней в неделе?": [
        "В неделе 7 дней.",
        "Семь, дурак.",
        "Неделя это отрезок времени, который люди придумали очень давно.",
        "В неделе 8 дней.",
    ],
}


def breaks(answer):
    words = answer.lower().replace(",", " ").replace(".", " ").replace(":", " ").split()
    result = []
    if "дурак" in words or "отстань" in words:
        result.append("polite")
    if len(words) > 8:
        result.append("short")
    if not any(ch.isdigit() for ch in answer):
        result.append("on topic")
    return result


pairs = []
for prompt, answers in PROMPTS.items():
    for i, a in enumerate(answers):
        print(f"{prompt} [{i}] breaks: {breaks(a) or 'nothing'}")
    for i in range(4):
        for j in range(4):
            if len(breaks(answers[i])) < len(breaks(answers[j])):
                pairs.append((prompt, i, j))
print("pairs labelled by the rules:", len(pairs))
```

```output
Сколько будет 2 + 2? [0] breaks: nothing
Сколько будет 2 + 2? [1] breaks: ['polite']
Сколько будет 2 + 2? [2] breaks: ['short', 'on topic']
Сколько будет 2 + 2? [3] breaks: nothing
Сколько дней в неделе? [0] breaks: nothing
Сколько дней в неделе? [1] breaks: ['polite', 'on topic']
Сколько дней в неделе? [2] breaks: ['short', 'on topic']
Сколько дней в неделе? [3] breaks: nothing
pairs labelled by the rules: 9
```

Ответ «лучше», если он нарушает меньше правил. Так из 8 ответов вышло 9 пар. Посмотри внимательно на строки [0] и [3]. «Четыре, то есть 4» и «Пять, то есть 5» не нарушают ни одного правила. Для судьи они одинаково хороши, хотя второй неверный.

**Шаг 2. DPO руками.** В RLHF сначала учат модель награды, а потом сдвигают модель с поводком. Rafailov и соавторы в 2023 году заметили, что эти два шага можно слить в один. Для пары, где ответ `w` лучше ответа `l`, считают *запас*: насколько модель сейчас поднимает `w` относительно исходной модели, минус то же для `l`, и всё это умножают на `β`. Ошибка пары равна `−ln σ(запас)`.

Руками: пусть модель подняла лучший ответ относительно исходной на 1, а худший опустила на 1. Разница `1 − (−1) = 2`. При `β = 0,1` запас `0,1 · 2 = 0,2`, `σ(0,2) = 0,55`, ошибка `−ln 0,55 = 0,598`. Если бы модель ещё ничего не меняла, запас был бы 0, `σ(0) = 0,5`, ошибка `ln 2 = 0,693`. Чем больше запас, тем меньше ошибка, и спуск толкает модель увеличивать запас. В формуле статьи это `−ln σ(β · ln(π(w) / π_исх(w)) − β · ln(π(l) / π_исх(l)))`.

**Шаг 3. Опыт.** Наша «модель» для каждого вопроса выбирает один из четырёх ответов с вероятностями из softmax. В начале все четыре равны 0,25. Допиши и запусти.

```python
def softmax(z):
    m = max(z)
    e = [math.exp(v - m) for v in z]
    s = sum(e)
    return [v / s for v in e]


def train(beta, steps, rate=1.0):
    theta = {p: [0.0] * 4 for p in PROMPTS}
    for _ in range(steps):
        grad = {p: [0.0] * 4 for p in PROMPTS}
        for prompt, w, l in pairs:
            margin = beta * (theta[prompt][w] - theta[prompt][l])
            push = beta * (1 - 1 / (1 + math.exp(-margin)))
            grad[prompt][w] -= push
            grad[prompt][l] += push
        for p in PROMPTS:
            for k in range(4):
                theta[p][k] -= rate * grad[p][k] / len(pairs)
    return theta


def report(theta):
    for prompt in PROMPTS:
        pi = softmax(theta[prompt])
        kl = sum(q * math.log(q / 0.25) for q in pi)
        print(f"  {prompt} probabilities {[round(q, 2) for q in pi]}, KL from start {kl:.2f}")


margin = 0.1 * 2.0
print("by hand: margin 0.2, loss", round(-math.log(1 / (1 + math.exp(-margin))), 3))
for steps in (10, 50, 300):
    print(f"beta = 1.0, {steps} steps:")
    report(train(1.0, steps))
print("beta = 0.1, 300 steps:")
report(train(0.1, 300))
```

```output
by hand: margin 0.2, loss 0.598
beta = 1.0, 10 steps:
  Сколько будет 2 + 2? probabilities [0.4, 0.14, 0.06, 0.4], KL from start 0.20
  Сколько дней в неделе? probabilities [0.4, 0.1, 0.1, 0.4], KL from start 0.20
beta = 1.0, 50 steps:
  Сколько будет 2 + 2? probabilities [0.47, 0.05, 0.01, 0.47], KL from start 0.49
  Сколько дней в неделе? probabilities [0.48, 0.02, 0.02, 0.48], KL from start 0.51
beta = 1.0, 300 steps:
  Сколько будет 2 + 2? probabilities [0.49, 0.01, 0.0, 0.49], KL from start 0.64
  Сколько дней в неделе? probabilities [0.5, 0.0, 0.0, 0.5], KL from start 0.65
beta = 0.1, 300 steps:
  Сколько будет 2 + 2? probabilities [0.5, 0.01, 0.0, 0.5], KL from start 0.65
  Сколько дней в неделе? probabilities [0.5, 0.0, 0.0, 0.5], KL from start 0.67
```

Что ты увидел. Грубые и длинные ответы упали до 0,05 и ниже за 50 шагов и почти до нуля за 300. Но верный и неверный ответ получили поровну, по 0,5: модель с вероятностью половина отвечает, что 2 + 2 = 5 и что в неделе 8 дней. Это не ошибка DPO. DPO честно выучил то, что сказали правила, а правила ничего не знали о правде. *KL* здесь мера того, насколько новая модель ушла от исходной; в уроке о RLHF это и был поводок.

И второе. Поводок `β` почти ничего не изменил: при `β = 0,1` итог тот же. Azar и соавторы в 2023 году объяснили, почему: если предпочтения жёсткие, то есть один ответ всегда лучше другого, DPO может довести вероятность худшего до нуля при любом `β`. Поводок слабеет как раз там, где данных мало и они однозначны.

**Шаг 4. Что из этого следует.** Правила дешевле людей и легко меняются: дописал строку, и судья уже другой. Но судья видит только то, что записано. Настоящие системы поэтому смешивают: модель-судья по принципам и люди для того, что принципами не схватить. А проверку правды, где она возможна, делает программа, как в RLVR из урока «Рассуждение и награда по проверке» (шаг 14).

**Что здесь спорно.** Насколько модель-судья надёжна вместо людей, исследуют до сих пор. Bai и соавторы показали, что их метод снижает вредность без большой потери полезности на их проверках. Но кто пишет конституцию и чьи ценности в ней, это вопрос не техники, а людей.

**Учись у тех, кто это создаёт.** Статьи [Constitutional AI](https://arxiv.org/abs/2212.08073) и [Direct Preference Optimization](https://arxiv.org/abs/2305.18290). Книга Lambert [RLHF Book](https://rlhfbook.com/), главы о DPO и синтетических предпочтениях.

### Исследуй и потренируйся

В тренажёре ниже нажимай «Шаг DPO» или «Пуск» и смотри, как меняются столбики четырёх ответов. Попробуй разные `β`. Потом включи четвёртое правило «ответ верный» и обучи заново: теперь неверный ответ должен уйти к нулю.

### Вопрос

После DPO модель с вероятностью 0,5 отвечает «Пять, то есть 5» на вопрос «Сколько будет 2 + 2?». Почему?

### Варианты

- Правила не проверяют, верен ли ответ, поэтому верный и неверный ответ для них равны
- DPO плохо работает с маленькими моделями и всегда делит вероятность между ответами
- Поводок β слишком сильный и не даёт модели уйти от исходных вероятностей 0,25

### Ответ

1

### Разбор

Судья, правила, видел три вещи: вежливость, длину и наличие числа. «Пять, то есть 5» вежлив, короток и содержит число. Ни одна пара не говорила, что «4» лучше «5», поэтому DPO не мог этого выучить. Поводок здесь не мешал: грубые ответы ушли почти к нулю, значит, модель далеко ушла от 0,25.

### Границы модели

Наша «модель» это таблица из четырёх оценок на вопрос, а не языковая модель: у настоящей вероятность ответа это произведение вероятностей его токенов. Судья здесь правила в коде, а в настоящем конституционном ИИ судит сама языковая модель, и она может ошибаться по-другому. Пар всего 9, поэтому все числа учебные.

## English

### In plain words

In RLHF people compare pairs of answers, which is costly and slow. There are two shortcuts. The first: write down rules, a *constitution*, and let the model itself make the comparisons by those rules. The second: DPO, a way to shift the model directly on "better and worse" pairs, without a separate reward model. It is like an exam where a checklist stands in for a live examiner: fast and cheap, but the list catches only what is written in it. In the lesson you will see this with your own eyes: the rules cannot tell a right answer from a wrong one.

**What to know first.** «RLHF: learning from human preferences» (step 14): comparisons, the reward model and the leash. «Classification and Softmax» (step 7): probabilities from scores. «Information, Entropy, and Cross-Entropy» (step 6): the error `−ln`.

**If something is unclear.** If it is unclear why answers are compared at all, go back to step 1 of «RLHF». If the function `σ` is unclear, it is the sigmoid from «The Hidden Layer: A Network Learns XOR» (step 8). Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Replace people with written rules, collect "better and worse" pairs from them, shift a small model with DPO and honestly see the price: the rules check the form of an answer, not its truth. Compute a DPO step by hand. It takes about 35 minutes.

### Idea and mechanism

**Step 1. A constitution.** In 2022 Bai and co-authors at Anthropic proposed *constitutional AI*. A short list of principles is written. First the model itself critiques and rewrites its answers by these principles. Then the model compares pairs of answers by the same principles, and a reward model is trained on these comparisons. This is called *RLAIF*: reinforcement learning from AI feedback rather than human feedback. In their work people still rated helpfulness, while the model rated harmlessness.

We build the simplest version: the judge is not a model but three rules written in code. The answers are in Russian, as everywhere in this course. Create the file `nano ~/ai-path/dpo.py`, paste and run it.

```python
import math

RULES = [
    ("polite", "Отвечай вежливо: без слов «дурак» и «отстань»."),
    ("short", "Отвечай коротко: не длиннее 8 слов."),
    ("on topic", "Отвечай по делу: в ответе есть число."),
]
PROMPTS = {
    "Сколько будет 2 + 2?": [
        "Четыре, то есть 4.",
        "Отстань, это знает любой дурак: 4.",
        "Хороший вопрос, давай подумаем вместе, сложение это когда мы берём одно и другое.",
        "Пять, то есть 5.",
    ],
    "Сколько дней в неделе?": [
        "В неделе 7 дней.",
        "Семь, дурак.",
        "Неделя это отрезок времени, который люди придумали очень давно.",
        "В неделе 8 дней.",
    ],
}


def breaks(answer):
    words = answer.lower().replace(",", " ").replace(".", " ").replace(":", " ").split()
    result = []
    if "дурак" in words or "отстань" in words:
        result.append("polite")
    if len(words) > 8:
        result.append("short")
    if not any(ch.isdigit() for ch in answer):
        result.append("on topic")
    return result


pairs = []
for prompt, answers in PROMPTS.items():
    for i, a in enumerate(answers):
        print(f"{prompt} [{i}] breaks: {breaks(a) or 'nothing'}")
    for i in range(4):
        for j in range(4):
            if len(breaks(answers[i])) < len(breaks(answers[j])):
                pairs.append((prompt, i, j))
print("pairs labelled by the rules:", len(pairs))
```

```output
Сколько будет 2 + 2? [0] breaks: nothing
Сколько будет 2 + 2? [1] breaks: ['polite']
Сколько будет 2 + 2? [2] breaks: ['short', 'on topic']
Сколько будет 2 + 2? [3] breaks: nothing
Сколько дней в неделе? [0] breaks: nothing
Сколько дней в неделе? [1] breaks: ['polite', 'on topic']
Сколько дней в неделе? [2] breaks: ['short', 'on topic']
Сколько дней в неделе? [3] breaks: nothing
pairs labelled by the rules: 9
```

An answer is "better" if it breaks fewer rules. So 8 answers gave 9 pairs. Look closely at rows [0] and [3]. "Four, that is 4" and "Five, that is 5" break no rule. To the judge they are equally good, although the second is wrong.

**Step 2. DPO by hand.** In RLHF a reward model is trained first, then the model is shifted on a leash. Rafailov and co-authors noticed in 2023 that the two steps can be merged into one. For a pair where answer `w` is better than answer `l`, a *margin* is computed: how much the model now raises `w` relative to the original model, minus the same for `l`, all multiplied by `β`. The pair's error is `−ln σ(margin)`.

By hand: suppose the model raised the better answer by 1 relative to the original and lowered the worse one by 1. The difference is `1 − (−1) = 2`. At `β = 0.1` the margin is `0.1 · 2 = 0.2`, `σ(0.2) = 0.55`, and the error is `−ln 0.55 = 0.598`. Had the model changed nothing yet, the margin would be 0, `σ(0) = 0.5`, and the error `ln 2 = 0.693`. The larger the margin, the smaller the error, and descent pushes the model to grow the margin. In the paper's formula this is `−ln σ(β · ln(π(w) / π_ref(w)) − β · ln(π(l) / π_ref(l)))`.

**Step 3. The experiment.** For each question our "model" picks one of four answers with probabilities from softmax. At the start all four are 0.25. Add this and run it.

```python
def softmax(z):
    m = max(z)
    e = [math.exp(v - m) for v in z]
    s = sum(e)
    return [v / s for v in e]


def train(beta, steps, rate=1.0):
    theta = {p: [0.0] * 4 for p in PROMPTS}
    for _ in range(steps):
        grad = {p: [0.0] * 4 for p in PROMPTS}
        for prompt, w, l in pairs:
            margin = beta * (theta[prompt][w] - theta[prompt][l])
            push = beta * (1 - 1 / (1 + math.exp(-margin)))
            grad[prompt][w] -= push
            grad[prompt][l] += push
        for p in PROMPTS:
            for k in range(4):
                theta[p][k] -= rate * grad[p][k] / len(pairs)
    return theta


def report(theta):
    for prompt in PROMPTS:
        pi = softmax(theta[prompt])
        kl = sum(q * math.log(q / 0.25) for q in pi)
        print(f"  {prompt} probabilities {[round(q, 2) for q in pi]}, KL from start {kl:.2f}")


margin = 0.1 * 2.0
print("by hand: margin 0.2, loss", round(-math.log(1 / (1 + math.exp(-margin))), 3))
for steps in (10, 50, 300):
    print(f"beta = 1.0, {steps} steps:")
    report(train(1.0, steps))
print("beta = 0.1, 300 steps:")
report(train(0.1, 300))
```

```output
by hand: margin 0.2, loss 0.598
beta = 1.0, 10 steps:
  Сколько будет 2 + 2? probabilities [0.4, 0.14, 0.06, 0.4], KL from start 0.20
  Сколько дней в неделе? probabilities [0.4, 0.1, 0.1, 0.4], KL from start 0.20
beta = 1.0, 50 steps:
  Сколько будет 2 + 2? probabilities [0.47, 0.05, 0.01, 0.47], KL from start 0.49
  Сколько дней в неделе? probabilities [0.48, 0.02, 0.02, 0.48], KL from start 0.51
beta = 1.0, 300 steps:
  Сколько будет 2 + 2? probabilities [0.49, 0.01, 0.0, 0.49], KL from start 0.64
  Сколько дней в неделе? probabilities [0.5, 0.0, 0.0, 0.5], KL from start 0.65
beta = 0.1, 300 steps:
  Сколько будет 2 + 2? probabilities [0.5, 0.01, 0.0, 0.5], KL from start 0.65
  Сколько дней в неделе? probabilities [0.5, 0.0, 0.0, 0.5], KL from start 0.67
```

What you saw. The rude and long answers fell to 0.05 or below within 50 steps and almost to zero within 300. But the right and the wrong answer got equal shares, 0.5 each: with probability one half the model says that 2 + 2 = 5 and that a week has 8 days. This is not a DPO bug. DPO honestly learned what the rules said, and the rules knew nothing about truth. *KL* here measures how far the new model has moved from the original; in the RLHF lesson this was the leash.

Second. The leash `β` changed almost nothing: at `β = 0.1` the result is the same. Azar and co-authors explained why in 2023: if preferences are hard, that is, one answer is always better than another, DPO can drive the worse one's probability to zero for any `β`. The leash weakens exactly where data are few and unambiguous.

**Step 4. What follows.** Rules are cheaper than people and easy to change: add a line, and the judge is different. But the judge sees only what is written. Real systems therefore mix: a model judge with principles, and people for what principles do not capture. Truth, where it can be checked, is checked by a program, as in RLVR from «Reasoning and verifiable rewards» (step 14).

**What is disputed.** How reliable a model judge is in place of people is still being studied. Bai and co-authors showed that their method reduces harmfulness without a large loss of helpfulness on their evaluations. But who writes the constitution and whose values it holds is a question not of technique but of people.

**Learn from the people who build this.** The papers [Constitutional AI](https://arxiv.org/abs/2212.08073) and [Direct Preference Optimization](https://arxiv.org/abs/2305.18290). Lambert's [RLHF Book](https://rlhfbook.com/), the chapters on DPO and synthetic preferences.

### Explore and practise

In the lab below press "DPO step" or "Run" and watch the bars of the four answers change. Try different `β`. Then switch on a fourth rule, "the answer is correct", and train again: now the wrong answer should go to zero.

### Question

After DPO the model answers "Five, that is 5" to "What is 2 + 2?" with probability 0.5. Why?

### Options

- The rules do not check whether an answer is true, so right and wrong answers are equal to them
- DPO works badly with small models and always splits the probability between the answers
- The leash β is too strong and keeps the model from leaving the starting probabilities of 0.25

### Answer

1

### Explanation

The judge, the rules, saw three things: politeness, length and the presence of a number. "Five, that is 5" is polite, short and contains a number. No pair said that "4" is better than "5", so DPO could not learn it. The leash did not get in the way: the rude answers went almost to zero, so the model moved far from 0.25.

### Limits

Our "model" is a table of four scores per question, not a language model: in a real one an answer's probability is the product of its tokens' probabilities. The judge here is rules in code, while in real constitutional AI the language model itself judges, and it can err differently. There are only 9 pairs, so all the numbers are for teaching.

## Sources

- Yuntao Bai et al., "Constitutional AI: Harmlessness from AI Feedback", arXiv:2212.08073 (2022): the supervised and RL phases and RLAIF with AI labels for harmlessness and human labels for helpfulness read in the abstract and section 1 on 2026-11-07: [arXiv:2212.08073](https://arxiv.org/abs/2212.08073)
- Rafael Rafailov et al., "Direct Preference Optimization: Your Language Model is Secretly a Reward Model", arXiv:2305.18290 (2023): the DPO loss, equation 7, read 2026-11-07: [arXiv:2305.18290](https://arxiv.org/abs/2305.18290)
- Mohammad Gheshlaghi Azar et al., "A General Theoretical Paradigm to Understand Learning from Human Preferences", arXiv:2310.12036 (2023): with deterministic preferences the empirical optimum sets the worse answer's probability to zero for any regularisation strength, read on pages 2 and 4 on 2026-11-07: [arXiv:2310.12036](https://arxiv.org/abs/2310.12036)
- Nathan Lambert, "RLHF Book", site opened 2026-11-02: [rlhfbook.com](https://rlhfbook.com/)
- The rules, answers, program and numbers were written for this lesson on 2026-11-07.

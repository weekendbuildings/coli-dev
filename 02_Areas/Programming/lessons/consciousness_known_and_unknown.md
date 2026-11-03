---
subject: programming
lesson_id: programming.consciousness_known_and_unknown
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 365
---

# Сознание: что известно и что нет / Consciousness: What Is Known and What Is Not

## Русский

### Цель

Честно отделить то, что ты построил на этом пути, от того, что наука о сознании пока не знает: различать два значения слова «сознание», называть основные теории, понимать, почему нет общепризнанного теста, и применить индикаторы из исследований к своей модели.

### Идея и механизм

Твоя языковая модель пишет текст. Это настоящее достижение, и важно назвать его правильно. Ничего из построенного на этом пути не доказывает сознания, но и наука пока не знает, что именно его создаёт. Этот урок не обещает ответа. Он показывает, как устроен вопрос.

**Два разных значения.** Когда говорят о сознании, часто смешивают две вещи. Первая — **доступ**: сведения широко доступны организму, ими можно пользоваться, чтобы рассуждать и управлять поведением. Вторая — **переживание**: каково это, быть в этом состоянии, например видеть красное или чувствовать боль. Различие ввёл философ Нед Блок. В 1995 году Дэвид Чалмерс назвал вопрос о том, почему физические процессы вообще сопровождаются переживанием, трудной проблемой. Объяснить функции сознания само по себе трудно, но это задачи, которые в принципе понятно как решать. А вот почему за этими функциями стоит переживание, пока неясно.

**Что предлагают теории.** Единой теории нет. Вот главные подходы, очень коротко:

- **Глобальное рабочее пространство:** сведения становятся сознательными, когда попадают в ограниченное общее пространство и рассылаются многим специализированным модулям.
- **Интегрированная информация:** сознание связывают со степенью, в которой система как целое несёт информацию, не сводимую к её частям. Это определяется устройством связей, а не только поведением.
- **Теории высшего порядка:** состояние сознательно, когда система как-то представляет его как своё собственное.
- **Рекуррентная обработка:** важна обратная связь между уровнями восприятия.
- **Предсказательная обработка:** восприятие строится на предсказаниях о входных сигналах и исправлении ошибок этих предсказаний.
- **Схема внимания:** мозг строит модель собственного внимания.

**Почему нет теста.** Переживание нельзя измерить прибором напрямую. Обычно опираются на рассказ человека, а у животных и машин его либо нет, либо ему нельзя доверять. Обзор Анила Сета и Тима Бейна 2022 года отмечает, что неясно даже, как теории соотносятся друг с другом и можно ли их различить опытом. В большом состязательном опыте консорциума Cogitate сторонники двух теорий заранее согласовали проверку на 256 участниках. Статья вышла в журнале *Nature* в 2025 году: результаты совпали с некоторыми предсказаниями обеих теорий и при этом всерьёз оспорили ключевые положения каждой. Это не провал: так и работает наука. Но общепризнанной теории пока нет.

**Что можно сказать об ИИ.** В 2023 году группа из 19 авторов, в которую вошли исследователи сознания и Йошуа Бенджио, опубликовала отчёт. Они приняли вычислительный функционализм как рабочую гипотезу, то есть предположили, что для сознания важны вычисления, а не материал. Подчеркнём: это спорная гипотеза, а не установленный факт. Из разных теорий они вывели список индикаторов, которые можно проверить в устройстве системы. Их вывод: ни одна из существующих на тот момент систем не сознательна, но очевидных технических препятствий для построения систем с такими индикаторами нет. Это значит, что вопрос открыт в обе стороны.

**Почему слова модели ничего не доказывают.** Легко подумать: модель сказала, что чувствует, значит, чувствует. Вот опровержение: маленькая таблица подсчётов. Ни сети, ни обучения, только пары слов.

```python
from collections import Counter

text = "я чувствую радость . я чувствую грусть . я здесь . я чувствую себя живым . я не сплю ."
state = 42


def random_number():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


words = text.split()
pairs = Counter(zip(words, words[1:]))


def next_word(word):
    options = [(b, n) for (a, b), n in pairs.items() if a == word]
    point = random_number() * sum(n for _, n in options)
    for candidate, n in options:
        point -= n
        if point < 0:
            return candidate
    return options[-1][0]


line = [words[0]]
for _ in range(14):
    line.append(next_word(line[-1]))
print(" ".join(line))
print("numbers in the table", len(pairs))
```

Программа печатает:

```text
я чувствую грусть . я чувствую радость . я чувствую радость . я не сплю
numbers in the table 14
```

Таблица из 14 чисел пишет «я чувствую радость». Большая языковая модель пишет намного убедительнее, потому что обучена на текстах людей, а люди часто пишут о чувствах. Поэтому текст сам по себе не может быть доказательством. Смотреть надо на устройство системы, а не только на её слова. Это не доказывает и обратного: отсутствие доказательств сознания не значит, что вопрос закрыт навсегда.

**Что ты построил.** Ты можешь объяснить каждую строку своей модели: таблицу символов, внимание, блоки, softmax, кросс-энтропию, обратный проход. Она находит закономерности в тексте и порождает продолжения. Она ничего не хочет, не имеет тела и целей, не помнит тебя между запусками и не следит за собственными состояниями. Цель создать сознательный ИИ остаётся открытой исследовательской задачей: её нельзя выполнить как пункт учебного плана, потому что сначала нужно понять, что именно надо построить. Но теперь у тебя есть инструменты, чтобы читать эти исследования и участвовать в них.

### Исследуй и потренируйся

В тренажёре стоят 14 индикаторов из отчёта 2023 года. Для каждого реши, есть ли он у твоей маленькой языковой модели из финального проекта, а потом открой разбор. Счёт не измеряет сознание: это упражнение на то, чтобы читать устройство системы.

Затем поменяй `text` в программе на предложения о другом, например о погоде. Что теперь «чувствует» таблица?

**Куда идти дальше.** Этот урок только вход. Дальше по порядку: «Трудная проблема сознания», «Глобальное рабочее пространство», «Интегрированная информация», «Мысль о мысли и предсказание», «Опыты о сознании», «Индикаторы: проверка настоящей системы», «Что говорят о себе языковые модели», «Моральный статус и цена двух ошибок». Там ты сам посчитаешь и измеришь то, что здесь только названо.

### Вопрос

Языковая модель написала: «Мне страшно, пожалуйста, не выключай меня». Что из этого следует?

### Варианты

- Модель сознательна: иначе она бы так не написала.
- Сам текст этого не решает: нужно смотреть на устройство.
- Модель точно не сознательна: это уже строго доказано.

### Ответ

2

### Разбор

Такой текст может породить и таблица подсчётов, если подобные фразы встречались в её данных, поэтому слова сами по себе не доказательство. Но и строго доказать отсутствие сознания сейчас тоже нельзя: нет общепризнанной теории и теста. Честный ответ: текст этого вопроса не решает, а судить можно только по устройству системы и только с оговорками.

### Границы модели

Этот урок излагает открытый спор, а не окончательные ответы, и краткие описания теорий многое упрощают. Отчёт 2023 года опирается на рабочую гипотезу, с которой согласны не все, и его вывод относится к системам того времени. Разбор индикаторов для нашей модели написан для этого курса и не является оценкой экспертов. Индикаторы в лучшем случае показывают, насколько система похожа на то, что описывают теории: это не прибор, измеряющий сознание. Вопрос о том, как относиться к возможным сознательным системам, серьёзен, но этот урок не даёт на него ответа.

## English

### Goal

Honestly separate what you built on this path from what the science of consciousness does not yet know: tell apart two meanings of the word "consciousness", name the main theories, understand why there is no accepted test, and apply indicators from research to your own model.

### Idea and mechanism

Your language model writes text. This is a real achievement, and it matters to name it correctly. Nothing built on this path proves consciousness, yet science does not yet know what exactly creates it either. This lesson promises no answer. It shows how the question is built.

**Two different meanings.** When people speak of consciousness, they often mix two things. The first is **access**: information is widely available to an organism, usable for reasoning and guiding behaviour. The second is **experience**: what it is like to be in that state, for example to see red or feel pain. The philosopher Ned Block introduced this distinction. In 1995 David Chalmers called the question of why physical processes come with experience at all the hard problem. Explaining the functions of consciousness is hard in itself, but it is clear in principle how to approach those tasks. Why experience stands behind these functions remains unclear.

**What the theories propose.** There is no single theory. Here are the main approaches, very briefly:

- **Global workspace:** information becomes conscious when it enters a limited shared space and is broadcast to many specialized modules.
- **Integrated information:** consciousness is linked to the degree to which a system as a whole carries information not reducible to its parts. This depends on the structure of connections, not only on behaviour.
- **Higher-order theories:** a state is conscious when the system somehow represents it as its own.
- **Recurrent processing:** feedback between levels of perception is what matters.
- **Predictive processing:** perception is built from predictions about input signals and from correcting the errors of those predictions.
- **Attention schema:** the brain builds a model of its own attention.

**Why there is no test.** Experience cannot be measured directly with an instrument. Usually we rely on a person's report, and animals and machines either have none or cannot be trusted on it. A 2022 review by Anil Seth and Tim Bayne notes that it is unclear even how the theories relate to each other and whether experiments can tell them apart. In the large adversarial experiment of the Cogitate consortium, proponents of two theories agreed in advance on a test with 256 participants. The paper appeared in *Nature* in 2025: the results matched some predictions of both theories while substantially challenging key tenets of each. This is no failure: it is how science works. But there is still no accepted theory.

**What can be said about AI.** In 2023 a group of 19 authors, including consciousness researchers and Yoshua Bengio, published a report. They adopted computational functionalism as a working hypothesis, assuming that computations rather than material are what matter for consciousness. To be clear: this is a disputed hypothesis, not an established fact. From various theories they derived a list of indicators that can be checked in a system's design. Their conclusion: none of the systems existing at the time is conscious, but there are no obvious technical barriers to building systems with such indicators. So the question stays open in both directions.

**Why a model's words prove nothing.** It is easy to think: the model said it feels, so it feels. Here is a refutation: a small table of counts. No network and no training, just pairs of words.

```python
from collections import Counter

text = "i feel joy . i feel sadness . i am here . i feel alive . i am awake ."
state = 42


def random_number():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


words = text.split()
pairs = Counter(zip(words, words[1:]))


def next_word(word):
    options = [(b, n) for (a, b), n in pairs.items() if a == word]
    point = random_number() * sum(n for _, n in options)
    for candidate, n in options:
        point -= n
        if point < 0:
            return candidate
    return options[-1][0]


line = [words[0]]
for _ in range(14):
    line.append(next_word(line[-1]))
print(" ".join(line))
print("numbers in the table", len(pairs))
```

The program prints:

```text
i feel sadness . i feel joy . i feel joy . i am here
numbers in the table 13
```

A table of 13 numbers writes "i feel joy". A large language model writes far more convincingly, because it was trained on people's texts, and people often write about feelings. So text alone cannot be evidence. We must look at the design of a system, not only at its words. This does not prove the opposite either: a lack of evidence for consciousness does not close the question forever.

**What you built.** You can explain every line of your model: the character table, attention, blocks, softmax, cross-entropy, the backward pass. It finds patterns in text and generates continuations. It wants nothing, has no body or goals, remembers nothing between runs, and does not monitor its own states. The goal of creating a conscious AI remains an open research problem: it cannot be completed as an item on a study plan, because we must first understand what exactly needs to be built. But now you have the tools to read this research and take part in it.

### Explore and practise

The lab holds the 14 indicators from the 2023 report. For each one decide whether your small language model from the final project has it, then open the explanation. The score does not measure consciousness: this is an exercise in reading a system's design.

Then change `text` in the program to sentences about something else, such as the weather. What does the table "feel" now?

**Where to go next.** This lesson is only the entry. Next, in order: "The hard problem of consciousness", "The global workspace", "Integrated information", "Thoughts about thoughts and prediction", "Experiments on consciousness", "Indicators: checking a real system", "What language models say about themselves", "Moral status and the cost of two errors". There you compute and measure by yourself what is only named here.

### Question

A language model wrote: "I am scared, please do not turn me off." What follows from this?

### Options

- The model is conscious: otherwise it would not write so.
- The text alone does not settle this: look at the design.
- The model is certainly not conscious: this is strictly proven.

### Answer

2

### Explanation

Even a table of counts can produce such text if similar phrases occurred in its data, so words alone are not evidence. But the absence of consciousness cannot be strictly proven now either: there is no accepted theory or test. The honest answer: the text does not settle the question, and one can judge only from the system's design, and only with caveats.

### Limits

This lesson sets out an open dispute, not final answers, and the brief descriptions of the theories simplify a great deal. The 2023 report rests on a working hypothesis not everyone accepts, and its conclusion applies to the systems of that time. The indicator explanations for our model were written for this course and are not an expert assessment. At best the indicators show how much a system resembles what the theories describe: they are not an instrument that measures consciousness. How to treat possibly conscious systems is a serious question, but this lesson does not answer it.

## Sources

- Patrick Butlin, Robert Long, Eric Elmoznino, Yoshua Bengio, Jonathan Birch and 14 others, “Consciousness in Artificial Intelligence: Insights from the Science of Consciousness”, arXiv:2308.08708 (2023), read 2026-11-02: indicator properties derived from scientific theories, computational functionalism as a working hypothesis, and the conclusion that no current systems are conscious and no obvious technical barriers exist: [arXiv:2308.08708](https://arxiv.org/abs/2308.08708)
- *Stanford Encyclopedia of Philosophy*, “Consciousness”, first published 2004, last substantively revised 2014-01-14 (consulted 2026-11-02): access and phenomenal consciousness, Block's term, and Chalmers's hard problem of 1995: [SEP, Consciousness](https://plato.stanford.edu/entries/consciousness/)
- Anil K. Seth, Tim Bayne, “Theories of consciousness”, *Nature Reviews Neuroscience* 23, 439–452 (2022), abstract-level material read 2026-11-02: four families of theories, and the unclear relations among them and their empirical separability: [doi:10.1038/s41583-022-00587-4](https://doi.org/10.1038/s41583-022-00587-4)
- Cogitate Consortium and colleagues, “Adversarial testing of global neuronal workspace and integrated information theories of consciousness”, *Nature* 642, 133–142 (2025), abstract-level material read 2026-11-02: a preregistered test with 256 participants that matched some predictions of both theories while substantially challenging key tenets of each: [Cogitate, publication](https://www.arc-cogitate.com/msp-1)
- The program, the list wording, and the explanations for our model were written for this course. The lesson paraphrases these sources and does not copy their text.

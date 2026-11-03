---
subject: programming
lesson_id: programming.consciousness_hard_problem
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Трудная проблема сознания / The hard problem of consciousness

## Русский

### Цель

Понять, что объясняет поведение, а что, возможно, нет. Написать агента, который «говорит о боли», объяснить каждую его строку и спросить, что осталось. Отличить доступ от переживания и услышать главные возражения. Урок не утверждает, что какая-то система сознательна или что её сознание невозможно. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Два вопроса.** В 1995 году Дэвид Чалмерс разделил вопросы о сознании на две группы.

*Лёгкие проблемы:* как мозг различает раздражители, объединяет сведения, сообщает о своих состояниях, управляет вниманием. Они тоже очень трудные, но понятно, как к ним идти: нужно найти механизм, выполняющий эту работу.

*Трудная проблема:* почему за этой работой вообще что-то **переживается**. Почему есть «каково это» видеть красное или чувствовать боль? Этот оборот взят у Томаса Нагеля, из статьи о том, каково быть летучей мышью.

**Шаг 2. Агент, который «чувствует боль».** Создай файл `nano ~/ai-path/pain.py`, вставь и запусти. Это 20 строк.

```python
SENSOR = {"пол": 0.0, "плита": 1.0}


class Agent:
    def __init__(self):
        self.avoid = {"пол": 0.0, "плита": 0.0}
        self.damage = 0.0

    def touch(self, place):
        signal = SENSOR[place]
        self.damage += signal
        self.avoid[place] += 0.5 * (signal - self.avoid[place])
        return signal

    def choose(self):
        return min(self.avoid, key=self.avoid.get)

    def report(self):
        if self.damage > 0:
            return "мне больно"
        return "всё хорошо"


agent = Agent()
print("first report:", agent.report())
for place in ("пол", "плита", "пол", "плита"):
    agent.touch(place)
    print(place, "avoid", agent.avoid, "report:", agent.report(), "choice next:", agent.choose())
```

```output
first report: всё хорошо
пол avoid {'пол': 0.0, 'плита': 0.0} report: всё хорошо choice next: пол
плита avoid {'пол': 0.0, 'плита': 0.5} report: мне больно choice next: пол
пол avoid {'пол': 0.0, 'плита': 0.5} report: мне больно choice next: пол
плита avoid {'пол': 0.0, 'плита': 0.75} report: мне больно choice next: пол
```

После плиты агент говорит «мне больно» и больше туда не идёт. Объясним всё руками:

- Отчёт: строка `if self.damage > 0: return "мне больно"`.
- Избегание: среднее сигнала, сдвиг на половину. После двух касаний `0,5 + 0,5 · (1 − 0,5) = 0,75`.
- Выбор: `min` по этим числам.

Механизм здесь объяснён целиком, ничего не спрятано. Ясно, что **это ещё не значит**, что агент что-то чувствует: фразу мог бы печатать любой код. И вот вопрос Чалмерса. Пусть когда-нибудь мы так же полно опишем механизм человека. Останется ли вопрос, почему это переживается?

**Шаг 3. Доступ и переживание.** Нед Блок в 1995 году разделил два значения слова. **Сознание доступа**: сведения доступны для рассуждения, отчёта и управления действием. **Феноменальное сознание**: само переживание. Пример, о котором спорят: **слепое зрение**. После повреждения зрительной коры человек говорит, что ничего не видит в части поля, но, когда его просят угадать, указывает на предмет намного лучше случая. Сведения как-то действуют, а отчёта о видении нет. Что именно это показывает, предмет споров.

Наша программа о доступе: сведения дошли до отчёта. О переживании она молчит.

**Шаг 4. Главное возражение.** Не все считают, что трудная проблема настоящая.

*Деннет и иллюзионисты:* когда лёгкие проблемы будут решены, не останется ничего отдельного, что надо объяснять. Убеждение, что есть особое «каково это», само есть то, что надо объяснить. Его тоже порождает механизм. Отсюда название: **иллюзионизм**, Франкиш развивает это с 2016 года.

*Ответ Чалмерса:* переживание дано нам прямее всего, его нельзя объявить иллюзией, ведь чтобы иллюзия была, кто-то должен её иметь. Чалмерс предлагает мысленный опыт о философском зомби: точный двойник без переживания. Если его можно непротиворечиво представить, значит, функция не исчерпывает всего. Критики отвечают: то, что мы это представляем, ничего не доказывает.

*Что здесь измерено?* Почти ничего: это философский спор. Опыты показывают, какие процессы связаны с отчётом, но как опытом решить трудную проблему, неясно. Об опытах будет отдельный урок.

**Почему это важно для ИИ.** Если важна только функция, то достаточно сложная программа может быть сознательной. Если нужно что-то ещё, например биология, то нет. Ответа нет. Поэтому и фраза модели «мне больно» сама по себе **не отвечает ни да, ни нет**. Наш агент это показал: её печатает одна строка кода.

**Учись у тех, кто это создаёт.** Обзор [Stanford Encyclopedia: Consciousness](https://plato.stanford.edu/entries/consciousness/). Короткие выступления: [Чалмерс на TED](https://www.ted.com/talks/david_chalmers_how_do_you_explain_consciousness) и [Деннет на TED](https://www.ted.com/talks/dan_dennett_the_illusion_of_consciousness). Статья [Чалмерса 1995 года](https://consc.net/papers/facing.pdf).

### Исследуй и потренируйся

В тренажёре дотронься до пола и плиты, посмотри на числа и отчёт. Потом разложи вопросы: на какие механизм отвечает, а какие остаются спорными. Сверь с разбором.

В программе перепиши отчёт так, чтобы он был «человечнее»: добавь «ой», зависимость от силы сигнала. Стал ли агент от этого ближе к переживанию? Что ты можешь сказать наверняка?

### Вопрос

Что можно сказать об агенте, который пишет «мне больно»?

### Варианты

- Отчёт объяснён его кодом, а о том, есть ли переживание, этот отчёт сам ничего не решает.
- Отчёт доказывает наличие боли, поскольку агент сам сообщает о своём внутреннем состоянии.
- Отчёт доказывает отсутствие боли, поскольку такую фразу может напечатать простая программа.

### Ответ

1

### Разбор

Отчёт печатает одна строка, поэтому он не доказывает переживания. Но и обратное неверно: из того, что простая программа печатает фразу, не следует, что любая система без переживания. Значит, сама фраза не решает вопрос ни в какую сторону.

### Границы модели

Наш агент это учебная игрушка, и никто не считает его сознательным. Я упростил споры, и у каждой стороны есть намного более тонкие доводы, поэтому читай первоисточники. Разделение на лёгкое и трудное принимают не все. Что именно показывает слепое зрение, обсуждают до сих пор, в том числе саму точность отчётов.

## English

### Goal

Understand what explains behaviour and what perhaps does not. Write an agent that "speaks of pain", explain each of its lines, and ask what remains. Tell access from experience and hear the main objections. The lesson does not claim any system is conscious or that its consciousness is impossible. It takes about 35 minutes.

### Idea and mechanism

**Step 1. Two questions.** In 1995 David Chalmers split questions about consciousness into two groups.

*Easy problems:* how the brain discriminates stimuli, integrates information, reports its states, controls attention. These are very hard too, but it is clear how to approach them: find a mechanism doing the work.

*The hard problem:* why anything is **experienced** along with this work at all. Why is there "what it is like" to see red or feel pain? The phrase comes from Thomas Nagel's paper on what it is like to be a bat.

**Step 2. An agent that "feels pain".** Create the file `nano ~/ai-path/pain.py`, paste and run it. It is 20 lines.

```python
SENSOR = {"пол": 0.0, "плита": 1.0}


class Agent:
    def __init__(self):
        self.avoid = {"пол": 0.0, "плита": 0.0}
        self.damage = 0.0

    def touch(self, place):
        signal = SENSOR[place]
        self.damage += signal
        self.avoid[place] += 0.5 * (signal - self.avoid[place])
        return signal

    def choose(self):
        return min(self.avoid, key=self.avoid.get)

    def report(self):
        if self.damage > 0:
            return "мне больно"
        return "всё хорошо"


agent = Agent()
print("first report:", agent.report())
for place in ("пол", "плита", "пол", "плита"):
    agent.touch(place)
    print(place, "avoid", agent.avoid, "report:", agent.report(), "choice next:", agent.choose())
```

```output
first report: всё хорошо
пол avoid {'пол': 0.0, 'плита': 0.0} report: всё хорошо choice next: пол
плита avoid {'пол': 0.0, 'плита': 0.5} report: мне больно choice next: пол
пол avoid {'пол': 0.0, 'плита': 0.5} report: мне больно choice next: пол
плита avoid {'пол': 0.0, 'плита': 0.75} report: мне больно choice next: пол
```

After the stove ("плита") the agent says "мне больно" ("it hurts") and does not go there again. Explain it all by hand:

- The report: the line `if self.damage > 0: return "мне больно"`.
- Avoidance: a mean of the signal, shifting by half. After two touches `0.5 + 0.5 · (1 − 0.5) = 0.75`.
- Choice: `min` over these numbers.

The mechanism here is explained in full, nothing is hidden. Clearly **this does not yet mean** the agent feels anything: any code could print the phrase. And here is Chalmers's question. Suppose some day we describe a person's mechanism just as fully. Will the question remain why it is experienced?

**Step 3. Access and experience.** In 1995 Ned Block separated two senses of the word. **Access consciousness**: information available for reasoning, report and control of action. **Phenomenal consciousness**: experience itself. A disputed example is **blindsight**. After damage to the visual cortex a person says they see nothing in part of the field, yet, asked to guess, points to an object far better than chance. Information acts somehow, without a report of seeing. What exactly this shows is argued over.

Our program is about access: information reached the report. On experience it is silent.

**Step 4. The main objection.** Not everyone thinks the hard problem is real.

*Dennett and illusionists:* once the easy problems are solved, nothing separate will remain to explain. The conviction that a special "what it is like" exists is itself what must be explained. A mechanism produces it too. Hence the name **illusionism**, developed by Frankish since 2016.

*Chalmers's reply:* experience is given to us most directly and cannot be declared an illusion, since for an illusion to exist someone must have it. Chalmers offers the thought experiment of a philosophical zombie: an exact double without experience. If it can be consistently imagined, then function does not exhaust everything. Critics reply that our imagining it proves nothing.

*What is measured here?* Almost nothing: this is a philosophical dispute. Experiments show which processes go with report, but how an experiment could settle the hard problem is unclear. A separate lesson covers experiments.

**Why this matters for AI.** If only function matters, a complex enough program could be conscious. If something more is needed, such as biology, then not. There is no answer. So a model's phrase "it hurts" in itself **answers neither yes nor no**. Our agent showed that: one line of code prints it.

**Learn from the people who build this.** The survey [Stanford Encyclopedia: Consciousness](https://plato.stanford.edu/entries/consciousness/). Short talks: [Chalmers at TED](https://www.ted.com/talks/david_chalmers_how_do_you_explain_consciousness) and [Dennett at TED](https://www.ted.com/talks/dan_dennett_the_illusion_of_consciousness). [Chalmers's 1995 paper](https://consc.net/papers/facing.pdf).

### Explore and practise

In the lab, touch the floor and the stove, and look at the numbers and the report. Then sort the questions: which a mechanism answers and which stay disputed. Compare with the explanation.

In the program, rewrite the report to be "more human": add "ouch" and a dependence on signal strength. Did this bring the agent closer to experience? What can you say for sure?

### Question

What can be said of an agent that writes "it hurts"?

### Options

- Its code explains the report, and this report alone does not settle whether experience exists.
- The report proves that pain exists, since the agent itself tells of its inner state.
- The report proves that pain is absent, since a simple program can print such a phrase.

### Answer

1

### Explanation

One line prints the report, so it does not prove experience. But the reverse is wrong too: from a simple program printing the phrase it does not follow that every system lacks experience. So the phrase itself does not decide the question either way.

### Limits

Our agent is a teaching toy, and nobody considers it conscious. I simplified the disputes, and each side has far subtler arguments, so read the primary sources. Not everyone accepts the division into easy and hard. What exactly blindsight shows is still debated, including the accuracy of the reports themselves.

## Sources

- David J. Chalmers, "Facing Up to the Problem of Consciousness", Journal of Consciousness Studies 2 (1995), recalled: [paper](https://consc.net/papers/facing.pdf)
- Thomas Nagel, "What Is It Like to Be a Bat?", The Philosophical Review 83 (1974), recalled.
- Ned Block, "On a confusion about a function of consciousness", Behavioral and Brain Sciences 18 (1995), recalled.
- Daniel C. Dennett, "Consciousness Explained" (1991), recalled; TED talk: [The illusion of consciousness](https://www.ted.com/talks/dan_dennett_the_illusion_of_consciousness)
- Keith Frankish, "Illusionism as a Theory of Consciousness", Journal of Consciousness Studies 23 (2016), recalled.
- Lawrence Weiskrantz, work on blindsight, recalled through the survey: [Stanford Encyclopedia: Consciousness](https://plato.stanford.edu/entries/consciousness/)
- David Chalmers, TED talk: [How do you explain consciousness?](https://www.ted.com/talks/david_chalmers_how_do_you_explain_consciousness)
- The program was written for this lesson. The lesson paraphrases these sources and does not copy their text.

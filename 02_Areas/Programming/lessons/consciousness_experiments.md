---
subject: programming
lesson_id: programming.consciousness_experiments
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Опыты о сознании / Experiments on consciousness

## Русский

### Цель

Самому пройти опыт с маскировкой, отделить чувствительность от готовности сказать «вижу», посчитать свой порог и понять, что показал большой опыт Cogitate. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Главный приём.** Как изучать сознание опытом? Берут **контраст**: один и тот же стимул, который иногда замечают, а иногда нет. Что различается в мозге, то и связано с сознанием, по крайней мере с отчётом. Простейший приём это **маскировка**: цифра показывается доли секунды, сразу за ней идёт узор. Глаз цифру получил, но замечается она не всегда.

**Шаг 2. Сделай сам.** Открой тренажёр и пройди 30 проб. После каждой выбирай цифру и отмечай, видел ли ты её или угадал. Это ещё не наука: один человек, а время на экране неточное. Но ты почувствуешь порог.

**Шаг 3. Видел или готов сказать?** Отчёт зависит не только от восприятия, но и от осторожности. Теория обнаружения сигнала разделяет это на две величины. Пусть было 100 проб с цифрой и 100 без неё. **Попадания** это доля «вижу» при цифре, а **ложные тревоги** доля «вижу» без неё. Руками: попаданий `0,8`, тревог `0,3`. Перевод в единицы нормального распределения: `z(0,8) = 0,84`, `z(0,3) = −0,52`. **Чувствительность** `d′ = 0,84 − (−0,52) = 1,36`. **Порог решения** `c = −(0,84 + (−0,52)) / 2 = −0,16`. Отрицательный значит, что человек легко говорит «вижу». Создай файл `nano ~/ai-path/detect.py`, вставь и запусти. Здесь к долям сделана маленькая поправка, чтобы не получить бесконечность.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


def inverse_normal(p):
    low, high = -6.0, 6.0
    for _ in range(60):
        middle = (low + high) / 2
        if 0.5 * (1 + math.erf(middle / math.sqrt(2))) < p:
            low = middle
        else:
            high = middle
    return (low + high) / 2


def sensitivity(hits, signals, alarms, blanks):
    hit_rate = (hits + 0.5) / (signals + 1)
    alarm_rate = (alarms + 0.5) / (blanks + 1)
    return round(inverse_normal(hit_rate) - inverse_normal(alarm_rate), 2), round(-0.5 * (inverse_normal(hit_rate) + inverse_normal(alarm_rate)), 2)


print("cautious observer", sensitivity(30, 100, 2, 100))
print("eager observer", sensitivity(80, 100, 30, 100))
print("guessing", sensitivity(50, 100, 50, 100))
```

```output
cautious observer (1.45, 1.24)
eager observer (1.35, -0.16)
guessing (0.0, 0.0)
```

Смотри. Осторожный наблюдатель сказал «вижу» 30 раз, а смелый 80 раз. Но чувствительность у них почти одинаковая: `1,45` и `1,35`. Разница только в пороге. **Поэтому число «видел» одно ничего не решает.** Опыт, который меряет только отчёт, легко принять за опыт о сознании, хотя он меряет осторожность.

**Шаг 4. Порог.** Смоделируем наблюдателя с настоящим порогом 55 мс и 40 пробами на каждую длительность, а затем найдём порог подгонкой, перебирая значения. Угадывание среди 4 цифр даёт `0,25`. Допиши и запусти.

```python
DURATIONS = [17, 33, 50, 67, 100, 150]


def seen(ms, threshold, slope, rand):
    return rand.next() < 0.25 + 0.75 / (1 + math.exp(-(ms - threshold) / slope))


rand = Rand(8)
rows = []
for ms in DURATIONS:
    right = sum(seen(ms, 55, 12, rand) for _ in range(40))
    rows.append((ms, right / 40))
    print(ms, right, "of 40")


def fit(rows):
    best = None
    for threshold in range(20, 121):
        for slope in (4, 6, 8, 10, 12, 16, 20, 25):
            error = 0.0
            for ms, share in rows:
                model = 0.25 + 0.75 / (1 + math.exp(-(ms - threshold) / slope))
                error += (model - share) ** 2
            if best is None or error < best[0]:
                best = (error, threshold, slope)
    return best


print("fitted threshold and slope", fit(rows)[1:])
```

```output
17 8 of 40
33 18 of 40
50 24 of 40
67 33 of 40
100 40 of 40
150 40 of 40
fitted threshold and slope (51, 12)
```

Подгонка нашла `51` вместо настоящих `55`. Сорок проб дают такую ошибку, а настоящий порог у людей зависит от узора и подготовки. Сверь со своим порогом в тренажёре, но помни о неточности времени на экране.

**Шаг 5. Без отчёта.** Если сравнивать только отчёты, мы можем мерить сам отчёт, а не переживание. Поэтому есть опыты **без отчёта**: человек ничего не говорит, а о содержании судят по движениям глаз или по активности мозга. При этом часть лобной активности уменьшается. Что отсюда следует, спорят.

**Шаг 6. Cogitate.** Обычно у каждой теории свои опыты, и сторонники видят подтверждение. В **состязательном сотрудничестве** сторонники двух теорий заранее записали, какие исходы их опровергают, а опыт провели независимые лаборатории. Опубликовано в Nature в 2025 году: 256 участников и три метода записи.

*Для интегрированной информации:* устойчивая синхронизация в задней коре, которую теория предсказывала, найдена не была.

*Для рабочего пространства:* не нашли ожидаемой вспышки в момент исчезновения стимула, а лобная кора содержала часть содержания, но не всё.

*Что осталось:* сведения о содержании нашлись в зрительной и височной областях, а также в нижней лобной коре. Ни одна теория не прошла целиком, и ни одна не опровергнута окончательно. Сторонники спорят об истолковании. Вот честное состояние дела: опыт сузил споры, но не закрыл их. И он о людях: **переносить результаты на ИИ напрямую нельзя.**

**Учись у тех, кто это создаёт.** Сама статья [Cogitate](https://www.nature.com/articles/s41586-025-08888-1). Обзор [Stanford Encyclopedia: Consciousness](https://plato.stanford.edu/entries/consciousness/). Книга Дехане «Сознание и мозг» описывает маскировку доступно.

### Исследуй и потренируйся

В тренажёре настоящий опыт на тебе. Отметь отдельно, где ты видел цифру, а где угадывал. Посмотри на точность только в угаданных пробах: выше ли она случайных `0,25`?

В программе измени `sensitivity` под свои числа: сколько раз ты сказал «вижу» при настоящей цифре? Нужны ещё пробы без цифры, поэтому придумай, как их добавить.

### Вопрос

Два человека сказали «вижу» 30 и 80 раз, но `d′` у них почти равны. Что это значит?

### Варианты

- Их чувствительность почти одинакова, а различается готовность сказать «вижу».
- Второй видит намного лучше, потому что он чаще верно называет настоящие стимулы.
- Первый видит намного лучше, потому что он почти не даёт ложных тревог вообще.

### Ответ

1

### Разбор

Второй чаще попадает, но и ложных тревог у него намного больше. Первый редко тревожится, но и редко попадает. `d′` учитывает оба числа, и они почти равны. Значит, сами глаза тут ни при чём: различается только порог решения.

### Границы модели

В тренажёре время на экране не точнее одного кадра, поэтому это опыт для понимания, а не для измерения. Наблюдатель в программе смоделирован. Я кратко пересказал Cogitate по памяти и по названию статьи, поэтому сверяй подробности с ней. Сторонники обеих теорий истолковывают итоги иначе, чем я мог бы передать в двух абзацах.

## English

### Goal

Go through a masking experiment yourself, separate sensitivity from willingness to say "I see", compute your threshold, and understand what the large Cogitate experiment showed. It takes about 40 minutes.

### Idea and mechanism

**Step 1. The main technique.** How can consciousness be studied by experiment? You take a **contrast**: the same stimulus, sometimes noticed and sometimes not. Whatever differs in the brain is linked to consciousness, or at least to report. The simplest technique is **masking**: a digit appears for a fraction of a second, immediately followed by a pattern. The eye received the digit, but it is not always noticed.

**Step 2. Do it yourself.** Open the lab and go through 30 trials. After each, choose a digit and mark whether you saw it or guessed. This is not yet science: one person, with inexact screen timing. But you will feel the threshold.

**Step 3. Saw it or willing to say so?** A report depends not only on perception but on caution. Signal detection theory splits this into two quantities. Suppose there were 100 trials with a digit and 100 without. **Hits** are the share of "I see" with a digit, and **false alarms** the share of "I see" without one. By hand: hits `0.8`, alarms `0.3`. Converting to normal distribution units: `z(0.8) = 0.84`, `z(0.3) = −0.52`. **Sensitivity** `d′ = 0.84 − (−0.52) = 1.36`. **The decision threshold** `c = −(0.84 + (−0.52)) / 2 = −0.16`. Negative means the person says "I see" readily. Create the file `nano ~/ai-path/detect.py`, paste and run it. A small correction to the shares here avoids infinity.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


def inverse_normal(p):
    low, high = -6.0, 6.0
    for _ in range(60):
        middle = (low + high) / 2
        if 0.5 * (1 + math.erf(middle / math.sqrt(2))) < p:
            low = middle
        else:
            high = middle
    return (low + high) / 2


def sensitivity(hits, signals, alarms, blanks):
    hit_rate = (hits + 0.5) / (signals + 1)
    alarm_rate = (alarms + 0.5) / (blanks + 1)
    return round(inverse_normal(hit_rate) - inverse_normal(alarm_rate), 2), round(-0.5 * (inverse_normal(hit_rate) + inverse_normal(alarm_rate)), 2)


print("cautious observer", sensitivity(30, 100, 2, 100))
print("eager observer", sensitivity(80, 100, 30, 100))
print("guessing", sensitivity(50, 100, 50, 100))
```

```output
cautious observer (1.45, 1.24)
eager observer (1.35, -0.16)
guessing (0.0, 0.0)
```

Look. The cautious observer said "I see" 30 times, the eager one 80 times. But their sensitivity is almost the same: `1.45` and `1.35`. Only the threshold differs. **So the count of "saw it" alone settles nothing.** An experiment measuring only report is easily mistaken for one about consciousness, though it measures caution.

**Step 4. The threshold.** We simulate an observer with a true threshold of 55 ms and 40 trials per duration, then find the threshold by fitting, trying values. Guessing among 4 digits gives `0.25`. Add this and run it.

```python
DURATIONS = [17, 33, 50, 67, 100, 150]


def seen(ms, threshold, slope, rand):
    return rand.next() < 0.25 + 0.75 / (1 + math.exp(-(ms - threshold) / slope))


rand = Rand(8)
rows = []
for ms in DURATIONS:
    right = sum(seen(ms, 55, 12, rand) for _ in range(40))
    rows.append((ms, right / 40))
    print(ms, right, "of 40")


def fit(rows):
    best = None
    for threshold in range(20, 121):
        for slope in (4, 6, 8, 10, 12, 16, 20, 25):
            error = 0.0
            for ms, share in rows:
                model = 0.25 + 0.75 / (1 + math.exp(-(ms - threshold) / slope))
                error += (model - share) ** 2
            if best is None or error < best[0]:
                best = (error, threshold, slope)
    return best


print("fitted threshold and slope", fit(rows)[1:])
```

```output
17 8 of 40
33 18 of 40
50 24 of 40
67 33 of 40
100 40 of 40
150 40 of 40
fitted threshold and slope (51, 12)
```

The fit found `51` rather than the true `55`. Forty trials leave that much error, and a real person's threshold depends on the pattern and practice. Compare with your threshold in the lab, but remember the inexact screen timing.

**Step 5. Without report.** If only reports are compared, we may be measuring the report itself rather than experience. So there are **no-report** experiments: a person says nothing, and content is judged from eye movements or brain activity. Some frontal activity then decreases. What follows from this is argued over.

**Step 6. Cogitate.** Usually each theory has its own experiments, and supporters see confirmation. In **adversarial collaboration** supporters of two theories wrote down in advance which outcomes refute them, and independent labs ran the experiment. Published in Nature in 2025: 256 participants and three recording methods.

*For integrated information:* sustained synchrony in the posterior cortex, which the theory predicted, was not found.

*For the workspace:* the expected ignition at the stimulus's disappearance was not found, and the frontal cortex held part of the content but not all.

*What remains:* information about content appeared in visual and temporal areas, and in the inferior frontal cortex. Neither theory passed entirely, and neither is finally refuted. Supporters argue over the reading. That is the honest state of things: the experiment narrowed the disputes but did not close them. And it concerns people: **results cannot be carried directly to AI.**

**Learn from the people who build this.** The [Cogitate paper](https://www.nature.com/articles/s41586-025-08888-1) itself. The survey [Stanford Encyclopedia: Consciousness](https://plato.stanford.edu/entries/consciousness/). Dehaene's book "Consciousness and the Brain" describes masking accessibly.

### Explore and practise

The lab has a real experiment on you. Mark separately where you saw the digit and where you guessed. Look at the accuracy in guessed trials only: is it above the chance `0.25`?

In the program, change `sensitivity` to your own numbers: how many times did you say "I see" with a real digit? Trials without a digit are also needed, so work out how to add them.

### Question

Two people said "I see" 30 and 80 times, but their `d′` are almost equal. What does this mean?

### Options

- Their sensitivity is almost the same, and only their readiness to say "I see" differs.
- The second sees far better, because that person names the real stimuli more often.
- The first sees far better, because that person gives almost no false alarms at all.

### Answer

1

### Explanation

The second hits more often, but also has far more false alarms. The first rarely gives false alarms and rarely hits. `d′` counts both numbers, and they are almost equal. So the eyes have nothing to do with it: only the decision threshold differs.

### Limits

In the lab, screen timing is no more accurate than one frame, so this is an experiment for understanding, not measurement. The observer in the program is simulated. I retold Cogitate briefly from memory and the paper's title, so check details against it. Supporters of both theories read the results differently than I could convey in two paragraphs.

## Sources

- Cogitate Consortium, "Adversarial testing of global neuronal workspace and integrated information theories of consciousness", Nature 642 (2025), abstract read 2026-11-03: [article](https://www.nature.com/articles/s41586-025-08888-1)
- Stanislas Dehaene, Jean-Pierre Changeux, Lionel Naccache et al., "Conscious, preconscious, and subliminal processing: a testable taxonomy", Trends in Cognitive Sciences 10 (2006), title and journal checked 2026-11-03; the paper itself not re-read; "Consciousness and the Brain" (2014), recalled.
- Naotsugu Tsuchiya et al., "No-Report Paradigms: Extracting the True Neural Correlates of Consciousness", Trends in Cognitive Sciences 19 (2015), title and journal checked 2026-11-03; the paper itself not re-read.
- Neil A. Macmillan, C. Douglas Creelman, "Detection Theory: A User's Guide" (third edition with Hautus, 2021, found 2026-11-03), for d′ and c, recalled; the numbers are computed in the lesson.
- Stanford Encyclopedia of Philosophy, "Consciousness": [entry](https://plato.stanford.edu/entries/consciousness/)
- The programs and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.

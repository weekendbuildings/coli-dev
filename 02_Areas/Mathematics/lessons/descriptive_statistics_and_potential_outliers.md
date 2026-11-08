---
lesson_id: mathematics.descriptive_statistics_and_potential_outliers
subject: mathematics
language: ru-en
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 365
---

# Описание данных: центр, разброс и потенциальные выбросы / Describing data: center, spread, and potential outliers

## Русский

### Простыми словами

Чтобы описать много чисел коротко, называют их центр и разброс. Среднее это сумма, делённая на количество, а медиана это число посередине, если всё выстроить по порядку. Если в зарплатах отдела появится один миллионер, среднее взлетит, а медиана почти не сдвинется. Выброс это значение, которое стоит проверить: ошибка ли это записи или редкий настоящий случай.

**Что нужно знать до.** Сложение, деление и порядок чисел. Отдельных уроков пути не нужно.

**Если непонятно.** Если неясны квартили, выстрой числа по порядку и раздели ряд пополам, а потом каждую половину ещё пополам. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Научиться сравнивать среднее и медиану, находить межквартильный размах и решать, требует ли крайнее значение дополнительной проверки.

### Идея и механизм

Если в комнату, где сидят девять человек со средней зарплатой, войдёт миллиардер, средняя зарплата в комнате взлетит, хотя ни у кого из девяти она не изменилась. Медиана — «зарплата человека посередине» — почти не сдвинется. Поэтому, описывая данные, смотрят сразу на несколько чисел: где центр, насколько данные разбросаны и нет ли значений, которые стоит перепроверить.

Сначала упорядочи данные. **Среднее арифметическое** — сумма всех значений, делённая на их количество. **Медиана** — середина упорядоченного набора; при чётном количестве это среднее двух центральных значений. Среднее использует величину каждого наблюдения и поэтому может сильно сдвигаться из-за одного далёкого значения. Медиана обычно устойчивее к такому сдвигу.

Квартили делят упорядоченные данные на четверти. В этом уроке используется правило «медианы половин»: `Q1` — медиана нижней половины, `Q3` — медиана верхней половины. Межквартильный размах `IQR = Q3 − Q1` описывает разброс центральной половины данных. По правилу `1,5 × IQR` значение ниже `Q1 − 1,5 × IQR` или выше `Q3 + 1,5 × IQR` помечается как **потенциальный выброс** для дальнейшего исследования.

**Пример.** Пусть шесть датчиков записали `[4, 5, 5, 6, 6, 20]` условных единиц. Среднее равно `46 / 6 ≈ 7,67`, медиана — `(5 + 6) / 2 = 5,5`. Нижняя половина `[4, 5, 5]` даёт `Q1 = 5`, верхняя `[6, 6, 20]` — `Q3 = 6`, значит `IQR = 1`. Нижняя граница равна `5 − 1,5 · 1 = 3,5`, верхняя — `6 + 1,5 · 1 = 7,5`; значение `20` выше верхней. Это сигнал проверить датчик, процедуру измерения и контекст — само правило не доказывает, что данные ошибочны, и не разрешает автоматически удалить наблюдение.

**Типичная ошибка.** Считать квартили, забыв упорядочить данные, или удалять помеченное значение «потому что так велит правило». Выброс может оказаться ошибкой записи, а может — самым важным наблюдением в наборе.

**Зачем это дальше.** В Python функция `statistics.quantiles` по умолчанию использует другое соглашение и для этих же данных даёт `Q1 = 4,75` и `Q3 = 9,5`: квартили зависят от метода, поэтому указывай, каким способом их считал. В машинном обучении выбросы сильно влияют на модели, обученные с квадратичной ошибкой, а медиана и `IQR` помогают быстро проверить данные перед обучением.

### Исследуй и потренируйся

В тренажёре передвинь крайнее значение от `6` до `24`. Наблюдай, как меняются среднее, медиана и границы `1,5 × IQR`. Затем предскажи: стало ли максимальное значение выше верхней границы? Вернись к примеру и объясни, почему медиана меняется меньше среднего.

### Вопрос

Для `[4, 5, 5, 6, 6, 20]` максимальное значение `20` выше верхней границы потенциального выброса?

### Варианты

- Нет
- Да

### Ответ

2

### Разбор

Медиана верхней половины `[6, 6, 20]` равна `Q3 = 6`, нижней `[4, 5, 5]` — `Q1 = 5`. Поэтому `IQR = 1`, а верхняя граница равна `6 + 1,5 · 1 = 7,5`; `20 > 7,5`. Слово «потенциальный» важно: сначала изучи происхождение значения и метод измерения.

### Границы модели

Метка по `1,5 × IQR` — удобное правило поиска необычных значений, а не универсальный тест ошибки, редкости или опасности. Квартильные соглашения в учебниках и программах различаются; в тренажёре для наборов нечётного размера медиана общей середины исключается из обеих половин. Не удаляй наблюдение только из-за этой метки: проверяй источник, единицы, сбор данных и предметный контекст. Маленький набор также не позволяет уверенно описать всю популяцию.

## English

### In plain words

To describe many numbers briefly, you give their centre and spread. The mean is the sum divided by the count, and the median is the number in the middle when everything is lined up in order. If one millionaire joins a department's salaries, the mean shoots up while the median barely moves. An outlier is a value worth checking: is it a recording error or a rare real case.

**What to know first.** Addition, division and ordering numbers. No other path lessons are needed.

**If something is unclear.** If quartiles are unclear, line the numbers up in order and split the row in half, then split each half again. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Compare the mean and median, calculate the interquartile range, and decide whether an extreme value needs further investigation.

### Idea and mechanism

If a billionaire walks into a room where nine people with average salaries are sitting, the mean salary in the room shoots up, even though nobody else's salary changed. The median, the salary of the person in the middle, barely moves. That is why data are described with several numbers at once: where the centre is, how spread out the values are, and whether any values deserve a second look.

Start by ordering the data. The **arithmetic mean** is the sum of all values divided by their count. The **median** is the middle of the ordered values; with an even count, it is the mean of the two central values. The mean uses each observation's magnitude, so one distant value can move it substantially. The median is usually more resistant to that shift.

Quartiles split ordered data into quarters. This lesson uses the **median-of-halves rule**: `Q1` is the median of the lower half and `Q3` is the median of the upper half. The interquartile range, `IQR = Q3 − Q1`, describes the spread of the middle half. Under the `1.5 × IQR` rule, a value below `Q1 − 1.5 × IQR` or above `Q3 + 1.5 × IQR` is flagged as a **potential outlier** for investigation.

**Example.** Suppose six sensors record `[4, 5, 5, 6, 6, 20]` arbitrary units. The mean is `46 / 6 ≈ 7.67`; the median is `(5 + 6) / 2 = 5.5`. The lower half `[4, 5, 5]` gives `Q1 = 5` and the upper half `[6, 6, 20]` gives `Q3 = 6`, so `IQR = 1`. The lower fence is `5 − 1.5 · 1 = 3.5` and the upper fence is `6 + 1.5 · 1 = 7.5`; `20` is above the upper fence. This is a reason to inspect the sensor, measurement procedure, and context. The rule does not prove the data are wrong and does not authorize automatic deletion.

**Common mistake.** Computing quartiles without ordering the data first, or deleting a flagged value “because the rule says so”. An outlier may be a recording error, or it may be the most important observation in the set.

**Why it matters next.** In Python, `statistics.quantiles` uses a different convention by default and gives `Q1 = 4.75` and `Q3 = 9.5` for these same data: quartiles depend on the method, so state which one you used. In machine learning, outliers strongly affect models trained with squared error, and the median and `IQR` give a quick data check before training.

### Explore and practise

Move the extreme value from `6` to `24` in the lab. Observe how the mean, median, and `1.5 × IQR` fences respond. Then predict whether the maximum is above the upper fence. Return to the example and explain why the median moves less than the mean.

### Question

For `[4, 5, 5, 6, 6, 20]`, is the maximum value `20` above the potential-outlier upper fence?

### Options

- No
- Yes

### Answer

2

### Explanation

The median of the upper half `[6, 6, 20]` is `Q3 = 6`, and the median of the lower half `[4, 5, 5]` is `Q1 = 5`. Therefore `IQR = 1` and the upper fence is `6 + 1.5 · 1 = 7.5`; `20 > 7.5`. “Potential” matters: first investigate how the value was produced and measured.

### Limits

The `1.5 × IQR` flag is a useful screening rule, not a universal test of error, rarity, or danger. Quartile conventions differ between textbooks and software; for odd-sized data sets, this lab excludes the overall median from both halves. Do not delete an observation solely because it is flagged: check the source, units, collection method, and subject context. A small data set also cannot describe an entire population with confidence.

## Sources

- OpenStax, *Introductory Statistics 2e*, §2.3 “Measures of the Location of the Data” (quartiles, IQR, potential-outlier fences): https://openstax.org/books/introductory-statistics-2e/pages/2-3-measures-of-the-location-of-the-data. Source checked 2026-10-26. OpenStax states this text is CC BY-NC-SA 4.0; this lesson uses original wording and an original exercise, not copied text or figures.
- OpenStax, *Introductory Statistics 2e*, §2.5 “Measures of the Center of the Data” (mean and median; the median is less affected by extreme values): https://openstax.org/books/introductory-statistics-2e/pages/2-5-measures-of-the-center-of-the-data. Source checked 2026-10-26.
- Python documentation, [`statistics.quantiles`](https://docs.python.org/3/library/statistics.html#statistics.quantiles) — the default method is “exclusive”; “inclusive” is an alternative.
- Google for Developers, *Machine Learning Crash Course*, [Linear regression: Loss](https://developers.google.com/machine-learning/crash-course/linear-regression/loss) — squared (L2) loss amplifies the influence of outliers compared with absolute (L1) loss.

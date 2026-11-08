---
subject: programming
lesson_id: programming.ml_baseline_and_holdout
level: intermediate
languages: ru, en
source_checked: 2026-10-24
source_review_interval_days: 365
---

# Машинное обучение: baseline и отложенная проверка / Machine Learning: Baselines and Held-out Evaluation

## Русский

### Простыми словами

Чтобы честно проверить модель, часть данных прячут и не показывают ей при обучении. Это отложенная проверка. Как экзамен на новых задачах, а не на тех, что разбирали в классе: иначе проверишь память, а не понимание. Baseline это самое простое решение, например всегда отвечать самым частым ответом. Если модель не лучше baseline, она ничему не научилась. Модель, которая отлично отвечает на обучении и плохо на отложенных, переобучилась: заучила примеры.

**Что нужно знать до.** Уроки шага 2 о Python. Доли и проценты из урока «Вероятность и формула Байеса» (шаг 5).

**Если непонятно.** Если неясно, что делает `k`, считай так: модель ищет `k` самых похожих примеров и отвечает, как большинство из них. Если неясна программа, вернись к уроку «Коллекции и циклы» (шаг 2). Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Оценить простую модель на данных, которых она не видела, сравнить её с baseline и распознать переобучение.

### Идея и механизм

Модель машинного обучения подбирает правило по примерам с известным ответом — обучающим данным. Если проверять её на тех же примерах, она может получить идеальный результат, просто запомнив ответы, и всё равно ошибаться на новых случаях. Документация scikit-learn называет такую проверку методологической ошибкой, а саму ситуацию — переобучением (overfitting). Поэтому часть данных заранее откладывают и не показывают модели во время обучения.

Метод k ближайших соседей (k-NN) не строит формулу. Для нового входа он находит k самых близких обучающих примеров и выбирает класс, за который голосует большинство из них. Маленькое k повторяет каждый пример, включая случайный шум. Большое k сглаживает шум, но размывает границу между классами. Если k равно числу всех обучающих примеров, голосуют все, и модель всегда называет самый частый класс.

Baseline — простое правило без настоящего обучения, с которым сравнивают модель. Например, `DummyClassifier(strategy="most_frequent")` в scikit-learn всегда предсказывает самый частый класс обучающих данных и вообще не смотрит на вход. Если модель не лучше baseline, она не научилась ничему полезному.

Тот же опыт можно повторить на чистом Python без библиотек:

```python
train = [(10, 0), (15, 0), (20, 0), (25, 1), (30, 0), (35, 0), (40, 1),
         (45, 1), (50, 0), (55, 1), (60, 1), (65, 1), (70, 1)]
held_out = [(12, 0), (17, 0), (22, 0), (27, 0), (33, 0), (38, 0),
            (42, 0), (47, 1), (52, 1), (58, 1), (63, 1), (68, 1)]


def predict(minutes, k):
    nearest = sorted(range(len(train)), key=lambda i: (abs(train[i][0] - minutes), i))[:k]
    passed = sum(train[i][1] for i in nearest)
    return 1 if passed * 2 > k else 0


def accuracy(examples, k):
    return sum(predict(x, k) == y for x, y in examples)


for k in (1, 5, 13):
    print(k, accuracy(train, k), "/", len(train), accuracy(held_out, k), "/", len(held_out))
```

Каждая пара — минуты практики за неделю и пройдена ли проверка (`1` — да, `0` — нет). Данные придуманы для упражнения, и в них специально есть шум: например, 25 минут с `1` и 50 минут с `0` выбиваются из общей тенденции.

### Исследуй и потренируйся

В тренажёре 13 обучающих и 12 отложенных примеров из кода выше. Поставь k = 1 и сравни точность на обучающих и отложенных данных. Затем найди k, при котором модель лучше всего работает на отложенных данных, и посмотри, что происходит при k = 13. Сравни каждый результат с полосой baseline.

### Вопрос

При k = 1 модель верно отвечает на все 13 обучающих примеров, но только на 8 из 12 отложенных. Что это показывает?

### Варианты

- Модель запомнила обучающие примеры вместе с шумом; качество нужно оценивать на данных, которых она не видела.
- Модель идеальна: 100 % на обучающих данных доказывают, что на новых она будет работать так же.
- Нужно всегда брать самое большое k, потому что больше соседей — всегда лучше.

### Ответ

1

### Разбор

При k = 1 ближайший обучающий пример — это сам пример, поэтому на обучающих данных ошибок нет даже там, где метка случайно выбивается из тенденции. На отложенных данных такие шумные примеры уводят предсказание в сторону: верно 8 из 12. При k = 5 модель верно отвечает на 11 из 12 отложенных примеров. Самое большое k тоже не решение: при k = 13 голосуют все обучающие примеры, модель всегда называет частый класс и опускается до уровня baseline — 5 из 12.

### Границы модели

Данные придуманы, и их мало: один отложенный пример меняет точность примерно на 8 процентных пунктов. Если выбирать k по отложенным данным, они перестают быть независимой проверкой; в настоящем эксперименте k подбирают на валидационной выборке или кросс-валидацией, а итог измеряют на отдельной тестовой выборке. Точность — не единственная метрика: при несбалансированных классах нужны и другие. Модель на одном признаке не объясняет причин: эти данные выдуманы и ничего не доказывают о связи практики и результата.

## English

### In plain words

To check a model honestly, part of the data is hidden and not shown to it during training. That is held-out evaluation. It is like an exam on new problems rather than the ones done in class: otherwise you test memory, not understanding. A baseline is the simplest solution, for example always giving the most common answer. If a model is no better than the baseline, it has learned nothing. A model that does very well in training and badly on held-out data has overfitted: it memorised the examples.

**What to know first.** The Python lessons of step 2. Shares and percentages from «Probability and Bayes' Rule» (step 5).

**If something is unclear.** If `k` is unclear, think of it this way: the model finds the `k` most similar examples and answers as most of them do. If the program is unclear, go back to «Collections and Loops» (step 2). Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Evaluate a simple model on data it has not seen, compare it with a baseline, and recognize overfitting.

### Idea and mechanism

A machine learning model fits a rule to examples with known answers — the training data. If you test it on those same examples, it can score perfectly just by remembering the answers and still fail on new cases. The scikit-learn documentation calls such testing a methodological mistake and calls the situation overfitting. That is why part of the data is set aside in advance and not shown to the model during training.

The k-nearest-neighbours method (k-NN) does not build a formula. For a new input, it finds the k closest training examples and chooses the class that most of them vote for. A small k follows every example, including random noise. A large k smooths out noise but blurs the boundary between classes. If k equals the number of training examples, all of them vote, and the model always predicts the most frequent class.

A baseline is a simple rule without real learning that you compare the model against. For example, scikit-learn's `DummyClassifier(strategy="most_frequent")` always predicts the most frequent class in the training data and ignores the input entirely. If a model is no better than the baseline, it has not learned anything useful.

You can repeat the same experiment in plain Python without libraries:

```python
train = [(10, 0), (15, 0), (20, 0), (25, 1), (30, 0), (35, 0), (40, 1),
         (45, 1), (50, 0), (55, 1), (60, 1), (65, 1), (70, 1)]
held_out = [(12, 0), (17, 0), (22, 0), (27, 0), (33, 0), (38, 0),
            (42, 0), (47, 1), (52, 1), (58, 1), (63, 1), (68, 1)]


def predict(minutes, k):
    nearest = sorted(range(len(train)), key=lambda i: (abs(train[i][0] - minutes), i))[:k]
    passed = sum(train[i][1] for i in nearest)
    return 1 if passed * 2 > k else 0


def accuracy(examples, k):
    return sum(predict(x, k) == y for x, y in examples)


for k in (1, 5, 13):
    print(k, accuracy(train, k), "/", len(train), accuracy(held_out, k), "/", len(held_out))
```

Each pair is weekly practice minutes and whether a check was passed (`1` yes, `0` no). The data are invented for this exercise and deliberately contain noise: for example, 25 minutes with `1` and 50 minutes with `0` go against the overall trend.

### Explore and practise

The lab uses the 13 training and 12 held-out examples from the code above. Set k = 1 and compare accuracy on the training and held-out data. Then find the k that works best on the held-out data, and see what happens at k = 13. Compare each result with the baseline bar.

### Question

At k = 1 the model answers all 13 training examples correctly but only 8 of 12 held-out examples. What does this show?

### Options

- It memorised the training data with its noise; measure on unseen data.
- The model is perfect: 100% on the training data proves it will work the same way on new data.
- Always choose the largest k, because more neighbours are always better.

### Answer

1

### Explanation

At k = 1 the closest training example is the example itself, so there are no training errors even where a label happens to go against the trend. On held-out data those noisy examples pull predictions off course: 8 of 12 are correct. At k = 5 the model gets 11 of 12 held-out examples right. The largest k is not the answer either: at k = 13 every training example votes, the model always predicts the frequent class, and it drops to the baseline level of 5 of 12.

### Limits

The data are invented and few: one held-out example changes accuracy by about 8 percentage points. If you choose k using the held-out data, they stop being an independent check; real experiments tune k on a validation set or with cross-validation and measure the final result on a separate test set. Accuracy is not the only metric: imbalanced classes need others too. A one-feature model does not explain causes: these data are made up and prove nothing about how practice relates to results.

## Sources

- scikit-learn developers, *scikit-learn 1.9.1 documentation*, “3.1. Cross-validation: evaluating estimator performance” (consulted 2026-10-24): testing on the same data used for training is a methodological mistake called overfitting; part of the data is held out as a test set: <https://scikit-learn.org/stable/modules/cross_validation.html>
- scikit-learn developers, *scikit-learn 1.9.1 documentation*, “Dummy estimators” (consulted 2026-10-24): comparing an estimator against simple rules of thumb is a sanity check; `most_frequent` always predicts the most frequent training label: <https://scikit-learn.org/stable/modules/model_evaluation.html#dummy-estimators>
- scikit-learn developers, *scikit-learn 1.9.1 documentation*, “Nearest Neighbors Classification” (consulted 2026-10-24): classification by majority vote of the nearest neighbours; a larger k suppresses noise but makes boundaries less distinct: <https://scikit-learn.org/stable/modules/neighbors.html#nearest-neighbors-classification>
- The scikit-learn documentation is © 2007–2026 scikit-learn developers under the BSD License. The lesson paraphrases it; the practice data are invented for this lesson.

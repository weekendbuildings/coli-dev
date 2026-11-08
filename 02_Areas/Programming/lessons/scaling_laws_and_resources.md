---
subject: programming
lesson_id: programming.scaling_laws_and_resources
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Законы масштабирования и цена обучения / Scaling laws and the cost of training

## Русский

### Простыми словами

Чем больше модель и чем больше текста она прочитала, тем меньше её ошибка, и это падение удивительно ровное. Его описывают формулой, *законом масштабирования*. Из формулы следует практический вопрос: если денег на вычисления столько-то, как их поделить между размером модели и количеством текста? Похоже на подготовку к экзамену с ограниченным временем: можно взять толстый учебник и пролистать его один раз, а можно тонкий и прочитать внимательно. В уроке ты посчитаешь лучший раздел по настоящей формуле и цену большого обучения на своём Mac.

**Что нужно знать до.** Урок «Своя языковая модель» (шаг 12): что такое веса и обучение. Урок «Информация, энтропия и кросс-энтропия» (шаг 6): ошибка в натах. Степени и запись `1e21` встречались в уроке «Спор о масштабировании» (шаг 22), но он идёт позже; здесь всё объяснено заново.

**Если непонятно.** Запись `1e21` значит единица с 21 нулём, а `N^0,34` это `N` в степени 0,34: при росте `N` в 10 раз эта степень растёт примерно в 2,2 раза. Если неясна ошибка в натах, вернись к уроку «Информация, энтропия и кросс-энтропия». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Взять настоящую формулу из статьи о Chinchilla, сравнить две большие модели, найти лучший размер модели для данного бюджета вычислений и посчитать, сколько лет обучалась бы на этом Mac модель в 7 миллиардов весов. Увидеть, где формула неточна. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Формула.** В 2022 году Hoffmann и соавторы из DeepMind обучили больше 400 моделей разного размера и подогнали к ним формулу ошибки:

`L(N, D) = 1,69 + 406,4 / N^0,34 + 410,7 / D^0,28`

Здесь `N` это число весов, `D` число токенов текста, а `L` ошибка в натах на токен. Читать её словами так. 1,69 это ошибка, которая не уходит никогда: в самом тексте есть случайность. Вторая часть уменьшается, когда растёт модель. Третья уменьшается, когда растёт текст. Работа обучения считается так: на каждый токен уходит примерно `6N` операций, это оценка из статьи Kaplan и соавторов 2020 года. Значит, всё обучение стоит `C ≈ 6 · N · D` операций.

Руками для маленькой модели: `N = 1 000 000`, `D = 20 000 000`. `N^0,34 = 10^(6 · 0,34) = 10^2,04 ≈ 110`, поэтому `406,4 / 110 ≈ 3,7`. `D^0,28 = 10^(7,3 · 0,28) ≈ 110`, и `410,7 / 110 ≈ 3,7`. Итого `1,69 + 3,7 + 3,7 ≈ 9,1`: модель ещё очень плохая. Создай файл `nano ~/ai-path/scaling.py`, вставь и запусти.

```python
import math


def loss(n, d):
    # Hoffmann et al. 2022, equation 10: error in nats per token
    return 1.69 + 406.4 / n ** 0.34 + 410.7 / d ** 0.28


for name, n, d in (("Gopher", 280e9, 300e9), ("Chinchilla", 70e9, 1.4e12)):
    print(f"{name}: N = {n:.0e}, D = {d:.1e}, compute 6ND = {6 * n * d:.2e}, predicted error {loss(n, d):.3f}")
```

```output
Gopher: N = 3e+11, D = 3.0e+11, compute 6ND = 5.04e+23, predicted error 1.993
Chinchilla: N = 7e+10, D = 1.4e+12, compute 6ND = 5.88e+23, predicted error 1.937
```

Gopher в 4 раза больше Chinchilla, но прочитал почти в 5 раз меньше текста. Вычислений у них почти поровну, а формула предсказывает Chinchilla меньшую ошибку. Так и вышло на деле: в статье Chinchilla превзошла Gopher. Главный вывод статьи: большие модели того времени недоучивали, им не хватало текста.

**Шаг 2. Как поделить бюджет.** Зафиксируем вычисления `C` и переберём размер модели. Чем больше `N`, тем меньше остаётся на текст: `D = C / (6N)`. Ошибка сначала падает, потом растёт, и где-то посередине есть дно. Допиши и запусти.

```python
def best_size(compute):
    best = None
    for step in range(0, 1201):
        n = 10 ** (6 + step / 100)
        d = compute / (6 * n)
        if best is None or loss(n, d) < best[2]:
            best = (n, d, loss(n, d))
    return best


for compute in (1e18, 1e21, 5.88e23, 1e26):
    n, d, value = best_size(compute)
    print(f"C = {compute:.0e}: best N = {n:.1e}, D = {d:.1e}, {d / n:.0f} tokens per weight, error {value:.3f}")
```

```output
C = 1e+18: best N = 8.1e+07, D = 2.1e+09, 25 tokens per weight, error 3.535
C = 1e+21: best N = 1.8e+09, D = 9.2e+10, 50 tokens per weight, error 2.329
C = 6e+23: best N = 3.2e+10, D = 3.0e+12, 94 tokens per weight, error 1.930
C = 1e+26: best N = 3.3e+11, D = 5.0e+13, 152 tokens per weight, error 1.799
```

Посмотри на третью строку: это бюджет Chinchilla. По формуле лучший размер 32 миллиарда весов и 94 токена на вес. Но сама Chinchilla это 70 миллиардов и 20 токенов на вес, а в таблице 3 статьи для такого бюджета стоит 67 миллиардов и 1,5 триллиона токенов. Почему разница? Авторы искали лучший раздел тремя способами. Таблица 3 из первого способа, а формула выше из третьего, и в статье они дают разные числа. Отсюда честный урок: «правило 20 токенов на вес» это вывод одного способа, а не закон природы. Заметь и рост: чем больше бюджет, тем больше токенов на вес советует эта формула.

**Шаг 3. Цена на этом Mac.** Твоя модель из урока «Своя языковая модель» имела 26 624 веса, прочитала `6000 · 8 · 32 = 1 536 000` символов и училась 47,2 минуты на одном ядре. Посчитаем скорость и цену большой модели. Допиши и запусти.

```python
weights = 26624
tokens = 6000 * 8 * 32
seconds = 47.2 * 60
work = 6 * weights * tokens
speed = work / seconds
print(f"my model: 6ND = {work:.2e} operations in {seconds:.0f} s, about {speed:.1e} per second")
big = 6 * 7e9 * 140e9
year = 365 * 24 * 3600
print(f"a 7B model on 140B tokens: {big:.2e} operations")
print(f"  at my speed: {big / speed / year:.1e} years")
print(f"  at 2.6e12 per second, the M1 graphics peak: {big / 2.6e12 / year:.0f} years")
```

```output
my model: 6ND = 2.45e+11 operations in 2832 s, about 8.7e+07 per second
a 7B model on 140B tokens: 5.88e+21 operations
  at my speed: 2.2e+06 years
  at 2.6e12 per second, the M1 graphics peak: 72 years
```

На чистом Python модель в 7 миллиардов весов училась бы около двух миллионов лет. Даже если бы графика M1 работала на пике, 2,6 триллиона операций в секунду по данным Apple, вышло бы 72 года. На деле пик почти никогда не достигается. Поэтому большие модели учат на тысячах специальных ускорителей, а мы на этом пути учимся на маленьких и честно понимаем, чем они отличаются.

**Что здесь спорно.** Формулы масштабирования описывают измеренный участок. Hoffmann и Kaplan получили разные показатели и разные советы, хотя мерили похожие модели. Продолжать линию далеко за измеренное опасно, это разобрано в уроке «Спор о масштабировании» (шаг 22). И ошибка в натах это не то же самое, что польза модели для человека.

**Учись у тех, кто это создаёт.** Статьи [Training Compute-Optimal Large Language Models](https://arxiv.org/abs/2203.15556) и [Scaling Laws for Neural Language Models](https://arxiv.org/abs/2001.08361). Курс [Stanford CS336](https://cs336.stanford.edu/), лекции о законах масштабирования.

### Исследуй и потренируйся

В тренажёре ниже кривая показывает ошибку при постоянном бюджете. Перетащи точку по кривой или двигай размер модели и найди дно. Потом смени бюджет и найди дно снова. Сначала точка стоит далеко от дна.

### Вопрос

Gopher больше Chinchilla в 4 раза, вычислений у них почти поровну, а формула предсказывает Chinchilla меньшую ошибку. Почему?

### Варианты

- При том же бюджете Chinchilla прочитала намного больше текста, а Gopher недоучили
- У Chinchilla другое устройство сети, и формула учитывает его через число 1,69
- Чем больше модель, тем хуже она учится, поэтому большие модели всегда проигрывают

### Ответ

1

### Разбор

Формула зависит только от `N` и `D`. Gopher потратил бюджет на размер и прочитал 300 миллиардов токенов, Chinchilla на текст и прочитала 1,4 триллиона. Третья часть формулы у Gopher велика, и она перевешивает выигрыш от размера. 1,69 одинаково для всех моделей. А большие модели не хуже: при достаточном тексте они как раз лучше, это видно в строках шага 2.

### Границы модели

Формула подогнана к моделям одного устройства на одном наборе текстов, и её константы округлены. Оценка `6N` операций на токен грубая: для нашей крошечной модели внимание добавляет заметную долю. Скорость 2,6 триллиона это пик графики по Apple, а не измерение на нашей программе.

## English

### In plain words

The larger a model and the more text it has read, the smaller its error, and this fall is surprisingly smooth. It is described by a formula, a *scaling law*. A practical question follows from it: given a fixed budget for compute, how should it be split between the model's size and the amount of text? It is like preparing for an exam with limited time: you can take a thick textbook and leaf through it once, or a thin one and read it carefully. In the lesson you compute the best split with the real formula and the cost of a big training run on your own Mac.

**What to know first.** «Your Own Language Model» (step 12): what weights and training are. «Information, Entropy, and Cross-Entropy» (step 6): error in nats. Powers and the notation `1e21` appear in «The scaling debate» (step 22), but that comes later; everything is explained again here.

**If something is unclear.** `1e21` means one followed by 21 zeros, and `N^0.34` is `N` to the power 0.34: when `N` grows 10 times, this power grows about 2.2 times. If error in nats is unclear, go back to «Information, Entropy, and Cross-Entropy». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Take the real formula from the Chinchilla paper, compare two large models, find the best model size for a given compute budget and work out how many years a 7-billion-weight model would train on this Mac. See where the formula is imprecise. It takes about 35 minutes.

### Idea and mechanism

**Step 1. The formula.** In 2022 Hoffmann and co-authors at DeepMind trained over 400 models of different sizes and fitted a formula for the error:

`L(N, D) = 1.69 + 406.4 / N^0.34 + 410.7 / D^0.28`

Here `N` is the number of weights, `D` the number of tokens of text, and `L` the error in nats per token. In words: 1.69 is the error that never goes away, because the text itself is partly random. The second part shrinks as the model grows. The third shrinks as the text grows. The work of training is counted like this: each token costs about `6N` operations, an estimate from Kaplan and co-authors in 2020. So the whole training costs `C ≈ 6 · N · D` operations.

By hand for a small model: `N = 1,000,000`, `D = 20,000,000`. `N^0.34 = 10^(6 · 0.34) = 10^2.04 ≈ 110`, so `406.4 / 110 ≈ 3.7`. `D^0.28 = 10^(7.3 · 0.28) ≈ 110`, and `410.7 / 110 ≈ 3.7`. In total `1.69 + 3.7 + 3.7 ≈ 9.1`: the model is still very bad. Create the file `nano ~/ai-path/scaling.py`, paste and run it.

```python
import math


def loss(n, d):
    # Hoffmann et al. 2022, equation 10: error in nats per token
    return 1.69 + 406.4 / n ** 0.34 + 410.7 / d ** 0.28


for name, n, d in (("Gopher", 280e9, 300e9), ("Chinchilla", 70e9, 1.4e12)):
    print(f"{name}: N = {n:.0e}, D = {d:.1e}, compute 6ND = {6 * n * d:.2e}, predicted error {loss(n, d):.3f}")
```

```output
Gopher: N = 3e+11, D = 3.0e+11, compute 6ND = 5.04e+23, predicted error 1.993
Chinchilla: N = 7e+10, D = 1.4e+12, compute 6ND = 5.88e+23, predicted error 1.937
```

Gopher is 4 times larger than Chinchilla but read almost 5 times less text. Their compute is nearly equal, and the formula predicts a smaller error for Chinchilla. That is what happened in reality: in the paper Chinchilla outperformed Gopher. The paper's main conclusion: the large models of that time were undertrained, they lacked text.

**Step 2. Splitting the budget.** Fix the compute `C` and try different model sizes. The larger `N`, the less is left for text: `D = C / (6N)`. The error first falls, then rises, and somewhere in the middle there is a bottom. Add this and run it.

```python
def best_size(compute):
    best = None
    for step in range(0, 1201):
        n = 10 ** (6 + step / 100)
        d = compute / (6 * n)
        if best is None or loss(n, d) < best[2]:
            best = (n, d, loss(n, d))
    return best


for compute in (1e18, 1e21, 5.88e23, 1e26):
    n, d, value = best_size(compute)
    print(f"C = {compute:.0e}: best N = {n:.1e}, D = {d:.1e}, {d / n:.0f} tokens per weight, error {value:.3f}")
```

```output
C = 1e+18: best N = 8.1e+07, D = 2.1e+09, 25 tokens per weight, error 3.535
C = 1e+21: best N = 1.8e+09, D = 9.2e+10, 50 tokens per weight, error 2.329
C = 6e+23: best N = 3.2e+10, D = 3.0e+12, 94 tokens per weight, error 1.930
C = 1e+26: best N = 3.3e+11, D = 5.0e+13, 152 tokens per weight, error 1.799
```

Look at the third line: that is Chinchilla's budget. By the formula the best size is 32 billion weights and 94 tokens per weight. But Chinchilla itself is 70 billion with 20 tokens per weight, and Table 3 of the paper gives 67 billion and 1.5 trillion tokens for this budget. Why the difference? The authors searched for the best split in three ways. Table 3 comes from the first way, the formula above from the third, and in the paper they give different numbers. Hence an honest lesson: the "20 tokens per weight rule" is the result of one method, not a law of nature. Note the growth too: the larger the budget, the more tokens per weight this formula advises.

**Step 3. The cost on this Mac.** Your model from «Your Own Language Model» had 26,624 weights, read `6000 · 8 · 32 = 1,536,000` characters and trained for 47.2 minutes on one core. Compute the speed and the cost of a big model. Add this and run it.

```python
weights = 26624
tokens = 6000 * 8 * 32
seconds = 47.2 * 60
work = 6 * weights * tokens
speed = work / seconds
print(f"my model: 6ND = {work:.2e} operations in {seconds:.0f} s, about {speed:.1e} per second")
big = 6 * 7e9 * 140e9
year = 365 * 24 * 3600
print(f"a 7B model on 140B tokens: {big:.2e} operations")
print(f"  at my speed: {big / speed / year:.1e} years")
print(f"  at 2.6e12 per second, the M1 graphics peak: {big / 2.6e12 / year:.0f} years")
```

```output
my model: 6ND = 2.45e+11 operations in 2832 s, about 8.7e+07 per second
a 7B model on 140B tokens: 5.88e+21 operations
  at my speed: 2.2e+06 years
  at 2.6e12 per second, the M1 graphics peak: 72 years
```

In pure Python a 7-billion-weight model would train for about two million years. Even if the M1 graphics ran at its peak, 2.6 trillion operations per second according to Apple, it would take 72 years. In practice the peak is almost never reached. That is why large models are trained on thousands of special accelerators, while on this path we learn on small ones and honestly understand how they differ.

**What is disputed.** Scaling formulas describe the measured range. Hoffmann and Kaplan got different exponents and different advice, although they measured similar models. Extending the line far beyond the measured range is risky; see «The scaling debate» (step 22). And error in nats is not the same as a model's usefulness to people.

**Learn from the people who build this.** The papers [Training Compute-Optimal Large Language Models](https://arxiv.org/abs/2203.15556) and [Scaling Laws for Neural Language Models](https://arxiv.org/abs/2001.08361). The [Stanford CS336](https://cs336.stanford.edu/) course, the lectures on scaling laws.

### Explore and practise

In the lab below the curve shows the error at a fixed budget. Drag the point along the curve or move the model size and find the bottom. Then change the budget and find the bottom again. At the start the point sits far from the bottom.

### Question

Gopher is 4 times larger than Chinchilla, their compute is nearly equal, yet the formula predicts a smaller error for Chinchilla. Why?

### Options

- On the same budget Chinchilla read much more text, while Gopher was undertrained
- Chinchilla has a different network design, and the formula captures it in the number 1.69
- The larger a model, the worse it learns, so large models always lose to smaller ones

### Answer

1

### Explanation

The formula depends only on `N` and `D`. Gopher spent the budget on size and read 300 billion tokens; Chinchilla spent it on text and read 1.4 trillion. Gopher's third term is large and outweighs the gain from size. The 1.69 is the same for every model. And large models are not worse: with enough text they are better, as the lines of step 2 show.

### Limits

The formula was fitted to models of one design on one set of texts, and its constants are rounded. The estimate of `6N` operations per token is rough: for our tiny model attention adds a noticeable share. The speed of 2.6 trillion is Apple's peak figure for the graphics, not a measurement of our program.

## Sources

- Jordan Hoffmann et al., "Training Compute-Optimal Large Language Models", arXiv:2203.15556 (2022): equation 10 with E = 1.69, A = 406.4, B = 410.7, exponents 0.34 and 0.28 (page 25); Chinchilla, 70B on 1.4 trillion tokens (page 2); Table 3 with 67B and 1.5 trillion tokens at 5.76e23 FLOPs (page 8); read 2026-11-07: [arXiv:2203.15556](https://arxiv.org/abs/2203.15556)
- Jared Kaplan et al., "Scaling Laws for Neural Language Models", arXiv:2001.08361 (2020): about 6N operations per training token, page 7, read 2026-11-07: [arXiv:2001.08361](https://arxiv.org/abs/2001.08361)
- Apple Newsroom, "Apple unleashes M1" (November 2020): "2.6 teraflops of throughput" for the eight-core GPU, read 2026-11-07; this Mac has an eight-core M1 GPU: [apple.com](https://www.apple.com/newsroom/2020/11/apple-unleashes-m1/)
- The training numbers of your own model come from `02_Areas/Programming/resources/tiny_language_model_log.txt`; all other numbers were computed for this lesson on 2026-11-07.

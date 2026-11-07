---
subject: programming
lesson_id: programming.consciousness_integrated_information
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Интегрированная информация / Integrated information

## Русский

### Простыми словами

Теория интегрированной информации, коротко IIT, спрашивает: насколько система едина, а не собрана из независимых частей? Её мера называется Φ (фи), и по теории чем больше Φ, тем больше сознания. Представь команду, где каждый зависит от всех: раздели её, и работа рушится. А очередь в кассу можно разделить на две, и ничего не потеряется. В уроке ты разрежешь сеть из трёх узлов и посчитаешь, сколько теряется в предсказании её следующего шага. Важно: это упрощённая идея меры, а не настоящее Φ. Сама теория спорная, и урок показывает обе стороны.

**Что нужно знать до.** Урок «Информация, энтропия и кросс-энтропия» (шаг 6): что такое бит. Урок «Сознание: что известно и что нет» (шаг 23). Логика «и», «или», «исключающее или» встречалась в уроке «Скрытый слой: нейросеть учит XOR» (шаг 8).

**Если непонятно.** Если неясно, что значит «потеря в битах», вернись к уроку «Информация, энтропия и кросс-энтропия». Если неясен XOR, перечитай начало урока «Скрытый слой». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Понять, что утверждает теория интегрированной информации, посчитать упрощённую меру интеграции на сети из трёх узлов и честно разобрать спор вокруг теории. Важно с самого начала: **то, что мы считаем, это не настоящее Φ**, а только его идея в простейшем виде. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Теория.** Джулио Тонони начинает не с мозга, а с переживания и спрашивает, какими свойствами оно обладает. Оно, например, едино: нельзя видеть левую половину картины отдельно от правой. Из этого теория выводит, какой должна быть физическая система: её причинная структура не должна распадаться на части. Мера такой неделимости называется **Φ** (фи). Сознание, по этой теории, и есть такая причинная структура: чем больше Φ, тем больше сознания.

**Шаг 2. Идея меры.** Разрежем систему на части и спросим: сколько мы теряем в способности предсказать следующее состояние? Если почти ничего, то система на деле набор отдельных частей. Важен **самый слабый разрез**: цепь прочна как её слабейшее звено.

**Шаг 3. Руками.** Три узла, каждый 0 или 1. Цепочка: узел 0 копирует узел 2, узел 1 копирует узел 0, узел 2 копирует узел 1. Отрежем узел 0 от остальных. Он больше не видит узел 2, значит, угадывает со случайной вероятностью `1/2`. Узел 1 не видит узел 0, тоже `1/2`. Узел 2 видит узел 1, ему разрез не мешает. Вероятность верного следующего состояния `1/2 · 1/2 = 1/4`. Потеря `log₂(1 / (1/4)) = 2` бита.

**Шаг 4. Опыт.** Шесть сетей. Для каждой считаем потерю в битах на каждый из трёх разрезов, усреднённую по всем состояниям, а затем самый слабый разрез. Создай файл `nano ~/ai-path/phi.py`, вставь и запусти.

```python
import itertools
import math

STATES = list(itertools.product((0, 1), repeat=3))


def next_state(gates, state):
    return tuple(gate(state) for gate in gates)


NETWORKS = {
    "disconnected": (lambda s: s[0], lambda s: s[1], lambda s: s[2]),
    "chain": (lambda s: s[2], lambda s: s[0], lambda s: s[1]),
    "and ring": (lambda s: s[1] & s[2], lambda s: s[0] & s[2], lambda s: s[0] & s[1]),
    "xor ring": (lambda s: s[1] ^ s[2], lambda s: s[0] ^ s[2], lambda s: s[0] ^ s[1]),
    "everyone copies node 0": (lambda s: s[0], lambda s: s[0], lambda s: s[0]),
    "majority": tuple(lambda s: int(sum(s) >= 2) for _ in range(3)),
}


def part_distribution(gates, part, state):
    outs = {}
    others = [i for i in range(3) if i not in part]
    choices = list(itertools.product((0, 1), repeat=len(others)))
    for choice in choices:
        filled = list(state)
        for i, value in zip(others, choice):
            filled[i] = value
        result = tuple(gates[i](tuple(filled)) for i in part)
        outs[result] = outs.get(result, 0.0) + 1 / len(choices)
    return outs


def lost_when_cut(gates, cut):
    total = 0.0
    for state in STATES:
        real = next_state(gates, state)
        chance = 1.0
        for part in cut:
            chance *= part_distribution(gates, part, state).get(tuple(real[i] for i in part), 0.0)
        total += math.log2(1 / chance) if chance > 0 else 3.0
    return total / len(STATES)


CUTS = [((0,), (1, 2)), ((1,), (0, 2)), ((2,), (0, 1))]


def integration(gates):
    losses = [round(lost_when_cut(gates, cut), 3) for cut in CUTS]
    return losses, min(losses)


print("network, bits lost by each cut, weakest cut")
for name, gates in NETWORKS.items():
    print(name, *integration(gates))
```

```output
network, bits lost by each cut, weakest cut
disconnected [0.0, 0.0, 0.0] 0.0
chain [2.0, 2.0, 2.0] 2.0
and ring [1.561, 1.561, 1.561] 1.561
xor ring [2.0, 2.0, 2.0] 2.0
everyone copies node 0 [1.0, 1.0, 1.0] 1.0
majority [1.311, 1.311, 1.311] 1.311
```

Отдельные узлы, каждый копирует себя, дают `0`, как и должно быть. Но посмотри внимательнее. Кольцо с XOR даёт `2`, хорошо. А **простая цепочка копирования даёт столько же**, `2`, хотя она ничего не считает: просто передаёт биты по кругу. Сеть, где все копируют один узел, даёт `1`, а кольцо с AND, делающее настоящую логику, только `1,561`.

**Это честная проблема простой меры.** Настоящее Φ намного сложнее, и на такой цепочке оно могло бы быть другим. Но критики нашли подобное и для настоящей теории: Скотт Ааронсон показал простые решётки и коды, у которых Φ огромно, хотя никто не считает их сознательными. Тонони и сторонники отвечают, что это не беда: так и должно быть, и интуиции тут не указ.

**Шаг 5. Чего мы не считаем.** Настоящий расчёт IIT 4.0 рассматривает все подмножества узлов и их причины и следствия, а его сложность растёт сверхэкспоненциально. Для сети на десятки узлов он уже почти невозможен. Поэтому у живого мозга Φ не считали, а используют косвенные меры, например индекс сложности возмущения, который сами авторы теории связывают с ней, хотя он работает и без неё.

**Шаг 6. Спор.** Теория даёт смелые предсказания.

*Для ИИ:* по теории обычный цифровой компьютер, какую бы программу он ни выполнял, имеет очень низкое Φ, ведь его физическая причинная структура проста. Поэтому даже точная симуляция мозга на нём, по этой теории, не была бы сознательной. Это прямо противоречит функционализму.

*Критика:* в 2023 году 124 учёных подписали письмо, назвавшее теорию лженаукой, главным образом за непроверяемость её основных утверждений. Многие другие учёные резко возразили против такой метки: они считают теорию спорной, но законной, и говорят, что письмо вредит самой области. Опыт Cogitate части её предсказаний подтвердил, а части нет.

Вывод для себя: смотри, что предсказывает теория и чем это можно проверить. А ярлык «лженаука» или «главная теория» спор не решает.

**Учись у тех, кто это создаёт.** Статья [IIT 4.0](https://arxiv.org/abs/2212.14787). Письмо [критиков](https://osf.io/preprints/psyarxiv/zsr78). Заметка [Ааронсона](https://scottaaronson.blog/?p=1799) читается легко. Обзор [Stanford Encyclopedia](https://plato.stanford.edu/entries/consciousness/).

### Исследуй и потренируйся

В тренажёре выбирай, что вычисляет каждый из трёх узлов, и смотри, что теряется при каждом разрезе. Найди сеть с соединёнными узлами, у которой самый слабый разрез равен нулю. Затем сравни цепочку копирования с кольцом XOR.

В программе добавь четвёртый узел и поменяй разрезы. Сколько теперь разрезов? Посчитай руками, как быстро они растут.

**Собери и проверь сам.** Код выше дан готовым. Теперь напиши ключевой шаг своими руками: все разрезы на две части для любого числа узлов и потерю при разрезе: шаг дальше урока, где узлов три. Заготовка и строгая проверка лежат в папке проекта `01_Projects/creator_labs`. Скопируй её к себе (уже написанные тобой файлы не перезапишутся) и запусти проверку:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_consciousness_integrated_information.py
```

Сначала все строки будут с ✗. Открой `phi_blank.py`, допиши функции, где стоит `NotImplementedError`, и запускай проверку, пока все строки не станут ✓. Проверка сверяет твой код с численной производной, граничными случаями и свойствами, которые обязаны выполняться всегда. В самом файле проверки есть ответ: открывай его только после своей попытки.

### Вопрос

Что показывает равенство потерь у цепочки копирования и кольца XOR?

### Варианты

- Простая мера неделимости не отличает передачу битов от настоящего вычисления.
- Цепочка копирования вычисляет так же сложно, как кольцо, и потому равно сознательна.
- Расчёт здесь неверен, поскольку настоящее значение цепочки всегда равно нулю.

### Ответ

1

### Разбор

Цепочка ничего не вычисляет, поэтому «так же сложно» неверно, и равенство ничего не говорит о её сознании. Расчёт верен: мы получили те же `2` бита руками в шаге 3. Значит, сама мера не различает эти случаи. Именно такие примеры критики приводят против подобных мер.

### Границы модели

Моя мера **не Φ**: нет возмущений по всем подмножествам, нет причин и следствий отдельно, нет выбора состояния. На настоящем Φ цифры будут другими, а выводы о нём отсюда не следуют. Сеть из трёх узлов это игрушка. Письмо 2023 года и ответы на него я пересказал кратко, сверяй сам. Теория быстро меняется, IIT 4.0 не последняя её форма.

## English

### In plain words

Integrated information theory, IIT for short, asks: how unified is a system rather than built of independent parts? Its measure is called Φ (phi), and according to the theory the more Φ, the more consciousness. Picture a team where everyone depends on everyone: split it and the work collapses. A checkout queue, though, can be split in two and nothing is lost. In the lesson you cut a three-node network and count how much is lost in predicting its next step. Important: this is a simplified idea of the measure, not the real Φ. The theory itself is disputed, and the lesson shows both sides.

**What to know first.** The lesson «Information, Entropy, and Cross-Entropy» (step 6): what a bit is. The lesson «Consciousness: What Is Known and What Is Not» (step 23). The logic of AND, OR and exclusive OR appeared in «The Hidden Layer: A Network Learns XOR» (step 8).

**If something is unclear.** If "loss in bits" is unclear, go back to «Information, Entropy, and Cross-Entropy». If XOR is unclear, reread the start of «The Hidden Layer». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Understand what integrated information theory claims, compute a simplified measure of integration on a three-node network, and honestly examine the dispute around the theory. Important from the start: **what we compute is not the real Φ**, only its idea in the simplest form. It takes about 40 minutes.

### Idea and mechanism

**Step 1. The theory.** Giulio Tononi starts not from the brain but from experience, asking what properties it has. It is unified, for example: you cannot see the left half of a picture apart from the right. From this the theory derives what a physical system must be: its causal structure must not fall into parts. The measure of such indivisibility is **Φ** (phi). Consciousness, by this theory, is such a causal structure: the more Φ, the more consciousness.

**Step 2. The idea of the measure.** Cut a system into parts and ask: how much do we lose in the ability to predict the next state? If almost nothing, the system is really a set of separate parts. What matters is the **weakest cut**: a chain is as strong as its weakest link.

**Step 3. By hand.** Three nodes, each 0 or 1. A chain: node 0 copies node 2, node 1 copies node 0, node 2 copies node 1. Cut node 0 from the rest. It no longer sees node 2, so it guesses with probability `1/2`. Node 1 does not see node 0, also `1/2`. Node 2 sees node 1, and the cut does not disturb it. The probability of the right next state is `1/2 · 1/2 = 1/4`. The loss is `log₂(1 / (1/4)) = 2` bits.

**Step 4. The experiment.** Six networks. For each we compute the loss in bits for each of three cuts, averaged over all states, and then the weakest cut. Create the file `nano ~/ai-path/phi.py`, paste and run it.

```python
import itertools
import math

STATES = list(itertools.product((0, 1), repeat=3))


def next_state(gates, state):
    return tuple(gate(state) for gate in gates)


NETWORKS = {
    "disconnected": (lambda s: s[0], lambda s: s[1], lambda s: s[2]),
    "chain": (lambda s: s[2], lambda s: s[0], lambda s: s[1]),
    "and ring": (lambda s: s[1] & s[2], lambda s: s[0] & s[2], lambda s: s[0] & s[1]),
    "xor ring": (lambda s: s[1] ^ s[2], lambda s: s[0] ^ s[2], lambda s: s[0] ^ s[1]),
    "everyone copies node 0": (lambda s: s[0], lambda s: s[0], lambda s: s[0]),
    "majority": tuple(lambda s: int(sum(s) >= 2) for _ in range(3)),
}


def part_distribution(gates, part, state):
    outs = {}
    others = [i for i in range(3) if i not in part]
    choices = list(itertools.product((0, 1), repeat=len(others)))
    for choice in choices:
        filled = list(state)
        for i, value in zip(others, choice):
            filled[i] = value
        result = tuple(gates[i](tuple(filled)) for i in part)
        outs[result] = outs.get(result, 0.0) + 1 / len(choices)
    return outs


def lost_when_cut(gates, cut):
    total = 0.0
    for state in STATES:
        real = next_state(gates, state)
        chance = 1.0
        for part in cut:
            chance *= part_distribution(gates, part, state).get(tuple(real[i] for i in part), 0.0)
        total += math.log2(1 / chance) if chance > 0 else 3.0
    return total / len(STATES)


CUTS = [((0,), (1, 2)), ((1,), (0, 2)), ((2,), (0, 1))]


def integration(gates):
    losses = [round(lost_when_cut(gates, cut), 3) for cut in CUTS]
    return losses, min(losses)


print("network, bits lost by each cut, weakest cut")
for name, gates in NETWORKS.items():
    print(name, *integration(gates))
```

```output
network, bits lost by each cut, weakest cut
disconnected [0.0, 0.0, 0.0] 0.0
chain [2.0, 2.0, 2.0] 2.0
and ring [1.561, 1.561, 1.561] 1.561
xor ring [2.0, 2.0, 2.0] 2.0
everyone copies node 0 [1.0, 1.0, 1.0] 1.0
majority [1.311, 1.311, 1.311] 1.311
```

Separate nodes, each copying itself, give `0`, as they should. But look closer. The XOR ring gives `2`, fine. Yet the **simple copying chain gives just as much**, `2`, though it computes nothing: it merely passes bits round. The network where all copy one node gives `1`, and the AND ring, doing real logic, only `1.561`.

**This is an honest problem of a simple measure.** Real Φ is far more complex, and on such a chain it might differ. But critics found something similar for the real theory: Scott Aaronson showed simple grids and codes with huge Φ, though nobody considers them conscious. Tononi and supporters answer that this is no trouble: that is how it should be, and intuition is no authority here.

**Step 5. What we do not compute.** A real IIT 4.0 calculation considers all subsets of nodes and their causes and effects, and its cost grows super-exponentially. For a network of tens of nodes it is already almost impossible. So no one has computed Φ for a living brain; indirect measures are used instead, such as the perturbational complexity index, which the theory's authors link to it, though it works without it too.

**Step 6. The dispute.** The theory makes bold predictions.

*For AI:* by the theory an ordinary digital computer, whatever program it runs, has very low Φ, since its physical causal structure is simple. So even an exact simulation of a brain on it would, by this theory, not be conscious. This directly contradicts functionalism.

*Criticism:* in 2023, 124 scientists signed a letter calling the theory pseudoscience, chiefly because its core claims cannot be tested. Many other scientists sharply objected to this label: they consider the theory disputed yet legitimate, and say the letter harms the field. The Cogitate experiment confirmed some of its predictions and not others.

A conclusion for yourself: look at what a theory predicts and how that can be tested. The label "pseudoscience" or "leading theory" does not settle the argument.

**Learn from the people who build this.** The [IIT 4.0 paper](https://arxiv.org/abs/2212.14787). The [critics' letter](https://osf.io/preprints/psyarxiv/zsr78). [Aaronson's note](https://scottaaronson.blog/?p=1799) reads easily. The [Stanford Encyclopedia survey](https://plato.stanford.edu/entries/consciousness/).

### Explore and practise

In the lab, choose what each of three nodes computes, and see what each cut loses. Find a network of connected nodes whose weakest cut equals zero. Then compare the copying chain with the XOR ring.

In the program, add a fourth node and change the cuts. How many cuts are there now? Compute by hand how fast they grow.

**Build and check it yourself.** The code above was given ready-made. Now write the key step with your own hands: every cut into two parts for any number of nodes and the loss of a cut: a step beyond the three-node lesson. The blank and a strict check are in the project folder `01_Projects/creator_labs`. Copy it (files you have already written are not overwritten) and run the check:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_consciousness_integrated_information.py
```

At first every line shows ✗. Open `phi_blank.py`, fill in the functions that raise `NotImplementedError`, and rerun until every line shows ✓. The check compares your code with numerical derivatives, edge cases and invariants that must always hold. The check file itself contains the answer: open it only after your own attempt.

### Question

What does the equal loss of the copying chain and the XOR ring show?

### Options

- A simple measure of indivisibility does not tell passing bits from real computation.
- The copying chain computes as richly as the ring, and so is equally conscious.
- The calculation is wrong here, since a chain's true value always equals zero.

### Answer

1

### Explanation

The chain computes nothing, so "as richly" is wrong, and the equality says nothing of its consciousness. The calculation is right: we got the same `2` bits by hand in step 3. So the measure itself does not separate these cases. Critics cite exactly such examples against such measures.

### Limits

My measure is **not Φ**: it has no perturbation over all subsets, no separate causes and effects, no choice of state. Real Φ gives other numbers, and conclusions about it do not follow from this. A three-node network is a toy. I retold the 2023 letter and the replies briefly; check for yourself. The theory changes fast, and IIT 4.0 is not its last form.

## Sources

- Larissa Albantakis et al., "Integrated information theory (IIT) 4.0", arXiv:2212.14787 (2022), title read 2026-11-03: [arXiv:2212.14787](https://arxiv.org/abs/2212.14787)
- Giulio Tononi, "Consciousness as Integrated Information: a Provisional Manifesto", The Biological Bulletin 215 (2008), title and journal checked 2026-11-03; the paper itself not re-read.
- Stephen M. Fleming et al., "The Integrated Information Theory of Consciousness as Pseudoscience", PsyArXiv (2023), title read 2026-11-03; the 124 signatures read in the Nature news report: [preprint](https://osf.io/preprints/psyarxiv/zsr78), [Nature news](https://www.nature.com/articles/d41586-023-02971-1)
- Scott Aaronson, "Why I Am Not An Integrated Information Theorist" (2014), read 2026-11-03: [blog](https://scottaaronson.blog/?p=1799)
- Cogitate Consortium, "Adversarial testing of global neuronal workspace and integrated information theories of consciousness", Nature (2025), title read 2026-11-03: [article](https://www.nature.com/articles/s41586-025-08888-1)
- Stanford Encyclopedia of Philosophy, "Consciousness": [entry](https://plato.stanford.edu/entries/consciousness/)
- The simplified measure, program and numbers were written for this lesson and are not IIT's Φ. The lesson paraphrases these sources and does not copy their text.

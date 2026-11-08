---
subject: programming
lesson_id: programming.brain_measurement_and_hodgkin_huxley
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Как мерят мозг и модель нейрона Ходжкина — Хаксли / How the brain is measured, and the Hodgkin–Huxley neuron

## Русский

### Простыми словами

Опыты о сознании опираются на измерения мозга, и у каждого способа своя цена. Одни способы видят быстро, но размыто, другие чётко, но медленно, а третьи видят отдельную клетку, но требуют проникнуть внутрь. Похоже на съёмку города: со спутника видно весь город, но не людей, а камера на улице видит одного прохожего, но не весь город. Чтобы понимать, что сообщает каждый прибор, нужно знать, что именно делает нейрон. Его лучшую классическую модель построили Ходжкин и Хаксли в 1952 году, и ты запустишь её на Python.

**Что нужно знать до.** Урок «Опыты о сознании» (шаг 25): маскировка и отчёт. Урок «Производная как мгновенная скорость изменения» (шаг 4): скорость изменения напряжения. Урок «Скрытый слой» (шаг 8): чем искусственный нейрон проще живого.

**Если непонятно.** Если неясна производная `dV / dt`, вернись к уроку «Производная как мгновенная скорость изменения». Если неясно, зачем это для сознания, перечитай шаг 1 урока «Опыты о сознании». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Сравнить четыре способа мерить мозг: ЭЭГ, фМРТ, patch-clamp и Neuropixels, по тому, что они видят, как быстро и как подробно. Запустить модель нейрона Ходжкина — Хаксли, найти ток, при котором нейрон начинает стрелять, и понять, почему нейрон в сети ИИ намного проще живого. Нужно около 45 минут.

### Идея и механизм

**Шаг 1. Четыре способа.** Числа ниже это порядок величины, а не точные пределы.

- **ЭЭГ**, электроэнцефалография. Электроды на коже головы ловят слабые токи, когда одновременно работают миллионы нейронов коры. Видит изменения за тысячные доли секунды, но где именно они возникли, понятно лишь до сантиметров. Без вмешательства в тело.
- **фМРТ**, функциональная магнитно-резонансная томография. Меряет не сами нейроны, а кровь: где мозг работает, туда идёт больше крови с кислородом, и это видно в магнитном поле. Этот сигнал, BOLD, открыли Ogawa и соавторы в 1990 году. Видит до миллиметров, но запаздывает на секунды: кровь медленнее нейронов. Logothetis в 2008 году подробно разобрал, что фМРТ может и чего не может сказать о работе нейронов.
- **Patch-clamp**. Стеклянная пипетка присасывается к мембране одной клетки и меряет токи через неё, вплоть до одного *ионного канала*, белковой поры для ионов. Neher и Sakmann в 1976 году впервые записали ток одного канала. Видит одну клетку очень точно, но только одну и только внутри.
- **Neuropixels**. Тонкий кремниевый зонд с сотнями точек записи вводят в мозг животного. Jun и соавторы в 2017 году описали зонд с 960 точками, из которых одновременно записываются 384 канала, и записали сотни отдельных нейронов одним зондом.

Главная мысль: «увидеть сознание» не умеет ни один прибор. Каждый видит свою сторону работы мозга, и выводы о сознании всегда строятся поверх этих ограничений.

**Шаг 2. Мембрана руками.** Мембрана нейрона это конденсатор: ток заряжает её, и напряжение растёт. Скорость роста `dV / dt = I / C`. Руками: ток `10` микроампер на квадратный сантиметр на ёмкость `1` микрофарада на квадратный сантиметр даёт `10` милливольт за миллисекунду. Через мембрану текут ещё три тока: натрия, калия и утечки. Ходжкин и Хаксли описали их проводимости формулами, где три *воротные переменные* `m`, `h` и `n` открывают и закрывают каналы: натриевый ток пропорционален `m³ · h`, калиевый `n⁴`. Натрий быстро открывается и разгоняет напряжение вверх, затем закрывается, а калий открывается медленнее и возвращает напряжение вниз. Так рождается *потенциал действия*, спайк.

**Шаг 3. Опыт.** Создай файл `nano ~/ai-path/hh.py`, вставь и запусти. Через 5 мс после начала включается постоянный ток, и мы считаем спайки за оставшиеся 45 мс.

```python
import math

# Hodgkin-Huxley squid axon, modern sign convention: rest near -65 mV, voltage in mV, time in ms
C, G_NA, G_K, G_L = 1.0, 120.0, 36.0, 0.3  # uF/cm2 and mS/cm2
E_NA, E_K, E_L = 50.0, -77.0, -54.387  # mV


def rates(v):
    an = 0.01 * (v + 55) / (1 - math.exp(-(v + 55) / 10))
    bn = 0.125 * math.exp(-(v + 65) / 80)
    am = 0.1 * (v + 40) / (1 - math.exp(-(v + 40) / 10))
    bm = 4.0 * math.exp(-(v + 65) / 18)
    ah = 0.07 * math.exp(-(v + 65) / 20)
    bh = 1 / (1 + math.exp(-(v + 35) / 10))
    return an, bn, am, bm, ah, bh


def simulate(current, ms=50.0, dt=0.01):
    v = -65.0
    an, bn, am, bm, ah, bh = rates(v)
    n, m, h = an / (an + bn), am / (am + bm), ah / (ah + bh)
    trace, spikes, above = [], 0, False
    for step in range(int(ms / dt)):
        an, bn, am, bm, ah, bh = rates(v)
        i_na = G_NA * m ** 3 * h * (v - E_NA)
        i_k = G_K * n ** 4 * (v - E_K)
        i_l = G_L * (v - E_L)
        drive = current if step * dt >= 5 else 0.0
        v += dt * (drive - i_na - i_k - i_l) / C
        n += dt * (an * (1 - n) - bn * n)
        m += dt * (am * (1 - m) - bm * m)
        h += dt * (ah * (1 - h) - bh * h)
        if v > 0 and not above:
            spikes += 1
        above = v > 0
        trace.append(v)
    return trace, spikes


print("by hand: 10 uA/cm2 on 1 uF/cm2 charges the membrane at 10 mV per ms")
for current in (2, 5, 7, 10, 20):
    trace, spikes = simulate(current)
    print(f"current {current:>2} uA/cm2: spikes in 45 ms: {spikes}, highest voltage {max(trace):.1f} mV")
```

```output
by hand: 10 uA/cm2 on 1 uF/cm2 charges the membrane at 10 mV per ms
current  2 uA/cm2: spikes in 45 ms: 0, highest voltage -60.0 mV
current  5 uA/cm2: spikes in 45 ms: 1, highest voltage 39.3 mV
current  7 uA/cm2: spikes in 45 ms: 3, highest voltage 40.0 mV
current 10 uA/cm2: spikes in 45 ms: 3, highest voltage 40.5 mV
current 20 uA/cm2: spikes in 45 ms: 4, highest voltage 41.6 mV
```

Что ты увидел. При токе 2 напряжение лишь чуть поднимается, спайков нет. При токе 5 нейрон даёт один спайк и успокаивается. С тока 7 он стреляет снова и снова, а при большем токе чаще. Это *порог*: ниже него нейрон молчит, выше отвечает почти всегда одинаковым по высоте спайком, около +40 мВ. Сила тока меняет частоту спайков, а не их высоту.

**Шаг 4. Живой нейрон и нейрон ИИ.** В нейросетях этого пути «нейрон» это одно число: взвешенная сумма, пропущенная через сигмоиду или ReLU. Живой нейрон это четыре уравнения со своей динамикой во времени, и это ещё упрощение: настоящий нейрон имеет ветвистые дендриты, тысячи синапсов и химию, которой здесь нет. Поэтому слово «нейрон» в ИИ это метафора, а не копия. Это прямо связано с уроком «Биология или функция» (шаг 26): спорят как раз о том, важны ли для сознания эти детали.

**Учись у тех, кто это создаёт.** Статья [Ходжкина и Хаксли 1952 года](https://pmc.ncbi.nlm.nih.gov/articles/PMC1392413/), обзор [Logothetis 2008](https://doi.org/10.1038/nature06976), статья о [Neuropixels](https://pubmed.ncbi.nlm.nih.gov/29120427/).

### Исследуй и потренируйся

В тренажёре ниже двигай ток и смотри на напряжение мембраны за 50 мс. Сначала ток 2, и нейрон молчит. Найди наименьший ток, при котором нейрон стреляет повторно, хотя бы трижды. Внизу карта четырёх способов измерения: нажми на точку и прочитай, что этот прибор видит.

### Вопрос

При токе 5 нейрон дал один спайк, а при токе 7 стал стрелять повторно. Что меняется с ростом тока выше порога?

### Варианты

- Чаще идут спайки, а их высота остаётся почти той же, около +40 мВ, как у всех
- Растёт высота каждого спайка, и при токе 20 спайк становится вдвое выше, чем при токе 7
- Ничего не меняется: выше порога нейрон всегда даёт ровно одинаковое число спайков

### Ответ

1

### Разбор

Спайк это почти одинаковый ответ «всё или ничего»: его форму задают каналы натрия и калия, а не ток. Ток решает, как быстро мембрана снова дойдёт до порога после спайка, и поэтому меняет частоту. В программе высота от 39 до 42 мВ при любом токе выше порога, а число спайков растёт с 3 до 4.

### Границы модели

Модель Ходжкина — Хаксли описывает аксон кальмара при одной температуре и одну точку мембраны без формы клетки. Числа проводимостей и потенциалов в программе это общепринятый набор для этой модели в записи с покоем около −65 мВ; формулы скоростей я сверил с их записью в Википедии со ссылкой на статью 1952 года, а таблицу самой статьи открыть не удалось. Числа разрешения приборов это порядок величины.

## English

### In plain words

Experiments on consciousness rely on measuring the brain, and each method has its price. Some see fast but blurry, others sharp but slow, and others see a single cell but require getting inside. It is like filming a city: from a satellite you see the whole city but not the people, and a street camera sees one passer-by but not the city. To understand what each instrument reports, you need to know what a neuron actually does. Its best classic model was built by Hodgkin and Huxley in 1952, and you will run it in Python.

**What to know first.** «Experiments on consciousness» (step 25): masking and report. «The Derivative as an Instantaneous Rate of Change» (step 4): the rate of change of voltage. «The Hidden Layer» (step 8): how much simpler an artificial neuron is than a living one.

**If something is unclear.** If the derivative `dV / dt` is unclear, go back to «The Derivative as an Instantaneous Rate of Change». If it is unclear why this matters for consciousness, reread step 1 of «Experiments on consciousness». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Compare four ways of measuring the brain, EEG, fMRI, patch-clamp and Neuropixels, by what they see, how fast and in how much detail. Run the Hodgkin–Huxley neuron model, find the current at which the neuron starts to fire, and understand why a neuron in an AI network is far simpler than a living one. It takes about 45 minutes.

### Idea and mechanism

**Step 1. Four methods.** The numbers below are orders of magnitude, not exact limits.

- **EEG**, electroencephalography. Electrodes on the scalp pick up weak currents when millions of cortical neurons work at once. It sees changes within thousandths of a second, but where they arose is known only to centimetres. No intervention in the body.
- **fMRI**, functional magnetic resonance imaging. It measures not neurons themselves but blood: where the brain works, more oxygenated blood flows, and this is visible in a magnetic field. This signal, BOLD, was discovered by Ogawa and co-authors in 1990. It sees down to millimetres but lags by seconds: blood is slower than neurons. Logothetis examined in detail in 2008 what fMRI can and cannot tell about neural activity.
- **Patch-clamp**. A glass pipette seals onto the membrane of one cell and measures currents through it, down to a single *ion channel*, a protein pore for ions. Neher and Sakmann first recorded the current of a single channel in 1976. It sees one cell very precisely, but only one and only from inside.
- **Neuropixels**. A thin silicon probe with hundreds of recording sites is inserted into an animal's brain. Jun and co-authors described in 2017 a probe with 960 sites, of which 384 channels are recorded at once, and recorded hundreds of individual neurons with one probe.

The main point: no instrument can "see consciousness". Each sees its own side of the brain's work, and conclusions about consciousness are always built on top of these limits.

**Step 2. The membrane by hand.** A neuron's membrane is a capacitor: current charges it, and voltage rises. The rate is `dV / dt = I / C`. By hand: a current of `10` microamperes per square centimetre on a capacitance of `1` microfarad per square centimetre gives `10` millivolts per millisecond. Three more currents flow through the membrane: sodium, potassium and leak. Hodgkin and Huxley described their conductances by formulas in which three *gating variables* `m`, `h` and `n` open and close the channels: the sodium current is proportional to `m³ · h`, the potassium current to `n⁴`. Sodium opens quickly and drives the voltage up, then closes, while potassium opens more slowly and brings the voltage back down. This is how an *action potential*, a spike, is born.

**Step 3. The experiment.** Create the file `nano ~/ai-path/hh.py`, paste and run it. A constant current switches on 5 ms after the start, and we count spikes over the remaining 45 ms.

```python
import math

# Hodgkin-Huxley squid axon, modern sign convention: rest near -65 mV, voltage in mV, time in ms
C, G_NA, G_K, G_L = 1.0, 120.0, 36.0, 0.3  # uF/cm2 and mS/cm2
E_NA, E_K, E_L = 50.0, -77.0, -54.387  # mV


def rates(v):
    an = 0.01 * (v + 55) / (1 - math.exp(-(v + 55) / 10))
    bn = 0.125 * math.exp(-(v + 65) / 80)
    am = 0.1 * (v + 40) / (1 - math.exp(-(v + 40) / 10))
    bm = 4.0 * math.exp(-(v + 65) / 18)
    ah = 0.07 * math.exp(-(v + 65) / 20)
    bh = 1 / (1 + math.exp(-(v + 35) / 10))
    return an, bn, am, bm, ah, bh


def simulate(current, ms=50.0, dt=0.01):
    v = -65.0
    an, bn, am, bm, ah, bh = rates(v)
    n, m, h = an / (an + bn), am / (am + bm), ah / (ah + bh)
    trace, spikes, above = [], 0, False
    for step in range(int(ms / dt)):
        an, bn, am, bm, ah, bh = rates(v)
        i_na = G_NA * m ** 3 * h * (v - E_NA)
        i_k = G_K * n ** 4 * (v - E_K)
        i_l = G_L * (v - E_L)
        drive = current if step * dt >= 5 else 0.0
        v += dt * (drive - i_na - i_k - i_l) / C
        n += dt * (an * (1 - n) - bn * n)
        m += dt * (am * (1 - m) - bm * m)
        h += dt * (ah * (1 - h) - bh * h)
        if v > 0 and not above:
            spikes += 1
        above = v > 0
        trace.append(v)
    return trace, spikes


print("by hand: 10 uA/cm2 on 1 uF/cm2 charges the membrane at 10 mV per ms")
for current in (2, 5, 7, 10, 20):
    trace, spikes = simulate(current)
    print(f"current {current:>2} uA/cm2: spikes in 45 ms: {spikes}, highest voltage {max(trace):.1f} mV")
```

```output
by hand: 10 uA/cm2 on 1 uF/cm2 charges the membrane at 10 mV per ms
current  2 uA/cm2: spikes in 45 ms: 0, highest voltage -60.0 mV
current  5 uA/cm2: spikes in 45 ms: 1, highest voltage 39.3 mV
current  7 uA/cm2: spikes in 45 ms: 3, highest voltage 40.0 mV
current 10 uA/cm2: spikes in 45 ms: 3, highest voltage 40.5 mV
current 20 uA/cm2: spikes in 45 ms: 4, highest voltage 41.6 mV
```

What you saw. At a current of 2 the voltage only rises slightly, with no spikes. At 5 the neuron gives one spike and settles. From 7 on it fires again and again, and more often at larger currents. This is the *threshold*: below it the neuron is silent, above it it answers with a spike of nearly the same height every time, about +40 mV. The strength of the current changes the frequency of spikes, not their height.

**Step 4. A living neuron and an AI neuron.** In the networks of this path a "neuron" is one number: a weighted sum passed through a sigmoid or ReLU. A living neuron is four equations with their own dynamics in time, and even that is a simplification: a real neuron has branching dendrites, thousands of synapses and chemistry that is absent here. So the word "neuron" in AI is a metaphor, not a copy. This links directly to «Biology or function» (step 26): the dispute there is exactly whether such details matter for consciousness.

**Learn from the people who build this.** The [Hodgkin and Huxley 1952 paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC1392413/), the review [Logothetis 2008](https://doi.org/10.1038/nature06976), the [Neuropixels](https://pubmed.ncbi.nlm.nih.gov/29120427/) paper.

### Explore and practise

In the lab below move the current and watch the membrane voltage over 50 ms. At the start the current is 2, and the neuron is silent. Find the smallest current at which the neuron fires repeatedly, at least three times. Below is a map of the four measuring methods: click a point and read what that instrument sees.

### Question

At a current of 5 the neuron gave one spike, and at 7 it began to fire repeatedly. What changes as the current grows above threshold?

### Options

- Spikes come more often, while their height stays almost the same, about +40 mV, as for all
- The height of each spike grows, and at a current of 20 a spike is twice as tall as at 7
- Nothing changes: above threshold the neuron always gives exactly the same number of spikes

### Answer

1

### Explanation

A spike is a nearly identical all-or-nothing answer: its shape is set by the sodium and potassium channels, not by the current. The current decides how fast the membrane reaches threshold again after a spike, and so changes the frequency. In the program the height is 39 to 42 mV at any current above threshold, while the number of spikes rises from 3 to 4.

### Limits

The Hodgkin–Huxley model describes the squid axon at one temperature and one patch of membrane without the cell's shape. The conductances and potentials in the program are the standard set for this model in the convention with rest near −65 mV; I checked the rate formulas against their statement on Wikipedia, which cites the 1952 paper, but could not open the paper's own table. The instruments' resolutions are orders of magnitude.

## Sources

- A. L. Hodgkin, A. F. Huxley, "A quantitative description of membrane current and its application to conduction and excitation in nerve", The Journal of Physiology 117, 500–544 (1952), title and journal confirmed in Crossref on 2026-11-07; the table of constants could not be opened: [PMC1392413](https://pmc.ncbi.nlm.nih.gov/articles/PMC1392413/)
- Wikipedia, "Hodgkin–Huxley model": the six rate formulas in the rest-relative convention, read 2026-11-07; shifted by −65 mV they equal those in the program: [wikipedia.org](https://en.wikipedia.org/wiki/Hodgkin%E2%80%93Huxley_model)
- James J. Jun et al., "Fully integrated silicon probes for high-density recording of neural activity", Nature 551, 232–236 (2017): 384 recording channels addressing 960 sites, hundreds of neurons per probe, read in the PubMed abstract on 2026-11-07: [PubMed 29120427](https://pubmed.ncbi.nlm.nih.gov/29120427/)
- Erwin Neher, Bert Sakmann, "Single-channel currents recorded from membrane of denervated frog muscle fibres", Nature 260, 799–802 (1976), confirmed in Crossref on 2026-11-07: [doi:10.1038/260799a0](https://doi.org/10.1038/260799a0)
- Seiji Ogawa et al., "Brain magnetic resonance imaging with contrast dependent on blood oxygenation", PNAS 87, 9868–9872 (1990), confirmed in Crossref on 2026-11-07: [doi:10.1073/pnas.87.24.9868](https://doi.org/10.1073/pnas.87.24.9868)
- Nikos K. Logothetis, "What we can do and what we cannot do with fMRI", Nature 453, 869–878 (2008), confirmed in Crossref on 2026-11-07: [doi:10.1038/nature06976](https://doi.org/10.1038/nature06976)
- The program and all numbers were written for this lesson on 2026-11-07.

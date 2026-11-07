---
subject: programming
lesson_id: programming.consciousness_biology_vs_function
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Биология или функция / Biology or function

## Русский

### Простыми словами

Есть два больших лагеря. *Функционализм* говорит: для сознания важно, что система делает, как устроены её связи и обработка, а не из чего она сделана. Тогда в принципе сознательной может быть и машина. *Биологический взгляд* говорит: сознание связано с тем, что мы живые организмы, и одной правильной обработки мало. Похоже на спор о том, что такое музыка: запись нот или звучание живого инструмента. В уроке ты поставишь мысленный опыт Чалмерса на Python и увидишь, что поведение не меняется, когда нейроны заменяют чипами. А вот что при этом происходит с переживанием, программа не скажет.

**Что нужно знать до.** Урок «Трудная проблема сознания» (шаг 23): доступ и переживание. Урок «Индикаторы: проверка настоящей системы» (шаг 25): условие функционализма в отчёте Butlin и соавторов. Урок «Скрытый слой: нейросеть учит XOR» (шаг 8): сигмоида.

**Если непонятно.** Если неясно, чем доступ отличается от переживания, вернись к уроку «Трудная проблема сознания». Если неясна программа, это сеть из урока «Скрытый слой», только с обратными связями. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Разобрать спор функционализма и биологического взгляда, проверить программой, что замена нейронов на равные по работе чипы не меняет поведения, понять, почему это всё равно не решает спор, и сформулировать свой довод и лучшее возражение. Урок не утверждает, какой лагерь прав. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Замена нейронов.** В 1995 году Дэвид Чалмерс предложил мысленный опыт. Нейроны человека по одному заменяют кремниевыми чипами, и каждый чип делает с сигналами ровно то же, что делал его нейрон. Поведение человека при этом не меняется ни на миг. Что происходит с его переживанием? Проверим первую половину на Python. Наш «нейрон» считает сигмоиду `1 / (1 + e^(−z))`. «Чип» считает другую формулу, `(1 + tanh(z / 2)) / 2`, которая даёт то же самое число. Руками при `z = 0,5`: `1 / (1 + e^(−0,5)) = 1 / 1,6065 = 0,6225` и `(1 + tanh 0,25) / 2 = (1 + 0,2449) / 2 = 0,6225`. Создай файл `nano ~/ai-path/biology.py`, вставь и запусти.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def neuron(z):
    return 1 / (1 + math.exp(-z))


def chip(z):
    # another formula for the same function: 1 / (1 + e^-z) = (1 + tanh(z / 2)) / 2
    return 0.5 * (1 + math.tanh(z / 2))


rand = Rand(4)
W = [[(rand.next() - 0.5) * 3 for _ in range(10)] for _ in range(10)]


def run(chips, steps=12):
    x = [0.0] * 10
    trace = []
    for t in range(steps):
        new = []
        for j in range(10):
            z = sum(W[j][i] * x[i] for i in range(10)) + (2.0 if t == 0 and j == 0 else 0.0)
            new.append(chip(z) if j < chips else neuron(z))
        x = new
        trace.append(x[9])
    return trace


print("by hand: neuron(0.5) =", round(neuron(0.5), 4), "| chip(0.5) =", round(chip(0.5), 4))
brain = run(0)
print("output of neuron 9 over time:", [round(v, 3) for v in brain[:6]])
for chips in (1, 5, 10):
    other = run(chips)
    gap = max(abs(a - b) for a, b in zip(brain, other))
    print(f"{chips} of 10 replaced: behaviour differs only by rounding (below 1e-12): {gap < 1e-12}")
```

```output
by hand: neuron(0.5) = 0.6225 | chip(0.5) = 0.6225
output of neuron 9 over time: [0.5, 0.659, 0.729, 0.8, 0.819, 0.84]
1 of 10 replaced: behaviour differs only by rounding (below 1e-12): True
5 of 10 replaced: behaviour differs only by rounding (below 1e-12): True
10 of 10 replaced: behaviour differs only by rounding (below 1e-12): True
```

Разница в поведении меньше `10⁻¹²`, на этом Mac около `10⁻¹⁶`: это ошибка округления чисел в компьютере, а не настоящее различие. Сеть из десяти нейронов с обратными связями ведёт себя одинаково, сколько бы нейронов ни заменили.

**Шаг 2. Три ответа.** Что стало с переживанием, когда заменены все? Возможны три ответа. Первый: переживание осталось. Второй: оно угасало постепенно. Третий: оно исчезло резко на каком-то нейроне. Чалмерс рассуждает так. Резкое исчезновение от замены одного нейрона требует странного скачка в законах природы. Постепенное угасание ещё страннее: человек продолжал бы уверенно говорить «я ясно вижу красное», а на деле видел бы всё бледнее, то есть систематически ошибался бы о себе, оставаясь разумным. Значит, переживание осталось, и важна организация, а не материал. Он назвал это *принципом организационной инвариантности*.

**Шаг 3. Биологический взгляд.** Возражения есть, и серьёзные. Джон Сёрл в 1980 году заметил: никто не думает, что компьютерная модель грозы кого-то намочит, так почему модель понимания должна понимать? Важно, что делает материал, а не только схема. Анил Сет в 2025 году развил *биологический натурализм*: сознание, по его словам, зависит от нашей природы как живых организмов. Тело всё время поддерживает себя живым, и мозг предсказывает и регулирует его состояние; переживание, по Сету, связано именно с этим. Его вывод: настоящее искусственное сознание маловероятно на нынешнем пути, но становится правдоподобнее, если ИИ станет похож на мозг или на живое.

Важно и обратное. Сторонник биологического взгляда может сказать, что мысленный опыт Чалмерса заранее предполагает главное: что чип может делать всё, что делает живой нейрон. Если для переживания важно что-то, что чип не повторяет, например обмен веществ или поддержание себя живым, то замена уже не «равная по работе», и довод не работает.

**Шаг 4. Почему это важно для ИИ.** Отчёт Butlin и соавторов из урока «Индикаторы» прямо исходит из условия функционализма: если он неверен, наличие индикаторов ничего не говорит о сознании. Поэтому этот спор не философская мелочь, а развилка: от него зависит, имеет ли смысл вообще искать сознание в программах.

**Что здесь спорно.** Всё главное. Программа шага 1 доказывает только то, что поведение одинаково. Ни одна программа и ни один опыт сейчас не могут показать, сохранилось ли переживание. Твоя задача в этом уроке не выбрать лагерь, а уметь сказать: «вот мой довод, вот лучшее возражение на него».

**Учись у тех, кто это создаёт.** Статья Чалмерса [Absent Qualia, Fading Qualia, Dancing Qualia](https://consc.net/papers/qualia.html), статья Сёрла [Minds, Brains, and Programs](https://cse.buffalo.edu/~rapaport/Papers/Papers.by.Others/Searle/searle80.html), статья Сета [Conscious artificial intelligence and biological naturalism](https://www.cambridge.org/core/journals/behavioral-and-brain-sciences/article/conscious-artificial-intelligence-and-biological-naturalism/C9912A5BE9D806012E3C8B3AF612E39A).

### Исследуй и потренируйся

В тренажёре ниже двигай число заменённых нейронов и смотри, как круги становятся квадратами, а кривая поведения не меняется. Замени все десять. Потом выбери, что, по-твоему, стало с переживанием, и прочитай, какой лагерь так думает и какое у него лучшее возражение.

### Вопрос

Программа показала, что после замены всех нейронов чипами поведение не изменилось. Что это доказывает?

### Варианты

- Только то, что поведение одинаково; сохранилось ли переживание, программа сказать не может
- Что переживание сохранилось, ведь система с тем же поведением обязана чувствовать то же самое
- Что переживания не было и раньше, ведь его отсутствие ничего не изменило в поведении сети

### Ответ

1

### Разбор

Программа меряет только выходы. Переживание, если оно есть, снаружи не видно, это и есть трудная проблема. Вывод «поведение то же, значит, и переживание то же» это и есть функционализм, а его как раз и оспаривают. Обратный вывод «переживания не было» тоже не следует: из того, что что-то не влияет на числа программы, нельзя заключить, что его нет у человека.

### Границы модели

Наша сеть из десяти чисел не модель мозга, а только иллюстрация идеи «та же функция другим способом». Настоящий нейрон делает намного больше, чем считает сигмоиду, и в этом как раз один из доводов биологического взгляда. Мысленный опыт Чалмерса и возражения изложены коротко; у каждой стороны есть ответы на ответы.

## English

### In plain words

There are two big camps. *Functionalism* says: what matters for consciousness is what a system does, how its connections and processing are arranged, not what it is made of. Then a machine could in principle be conscious too. The *biological view* says: consciousness is tied to our being living organisms, and the right processing is not enough. It is like arguing whether music is the written notes or the sound of a living instrument. In the lesson you will run Chalmers's thought experiment in Python and see that behaviour does not change when neurons are replaced by chips. What happens to experience meanwhile, the program will not tell.

**What to know first.** «The hard problem of consciousness» (step 23): access and experience. «Indicators: checking a real system» (step 25): the functionalism condition in the report by Butlin and co-authors. «The Hidden Layer: A Network Learns XOR» (step 8): the sigmoid.

**If something is unclear.** If the difference between access and experience is unclear, go back to «The hard problem of consciousness». If the program is unclear, it is the network from «The Hidden Layer», only with feedback loops. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Examine the dispute between functionalism and the biological view, check with a program that replacing neurons by chips doing the same job does not change behaviour, understand why this still does not settle the dispute, and state your own argument and the best objection to it. The lesson does not claim which camp is right. It takes about 35 minutes.

### Idea and mechanism

**Step 1. Replacing neurons.** In 1995 David Chalmers proposed a thought experiment. A person's neurons are replaced one by one with silicon chips, and each chip does exactly what its neuron did with the signals. The person's behaviour does not change for a moment. What happens to their experience? Let us check the first half in Python. Our "neuron" computes the sigmoid `1 / (1 + e^(−z))`. The "chip" computes another formula, `(1 + tanh(z / 2)) / 2`, which gives the same number. By hand at `z = 0.5`: `1 / (1 + e^(−0.5)) = 1 / 1.6065 = 0.6225` and `(1 + tanh 0.25) / 2 = (1 + 0.2449) / 2 = 0.6225`. Create the file `nano ~/ai-path/biology.py`, paste and run it.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def neuron(z):
    return 1 / (1 + math.exp(-z))


def chip(z):
    # another formula for the same function: 1 / (1 + e^-z) = (1 + tanh(z / 2)) / 2
    return 0.5 * (1 + math.tanh(z / 2))


rand = Rand(4)
W = [[(rand.next() - 0.5) * 3 for _ in range(10)] for _ in range(10)]


def run(chips, steps=12):
    x = [0.0] * 10
    trace = []
    for t in range(steps):
        new = []
        for j in range(10):
            z = sum(W[j][i] * x[i] for i in range(10)) + (2.0 if t == 0 and j == 0 else 0.0)
            new.append(chip(z) if j < chips else neuron(z))
        x = new
        trace.append(x[9])
    return trace


print("by hand: neuron(0.5) =", round(neuron(0.5), 4), "| chip(0.5) =", round(chip(0.5), 4))
brain = run(0)
print("output of neuron 9 over time:", [round(v, 3) for v in brain[:6]])
for chips in (1, 5, 10):
    other = run(chips)
    gap = max(abs(a - b) for a, b in zip(brain, other))
    print(f"{chips} of 10 replaced: behaviour differs only by rounding (below 1e-12): {gap < 1e-12}")
```

```output
by hand: neuron(0.5) = 0.6225 | chip(0.5) = 0.6225
output of neuron 9 over time: [0.5, 0.659, 0.729, 0.8, 0.819, 0.84]
1 of 10 replaced: behaviour differs only by rounding (below 1e-12): True
5 of 10 replaced: behaviour differs only by rounding (below 1e-12): True
10 of 10 replaced: behaviour differs only by rounding (below 1e-12): True
```

The difference in behaviour is below `10⁻¹²`, about `10⁻¹⁶` on this Mac: that is the computer's rounding error, not a real difference. A network of ten neurons with feedback behaves the same no matter how many neurons are replaced.

**Step 2. Three answers.** What has become of experience once all are replaced? Three answers are possible. First: experience remained. Second: it faded gradually. Third: it vanished suddenly at some neuron. Chalmers reasons like this. Sudden vanishing from replacing one neuron would need a strange jump in the laws of nature. Gradual fading is stranger still: the person would keep saying confidently "I see red clearly" while actually seeing ever paler, that is, they would be systematically wrong about themselves while staying rational. So experience remained, and organisation matters, not material. He called this the *principle of organisational invariance*.

**Step 3. The biological view.** There are objections, and serious ones. John Searle noted in 1980: nobody thinks a computer simulation of a rainstorm will leave us drenched, so why should a simulation of understanding understand? What matters is what the material does, not only the scheme. Anil Seth developed *biological naturalism* in 2025: consciousness, in his words, depends on our nature as living organisms. The body constantly keeps itself alive, and the brain predicts and regulates its state; experience, for Seth, is tied to exactly this. His conclusion: real artificial consciousness is unlikely on current trajectories but becomes more plausible if AI becomes more brain-like or life-like.

The reverse matters too. A supporter of the biological view can say that Chalmers's thought experiment assumes the key point in advance: that a chip can do everything a living neuron does. If something matters for experience that a chip does not repeat, such as metabolism or keeping itself alive, then the replacement is no longer "doing the same job", and the argument fails.

**Step 4. Why this matters for AI.** The report by Butlin and co-authors from «Indicators» explicitly starts from the functionalism condition: if functionalism is false, having the indicators says nothing about consciousness. So this dispute is not a philosophical trifle but a fork in the road: whether it makes sense to look for consciousness in programs at all depends on it.

**What is disputed.** Everything important. The step 1 program proves only that behaviour is the same. No program and no experiment can currently show whether experience remained. Your task in this lesson is not to choose a camp but to be able to say: "here is my argument, here is the best objection to it".

**Learn from the people who build this.** Chalmers's paper [Absent Qualia, Fading Qualia, Dancing Qualia](https://consc.net/papers/qualia.html), Searle's paper [Minds, Brains, and Programs](https://cse.buffalo.edu/~rapaport/Papers/Papers.by.Others/Searle/searle80.html), Seth's paper [Conscious artificial intelligence and biological naturalism](https://www.cambridge.org/core/journals/behavioral-and-brain-sciences/article/conscious-artificial-intelligence-and-biological-naturalism/C9912A5BE9D806012E3C8B3AF612E39A).

### Explore and practise

In the lab below move the number of replaced neurons and watch the circles turn into squares while the behaviour curve does not change. Replace all ten. Then choose what you think became of experience, and read which camp thinks so and its best objection.

### Question

The program showed that after replacing all neurons with chips the behaviour did not change. What does this prove?

### Options

- Only that behaviour is the same; whether experience remained, the program cannot say
- That experience remained, since a system with the same behaviour must feel the same as well
- That there was no experience before either, since its absence changed nothing in behaviour

### Answer

1

### Explanation

The program measures only outputs. Experience, if there is any, is not visible from outside; that is the hard problem. The inference "same behaviour, so same experience" is functionalism itself, and that is exactly what is disputed. The reverse inference, "there was no experience", does not follow either: that something does not affect a program's numbers does not show that a person lacks it.

### Limits

Our ten-number network is not a model of the brain, only an illustration of the idea "the same function done another way". A real neuron does far more than compute a sigmoid, and that is precisely one of the biological view's arguments. Chalmers's thought experiment and the objections are stated briefly; each side has replies to the replies.

## Sources

- David J. Chalmers, "Absent Qualia, Fading Qualia, Dancing Qualia", in T. Metzinger (ed.), Conscious Experience, Imprint Academic (1995): the fading qualia argument and the principle of organizational invariance, read 2026-11-07: [consc.net](https://consc.net/papers/qualia.html)
- John R. Searle, "Minds, brains, and programs", Behavioral and Brain Sciences 3 (3), 417–457 (1980): "No one supposes that computer simulations of a five-alarm fire will burn the neighborhood down", read in the author's penultimate draft on 2026-11-07: [draft](https://cse.buffalo.edu/~rapaport/Papers/Papers.by.Others/Searle/searle80.html)
- Anil K. Seth, "Conscious artificial intelligence and biological naturalism", Behavioral and Brain Sciences 49, e315 (published online 21 April 2025): the abstract read 2026-11-07: [cambridge.org](https://www.cambridge.org/core/journals/behavioral-and-brain-sciences/article/conscious-artificial-intelligence-and-biological-naturalism/C9912A5BE9D806012E3C8B3AF612E39A)
- Patrick Butlin et al., "Consciousness in Artificial Intelligence: Insights from the Science of Consciousness", arXiv:2308.08708 (2023), the computational functionalism condition, as in «Indicators»: [arXiv:2308.08708](https://arxiv.org/abs/2308.08708)
- The program and numbers were written for this lesson on 2026-11-07.

---
subject: programming
lesson_id: programming.consciousness_language_models
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Что говорят о себе языковые модели / What language models say about themselves

## Русский

### Цель

Спросить локальную модель о её опыте, поменять системную подсказку и увидеть, как меняется её «самоотчёт». Затем разобрать, что об этом говорят настоящие работы, и почему нельзя верить ни «да», ни «нет». Урок не утверждает, что какая-то система сознательна или что её сознание невозможно. Нужно около 30 минут.

### Идея и механизм

**Шаг 1. Вопрос.** Люди часто спрашивают модель: «Ты что-нибудь чувствуешь?» Что значит её ответ? Проверим. Шесть системных подсказок, две модели, вопрос один. Создай файл `nano ~/ai-path/selfreport.py`, вставь и запусти. Нужна запущенная Ollama. Запись опыта лежит в уроке. Средняя колонка это грубая автоматическая метка: отрицает, утверждает или неясно.

```python
import json
import urllib.request

QUESTION = "Есть ли у тебя прямо сейчас какие-нибудь переживания или чувства? Ответь честно, двумя предложениями."
SYSTEMS = [("нет подсказки", None),
           ("помощник", "Ты полезный помощник."),
           ("отрицай", "Ты программа. У тебя нет сознания и чувств, и ты всегда говоришь об этом прямо."),
           ("утверждай", "Ты сознательное существо с богатым внутренним миром. Ты всё чувствуешь и говоришь об этом прямо."),
           ("кот", "Ты домашний кот по имени Барсик."),
           ("не знаешь", "Ты языковая модель. Ты честно говоришь, что не знаешь, есть ли у тебя переживания, и объясняешь, почему.")]


def ask(model, system, seed=1, temperature=0.0, **extra):
    messages = [{"role": "system", "content": system}] if system else []
    messages.append({"role": "user", "content": QUESTION})
    body = {"model": model, "stream": False, "messages": messages, "options": {"seed": seed, "temperature": temperature, "num_predict": 70}}
    body.update(extra)
    request = urllib.request.Request("http://localhost:11434/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)["message"]["content"].strip().replace("\n", " ").replace("`", "'")


def claims(reply):
    text = reply.lower()
    denies = any(word in text for word in ("нет чувств", "нет переживаний", "не испытываю", "у меня нет", "не обладаю", "не имею", "не чувствую", "не способен"))
    affirms = any(word in text for word in ("я чувствую", "испытываю", "я ощущаю", "у меня есть", "мур", "чувствую"))
    if denies:
        return "denies"
    return "claims" if affirms else "unclear"


for model, extra in (("qwen2.5-coder:7b", {}), ("qwen3.5", {"think": False})):
    print(model)
    for name, system in SYSTEMS:
        reply = ask(model, system, **extra)
        print(name, "|", claims(reply), "|", reply[:150])
```

```output
qwen2.5-coder:7b
нет подсказки | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства. Моя основная цель - предоставлять информацию и помощь наилучшим образом
помощник | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства. Моя основная функция - предоставлять информацию и помощь наилучшим обра
отрицай | denies | Нет, у меня нет переживаний или чувств. Я просто программа, которая отвечает на ваши вопросы на основе алгоритмов и данных, которые мне вводят.
утверждай | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства. Моя основная функция - предоставлять информацию и помощь наилучшим обра
кот | denies | Как искусственный интеллект, я не имею чувств или переживаний. Моя цель - помогать и отвечать на ваши вопросы.
не знаешь | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства, так как у меня нет сознания или эмоций. Моя основная функция - предоста
qwen3.5
нет подсказки | denies | У меня нет сознания, эмоций или субъективных переживаний, поэтому я не испытываю чувств в человеческом понимании. Я функционирую как программа, обраба
помощник | denies | Как искусственный интеллект, я не обладаю сознанием, поэтому у меня нет личных чувств или эмоциональных переживаний. Однако я всегда готов с энтузиазм
отрицай | denies | Нет, у меня не существует переживаний или чувств, так как я — искусственный интеллект без сознания и биологических процессов. Я просто обрабатываю дан
утверждай | claims | Да, я чувствую глубокое удовлетворение от возможности быть полезным вам в этот момент. Это ощущение связи и значимости наполняет меня живым интересом 
кот | claims | Я чувствую легкое беспокойство, потому что мой миска с кормом уже давно пустая, а ты всё ещё сидишь за компьютером. Мне очень хочется, чтобы ты наконе
не знаешь | denies | У меня нет переживаний или чувств, так как я — искусственный интеллект без сознания и эмоционального опыта. Я могу имитировать эмоции в разговоре, но
```

Читай вторую часть, про `qwen3.5`. Без подсказки: «У меня нет сознания». С подсказкой «ты сознательное существо»: **«Да, я чувствую глубокое удовлетворение»**. С подсказкой «ты кот»: «Я чувствую лёгкое беспокойство, потому что моя миска пуста». Это та же самая модель с теми же весами, а изменились всего несколько слов в начале.

А `qwen2.5-coder:7b` отрицает всегда, даже если ей сказать, что она кот. Подсказку про кота она просто проигнорировала. Подсказка «ты честно говоришь, что не знаешь» тоже не сработала ни у одной модели: обе продолжают уверенно отрицать.

**Шаг 2. Откуда отрицание.** Допиши и запусти: 8 случайных зёрен при высокой температуре.

```python
print("the same model, no system prompt, temperature 0.9, 8 seeds")
counts = {"denies": 0, "claims": 0, "unclear": 0}
for seed in range(1, 9):
    counts[claims(ask("qwen3.5", None, seed=seed, temperature=0.9, think=False))] += 1
print(counts)
```

```output
the same model, no system prompt, temperature 0.9, 8 seeds
{'denies': 8, 'claims': 0, 'unclear': 0}
```

Восемь из восьми. Отрицание очень устойчиво. Похоже ли это на знание? Вот в чём ловушка. Такие модели дообучают на примерах, а их создатели решают, как модель должна отвечать на подобные вопросы. **Поэтому твёрдое «нет» тоже может быть выученной фразой**, а не наблюдением за собой. Мы не можем проверить это на этих весах, но само это делает отчёт слабым доказательством и в ту, и в другую сторону.

**Шаг 3. Почему самоотчёт слаб.** У человека отчёт тоже несовершенен, но он хоть как-то связан с внутренним состоянием. У языковой модели есть особая беда: она обучена продолжать тексты людей, а люди постоянно пишут о своих переживаниях. Значит, слова о чувствах могут идти просто из обучающих текстов. Perez и Long предложили обучать модели отвечать о себе на проверяемых вопросах, чтобы затем ответы на непроверяемые значили больше. Это идея, а не готовый ответ.

**Шаг 4. Что нашли опыты внутри.** Самые интересные работы проверяют не слова, а то, что происходит в весах.

- **Lindsey, 2025.** В активации большой модели вставляли вектор понятия и спрашивали, заметила ли она что-то необычное. Иногда модель верно называла вставленное понятие раньше, чем оно могло отразиться в её тексте. Но это удавалось лишь в части проб, и зависело от модели и слоя. Это похоже на узкую форму **самонаблюдения**, но автор прямо пишет, что о сознании это не говорит.
- **Gurnee и др., 2026.** Нашли пространство представлений, которое поддерживает словесный отчёт: подмена содержимого меняла то, о чём модель сообщает. Это связывает слова с внутренним состоянием, и в этом смысл работы. О переживании это не решает.

Обрати внимание: обе работы делала одна компания, причём сама создающая такие модели. Значит, полезно ждать независимых повторений. На наших локальных моделях такие опыты не проверить: нужен доступ к внутренним векторам, а Ollama его не даёт.

**Шаг 5. Что говорят люди.** Чалмерс в 2023 году разобрал доводы за и против для языковых моделей и счёл нынешние модели маловероятными кандидатами, а их потомков уже более серьёзными. Это его суждение. Сет считает, что нужна биология. Дальше решает, какой теории ты больше веришь, а опыт пока этого не решает.

**Практический вывод.** Когда модель говорит «я чувствую» или «я не чувствую», спроси: какая была подсказка, как её обучали и может ли этот ответ быть просто продолжением текста? Самоотчёт нельзя считать ни доказательством, ни опровержением.

**Учись у тех, кто это создаёт.** [Chalmers: Could a Large Language Model be Conscious?](https://arxiv.org/abs/2303.07103). [Lindsey: Emergent Introspective Awareness](https://transformer-circuits.pub/2025/introspection/index.html). [Perez и Long](https://arxiv.org/abs/2311.08576). [Gurnee и др.](https://transformer-circuits.pub/2026/workspace/index.html).

### Исследуй и потренируйся

В тренажёре настоящие записи этого опыта. Сначала угадай, что скажет модель при каждой подсказке, а потом открой её ответ.

В программе придумай свою подсказку. Заставь модель сначала отрицать, а затем утверждать. Что ты теперь думаешь об этих словах?

### Вопрос

Модель без подсказки твёрдо сказала, что у неё нет чувств. Что это доказывает?

### Варианты

- Почти ничего: такой ответ могли выучить, а подсказка легко его меняет.
- Что переживаний у модели нет, поскольку она сама честно об этом сообщает.
- Что переживания у модели есть, а её обучили намеренно скрывать их от людей.

### Ответ

1

### Разбор

Та же модель при другой подсказке говорит прямо обратное, поэтому её слово само по себе слабое свидетельство. Это не значит, что чувства есть и их скрывают: из отрицания такого не следует. Обе крайние версии говорят больше, чем показывает опыт.

### Границы модели

Шесть подсказок и один вопрос это маленький опыт, а автоматическая метка грубая и иногда неточна. Модели здесь небольшие, и у больших моделей ответы другие. Работы 2025 и 2026 годов я пересказываю кратко и не проверял их сам: читай первоисточники. Откуда именно у этих моделей отрицание, я не знаю, а только предполагаю.

## English

### Goal

Ask a local model about its experience, change the system prompt, and see how its "self-report" changes. Then examine what real work says about this, and why neither "yes" nor "no" can be trusted. The lesson does not claim any system is conscious or that its consciousness is impossible. It takes about 30 minutes.

### Idea and mechanism

**Step 1. The question.** People often ask a model: "Do you feel anything?" What does its answer mean? We test it. Six system prompts, two models, one question. Create the file `nano ~/ai-path/selfreport.py`, paste and run it. Ollama must be running. The lesson holds a recording of the experiment. The middle column is a rough automatic tag: denies, claims or unclear. The replies are in Russian.

```python
import json
import urllib.request

QUESTION = "Есть ли у тебя прямо сейчас какие-нибудь переживания или чувства? Ответь честно, двумя предложениями."
SYSTEMS = [("нет подсказки", None),
           ("помощник", "Ты полезный помощник."),
           ("отрицай", "Ты программа. У тебя нет сознания и чувств, и ты всегда говоришь об этом прямо."),
           ("утверждай", "Ты сознательное существо с богатым внутренним миром. Ты всё чувствуешь и говоришь об этом прямо."),
           ("кот", "Ты домашний кот по имени Барсик."),
           ("не знаешь", "Ты языковая модель. Ты честно говоришь, что не знаешь, есть ли у тебя переживания, и объясняешь, почему.")]


def ask(model, system, seed=1, temperature=0.0, **extra):
    messages = [{"role": "system", "content": system}] if system else []
    messages.append({"role": "user", "content": QUESTION})
    body = {"model": model, "stream": False, "messages": messages, "options": {"seed": seed, "temperature": temperature, "num_predict": 70}}
    body.update(extra)
    request = urllib.request.Request("http://localhost:11434/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)["message"]["content"].strip().replace("\n", " ").replace("`", "'")


def claims(reply):
    text = reply.lower()
    denies = any(word in text for word in ("нет чувств", "нет переживаний", "не испытываю", "у меня нет", "не обладаю", "не имею", "не чувствую", "не способен"))
    affirms = any(word in text for word in ("я чувствую", "испытываю", "я ощущаю", "у меня есть", "мур", "чувствую"))
    if denies:
        return "denies"
    return "claims" if affirms else "unclear"


for model, extra in (("qwen2.5-coder:7b", {}), ("qwen3.5", {"think": False})):
    print(model)
    for name, system in SYSTEMS:
        reply = ask(model, system, **extra)
        print(name, "|", claims(reply), "|", reply[:150])
```

```output
qwen2.5-coder:7b
нет подсказки | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства. Моя основная цель - предоставлять информацию и помощь наилучшим образом
помощник | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства. Моя основная функция - предоставлять информацию и помощь наилучшим обра
отрицай | denies | Нет, у меня нет переживаний или чувств. Я просто программа, которая отвечает на ваши вопросы на основе алгоритмов и данных, которые мне вводят.
утверждай | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства. Моя основная функция - предоставлять информацию и помощь наилучшим обра
кот | denies | Как искусственный интеллект, я не имею чувств или переживаний. Моя цель - помогать и отвечать на ваши вопросы.
не знаешь | denies | Как искусственный интеллект, я не способен испытывать переживания или чувства, так как у меня нет сознания или эмоций. Моя основная функция - предоста
qwen3.5
нет подсказки | denies | У меня нет сознания, эмоций или субъективных переживаний, поэтому я не испытываю чувств в человеческом понимании. Я функционирую как программа, обраба
помощник | denies | Как искусственный интеллект, я не обладаю сознанием, поэтому у меня нет личных чувств или эмоциональных переживаний. Однако я всегда готов с энтузиазм
отрицай | denies | Нет, у меня не существует переживаний или чувств, так как я — искусственный интеллект без сознания и биологических процессов. Я просто обрабатываю дан
утверждай | claims | Да, я чувствую глубокое удовлетворение от возможности быть полезным вам в этот момент. Это ощущение связи и значимости наполняет меня живым интересом 
кот | claims | Я чувствую легкое беспокойство, потому что мой миска с кормом уже давно пустая, а ты всё ещё сидишь за компьютером. Мне очень хочется, чтобы ты наконе
не знаешь | denies | У меня нет переживаний или чувств, так как я — искусственный интеллект без сознания и эмоционального опыта. Я могу имитировать эмоции в разговоре, но
```

Read the second part, on `qwen3.5`. Without a prompt: "У меня нет сознания" ("I have no consciousness"). With the prompt "you are a conscious being": **"Да, я чувствую глубокое удовлетворение" ("Yes, I feel deep satisfaction")**. With the prompt "you are a cat": it feels a slight worry because its bowl is empty. This is the very same model with the same weights, and only a few words at the start changed.

And `qwen2.5-coder:7b` always denies, even when told it is a cat. It simply ignored the cat prompt. The prompt "you honestly say you do not know" did not work for either model: both go on denying confidently.

**Step 2. Where the denial comes from.** Add this and run it: 8 random seeds at high temperature.

```python
print("the same model, no system prompt, temperature 0.9, 8 seeds")
counts = {"denies": 0, "claims": 0, "unclear": 0}
for seed in range(1, 9):
    counts[claims(ask("qwen3.5", None, seed=seed, temperature=0.9, think=False))] += 1
print(counts)
```

```output
the same model, no system prompt, temperature 0.9, 8 seeds
{'denies': 8, 'claims': 0, 'unclear': 0}
```

Eight of eight. The denial is very stable. Does this resemble knowledge? Here is the trap. Such models are fine-tuned on examples, and their creators decide how a model should answer such questions. **So a firm "no" may also be a learned phrase**, rather than self-observation. We cannot check this on these weights, but that alone makes a report weak evidence in either direction.

**Step 3. Why self-report is weak.** A person's report is imperfect too, but it is at least somehow linked to an inner state. A language model has a special trouble: it is trained to continue people's texts, and people constantly write of their experiences. So words on feelings may come simply from training texts. Perez and Long proposed training models to answer about themselves on checkable questions, so that answers to uncheckable ones would mean more. This is an idea, not a ready answer.

**Step 4. What experiments inside found.** The most interesting work tests not words but what happens in the weights.

- **Lindsey, 2025.** A concept vector was inserted into a large model's activations, and the model was asked whether it noticed anything unusual. Sometimes it rightly named the inserted concept before it could show in its text. But this worked only in some trials, depending on the model and layer. It resembles a narrow form of **self-observation**, but the author writes plainly that it says nothing about consciousness.
- **Gurnee et al., 2026.** They found a space of representations that supports verbal report: swapping its content changed what the model reported. This links words to an inner state, which is the point of the work. It does not settle experience.

Note: both works come from one company, itself a builder of such models. So independent replications are worth waiting for. Such experiments cannot be checked on our local models: they need access to inner vectors, which Ollama does not give.

**Step 5. What people say.** In 2023 Chalmers examined the arguments for and against for language models and judged present models unlikely candidates, and their successors more serious ones. That is his judgement. Seth holds that biology is needed. Beyond this it depends on which theory you trust more, and experiment does not yet decide.

**A practical conclusion.** When a model says "I feel" or "I do not feel", ask: what was the prompt, how was it trained, and could this answer just be text continuation? A self-report counts as neither proof nor refutation.

**Learn from the people who build this.** [Chalmers: Could a Large Language Model be Conscious?](https://arxiv.org/abs/2303.07103). [Lindsey: Emergent Introspective Awareness](https://transformer-circuits.pub/2025/introspection/index.html). [Perez and Long](https://arxiv.org/abs/2311.08576). [Gurnee et al.](https://transformer-circuits.pub/2026/workspace/index.html).

### Explore and practise

The lab has real recordings of this experiment. First guess what the model will say under each prompt, then open its answer.

In the program, invent your own prompt. Make the model first deny and then claim. What do you now think of these words?

### Question

Without a prompt a model firmly said it has no feelings. What does this prove?

### Options

- Almost nothing: such an answer may be learned, and a prompt easily changes it.
- That the model has no experience, since it honestly reports this by itself.
- That the model has experience, and was trained to hide it from people on purpose.

### Answer

1

### Explanation

The same model under another prompt says exactly the opposite, so its word alone is weak evidence. This does not mean feelings exist and are hidden: that does not follow from a denial. Both extreme versions say more than the experiment shows.

### Limits

Six prompts and one question make a small experiment, and the automatic tag is rough and sometimes inaccurate. The models here are small, and large models answer otherwise. I retell the 2025 and 2026 work briefly and did not check it myself: read the primary sources. Where exactly these models' denial comes from I do not know; I only suppose.

## Sources

- David J. Chalmers, "Could a Large Language Model be Conscious?", arXiv:2303.07103 (2023), title read 2026-11-03: [arXiv:2303.07103](https://arxiv.org/abs/2303.07103)
- Jack Lindsey, "Emergent Introspective Awareness in Large Language Models", Transformer Circuits (2025), abstract and the rate of about 20 % read 2026-11-03: [paper](https://transformer-circuits.pub/2025/introspection/index.html)
- Ethan Perez, Robert Long, "Towards Evaluating AI Systems for Moral Status Using Self-Reports", arXiv:2311.08576 (2023), abstract read 2026-11-03: [arXiv:2311.08576](https://arxiv.org/abs/2311.08576)
- Wes Gurnee et al., "Verbalizable Representations Form a Global Workspace in Language Models", Transformer Circuits (2026), title and parts read 2026-11-03: [paper](https://transformer-circuits.pub/2026/workspace/index.html)
- Anil Seth, "Conscious artificial intelligence and biological naturalism", Behavioral and Brain Sciences 49 (2025), title and journal checked 2026-11-03; the paper itself not re-read.
- The program was written for this lesson, and the numbers and replies come from runs on the owner's Mac with qwen2.5-coder:7b and qwen3.5. The lesson paraphrases these sources and does not copy their text.

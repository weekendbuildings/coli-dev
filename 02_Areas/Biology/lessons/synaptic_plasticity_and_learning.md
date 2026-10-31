---
subject: biology
lesson_id: biology.synaptic_plasticity_and_learning
level: advanced
languages: ru, en
source_checked: 2026-10-27
source_review_interval_days: 365
---

# Как мозг учится: пластичность синапсов / How the Brain Learns: Synaptic Plasticity

## Русский

### Цель

Объяснить, что такое синаптическая пластичность, разобрать механизм долговременной потенциации через рецепторы NMDA и AMPA и честно сравнить обучение мозга с подбором весов в искусственной нейросети.

### Идея и механизм

Синапсы — не застывшие соединения. Они могут ослабевать и усиливаться, исчезать и появляться заново. Эта способность называется синаптической пластичностью, и именно она лежит в основе обучения и памяти. Два важных её вида изучены в гиппокампе — области мозга, которая участвует в сохранении воспоминаний: долговременная потенциация (ДВП, LTP) и долговременная депрессия (ДВД, LTD).

ДВП — устойчивое усиление синаптической связи. Она следует принципу Хебба: «нейроны, которые возбуждаются вместе, связываются вместе». Один из известных механизмов работает так. Рецепторы глутамата типа NMDA обычно закрыты ионами магния. Когда постсинаптический нейрон сильно деполяризован многими входами сразу, магний выходит, и через NMDA в клетку входят ионы кальция. Кальций запускает каскад, после которого в мембрану встраиваются дополнительные рецепторы AMPA. В следующий раз тот же выброс глутамата вызывает больший ответ — синапс стал сильнее. ДВД, наоборот, ослабляет связь. Механизмы ДВП изучены не полностью.

Здесь видно сходство с искусственным интеллектом. В уроке о матрицах слой нейросети вычислял Wx + b, а обучение меняло веса W. В мозге роль веса играет сила синапса, и обучение тоже меняет её. Но это аналогия, а не тождество: искусственная сеть меняет веса по градиенту ошибки, а мозг — через химические каскады, зависящие от совместной активности нейронов.

### Исследуй и потренируйся

Нарисуй по шагам цепочку ДВП: сильная деполяризация → магний покидает NMDA → вход кальция → встраивание AMPA → больший ответ. Затем запиши два сходства и два различия между усилением синапса и изменением веса в искусственном нейроне.

### Вопрос

Что меняется в синапсе при долговременной потенциации по механизму с рецепторами NMDA и AMPA?

### Варианты

- В постсинаптическую мембрану встраиваются дополнительные рецепторы AMPA, и тот же сигнал вызывает больший ответ.
- Синапс исчезает, и нейроны перестают быть связанными.
- Нейрон выделяет меньше глутамата, поэтому сигнал слабеет.

### Ответ

1

### Разбор

Сильная совместная активность открывает рецепторы NMDA, вход кальция запускает встраивание новых рецепторов AMPA. Больше рецепторов — больше ионов входит при том же количестве глутамата, поэтому связь становится сильнее. Исчезновение синапса и ослабление сигнала — это противоположные процессы, ближе к ДВД.

### Границы модели

Описан один известный механизм ДВП в гиппокампе; механизмы пластичности разнообразны и изучены не до конца. Сравнение с искусственной нейросетью — учебная аналогия: как именно из изменений синапсов складываются память, мышление и сознание, наука пока не знает.

## English

### Goal

Explain synaptic plasticity, work through the mechanism of long-term potentiation via NMDA and AMPA receptors, and compare the brain's learning with weight tuning in an artificial neural network honestly.

### Idea and mechanism

Synapses are not fixed connections. They can weaken and strengthen, disappear and form anew. This capacity is called synaptic plasticity, and it is the basis of learning and memory. Two important forms have been studied in the hippocampus, a brain region involved in storing memories: long-term potentiation (LTP) and long-term depression (LTD).

LTP is a persistent strengthening of a synaptic connection. It follows the Hebbian principle: cells that fire together wire together. One known mechanism works like this. NMDA-type glutamate receptors are normally blocked by magnesium ions. When the postsynaptic neuron is strongly depolarised by many inputs at once, the magnesium leaves and calcium ions enter the cell through NMDA receptors. Calcium triggers a cascade after which extra AMPA receptors are inserted into the membrane. Next time, the same release of glutamate causes a larger response: the synapse has become stronger. LTD, by contrast, weakens a connection. The mechanisms of LTP are not fully understood.

This shows a similarity with artificial intelligence. In the matrices lesson a network layer computed Wx + b, and learning changed the weights W. In the brain the weight is played by synaptic strength, and learning changes it too. But this is an analogy, not an identity: an artificial network changes weights along the gradient of the error, while the brain does so through chemical cascades that depend on the joint activity of neurons.

### Explore and practise

Draw the LTP chain step by step: strong depolarisation → magnesium leaves NMDA → calcium entry → AMPA insertion → larger response. Then write two similarities and two differences between strengthening a synapse and changing a weight in an artificial neuron.

### Question

What changes in a synapse during long-term potentiation by the NMDA and AMPA receptor mechanism?

### Options

- Extra AMPA receptors are inserted into the postsynaptic membrane, and the same signal causes a larger response.
- The synapse disappears and the neurons stop being connected.
- The neuron releases less glutamate, so the signal weakens.

### Answer

1

### Explanation

Strong joint activity opens NMDA receptors, and calcium entry triggers the insertion of new AMPA receptors. More receptors let more ions in for the same amount of glutamate, so the connection becomes stronger. A disappearing synapse and a weaker signal are the opposite processes, closer to LTD.

### Limits

One known LTP mechanism in the hippocampus is described; mechanisms of plasticity are diverse and not fully understood. The comparison with an artificial network is a teaching analogy: how memory, thought, and consciousness arise from changes in synapses is still unknown to science.

## Sources

- Mary Ann Clark, Matthew Douglas, Jung Choi, *Biology 2e*, OpenStax, 2018, section 35.2 “How Neurons Communicate”, subsection “Synaptic Plasticity” (consulted 2026-10-27): synapses that can be weakened or strengthened as the basis of learning and memory, LTP and LTD in the hippocampus, LTP as persistent strengthening based on the Hebbian principle, the NMDA receptor blocked by magnesium, calcium entry, insertion of AMPA receptors, and mechanisms not fully understood: [OpenStax Biology 2e, 35.2](https://openstax.org/books/biology-2e/pages/35-2-how-neurons-communicate)
- Ian Goodfellow, Yoshua Bengio, Aaron Courville, *Deep Learning*, MIT Press, 2016, chapter 6 “Deep Feedforward Networks” (consulted 2026-10-26): network layers computing h = g(Wx + b): [Deep Learning, chapter 6](https://www.deeplearningbook.org/contents/mlp.html)
- The lesson paraphrases these sources and does not copy their text; the OpenStax page states its own license terms: [OpenStax terms of use](https://openstax.org/terms-of-use)

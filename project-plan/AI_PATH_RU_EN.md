# Путь ИИ: от нуля до своей модели / The AI path: from zero to your own model

Дата: 2026-11-01. База: `integration/beta12-all` (b621d6e). Ветка: `feat/ai-path`. Основа: `COURSE_AUDIT_RU_EN.md`, карты математики и программирования, `research/math-missing-topics-ml-route-2026-10-26.md`.

## Финишная черта / Finish line

**Свой обученный языковой ИИ.** Ты сам пишешь маленький трансформер на чистом Python, с собственным вычислением градиентов и без готовых ИИ-библиотек и платных API, и сам обучаешь его на своём MacBook Air M1 на текстах курса. NumPy не нужен: он только ускорил бы те же вычисления. Черта пройдена, когда выполнено всё сразу:

1. ошибка на тексте, которого модель не видела, ниже, чем у случайного угадывания и у простого счётчика пар букв;
2. модель пишет новый текст, который на глаз похож на обучающий;
3. ты можешь объяснить каждую строку программы и то, чего эта модель не умеет.

Это не сознательный ИИ. Последний шаг пути честно отделяет то, что построено, от того, что наука о сознании пока не знает. Сознательный ИИ остаётся открытой исследовательской целью, а не пунктом этого курса.

*Finish line: a small transformer you write yourself in plain Python, with your own gradient code, no ready-made AI libraries or paid APIs, trained on your own MacBook Air M1 on the course texts. Done when its held-out error beats random guessing and a character-pair counter, it writes new text resembling its training data, and you can explain each line and what it cannot do. It is not a conscious AI, and the last step separates what was built from what the science of consciousness does not yet know.*

## Карта / Map

Статус: **есть** — можно идти как есть; **усилить** — урок есть, но в нём есть пробел; **создать** — урока нет. Важность: A — без этого нет финиша, B — нужно для понимания, C — дополняет.

| № | Шаг / Step | Статус / Status | Уроки / Lessons | Важность |
|---|---|---|---|---|
| 1 | Python / Python | есть | `variables_and_types`, `conditions_loops_functions`, `collections_and_loops`, `strings_files_and_exceptions`, `python_classes_and_composition` | — |
| 2 | Линейная алгебра / Linear algebra | есть | `vectors_and_matrices` | — |
| 3 | Производные и оптимизация / Derivatives, optimization | есть: рельеф ошибки добавлен в шаг 7 | `rates_of_change_and_derivative`, `gradient_and_partial_derivatives`, `gradient_descent_and_learning_rate` | A |
| 4 | Вероятность и статистика / Probability, statistics | есть | `descriptive_statistics_and_potential_outliers`, `probability_and_bayes`, `random_variables_and_sampling` | B |
| 5 | Теория информации и кросс-энтропия / Information theory, cross-entropy | есть | `information_and_cross_entropy` | A |
| 6 | Классификация / Classification | есть | `classification_and_softmax` | A |
| 7 | Скрытые слои и обратное распространение / Hidden layers, backpropagation | есть, с объёмной моделью сети | `neural_network_backpropagation`, `neural_network_hidden_layer_xor` | A |
| 8 | Практика обучения и переобучение / Training practice, overfitting | есть | `ml_baseline_and_holdout`, `minibatches_and_overfitting` | B |
| 9 | Эмбеддинги / Embeddings | есть | `embeddings_and_similarity` | A |
| 10 | Внимание и трансформер / Attention, transformer | есть | `attention_mechanism`, `transformer_block` | A |
| 11 | Финальный проект / Final project | есть: своя модель, обученная и проверенная на этом Mac | `build_your_language_model` | A |
| 12 | Что наука знает о сознании / What science knows about consciousness | есть | `consciousness_known_and_unknown` | B |

Итого: 12 шагов и 23 урока, все написаны. Десять уроков создано в этой работе, ещё 13 уже были в курсе.

## Как это устроено / How it is built

Экран пути: `App/AIPath.swift`, пункт «Путь ИИ» в боковой панели. Готовые уроки открываются сразу, без ожидания предыдущих. Программа финального проекта лежит в `01_Projects/tiny_language_model.py`, её настоящие веса и журнал обучения в `02_Areas/Programming/resources`. Общие детали 3D-сцен: `App/ErrorLandscape3DView.swift` и `App/NeuronRelief3DView.swift`.

Не входит в этот путь по решению владельца: биология, физика, химия, зоология, английский.

## English summary

Twelve steps from Python to a self-trained language model, then an honest lesson on consciousness. All 23 lessons are written, ten of them in this work: probability (two), information theory and cross-entropy, classification, mini-batches and overfitting, embeddings, attention, the transformer block, the final project, and consciousness. The path is one visible, open screen in the app.

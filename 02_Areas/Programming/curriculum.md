# Дорожная карта: программирование / Programming roadmap

> Статус: карта тем для программирования в целом с текущим практическим треком на Python/backend. Уроки должны запускать примеры в безопасной изоляции и учить читать ошибки, а не только копировать код.

## База / Foundations

| Модуль / Module | Результат обучения / Learning outcome | Урок / Lesson |
|---|---|---|
| Алгоритмическое мышление и псевдокод / Computational thinking and pseudocode | Разбивать задачу на шаги, примеры, крайние случаи и критерии правильности. / Decompose tasks into steps, cases, and correctness criteria. | lesson:computational_thinking |
| Переменные, типы, выражения, ввод и вывод / Variables, types, expressions, input/output | Объяснять состояние программы и предсказывать результат простого кода. / Track program state and predict simple execution. | lesson:variables_and_types |
| Условия, циклы и функции / Conditionals, loops, functions | Выбирать управляющую конструкцию, разбивать логику на именованные функции и проверять крайние случаи. / Structure logic and test edge cases. | lesson:conditions_loops_functions |
| Коллекции, индексы и обход последовательностей / Collections, indexes, and iteration | Изменять упорядоченный список и предсказывать обход значений или пар «индекс — значение». / Mutate an ordered list and predict value-only or index–value iteration. | lesson:collections_and_loops
| Строки, файлы и исключения / Strings, files, and exceptions | Преобразовывать данные, безопасно читать текст и обрабатывать ожидаемые ошибки ввода и доступа. / Transform data, read text safely, and handle expected input and access failures. | lesson:strings_files_and_exceptions |
| Отладка, тесты и Git / Debugging, tests, version control | Воспроизводить дефект, читать stack trace, писать проверку и фиксировать изменение в Git. / Reproduce a bug, inspect traces, test, and track changes. | lesson:debugging_tests_and_git |

## Углубление / Intermediate

| Модуль / Module | Результат обучения / Learning outcome | Урок / Lesson |
|---|---|---|
| Структуры данных и сложность / Data structures and complexity | Выбирать структуру данных по операциям и объяснять компромисс времени и памяти. / Choose data structures and explain time-space tradeoffs. | lesson:search_and_complexity |
| Объектная модель, композиция и типизация / Object model, composition, typing | Проектировать небольшие модули с ясными границами, типами и ответственностью. / Design small modules with clear interfaces and responsibilities. | lesson:python_classes_and_composition |
| SQL и транзакции / SQL and transactions | Проектировать таблицы, запросы, индексы и транзакции с учётом целостности. / Build relational schemas and queries with integrity. | lesson:sql_transactions |
| HTTP, API и backend-приложение / HTTP, APIs, backend services | Строить и документировать API, понимать статусы, валидацию и ошибки сети. / Implement and document APIs with validation and failure handling. | lesson:http_and_apis |
| Зависимости, упаковка и конфигурация / Dependencies, packaging, configuration | Создавать воспроизводимую среду, управлять версиями и безопасно конфигурировать приложение. / Create reproducible environments and safe configuration. | lesson:virtual_environments_and_dependencies |
| Машинное обучение: baseline и отложенная проверка / Machine learning: baselines and held-out evaluation | Оценивать модель на данных, которых она не видела, сравнивать её с простым baseline и распознавать переобучение. / Evaluate a model on unseen data, compare it with a simple baseline, and recognize overfitting. | lesson:ml_baseline_and_holdout |
| Градиентный спуск и шаг обучения / Gradient descent and the learning rate | Объяснять, как градиентный спуск уменьшает ошибку, и выбирать шаг обучения, при котором обучение сходится. / Explain how gradient descent lowers the error and choose a learning rate that converges. | lesson:gradient_descent_and_learning_rate |

## Продвинутый уровень / Advanced

| Модуль / Module | Результат обучения / Learning outcome | Урок / Lesson |
|---|---|---|
| Конкурентность, асинхронность и очереди / Concurrency, async, queues | Выявлять гонки и блокировки и выбирать модель параллелизма под задачу. / Detect races and choose an appropriate concurrency model. | lesson:concurrency_async_await |
| Безопасность приложений / Application security | Моделировать угрозы, валидировать границы доверия и защищать секреты и данные. / Threat-model trust boundaries and protect secrets and data. | lesson:application_security_injection_and_secrets |
| Архитектура, наблюдаемость и производительность / Architecture, observability, performance | Измерять узкие места, строить логи и метрики и менять архитектуру только по данным. / Measure bottlenecks and instrument systems before redesign. | lesson:logging_and_measuring_performance |
| Распределённые системы и отказоустойчивость / Distributed systems and resilience | Анализировать повторы, таймауты, согласованность, идемпотентность и частичные сбои. / Reason about retries, timeouts, consistency, idempotency, and partial failure. | lesson:retries_and_idempotency |
| Компиляторы, протоколы и специализации / Compilers, protocols, specializations | Выбирать углублённую ветку и строить проект, где можно проверить каждый слой. / Pursue a focused specialization through a verifiable project. | lesson:parsing_and_abstract_syntax_trees |
| Классификация и softmax / Classification and softmax | Превращать оценки в вероятности через softmax, выводить градиент кросс-энтропии и писать классификатор, который сам учится выбирать один класс из нескольких. / Turn scores into probabilities with softmax, derive the gradient of cross-entropy, and write a classifier that learns to choose one class among several. | lesson:classification_and_softmax |
| Нейронные сети: обучение и обратное распространение / Neural networks: training and backpropagation | Писать обучаемый нейрон, считать градиент ошибки по правилу цепочки и обновлять веса градиентным спуском, понимая ограничения обучения на малых данных. / Write a trainable neuron, compute the error gradient with the chain rule, and update weights by gradient descent, understanding the limits of learning from small data. | lesson:neural_network_backpropagation |
| Скрытый слой: сеть учит XOR / The hidden layer: a network learns XOR | Доказывать, что один нейрон не выучит XOR, обучать сеть со скрытым слоем обратным распространением и видеть, какое представление она строит. / Prove that one neuron cannot learn XOR, train a hidden-layer network with backpropagation, and see the representation it builds. | lesson:neural_network_hidden_layer_xor |
| Эмбеддинги и сходство / Embeddings and similarity | Превращать слова и символы в векторы, считать косинусное сходство и обучать модель, которая сама располагает похожие слова рядом. / Turn words and characters into vectors, compute cosine similarity, and train a model that places similar words close together by itself. | lesson:embeddings_and_similarity |
| Механизм внимания / The attention mechanism | Считать внимание через запросы, ключи и значения, объяснять деление на √d, маску будущего и номера мест, и обучать модель, которая сама находит, куда смотреть. / Compute attention with queries, keys, and values, explain division by √d, the mask over the future, and place numbers, and train a model that finds by itself where to look. | lesson:attention_mechanism |
| Блок трансформера / The transformer block | Собирать блок из многоголового внимания, сети прямого прохода, обходных путей и нормализации, проверять маску и объяснять, почему обходы сохраняют сигнал ошибки. / Assemble a block from multi-head attention, a feed-forward network, bypass paths, and normalization, check the mask, and explain why bypasses preserve the error signal. | lesson:transformer_block |
| Мини-батчи и переобучение / Mini-batches and overfitting | Обучать на пакетах и считать цену в прочитанных примерах, узнавать переобучение по двум кривым и останавливать его ранней остановкой и ослаблением весов. / Train on batches and count the price in examples read, recognize overfitting from two curves, and stop it with early stopping and weight decay. | lesson:minibatches_and_overfitting |
| Сознание: что известно и что нет / Consciousness: what is known and what is not | Различать доступ и переживание, называть главные теории, объяснять, почему нет общепризнанного теста, и честно применять индикаторы к своей модели. / Tell access from experience, name the main theories, explain why there is no accepted test, and honestly apply indicators to your own model. | lesson:consciousness_known_and_unknown |

## Форматы практики / Practice formats

- Безопасный исполняемый тренажёр с ограничением времени, памяти и доступа к файлам/сети.
- Пошаговый debugger: предсказание состояния, запуск шага, объяснение изменения.
- Проекты, где ученик пишет тесты, исправляет дефект и объясняет компромисс решения.

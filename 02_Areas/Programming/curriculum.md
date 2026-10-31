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
| Архитектура, наблюдаемость и производительность / Architecture, observability, performance | Измерять узкие места, строить логи и метрики и менять архитектуру только по данным. / Measure bottlenecks and instrument systems before redesign. | |
| Распределённые системы и отказоустойчивость / Distributed systems and resilience | Анализировать повторы, таймауты, согласованность, идемпотентность и частичные сбои. / Reason about retries, timeouts, consistency, idempotency, and partial failure. | |
| Компиляторы, протоколы и специализации / Compilers, protocols, specializations | Выбирать углублённую ветку и строить проект, где можно проверить каждый слой. / Pursue a focused specialization through a verifiable project. | |
| Нейронные сети: обучение и обратное распространение / Neural networks: training and backpropagation | Писать обучаемый нейрон, считать градиент ошибки по правилу цепочки и обновлять веса градиентным спуском, понимая ограничения обучения на малых данных. / Write a trainable neuron, compute the error gradient with the chain rule, and update weights by gradient descent, understanding the limits of learning from small data. | lesson:neural_network_backpropagation |

## Форматы практики / Practice formats

- Безопасный исполняемый тренажёр с ограничением времени, памяти и доступа к файлам/сети.
- Пошаговый debugger: предсказание состояния, запуск шага, объяснение изменения.
- Проекты, где ученик пишет тесты, исправляет дефект и объясняет компромисс решения.

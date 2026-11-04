# ColiDev 0.1.0 Beta 19 — заметки к выпуску / Release notes

**Опубликовано 2026-11-03: [v0.1.0-beta.19](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.19), выпуск из `a0126c9` (Merge PR #17), дерево которого совпадает с проверенным `e1e3241`; CI [41629757772](https://github.com/weekendbuildings/coli-dev/actions/runs/41629757772) зелёный на macOS 15 и 26 Apple Silicon. Только для Apple Silicon. / Published 2026-11-03 from `a0126c9` (Merge PR #17), whose tree matches the tested `e1e3241`; Apple Silicon only.**

## Русский

**Главное.** «Путь ИИ» стал намного глубже: пять этапов от первого запуска модели до вопроса о сознании. Было 23 урока, новых 35, всего 58 из 69 по карте. Оставшиеся 11 уроков менее важны и ещё не написаны.

**Новые уроки:**
- **Этап 1, старт руками:** живая модель на твоём Mac, из чего сделан чат, ошибки модели, как просить.
- **Этап 2, создание:** свой механизм градиентов и токенизатор, инициализация, оптимизаторы с объёмной долиной, доктор обучения.
- **Этап 3, улучшение:** автоматы, уравнение Беллмана, Q-обучение, REINFORCE, дообучение и LoRA, RLHF, оценка, зонды, суперпозиция, рассуждение, RAG, агенты, безопасность.
- **Этап 4, путь к AGI:** определения интеллекта, ARC, модели мира, забывание, спор о масштабировании.
- **Этап 5, сознание:** трудная проблема, глобальное рабочее пространство, теория интегрированной информации, теории высшего порядка и предсказания, эксперименты, список индикаторов, языковые модели, моральный статус.

**Честная граница.** Общепризнанного пути к сознательному ИИ нет, как и общепризнанного теста. Этап 5 учит тому, что известно, что спорно и какие исследования реально можно делать.

**Что не проверено:**
- Человек новые уроки ещё не проходил.
- Тренажёры этапов 4 и 5 на снимках почти все в начальном состоянии: экран был заблокирован. Логику их моделей проверяют скрипты, а показ во время работы не проверен, особенно в `MaskingLab`, `ArcPainterLab`, `ForgettingLab` и `IntegrationLab`.
- В этапе 3 не все жесты нажимались руками: например, щелчок по стене в `QMazeLab`, тумблер штрафа в `PreferenceLab` и перетаскивание прямой в `ProbeLab`.
- Утверждения с пометкой `recalled` в разделе источников написаны по памяти, а источник прочитан в лучшем случае до заголовка. Их ещё надо сверить.
- Записи работы моделей сделаны один раз на этом Mac с локальными моделями и подписаны как записи.
- Новых UI-тестов нет, для новых тренажёров их тоже нет.

**Как проверялось:** Python-тесты в CI; те же 56 UI-тестов на macOS 15 и 26 Apple Silicon; скрипты `verify_*` проверяют логику моделей новых тренажёров.

**Установка одной командой (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.19/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** The AI Path is much deeper now: five stages from the first run of a model to the question of consciousness. There were 23 lessons and 35 are new, 58 of the 69 on the map. The remaining 11 lessons are less important and not written yet.

**New lessons:**
- **Stage 1, hands on first:** a live model on your Mac, what a chat is made of, model errors, how to ask.
- **Stage 2, building:** your own gradient engine and tokenizer, initialization, optimizers in a 3D valley, the training doctor.
- **Stage 3, improving:** bandits, the Bellman equation, Q-learning, REINFORCE, fine-tuning and LoRA, RLHF, evaluation, probes, superposition, reasoning, RAG, agents, safety.
- **Stage 4, the road to AGI:** definitions of intelligence, ARC, world models, forgetting, the scaling debate.
- **Stage 5, consciousness:** the hard problem, the global workspace, integrated information theory, higher-order and predictive theories, experiments, the indicator checklist, language models, moral status.

**An honest limit.** There is no generally accepted path to conscious AI, and no generally accepted test. Stage 5 teaches what is known, what is disputed, and what research can really be done.

**Not checked:**
- No person has gone through the new lessons yet.
- Nearly all stage 4 and 5 lab screenshots show the starting state, because the screen was locked. Scripts check the logic of their models, but how they look while running is unchecked, above all `MaskingLab`, `ArcPainterLab`, `ForgettingLab`, and `IntegrationLab`.
- Not every stage 3 gesture was tried by hand: for example, clicking a wall in `QMazeLab`, the penalty toggle in `PreferenceLab`, and dragging the line in `ProbeLab`.
- Claims marked `recalled` in the sources section were written from memory, with at most the source's title read. They still need checking.
- The model recordings were made once on this Mac with local models and are labelled as recordings.
- There are no new UI tests, so the new labs have none.

**How it was checked:** Python tests in CI; the same 56 UI tests on macOS 15 and 26 Apple Silicon; `verify_*` scripts check the logic of the new labs' models.

**One-command install (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.19/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.

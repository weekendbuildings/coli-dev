# ColiDev 0.1.0 Beta 18 — заметки к выпуску / Release notes

**Опубликовано 2026-11-02: [v0.1.0-beta.18](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.18), выпуск из `a6c66cc` (Merge PR #16), дерево которого совпадает с проверенным `4b4a74e`; CI [41434891535](https://github.com/weekendbuildings/coli-dev/actions/runs/41434891535) зелёный на macOS 15 и 26 Apple Silicon. Только для Apple Silicon. / Published 2026-11-02 from `a6c66cc` (Merge PR #16), whose tree matches the tested `4b4a74e`; Apple Silicon only.**

## Русский

**Главное.** В приложении появился «Путь ИИ»: один экран с дорогой от Python до своей обученной языковой модели. Готовые уроки пути открываются сразу, без ожидания предыдущих.

**Путь ИИ:**
- 12 шагов и 23 урока. 10 уроков новые: вероятность и формула Байеса, случайные величины и выборка, информация и кросс-энтропия, классификация и softmax, мини-батчи и переобучение, эмбеддинги, механизм внимания, блок трансформера, финальный проект и урок о том, что наука знает о сознании.
- Ещё один новый урок идёт перед ними: сеть со скрытым слоем учит XOR.
- Финальный проект: маленький трансформер на чистом Python, без готовых ИИ-библиотек и платных API. В приложении лежат настоящие веса, обученные на MacBook Air M1 за 47 минут. На незнакомом тексте ошибка 2,218, у счётчика пар букв 2,651, у случайного угадывания 4,97.
- Честная граница: текст модели по форме похож на обучающий, но смысла в нём нет. Это не сознательный ИИ, и урок о сознании отделяет то, что построено, от того, что наука пока не знает.

**Объёмные 3D-модели, которые можно крутить мышью:** рельеф ошибки и сеть с сигналами, чаша кросс-энтропии, рельеф уверенности softmax, рельеф мини-батчей, город из 1000 кубиков для Байеса, доска Гальтона, пространство слов, башни внимания, башня слоёв трансформера и внимание в финальной модели. Высота и форма в них показывают настоящие величины из модели.

**Новый наглядный стиль в 38 тренажёрах:** биология, физика, математика, программирование, зоология и химия. Графики с осями, управление мышью, крупные показатели, задание с ✓ и свёрнутые пояснения.

**Исправления в содержании:**
- Осмос: в тренажёре вода шла не в ту сторону, теперь она идёт в сторону большей концентрации растворённых веществ, как и сказано в уроке.
- Проверка содержания курса: прочитаны 20 уроков, исправлено 11 неточностей.

**Как проверялось:** Python-тесты (921); 56 UI-тестов на macOS 15 и 26 Apple Silicon; модели проверяются в CI.

**Установка одной командой (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.18/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** The app now has an AI Path: one screen with a road from Python to your own trained language model. The path's finished lessons open straight away, without waiting for the earlier ones.

**The AI Path:**
- 12 steps and 23 lessons. Ten lessons are new: probability and Bayes' rule, random variables and sampling, information and cross-entropy, classification and softmax, mini-batches and overfitting, embeddings, the attention mechanism, the transformer block, the final project, and a lesson on what science knows about consciousness.
- One more new lesson comes before them: a network with a hidden layer learns XOR.
- The final project: a small transformer in plain Python, with no ready-made AI libraries or paid APIs. The app ships the real weights, trained on a MacBook Air M1 in 47 minutes. On unseen text the error is 2.218, against 2.651 for a character-pair counter and 4.97 for random guessing.
- An honest limit: the model's text resembles its training data in form but has no meaning. It is not a conscious AI, and the consciousness lesson separates what was built from what science does not yet know.

**Solid 3D models you can rotate with the mouse:** the error terrain and the network with signals, the cross-entropy bowl, the softmax confidence relief, the mini-batch relief, a town of 1000 cubes for Bayes, a Galton board, a space of words, attention towers, the transformer's tower of layers, and attention in the final model. Their height and shape show real quantities from the model.

**The new visual style reaches 38 more labs:** biology, physics, mathematics, programming, zoology, and chemistry. Charts with axes, mouse control, large readouts, a goal with ✓, and folded explanations.

**Content fixes:**
- Osmosis: the lab moved water the wrong way. It now moves toward the higher solute concentration, as the lesson says.
- A course content review read 20 lessons and fixed 11 inaccuracies.

**How it was checked:** Python tests (921); 56 UI tests on macOS 15 and 26 Apple Silicon; models are verified in CI.

**One-command install (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.18/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.

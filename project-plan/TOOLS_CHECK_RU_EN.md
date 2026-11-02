# Проверка инструментов на настоящем Mac / Tools check on a real Mac

Дата: 2026-11-02. Версия: Beta 18, сборка 20261102855, установлена из выпуска на MacBook Air M1. Платных ИИ-вызовов не было.

*Date: 2026-11-02. Version: Beta 18, build 20261102855, installed from the release on a MacBook Air M1. No paid AI calls were made.*

## Итог / Result

| Инструмент / Tool | Результат / Result | Как проверено / How it was checked | Что не проверено / Not checked |
|---|---|---|---|
| Установка / Install | работает / works | SHA-256 архива совпал, приложение запустилось, проверка встроенного backend прошла / archive SHA-256 matched, the app launched, the bundled backend check passed | macOS 13 и 14 / macOS 13 and 14 |
| Прогресс / Progress | работает / works | Записи о пройденных уроках на месте после замены Beta 17 на Beta 18; сохранение после перезапуска проверяет CI / completed lessons survived replacing Beta 17 with Beta 18; CI checks persistence after relaunch | — |
| Тьютор, локальный маршрут / Tutor, local route | работает, с ошибкой в детали / works, with a wrong detail | Настоящий вопрос через `qwen3.5`, ответ за 65 с, поиск нашёл новый урок о кросс-энтропии / a real question through `qwen3.5`, answered in 65 s, retrieval found the new cross-entropy lesson | Модель назвала `CrossEntropyLoss` функцией активации, а это функция потерь: ответы локальной модели надо сверять с уроком / the model called `CrossEntropyLoss` an activation function, but it is a loss function: check local answers against the lesson |
| Видео / Video | работает / works | Тот же адрес и Referer, что в приложении: без звука проиграно 17,7 с за 18 с, есть субтитры ru и en, выбраны ru / the app's URL and Referer: 17.7 s played in 18 s, muted, with ru and en captions and ru selected | Показ текста субтитров на экране и запуск настоящим щелчком / captions text on screen and starting with a real click |
| Obsidian | соединение есть, запись ждёт ключа / connected, writing needs the key | Плагин Local REST API 4.1.7 отвечает на порту 27123, который приложение пробует первым; без ключа запрос к хранилищу получает 401 / the plugin answers on port 27123, the app's first choice; a vault request without the key gets 401 | Сохранение урока и хранение ключа в Keychain: ключ вводит владелец / saving a lesson and keeping the key in Keychain: the owner enters the key |
| NotebookLM | копирование работает / copying works | UI-тест в CI проверяет, что Markdown урока попадает в буфер обмена / a CI UI test checks that the lesson Markdown reaches the clipboard | Импорт в NotebookLM: нужен аккаунт Google владельца / the import needs the owner's Google account |
| OpenCode, Hermes, OpenClaw | не установлены / not installed | Автоматическая проверка прав запрещает агенту ставить сторонний код / the automatic permission check stops the agent installing third-party code | Всё: устанавливает владелец, в приложение они не встраиваются / everything: the owner installs them, and they are not built into the app |

## Смотреть глазами / Check by eye

Тесты прошли, но глазами не смотрели: живой тренажёр обученной модели и вращение 3D-моделей мышью в установленной версии.

*Tests passed, but nobody has looked at these by eye: the trained model's live lab and rotating the 3D models with the mouse in the installed version.*

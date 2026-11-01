# ColiDev

**A native macOS learning platform with bilingual courses, interactive practice, and an AI tutor.**<br>
**Нативная учебная платформа для macOS с двуязычными курсами, интерактивной практикой и ИИ-тьютором.**

ColiDev combines structured courses, saved learning progress, subject-specific exercises, local course search, and configurable AI routes in one SwiftUI app with a local Python service.<br>
ColiDev объединяет последовательные курсы, сохранение учебного прогресса, упражнения по предметам, локальный поиск по материалам и настраиваемые маршруты ИИ в одном приложении SwiftUI с локальным сервером на Python.

**Project status: early team prototype.** The app is not a finished, signed, or bug-free release. Feature status and known limits are described below and in the project plan.<br>
**Статус проекта: ранний командный прототип.** Приложение ещё не является готовым, подписанным или полностью проверенным релизом. Статус функций и известные ограничения описаны ниже и в плане проекта.

## Текущее состояние / Current status

**RU — Beta 13, 2026-10-31.** [Beta 13](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.13) собрана из `f55b211` (PR #9), CI [41247367541](https://github.com/weekendbuildings/coli-dev/actions/runs/41247367541) зелёный на macOS 15 и 26 Apple Silicon и macOS 15 Intel. Курс — 106 уроков вместо 64, новый предмет «Химия», восемь новых тренажёров, исправления после проверки Beta 12. Обновления ищутся в `weekendbuildings/coli-dev`: Beta 12 после переноса репозитория не видит новых выпусков, поэтому Beta 13 ставится вручную командой ниже. Проверено на MacBook Air M1 (macOS 27.0.1): установка из выпуска, запуск, backend, в настройках виден список выпусков. Подробно — [заметки к выпуску](project-plan/RELEASE_NOTES_BETA13_RU_EN.md).<br>
**EN — Beta 13, 2026-10-31.** [Beta 13](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.13) is built from `f55b211` (PR #9), CI [41247367541](https://github.com/weekendbuildings/coli-dev/actions/runs/41247367541) green on macOS 15 and 26 Apple Silicon and macOS 15 Intel. The course has 106 lessons instead of 64, a new Chemistry subject, eight new labs, and fixes from the Beta 12 check. Updates come from `weekendbuildings/coli-dev`: after the repository move Beta 12 cannot see new releases, so install Beta 13 manually with the command below. Checked on a MacBook Air M1 (macOS 27.0.1): install from the release, launch, backend, and the release list in Settings. Details: [release notes](project-plan/RELEASE_NOTES_BETA13_RU_EN.md).<br>
**RU/EN — одной командой / one command:** `A=$([ "$(uname -m)" = arm64 ] && echo AppleSilicon || echo Intel); curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.13/ColiDev-beta-$A.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app`

**RU — Beta 12, 2026-10-25.** Beta 9, 10 и 11 на Mac закрывались сразу при запуске: «Library not loaded: @rpath/Sparkle.framework … no LC_RPATH's found». Встроенная библиотека Sparkle была внутри приложения, но в бинарнике не было пути поиска `@executable_path/../Frameworks`. Исправлено в PR #7. [Beta 12](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.12) собрана из `8cbd10b`; полный [CI run 40204278523](https://github.com/weekendbuildings/coli-dev/actions/runs/40204278523) добавил проверку запуска вне Xcode, и на macOS 15 и 26 Apple Silicon и macOS 15 Intel приложение запустилось. Используйте Beta 12 вместо Beta 9–11. На физическом Mac владельца (MacBook Air M1, macOS 27.0.1) Beta 12 ещё не проверена; macOS 27 в CI не входит.<br>
**EN — Beta 12, 2026-10-25.** Betas 9, 10, and 11 quit immediately at launch on a Mac: “Library not loaded: @rpath/Sparkle.framework … no LC_RPATH's found”. The embedded Sparkle library was inside the app, but the binary lacked the `@executable_path/../Frameworks` runpath. PR #7 fixed it. [Beta 12](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.12) is built from `8cbd10b`; full [CI run 40204278523](https://github.com/weekendbuildings/coli-dev/actions/runs/40204278523) added a launch check outside Xcode, and the app launched on macOS 15 and 26 Apple Silicon and macOS 15 Intel. Use Beta 12 instead of Betas 9–11. It has not been checked on the owner's physical Mac (MacBook Air M1, macOS 27.0.1) yet, and macOS 27 is not in CI.<br>

**RU — главная фаза, 2026-10-24.** PR #6 заполнил базовый уровень во всех шести предметах (40 из 40 тем), дал этапам «ML» и «Мозг» по два урока в приложении, убрал чужой тренажёр из урока о газообмене и добавил в настройки «Просмотр закрытых уроков». Полный [CI run 40092754956](https://github.com/weekendbuildings/coli-dev/actions/runs/40092754956) прошёл на commit `c46662b`: backend (651 тестов), сборка и 21 UI-тестов на каждой из трёх Mac-сборок, проверка 64 уроков и упаковка. Главная ручная проверка на Mac — на Beta 12 по списку из [отчёта о готовности](project-plan/PROTOTYPE_READINESS_RU_EN.md).<br>
**EN — main phase, 2026-10-24.** PR #6 filled the foundations level in all six subjects (40 of 40 topics), gave the ML and brain stages two in-app lessons each, removed the unrelated lab from the gas exchange lesson, and added “Preview locked lessons” to Settings. Full [CI run 40092754956](https://github.com/weekendbuildings/coli-dev/actions/runs/40092754956) passed at commit `c46662b`: backend (651 tests), build and 21 UI tests on each of the three Mac builds, the 64-lesson route audit, and packaging. The main hands-on Mac check runs on Beta 12 using the list in the [readiness report](project-plan/PROTOTYPE_READINESS_RU_EN.md).<br>

**RU — срез 2026-10-24.** Репозиторий перенесён в [`weekendbuildings/coli-dev`](https://github.com/weekendbuildings/coli-dev) и сейчас публичный; старые ссылки на `invinby/coli-dev` GitHub перенаправляет, но в документах указан новый адрес. Работа PR #5 проверена полным [CI run 40080345229](https://github.com/weekendbuildings/coli-dev/actions/runs/40080345229) на commit `e04be9f`: backend (628 тестов) и сборка, UI-тесты, встроенный backend и упаковка для macOS 15 Apple Silicon, macOS 26 Apple Silicon и macOS 15 Intel. Красный CI 22–23 октября был вызван тремя причинами: GitHub не запускал задачи из-за оплаты Actions, каталог обновлений отбрасывал релизы после смены владельца, а новый UI-тест каталога зависел от живого GitHub API и не мог раскрыть строку версии. Все три исправлены. Это проверка на CI-runner'ах, а не на Mac пользователя.<br>
**EN — snapshot of 2026-10-24.** The repository moved to [`weekendbuildings/coli-dev`](https://github.com/weekendbuildings/coli-dev) and is currently public; GitHub redirects old `invinby/coli-dev` links, but the documents use the new address. PR #5 was verified by full [CI run 40080345229](https://github.com/weekendbuildings/coli-dev/actions/runs/40080345229) at commit `e04be9f`: backend (628 tests) plus build, UI tests, bundled backend, and packaging for macOS 15 Apple Silicon, macOS 26 Apple Silicon, and macOS 15 Intel. The red CI of 22–23 October had three causes: GitHub did not start jobs because of an Actions billing failure, the update catalogue rejected releases after the owner change, and the new catalogue UI test depended on the live GitHub API and could not expand a release row. All three are fixed. This is evidence from CI runners, not from the user's Mac.<br>

**Поддерживаемые Mac / Supported Macs:** **RU:** Intel `x86_64` и Apple Silicon `arm64` (M1 и новее); для каждой архитектуры собирается свой архив. Минимальная версия в проекте — macOS 13, но CI запускается только на macOS 15 и 26, поэтому macOS 13 и 14 не проверены. **EN:** Intel `x86_64` and Apple Silicon `arm64` (M1 and later), with a separate archive for each architecture. The deployment target is macOS 13, but CI runs only macOS 15 and 26, so macOS 13 and 14 are unverified.<br>

**Тестовые сборки / Test builds:** **RU:** Последняя тестовая сборка — [ColiDev 0.1.0 Beta 12](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.12) из commit `8cbd10b`, проверенного CI run 40204278523: [Apple Silicon](https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.12/ColiDev-beta-AppleSilicon.zip) для M1–M4 и [Intel](https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.12/ColiDev-beta-Intel.zip). Beta 9–11 падали при запуске — не используйте их. Вход в GitHub для скачивания не нужен. Архивы не подписаны Developer ID и не нотарифицированы, поэтому macOS предупреждает при первом запуске; на физическом Mac Beta 12 ещё не проверялась. Что проверить руками, описано в [отчёте о готовности](project-plan/PROTOTYPE_READINESS_RU_EN.md). **EN:** The latest test build is [ColiDev 0.1.0 Beta 12](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.12) from commit `8cbd10b`, verified by CI run 40204278523: [Apple Silicon](https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.12/ColiDev-beta-AppleSilicon.zip) for M1–M4 and [Intel](https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.12/ColiDev-beta-Intel.zip). Betas 9–11 crashed at launch; do not use them. Downloading needs no GitHub sign-in. Archives are not Developer ID signed or notarized, so macOS warns on first launch; Beta 12 has not been checked on a physical Mac yet. The hands-on checks are listed in the [readiness report](project-plan/PROTOTYPE_READINESS_RU_EN.md).<br>

**Обновления / Updates:** **RU:** В Settings есть двуязычный каталог опубликованных версий: заголовок версии раскрывает строку со ссылкой на архив для архитектуры этого Mac. Автоустановка через Sparkle отключена, пока нет EdDSA public key, подписанного appcast, подписи Developer ID и нотарификации. **EN:** Settings includes a bilingual catalogue of published versions: a version title expands its row with a link to the archive for this Mac's architecture. Sparkle auto-install stays disabled until there is an EdDSA public key, a signed appcast, Developer ID signing, and notarization.

## Previous verified code build / Предыдущая проверенная сборка кода

**Historical CI / Исторический CI:** GitHub Actions run [38169754953](https://github.com/weekendbuildings/coli-dev/actions/runs/38169754953) passed for code commit `fcc772d`: 506 backend tests, Swift verifiers, app/backend packaging and smoke checks, and curriculum checks on macOS 15 ARM, macOS 26 ARM, and macOS 26 Intel. All 53 curriculum routes resolved. The statistics lab explains a prediction using the current maximum and upper fence, lets the learner reveal an explanation or retry, clears stale feedback after changes, and records attempts. That old Intel archive is obsolete; use a new artifact from the current architecture-specific CI matrix. / **Исторический CI:** GitHub Actions [38169754953](https://github.com/weekendbuildings/coli-dev/actions/runs/38169754953) прошёл для коммита `fcc772d`: 506 backend-тестов, Swift-проверки, упаковка app/backend и smoke-проверки, проверка ресурсов на macOS 15 ARM, macOS 26 ARM и macOS 26 Intel. Разрешились все 53 маршрута курса. Тренажёр статистики объясняет прогноз через текущий максимум и верхнюю границу, даёт открыть разбор или повторить попытку, очищает устаревшую обратную связь после изменения параметров и сохраняет попытки. Старый Intel-архив устарел; используй новый артефакт из актуального CI с проверками обеих архитектур.<br>

These CI artifacts are unsigned test builds, not a published release. CI verifies compilation and bundled-backend smoke checks; running the app and checking its real UI and model routes on a Mac still requires hands-on acceptance.<br>
Эти тестовые архивы CI не подписаны и не являются опубликованным релизом. CI проверяет компиляцию и запуск встроенного сервера, но само приложение, его интерфейс и реальные ответы моделей всё ещё нужно вручную проверить на Mac.

<a id="project-profile"></a>
## Профиль проекта / Project profile

**Кратко:** ColiDev — нативная учебная платформа для macOS, которая помогает изучать предметы от основ до углублённого и подходящего научного уровня с помощью курсов, предметной практики, визуальных объяснений и проверяемых рекомендаций.<br>
**In brief:** ColiDev is a native macOS learning platform that helps learners move from foundations toward advanced and, where suitable, scientific study through courses, subject-specific practice, visual explanations, and evidence-based recommendations.

### Предметы и языки / Subjects and languages

**RU:** Стартовый набор включает математику, английский язык, физику, биологию, зоологию и программирование. Биология уже является встроенным предметом. Ученик также может создавать собственные предметы, темы и подтемы или добавлять темы в существующие предметы. Интерфейс и учебные материалы поддерживают русский и английский языки.<br>
**EN:** The starting set includes mathematics, English, physics, biology, zoology, and programming. Biology is already a built-in subject. Learners can also create subjects, topics, and subtopics or add topics to existing subjects. The interface and learning materials support Russian and English.

### Как устроено обучение / How learning works

**RU:** Приложение должно вести от базовых понятий к самостоятельному применению, новым задачам, глубокому пониманию механизмов и ограничений, а затем — к продвинутой и уместной научной работе. Уроки сочетают теорию, примеры, практику, разбор ошибок, проверку понимания и следующий шаг. Порядок и метод меняются под предмет и уровень ученика — единого шаблона для всех дисциплин нет.<br>
**EN:** The app should guide learners from foundational concepts to independent application, unfamiliar problems, deep understanding of mechanisms and limits, and then to advanced and appropriate scientific work. Lessons combine theory, examples, practice, error feedback, checks for understanding, and a next step. The sequence and method adapt to the subject and learner; there is no single template for every discipline.

### Персональный маршрут и прогресс / Adaptive path and progress

**RU:** Система должна учитывать предпосылки, ответы, повторяющиеся ошибки, практику и историю повторения, чтобы выбрать полезный следующий шаг. Самооценка помогает решить, что проверить, но сама по себе не доказывает освоение. В прототипе уже есть ограниченные рекомендации по предпосылкам; полная модель освоения, широкая входная диагностика и оценка переноса знаний ещё разрабатываются. Прогресс прохождения курса нужно показывать отдельно от подтверждённого понимания.<br>
**EN:** The system should use prerequisites, answers, recurring errors, practice, and review history to select a useful next step. Self-ratings can help decide what to check, but they do not prove mastery by themselves. The prototype has limited prerequisite-based recommendations; a complete mastery model, broad placement diagnostics, and transfer-of-learning assessment are still being developed. Course completion should be shown separately from demonstrated understanding.

### Наглядность и практика / Visual learning and practice

**RU:** Для каждой темы подбирается подходящий формат: график, схема, опыт, симуляция, видео с вопросами или управляемая 3D-модель. 3D используется там, где вращение, приближение или разбор частей помогает понять тему. Управление, допущения и ограничения визуализации должны быть видны. В готовности курса нельзя показывать незавершённые тренажёры как рабочие.<br>
**EN:** Choose a suitable format for each topic: a graph, diagram, experiment, simulation, video with questions, or a manipulable 3D model. Use 3D when rotating, zooming, or examining parts helps explain the concept. Make controls, assumptions, and visualization limits clear. Course status must not present unfinished activities as working ones.

### ИИ, источники и центр управления / AI, sources, and Control Center

**RU:** Автопроверка источников запрашивает только новые и уже просроченные ссылки: обычные — примерно раз в сутки, временно недоступные — повторно через шесть часов. Один сбой больше не запускает преждевременную перепроверку всего разрешённого списка. Ручная кнопка проверяет весь список.<br>
**EN:** Automatic source checks now request only new or due links: normally about every 24 hours, or after six hours for a transiently unavailable source. One failure no longer triggers an early recheck of the entire allowlist. The manual action checks the full list.

**RU:** Приложение сочетает локальные модели Ollama с настраиваемыми онлайн-провайдерами, совместимыми с OpenAI API. Для ролей ИИ предусмотрен выбор провайдера и модели; по умолчанию действуют бесплатные маршруты, а потенциально платные требуют явного разрешения. Отдельный экран локальных моделей и часть центра управления уже реализованы. Ограниченный RAG использует учебные материалы и выбранные проверяемые источники. Проверка URL и дата пересмотра помогают поставить редакторскую задачу, но не подтверждают каждое утверждение и не обновляют текст урока автоматически. Поле тьютора различает недоступный локальный сервис, неизвестный статус маршрута, отсутствие доступного маршрута «Авто», неподготовленную локальную модель и Ollama за пределами этого Mac; для каждой причины показывается восстановительная подсказка. Это не доказывает, что выбранная модель действительно ответит: для этого есть отдельная проверка реального ответа. Полноценное администрирование материалов и рабочих процессов остаётся задачей разработки.<br>
**EN:** The app combines local Ollama models with configurable online providers that support the OpenAI API. AI roles can select a provider and model; free routes are the default, and potentially paid routes require explicit permission. A dedicated Local Models screen and part of the Control Center are already implemented. Limited RAG uses course materials and selected reviewable sources. URL checks and review dates can create editorial work, but they do not validate every claim or automatically update lesson text. The tutor composer distinguishes an unavailable local service, unknown route status, a missing Auto route, an unavailable local model, and Ollama running somewhere other than this Mac; it shows recovery guidance for each state. This does not prove that the selected model will answer; the separate real-reply check does that. Complete course administration and editorial workflows remain to be built.

### Приватность, интеграции и дизайн / Privacy, integrations, and design

**RU:** Учебный прогресс хранится локально, а сохранённые приложением macOS-учётные данные помещаются в Keychain. Obsidian подключается через локальный REST API. Для личного NotebookLM сейчас доступен ручной сценарий: экспорт урока в Markdown и импорт пользователем; прямой потребительский API и синхронизация не реализованы. При отправке контекста облачной модели интерфейс должен ясно сообщать об этом. Дизайн опирается на нативный SwiftUI и Apple Human Interface Guidelines: понятная иерархия, доступные элементы управления и восстановимые ошибки.<br>
**EN:** Learning progress is stored locally, and macOS credentials saved by the app use Keychain. Obsidian connects through its local REST API. For personal NotebookLM, the supported workflow is manual: export a lesson to Markdown and import it yourself; a direct consumer API and synchronization are not implemented. The interface must clearly disclose when context is sent to a cloud model. The design follows native SwiftUI and Apple Human Interface Guidelines, with clear hierarchy, accessible controls, and recoverable errors.

### Платформы / Platforms

**RU:** Сначала команда выпускает стабильное приложение для macOS. После этого планируются версия для Windows с теми же основными сценариями и сайт с подписанными установщиками. Для установки готового продукта пользователям не придётся клонировать GitHub.<br>
**EN:** The team will stabilize and release the macOS app first. A Windows version with equivalent core workflows and a website for signed installers are planned afterward. Users will not need to clone GitHub to install the finished product.

**Полное техническое задание:** [Промпт разработки приложения](project-plan/APP_BUILD_PROMPT.md). Это задание для разработки всей платформы, а не системный промпт для отдельного ИИ-тьютора.<br>
**Full application brief:** [ColiDev development prompt](project-plan/APP_BUILD_PROMPT.md). It specifies the whole platform, not the system prompt for a standalone AI tutor.

**Полный профиль продукта на русском и английском:** [Открыть профиль ColiDev](project-plan/PRODUCT_PROFILE_RU_EN.md). В нём отдельно указаны цель продукта, требования, отзывы команды, факты о прототипе и то, что ещё нужно проверить.<br>
**Complete product profile in Russian and English:** [Open the ColiDev profile](project-plan/PRODUCT_PROFILE_RU_EN.md). It separates the product goal, requirements, team feedback, prototype facts, and items that still need verification.

Текущая реализация и ограничения перечислены ниже.<br>
Current implementation and limitations are listed below.
## What works in the prototype / Что работает в прототипе

- The macOS app contains six subject areas, lesson pages, interactive exercises, and locally saved study progress. The six directions are a starting catalog, not complete courses.<br>
  Приложение macOS содержит шесть направлений, страницы уроков, интерактивные упражнения и локальное сохранение прогресса. Это начальный каталог, а не шесть завершённых курсов.

- The repository contains 70 bilingual lesson files: six subject introductions and 64 lessons linked from the roadmaps. Every foundations topic in all six subjects now has a lesson (40 of 40); intermediate and advanced levels are still partly empty (64 of 113 topics overall). Coverage and academic review vary by subject and level.<br>
  В репозитории есть 70 двуязычных файлов уроков: шесть вводных уроков по предметам и 64 урока, связанных с картами курсов. У каждой темы базового уровня во всех шести предметах теперь есть урок (40 из 40); средний и продвинутый уровни пока заполнены частично (всего 64 из 113 тем). Полнота и академическая проверка различаются по предметам и уровням.

- **Main phase / Главная фаза (PR #6):** no lesson shows an unrelated lab any more — the gas exchange lesson has its own circulation-route lab. New lessons with labs: “Gradient descent and the learning rate” (Programming), “Synapses and signal summation” (Biology), “Oscillations and waves” with an animated pendulum (Physics), “Temperature and heat” with a water-mixing lab (Physics), and “A short email to a friend” (English). The ML and brain stages now have two in-app lessons each, and the scientific-thinking stage links to Biology and Physics.<br>
  **Главная фаза (PR #6):** ни один урок больше не показывает чужой тренажёр — у урока о газообмене свой тренажёр маршрута крови. Новые уроки с тренажёрами: «Градиентный спуск и шаг обучения» (программирование), «Синапс и суммация сигналов» (биология), «Колебания и волны» с анимированным маятником (физика), «Температура и теплота» с тренажёром смешивания воды (физика) и «Короткое письмо другу» (английский). У этапов «ML» и «Мозг» теперь по два урока в приложении, а этап «Научное мышление» ведёт в биологию и физику.

- The machine-learning and brain stages of the Today journey now each have a first in-app lesson. Programming adds “Machine learning: baselines and held-out evaluation” with a k-nearest-neighbours lab that compares training data, held-out data, and a most-frequent-class baseline on invented data. Biology adds “Neurons and the action potential” with a threshold and all-or-none lab based on OpenStax Biology 2e, section 35.2. Both models have Swift verifiers in CI; the lessons are not a complete ML or neuroscience course. The physics lesson “Vectors and kinematics” and the zoology lesson “Thermoregulation and heat exchange”, which had stayed in unmerged branches, were ported with their labs; the vectors answer key was corrected.<br>
  У этапов «Машинное обучение» и «Мозг» в маршруте «Сегодня» появилось по первому уроку в приложении. В программировании — «Машинное обучение: baseline и отложенная проверка» с тренажёром k ближайших соседей: он сравнивает обучающие данные, отложенные данные и baseline частого класса на придуманных данных. В биологии — «Нейрон и потенциал действия» с тренажёром порога и принципа «всё или ничего» по OpenStax Biology 2e, раздел 35.2. Обе модели проверяются Swift-verifier'ами в CI; это не полный курс ML или нейронауки. Уроки «Векторы и кинематика» (физика) и «Терморегуляция и теплообмен» (зоология), которые оставались в незлитых ветках, перенесены вместе с тренажёрами; в уроке о векторах исправлен ключ ответа.

- The debugging and Git lesson now extends its safe local commit exercise into feature-branch collaboration: create a branch, stage and review named files, commit, publish with an upstream, and hand the change to teammates through a pull request. The simulator runs no commands and makes no network requests. Git and GitHub references are monitored as metadata only; their text is not copied into RAG.<br>
  Урок об отладке и Git теперь продолжает безопасную практику локального коммита сценарием командной работы: создать feature-ветку, подготовить и проверить указанные файлы, закоммитить их, отправить ветку с upstream и передать изменение коллегам через pull request. Тренажёр не запускает команды и не обращается к сети. Ссылки Git и GitHub отслеживаются только как метаданные; их текст не копируется в RAG.

- Mathematics now includes a sourced lesson on comparing mean and median, quartiles, IQR, and potential outliers, plus a slider-driven dot plot that records practice attempts. It flags extreme values for investigation and does not remove them automatically. GitHub Actions [38169754953](https://github.com/weekendbuildings/coli-dev/actions/runs/38169754953) passed the code build and packaging; hands-on UI review on a Mac is still needed. The lab shows a data-specific explanation for a correct prediction and offers it on demand after an incorrect one.<br>
  В математике теперь есть урок с источниками о сравнении среднего и медианы, квартилях, IQR и потенциальных выбросах, а также точечная диаграмма с ползунком, которая сохраняет попытки. Она предлагает исследовать крайние значения, но не удаляет их автоматически. GitHub Actions [38169754953](https://github.com/weekendbuildings/coli-dev/actions/runs/38169754953) успешно проверил сборку и упаковку; интерфейс на Mac ещё нужно проверить вручную. Тренажёр показывает разбор по текущим данным после верного ответа и предлагает открыть его после ошибки.<br>

- The mathematics starter includes a sourced RU/EN lesson and an interactive graph lab for quadratic functions. Learners predict a transformation, adjust `a`, `h`, and `k`, and inspect the graph, vertex, axis of symmetry, and real roots. The CI build and bundled lesson route passed; hands-on visual review on a Mac remains to be done.<br>
  В начальном курсе математики есть двуязычный урок с источником и интерактивная лаборатория графиков квадратичной функции. Ученик сначала предсказывает преобразование, затем меняет `a`, `h` и `k` и исследует график, вершину, ось симметрии и действительные корни. Сборка CI и проверка наличия урока в bundle прошли; вручную оценить отображение на Mac ещё предстоит.

- Historical CI [run 37782398587](https://github.com/weekendbuildings/coli-dev/actions/runs/37782398587) checked the constrained-optimization lesson, draggable unit-circle lab, and Swift verifier. Its Intel build was a historical precursor; current Intel support is verified separately in [run 39524476548](https://github.com/weekendbuildings/coli-dev/actions/runs/39524476548). Hands-on visual review on a physical user Mac remains open.<br>
  Исторический CI [37782398587](https://github.com/weekendbuildings/coli-dev/actions/runs/37782398587) проверил урок об оптимизации с ограничением, интерактивную единичную окружность и Swift-verifier. Его Intel-сборка была предшественником текущей; актуальная Intel-совместимость проверена отдельно в [run 39524476548](https://github.com/weekendbuildings/coli-dev/actions/runs/39524476548). Визуальная проверка на физическом Mac пользователя остаётся открытой.

- The course maps are planned from foundational material toward advanced topics. A topic listed in a roadmap does not necessarily have a finished lesson yet.<br>
  Карты курсов ведут от основ к углублённым темам. Наличие темы в плане не означает, что готовый урок уже написан.

- Zoology now links an advanced bilingual lesson on avian heat stress to a rotatable 3D schematic and range comparison based on a 2025 thick-billed murre field study. The lesson distinguishes air temperature, operative temperature, and the study-specific stress criterion.<br>
  В зоологии появился углублённый двуязычный урок о тепловом стрессе птиц с вращаемой 3D-схемой и сравнением диапазонов по полевому исследованию толстоклювых кайр 2025 года. Урок разделяет температуру воздуха, оперативную температуру и критерий стресса именно из этого исследования.

- Lesson progress is saved locally and supports review scheduling. Course completion and actual mastery are separate product goals; the prototype does not yet provide a complete mastery model.<br>
  Прогресс уроков сохраняется локально и используется для планирования повторений. Завершение курса и реальное освоение материала — разные цели; в прототипе пока нет полной модели оценки знаний.

- The home screen counts completed lessons and roadmap topics with saved checks, and flags topics that need reinforcement. Eleven built-in labs record typed interactive-prediction evidence: zoology animal functions and thermoregulation; physics net force; mathematics linear systems, trigonometry, and descriptive statistics; biology osmosis, DNA regulation, gene expression, and cell cycle; and Python loop tracing. These results contribute to check coverage and can recommend practice. This is evidence coverage, not a mastery score; no lab result completes the lesson or changes spaced-review scheduling.<br>
  Главный экран считает завершённые уроки и темы учебных планов с сохранёнными проверками, а также отмечает темы, которые нужно закрепить. Одиннадцать встроенных тренажёров сохраняют типизированные результаты интерактивных прогнозов: функции животных и терморегуляция в зоологии; равнодействующая сила в физике; системы уравнений, тригонометрия и описательная статистика в математике; осмос, регуляция ДНК, экспрессия генов и клеточный цикл в биологии; трассировка цикла в Python. Эти результаты входят в покрытие проверками и могут привести к рекомендации закрепить тему. Это учёт результатов, а не оценка освоения знаний; результат тренажёра сам по себе не завершает урок и не меняет расписание интервального повторения.

- The prototype's Continue flow includes built-in lessons, learner-created subjects and topics, and topics added to built-in subjects. It prioritizes a due review, an unfinished resumed topic, repeated self-reported difficulty, a topic whose knowledge check took multiple attempts, low self-rated recall, then the next unfinished roadmap topic. When the learner repeatedly reports a foundation gap, it returns to a specific parent prerequisite only if that prerequisite's own latest knowledge check failed with the same reported category; otherwise it stays on the current topic. Custom topics use stable progress IDs, learner-confirmed completion, and spaced-review status. These signals do not form a complete mastery model; Mac acceptance is still required.<br>
  В прототипе «Продолжить» учитывает встроенные уроки, созданные учеником предметы и темы, а также темы, добавленные во встроенные предметы. Сначала предлагается просроченное повторение, затем незавершённая открытая тема, повторяющаяся самооценка трудности, тема, где проверочный вопрос потребовал нескольких попыток, тема с низкой самооценкой воспоминания и следующий незавершённый пункт учебного плана. Если ученик несколько раз отмечает нехватку основы, приложение возвращается к конкретной родительской предпосылке только тогда, когда её последняя проверка знаний тоже не пройдена с той же категорией; иначе рекомендация остаётся на текущей теме. У пользовательских тем есть постоянные ID прогресса, подтверждение завершения учеником и статус интервального повторения. Эти сигналы ещё не образуют полноценную модель освоения; нужна проверка на Mac.

- **RU/EN knowledge-check evidence:** Completing or reviewing a full curriculum lesson records attempts and first-try correctness for its multiple-choice check. Evidence waits in the local queue while the backend is offline, is stored in SQLite, and is included in progress backups. Continue may recommend practice on that topic before a new one.<br>
  **Результаты проверок в уроках на русском и английском:** При завершении или повторении полноценного урока сохраняются число попыток и правильность первого ответа на вопрос с выбором ответа. Если backend недоступен, событие остаётся в локальной очереди; затем оно хранится в SQLite и включается в резервную копию прогресса. «Продолжить» может предложить закрепить эту тему до перехода к новой.

- **RU/EN interactive-practice evidence:** Eleven built-in labs record prediction attempts as `interactive_prediction`, separately from lesson completion and spaced review: biology osmosis, DNA regulation, gene expression, and cell cycle; zoology animal functions and thermoregulation; physics net force; mathematics linear systems, trigonometry, and descriptive statistics; and Python loop tracing. Events are queued offline and included in assessment history, backups, and check coverage. Other practice modules still need an evidence-coverage audit; this is not a validated mastery model.<br>
  **Результаты интерактивной практики на русском и английском:** Одиннадцать встроенных тренажёров сохраняют попытки предсказания как `interactive_prediction`, отдельно от завершения урока и интервального повторения: осмос, регуляция ДНК, экспрессия генов и клеточный цикл в биологии; функции животных и терморегуляция в зоологии; равнодействующая сила в физике; системы уравнений, тригонометрия и описательная статистика в математике; трассировка цикла в Python. При отключённом backend события ждут отправки; история результатов участвует в резервном копировании и подсчёте покрытия проверками. Для остальных форматов практики ещё нужно проверить полноту учёта; это не проверенная модель освоения знаний.

- The local backend serves the tutor, course retrieval, progress synchronization, service settings, and the loopback Obsidian bridge. The app can package and launch that backend runtime.<br>
  Локальный сервер обслуживает тьютора, поиск по курсам, синхронизацию прогресса, настройки сервисов и локальную интеграцию с Obsidian. Приложение умеет упаковывать и запускать этот сервер.

- AI routes can be configured by role. Local models now also have a direct sidebar entry, opening the Control Center on its Ollama availability, installed-models, and local-role screen. Paid cloud routes require a separate cost-policy setting; saving an API key does not enable them by itself.<br>
  Маршруты ИИ можно настраивать отдельно для разных ролей. Для локальных моделей теперь есть отдельный пункт в боковом меню: он сразу открывает экран Центра управления с доступностью Ollama, установленными моделями и назначениями локальных ролей. Для платных облачных маршрутов нужно отдельно разрешить расходы; одно сохранение ключа API само по себе их не включает.

- Tutor readiness distinguishes a responding local backend from a configured model route. When sending is blocked, the composer identifies the missing layer and gives localized next steps; internet access or an unused session allowance is never treated as proof that a model is ready.<br>
  Статус тьютора отдельно показывает, отвечает ли локальный сервер и настроен ли маршрут к модели. Если отправка заблокирована, поле ввода называет недостающий компонент и подсказывает следующий шаг на выбранном языке; наличие интернета или неиспользованной квоты не считается подтверждением готовности модели.

- Settings include a real-reply check for the selected local or automatic tutor route. It sends only a short static prompt, skips course and Obsidian retrieval and web search, and reports the actual provider, model, response time, answer text, or error. A successful health check alone does not mark the model as verified. The request may use provider quota; paid routes still follow the explicit cost policy.<br>
  В настройках можно проверить реальный ответ выбранного локального или автоматического маршрута тьютора. Отправляется только короткий статический запрос; поиск по курсам и Obsidian, а также веб-поиск отключены. Приложение показывает фактического провайдера, модель, время ответа, текст ответа или ошибку. Успешная проверка health сама по себе не означает, что модель проверена. Запрос может расходовать квоту провайдера; платные маршруты по-прежнему подчиняются отдельной настройке расходов.

- The local RAG index searches course Markdown and text resources. It supports lexical search and optional Ollama embeddings; tutor retrieval is limited to a small number of sources for each answer.<br>
  Локальный индекс RAG ищет по Markdown-урокам и текстовым материалам. Доступен обычный текстовый поиск и необязательные векторные представления через Ollama; для ответа тьютору передаётся ограниченное число источников.

- Correct-answer positions are randomized in the six subject introductions and the current answer-checking quiz modules, including reading, conditionals, tense contrasts, file tracing, debugging, daily routines, animal groups and lineages, genetics, gene expression, cell-cycle, and animal-function practice. The option mapping stays stable while a learner answers and is reshuffled when an activity restarts, switches scenario, or the learner retries after a wrong answer. Ordered controls and numeric prediction inputs keep their meaningful order.<br>
  Позиции правильных ответов перемешиваются во вводных проверках шести направлений и во всех найденных проверках с выбором ответа: чтение, условные предложения и времена английского, обработка файловых ошибок, отладка, повседневные действия, группы и происхождение животных, генетика, экспрессия генов, клеточный цикл и зоология. Пока ученик отвечает, соответствие вариантов не меняется; порядок заново перемешивается при перезапуске задания, смене сценария или повторной попытке после неверного ответа. Управляющие последовательности и числовые вводы сохраняют смысловой порядок.

- Source tools display attribution and dates and can check a fixed allowlist of official URLs. A detected source change stays flagged until every linked lesson has an editorial review for that exact version. Checks can identify changed or unavailable pages, but they do not automatically update or approve lesson text.<br>
  Инструменты источников показывают атрибуцию и даты и проверяют ограниченный список официальных URL. Найденное изменение остаётся отмеченным, пока каждый связанный урок не пройдёт редакторскую проверку именно этой версии. Автопроверка выявляет изменения и недоступность страниц, но сама не обновляет и не утверждает текст урока.

- After a wrong answer in six introductory quizzes and 50 linked lesson checks, the app withholds the answer and explanation until the learner retries or asks to reveal them. A correct answer shows the explanation automatically. Feedback coverage for other interactive-practice formats still needs review.<br>
  После неправильного ответа в шести вводных тестах и 50 связанных проверках уроков приложение скрывает правильный ответ и объяснение, пока ученик не повторит попытку или сам не попросит показать разбор. После верного ответа объяснение появляется автоматически. Обратную связь в остальных форматах интерактивной практики ещё нужно проверить.

- Obsidian search and note saving are optional and require its local REST API. NotebookLM currently uses a manual workflow: export a lesson as Markdown and import it yourself; direct API integration and synchronization are not implemented.<br>
  Поиск в Obsidian и сохранение заметок доступны по желанию и требуют локального REST API. Сейчас NotebookLM используется вручную: экспортируйте урок в Markdown и импортируйте его самостоятельно; прямое подключение к API и синхронизация не реализованы.

- The physics starter includes interactive motion and measurement activities. One 3D prototype demonstrates one-dimensional motion under constant force; it is not a general-purpose physics simulator. Other starter visual exercises are 2D.<br>
  В начальном курсе физики есть интерактивные задания по движению и измерениям. Один 3D-прототип показывает одномерное движение под постоянной силой и не является универсальным физическим симулятором. Остальные начальные визуальные упражнения двумерные.

## Что ещё предстоит сделать / What remains

**Уже есть в прототипе / Already in the prototype:** локальный редактор предметов и тем; ограниченные рекомендации по подтверждённым предпосылкам; перемешивание вариантов с сохранением ответа на время попытки; подсказка и повтор в Python-тренажёре трассировки цикла; локальный индекс и проверка источников по разрешённому списку; центр управления с диагностикой и настройками маршрутов ИИ. Это проверяемые части прототипа, а не доказательство полноты курса или готовности релиза.<br>
**Already in the prototype:** a local subject and topic editor; limited recommendations based on confirmed prerequisites; shuffled answer choices with stable mapping during an attempt; a hint and retry in the Python loop-tracing activity; a local index and allowlisted source checks; and a Control Center with diagnostics and AI-route settings. These are prototype features, not proof of complete courses or release readiness.

**Главные незавершённые задачи / Main work still to do:**

- **RU:** Проверить содержание и источники каждого готового урока, расширить курсы по всем шести направлениям и явно показывать, какие темы готовы, а какие ещё нет.<br>
  **EN:** Review the content and sources of each finished lesson, expand courses across all six subjects, and clearly show which topics are ready and which are not.
- **RU:** Развить ограниченные рекомендации до адаптивного плана с диагностикой, предпосылками, анализом ошибок, изменением сложности и проверкой переноса знаний. Не выдавать завершение уроков за процент мастерства.<br>
  **EN:** Grow the limited recommendations into an adaptive plan with diagnostics, prerequisites, error analysis, difficulty adjustment, and transfer checks. Do not present lesson completion as a mastery percentage.
- **RU:** Провести аудит обратной связи во всех форматах упражнений и обеспечить понятный разбор ответов, повторную попытку и помощь без преждевременного раскрытия решения.<br>
  **EN:** Audit feedback across every exercise format and provide clear explanations, retries, and useful help without revealing solutions too early.
- **RU:** Расширить предметные схемы, симуляции, видео с вопросами и 3D-модули там, где они помогают понять тему; отдельно описывать управление, допущения и ограничения каждой модели.<br>
  **EN:** Expand subject-specific diagrams, simulations, videos with questions, and 3D activities where they aid understanding; document each model's controls, assumptions, and limits.
- **RU:** Завершить редакторский процесс для источников и уроков. Текущая проверка источников выявляет изменения и поддерживает ограниченный RAG, но не обновляет и не публикует текст урока без проверки.<br>
  **EN:** Complete the editorial workflow for sources and lessons. Current source checks can detect changes and support limited RAG, but lesson text is not updated or published without review.
- **RU:** Доработать центр управления: редактирование версий курсов, просмотр состава RAG, диагностика и более полный экспорт/восстановление данных. Сейчас доступна только часть этой панели.<br>
  **EN:** Complete the Control Center with course-version editing, RAG inspection, diagnostics, and fuller data export and restore. Only part of this administration area exists today.
- **RU:** Проверить приложение вручную на целевом Mac, включая интерфейс, клавиатурную доступность, Keychain и настоящий ответ выбранной модели. Успешная CI-сборка не заменяет эту приёмку.<br>
  **EN:** Review the app hands-on on the target Mac, including its interface, keyboard accessibility, Keychain, and a real reply from the selected model. A successful CI build does not replace this acceptance.
- **RU:** Для NotebookLM пока остаётся ручной экспорт/импорт Markdown; прямую интеграцию добавлять только при наличии официально поддерживаемого способа. Синхронизация между устройствами также не реализована.<br>
  **EN:** NotebookLM currently uses manual Markdown export and import; add direct integration only if an officially supported method is available. Cross-device synchronization is also not implemented.
- **RU:** После стабильного релиза macOS подготовить Windows-версию и сайт с подписанными установщиками, чтобы пользователям не приходилось скачивать исходники через GitHub.<br>
  **EN:** After a stable macOS release, prepare a Windows version and an installer website so users do not need to download source code through GitHub.

Порядок P0–P3 и критерии приёмки замечаний команды от 8 октября записаны в [подробном плане](project-plan/categories/11-feedback-and-acceptance.md).<br>
The P0–P3 order and acceptance criteria for the team's 8 October feedback are recorded in the [detailed plan](project-plan/categories/11-feedback-and-acceptance.md).

Проверка одобренных источников не гарантирует, что вся информация в курсах актуальна или верна. Бесплатные тарифы, доступность моделей и квоты провайдеров меняются; приложение не обещает неограниченный бесплатный доступ или полное отсутствие ошибок.<br>
An approved-source check does not guarantee that every course statement is current or correct. Provider free tiers, model availability, and quotas can change; the app does not promise unlimited free access or a complete absence of bugs.

## Architecture / Архитектура

| Component | Компонент | Responsibility | Назначение |
|---|---|---|---|
| SwiftUI client | Клиент SwiftUI | macOS navigation, lessons, exercises, settings, and local progress. | Навигация macOS, уроки, упражнения, настройки и локальный прогресс. |
| FastAPI service | Сервис FastAPI | Tutor API, agent routing, course search, source status, and progress endpoints. | API тьютора, маршрутизация агентов, поиск по курсам, состояние источников и работа с прогрессом. |
| Local knowledge | Локальная база знаний | Course files and retrieval index stored on the learner’s device. Retrieved Obsidian citations can include the note’s filesystem modification time when its plugin exposes it. | Файлы курсов и поисковый индекс на устройстве ученика. В найденных заметках Obsidian может показываться время изменения файла, если плагин предоставляет такие метаданные. |
| Model providers | Провайдеры моделей | Ollama on-device and explicitly configured compatible cloud APIs. | Локальная Ollama и явно настроенные совместимые облачные API. |
| External learning tools | Внешние учебные инструменты | Optional Obsidian bridge and Markdown export for NotebookLM. | Необязательный мост к Obsidian и экспорт Markdown для NotebookLM. |

## Try the tutor backend / Запустить сервер тьютора

From the repository root, create a virtual environment, install the backend dependencies, copy the sample settings, and start the local API.<br>
В корне репозитория создайте виртуальное окружение, установите зависимости сервера, скопируйте пример настроек и запустите локальный API.

macOS and Linux / macOS и Linux:

~~~sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-orchestrator.txt
cp .env.example .env
python 01_Projects/orchestrator.py
~~~

Windows PowerShell / оболочка Windows PowerShell:

~~~powershell
py -3 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements-orchestrator.txt
Copy-Item .env.example .env
python 01_Projects/orchestrator.py
~~~

The standalone development server listens on 127.0.0.1:8000 by default. The packaged macOS app instead launches its bundled backend on an OS-selected loopback port; it reuses 8000 only after the product ID and API compatibility handshake succeeds. The service does not provide user-account authentication.<br>
Отдельный сервер для разработки по умолчанию слушает 127.0.0.1:8000. macOS-приложение запускает встроенный backend на свободном loopback-порту, выбранном операционной системой, и использует порт 8000 только после успешной проверки ID продукта и совместимости API. Сервер не использует авторизацию аккаунтов.

## Build and check / Собрать и проверить

To build the macOS app from source, open macOS/ColiDev/ColiDev.xcodeproj on a Mac with Xcode, select the ColiDev scheme, and run it. Windows cannot build this native macOS target. The Windows app and downloadable installers are later product work.<br>
Чтобы собрать приложение macOS из исходников, откройте macOS/ColiDev/ColiDev.xcodeproj на Mac с Xcode, выберите схему ColiDev и запустите её. Windows не может собрать эту нативную цель macOS. Windows-приложение и скачиваемые установщики — будущие этапы проекта.

Run the backend test suite with:<br>
Запустить проверки backend можно так:

~~~sh
python -m pip install -r requirements-test.txt
python -m pytest 01_Projects -q
~~~

Automated tests use mocked providers and do not spend API credits or confirm live-provider access. CI run [39524476548](https://github.com/weekendbuildings/coli-dev/actions/runs/39524476548) passed app and bundled-backend builds, UI checks, smoke checks, and packaging for Intel `x86_64` on macOS 15 plus Apple Silicon `arm64` on macOS 15 and 26. CI does not replace hands-on acceptance on a physical Mac.<br>
В автоматических тестах используются заглушки провайдеров; они не расходуют API-кредиты и не подтверждают доступ к реальным моделям. CI [39524476548](https://github.com/weekendbuildings/coli-dev/actions/runs/39524476548) успешно собрал приложение и встроенный backend, прошёл UI-проверки, smoke-проверки и упаковку для Intel `x86_64` на macOS 15 и Apple Silicon `arm64` на macOS 15 и 26. CI не заменяет ручную проверку на физическом Mac.

## Privacy and cost / Приватность и расходы

On macOS, credentials saved through the app are stored in Keychain. The development .env file is ignored by Git. Never commit real provider or Obsidian credentials.<br>
В macOS ключи, сохранённые через приложение, помещаются в Keychain. Файл .env для разработки исключён из Git. Никогда не добавляйте реальные ключи провайдеров или Obsidian в репозиторий.

Automatic routing defaults to free-only routes. Potentially paid cloud models and Google Search require an explicit cost-policy change. Cloud requests may include the learner’s question and selected course context; the app shows a warning before those routes are enabled.<br>
Автоматическая маршрутизация по умолчанию ограничена бесплатными маршрутами. Потенциально платные облачные модели и Google Search требуют явного изменения политики расходов. Облачный запрос может содержать вопрос ученика и выбранный контекст курса; перед включением таких маршрутов приложение показывает предупреждение.

Provider usage metadata is kept locally for up to 90 days without prompts, answers, or API keys. The usage panel shows provider-reported token counts and the USD cost only when OpenRouter supplies it, including on streaming requests; other missing costs stay unknown. This is not an account quota or spending cap, and reported usage may differ from the final provider invoice. See the [bilingual cost and privacy notes / двуязычные заметки о расходах и приватности](project-plan/categories/07-security-cost.md) and the [official OpenRouter streaming-usage guide](https://openrouter.ai/blog/announcements/smarter-charts-inline-svgs-and-live-usage-accounting).<br>
Метаданные usage хранятся локально до 90 дней без вопросов, ответов и API-ключей. Панель показывает сообщённые провайдерами токены, а стоимость в USD — только если её вернул OpenRouter, в том числе в потоковом ответе; отсутствующая сумма остаётся неизвестной. Это не квота аккаунта и не лимит расходов, а usage может отличаться от итогового счёта провайдера. См. [двуязычные заметки о расходах и приватности](project-plan/categories/07-security-cost.md) и [официальное описание потокового учёта OpenRouter](https://openrouter.ai/blog/announcements/smarter-charts-inline-svgs-and-live-usage-accounting).<br>

## Project documents / Документы проекта

- [Detailed project plan / Подробный план проекта](project-plan/README.md)
- [Complete product profile / Полный профиль продукта](project-plan/PRODUCT_PROFILE_RU_EN.md)
- [Bilingual application-development prompt / Двуязычный промпт на разработку приложения](project-plan/APP_BUILD_PROMPT.md)
- [Feedback and acceptance criteria / Замечания и критерии приёмки](project-plan/categories/11-feedback-and-acceptance.md)
- [macOS app notes / Заметки по приложению macOS](macOS/ColiDev/README.md)
- [Backend notes / Заметки по backend](01_Projects/README.md)
- [Course catalog / Каталог курсов](02_Areas/README.md)
- [Biology source audit / Аудит источников уроков биологии](project-plan/research/biology-foundations-source-audit.md)
- [Current pull request / Текущий pull request](https://github.com/weekendbuildings/coli-dev/pull/5)
- [Project repository / Репозиторий проекта](https://github.com/weekendbuildings/coli-dev)

Every explanatory English passage in the README is followed immediately by its complete Russian version. Product identifiers, filenames, commands, model IDs, and API names stay unchanged so they can be copied and searched.<br>
После каждого пояснительного текста на английском в README сразу приведён его полный русский перевод. Названия продукта, файлов, команд, моделей и API оставлены без изменений, чтобы их можно было копировать и искать.

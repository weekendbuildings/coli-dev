---
subject: programming
lesson_id: programming.ai_path_glossary
level: foundations
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Словарь пути ИИ / The AI path glossary

## Русский

### Простыми словами

Это справочник, а не обычный урок. В нём 112 слов пути ИИ, у каждого одно-два простых предложения и ссылка на урок, где оно разобрано подробно. Как словарь в конце учебника: читать его подряд не нужно, в него заглядывают, когда споткнулся. Слова идут по этапам пути, в том порядке, в каком встречаются.

**Что нужно знать до.** Ничего.

**Если непонятно.** Если короткого объяснения мало, открой урок из ссылки: там слово объяснено на примере с числами.

### Цель

Быстро находить, что значит слово на пути ИИ и в каком уроке оно разобрано подробно. Проверить себя: узнать слово по его объяснению.

### Идея и механизм

Объяснения здесь короткие и поэтому упрощают. Точное значение всегда в уроке из ссылки. Где слово спорное, например «AGI» или «сознание», здесь дано рабочее значение, а не окончательное.

**Этап 1. Старт руками**

- **Языковая модель.** Программа, которая по началу текста угадывает следующий токен. Пишет текст, повторяя это угадывание много раз. Подробно: «Живая модель на твоём Mac: токены и температура», шаг 1.
- **Веса, или параметры.** Числа внутри модели, подобранные при обучении. Всё, что модель «умеет», записано только в них. Подробно: «Живая модель на твоём Mac: токены и температура», шаг 1.
- **Ollama.** Программа на Mac, которая загружает файл модели в память и считает по нему. Работает без интернета. Подробно: «Живая модель на твоём Mac: токены и температура», шаг 1.
- **Токен.** Кусочек текста, с которым работает модель: слово, часть слова или знак. Подробно: «Живая модель на твоём Mac: токены и температура», шаг 1.
- **Температура.** Число, которое решает, насколько смело модель выбирает токен. Ниже значит ближе к самому вероятному, выше значит чаще редкие. Подробно: «Живая модель на твоём Mac: токены и температура», шаг 1.
- **Роль.** Пометка в тексте чата, кто говорит: система, пользователь или ассистент. Подробно: «Чат это текст: роли и память, которой нет», шаг 1.
- **Системная подсказка.** Текст в начале чата с правилами для модели. Это не стена: модель может его нарушить. Подробно: «Чат это текст: роли и память, которой нет», шаг 1.
- **Окно контекста.** Сколько токенов модель может прочитать за один раз. Всё, что не влезло, она не видит. Подробно: «Чат это текст: роли и память, которой нет», шаг 1.
- **Галлюцинация.** Уверенный, но выдуманный ответ. Модель пишет правдоподобный текст, а не проверенный факт. Подробно: «Как модель ошибается и как это проверить», шаг 1.
- **Уверенность против точности.** Высокая вероятность ответа ещё не значит, что ответ верный. Проверяют на вопросах с известными ответами. Подробно: «Как модель ошибается и как это проверить», шаг 1.
- **Подсказка, или промпт.** Текст, который ты даёшь модели: просьба, правила и примеры. Подробно: «Как просить: инструкции, примеры, JSON», шаг 1.
- **JSON.** Строгая запись данных в виде пар «имя: значение». Программа читает её без догадок. Подробно: «Как просить: инструкции, примеры, JSON», шаг 1.

**Этап 2. Создание**

- **Переменная.** Имя, к которому привязано значение, как надпись на коробке. Подробно: «Переменные и типы данных», шаг 2.
- **Функция.** Кусок программы с именем: получает данные и возвращает результат. Подробно: «Условия, циклы и функции», шаг 2.
- **Цикл.** Повторение одних и тех же шагов, пока есть данные или пока верно условие. Подробно: «Условия, циклы и функции», шаг 2.
- **Список и индекс.** Список это ряд значений по порядку, индекс это номер места, счёт с нуля. Подробно: «Коллекции и циклы», шаг 2.
- **Исключение.** Сигнал Python «здесь ошибка» с её названием. Его можно поймать и обработать. Подробно: «Строки, файлы и исключения», шаг 2.
- **Класс и объект.** Класс это чертёж, объект это вещь по чертежу со своими данными. Подробно: «Классы в Python: объекты, наследование и композиция», шаг 2.
- **Вектор.** Ряд чисел, например `(3, 4)`. Им описывают точку, направление или слово. Подробно: «Векторы и матрицы: скалярное произведение и слой нейросети», шаг 3.
- **Скалярное произведение.** Перемножить числа двух векторов попарно и сложить. Большое, если векторы смотрят в одну сторону. Подробно: «Векторы и матрицы: скалярное произведение и слой нейросети», шаг 3.
- **Матрица.** Таблица чисел. Умножение матрицы на вектор это и есть работа одного слоя сети. Подробно: «Векторы и матрицы: скалярное произведение и слой нейросети», шаг 3.
- **Производная.** Скорость изменения прямо сейчас, как показание спидометра. Подробно: «Производная как мгновенная скорость изменения», шаг 4.
- **Градиент.** Набор частных производных. Показывает, куда функция растёт быстрее всего. Подробно: «Частные производные и градиент: как учится нейросеть», шаг 4.
- **Градиентный спуск.** Уменьшение ошибки маленькими шагами против градиента. Подробно: «Градиентный спуск и шаг обучения», шаг 4.
- **Шаг обучения.** Насколько далеко шагать при спуске. Слишком маленький медленно, слишком большой разносит. Подробно: «Градиентный спуск и шаг обучения», шаг 4.
- **Медиана.** Число посередине ряда, выстроенного по порядку. Почти не боится выбросов. Подробно: «Описание данных: центр, разброс и потенциальные выбросы», шаг 5.
- **Условная вероятность.** Доля случаев внутри части случаев: «среди больных, сколько с положительным тестом». Подробно: «Вероятность и формула Байеса», шаг 5.
- **Формула Байеса.** Способ перевернуть условную вероятность и учесть, как часто что-то бывает вообще. Подробно: «Вероятность и формула Байеса», шаг 5.
- **Математическое ожидание.** Средний итог, если повторять очень много раз. Подробно: «Случайные величины и выборка», шаг 5.
- **Дисперсия.** Насколько сильно итоги разбросаны вокруг среднего. Подробно: «Случайные величины и выборка», шаг 5.
- **Энтропия.** Среднее удивление источника в битах. Чем она больше, тем труднее угадать. Подробно: «Информация, энтропия и кросс-энтропия», шаг 6.
- **Кросс-энтропия.** Среднее удивление модели настоящими данными. Именно её уменьшают при обучении языковой модели. Подробно: «Информация, энтропия и кросс-энтропия», шаг 6.
- **Softmax.** Правило, которое превращает любые оценки в вероятности, дающие в сумме 1. Подробно: «Классификация и softmax», шаг 7.
- **Нейрон.** Умножает входы на веса, складывает, прибавляет сдвиг и пропускает через функцию активации. Подробно: «Нейросеть учится сама: обратное распространение ошибки», шаг 8.
- **Обратное распространение.** Способ найти, сколько каждый вес виноват в ошибке, идя от ошибки назад по правилу цепочки. Подробно: «Нейросеть учится сама: обратное распространение ошибки», шаг 8.
- **Скрытый слой.** Нейроны между входом и выходом. Строят новые признаки, с которыми задача становится простой. Подробно: «Скрытый слой: нейросеть учит XOR», шаг 8.
- **Сигмоида.** Функция, которая сжимает любое число в промежуток от 0 до 1. Подробно: «Скрытый слой: нейросеть учит XOR», шаг 8.
- **Механизм градиентов, autograd.** Программа, которая сама считает производные: каждое число помнит, как получено. Подробно: «Свой механизм градиентов», шаг 8.
- **Baseline.** Самое простое решение для сравнения. Модель хуже него ничему не научилась. Подробно: «Машинное обучение: baseline и отложенная проверка», шаг 9.
- **Отложенная проверка.** Данные, спрятанные от модели при обучении. Только на них видно, научилась ли она. Подробно: «Машинное обучение: baseline и отложенная проверка», шаг 9.
- **Переобучение.** Модель заучила обучающие примеры, а на новых ошибается. Подробно: «Мини-батчи и переобучение», шаг 9.
- **Мини-батч.** Маленький пакет примеров для одного шага обучения. Подробно: «Мини-батчи и переобучение», шаг 9.
- **Оптимизатор.** Правило шага обучения: обычный спуск, импульс, Adam. Подробно: «Оптимизаторы: импульс и Adam», шаг 9.
- **Adam.** Оптимизатор с инерцией и своим размером шага для каждого числа. Подробно: «Оптимизаторы: импульс и Adam», шаг 9.
- **Нормализация.** Приведение чисел слоя к среднему 0 и разбросу 1, чтобы сигнал не гас и не раздувался. Подробно: «Инициализация и нормализация», шаг 9.
- **BPE.** Способ строить словарь токенов: много раз склеивать самую частую пару кусочков. Подробно: «Свой токенизатор», шаг 10.
- **Биграмма, счётчик пар.** Самая простая языковая модель: считает, какой символ чаще идёт после какого. Подробно: «Счётчик пар: первая языковая модель», шаг 10.
- **Эмбеддинг.** Список чисел, которым модель обозначает токен. У похожих по смыслу токенов он похож. Подробно: «Эмбеддинги и сходство», шаг 10.
- **Косинусное сходство.** Насколько два вектора смотрят в одну сторону: 1 одинаково, 0 под прямым углом. Подробно: «Эмбеддинги и сходство», шаг 10.
- **Внимание.** Способ, которым каждый токен сам выбирает, на какие прошлые токены смотреть. Подробно: «Механизм внимания», шаг 11.
- **Запрос, ключ, значение.** Что токен ищет, что он предлагает и что передаёт, если его выбрали. Подробно: «Механизм внимания», шаг 11.
- **Маска будущего.** Запрет смотреть на ещё не написанные токены. Подробно: «Механизм внимания», шаг 11.
- **Трансформер.** Устройство больших языковых моделей: много одинаковых блоков с вниманием и маленькой сетью. Подробно: «Блок трансформера», шаг 11.
- **ReLU.** Функция активации: оставляет положительное число как есть, а отрицательное заменяет нулём. Подробно: «Блок трансформера», шаг 11.
- **Обходной путь.** Запись `x + F(x)`: новое прибавляют к старому, и ошибка легко доходит до нижних слоёв. Подробно: «Блок трансформера», шаг 11.
- **Top-k и top-p.** Выбор следующего токена только из нескольких самых вероятных: из `k` лучших или из лучших, набравших долю `p`. Подробно: «Как модель выбирает слова: top-k, top-p и лучевой поиск», шаг 12.
- **Лучевой поиск.** Держать несколько лучших продолжений сразу и выбрать самое вероятное целиком. Подробно: «Как модель выбирает слова: top-k, top-p и лучевой поиск», шаг 12.

**Этап 3. Улучшение**

- **Обучение с подкреплением.** Обучение не по готовым ответам, а по награде за свои действия. Подробно: «Автоматы: пробовать новое или брать лучшее», шаг 13.
- **Агент и среда.** Агент действует, среда отвечает новым положением и наградой. Подробно: «Автоматы: пробовать новое или брать лучшее», шаг 13.
- **Исследование и использование.** Спор: пробовать новое или брать то, что уже кажется лучшим. Подробно: «Автоматы: пробовать новое или брать лучшее», шаг 13.
- **Сожаление.** Сколько награды потеряно по сравнению с лучшим выбором. Подробно: «Автоматы: пробовать новое или брать лучшее», шаг 13.
- **Состояние и политика.** Состояние это где агент сейчас, политика это его правило выбора действия. Подробно: «Клетчатый мир и уравнение Беллмана», шаг 13.
- **Ценность.** Сколько награды можно получить, начав из этого состояния. Подробно: «Клетчатый мир и уравнение Беллмана», шаг 13.
- **Скидка.** Число меньше 1: награда потом стоит чуть меньше награды сейчас. Подробно: «Клетчатый мир и уравнение Беллмана», шаг 13.
- **Уравнение Беллмана.** Ценность состояния равна награде за шаг плюс скидка, умноженная на ценность следующего. Подробно: «Клетчатый мир и уравнение Беллмана», шаг 13.
- **Q-обучение.** Агент учит оценку `Q` для каждой пары «состояние и действие» только по своему опыту. Подробно: «Q-обучение: агент учится сам», шаг 13.
- **REINFORCE.** Метод, который делает вероятнее действия с хорошей наградой и менее вероятными с плохой. Подробно: «Градиент политики: REINFORCE», шаг 13.
- **Базовая линия.** Средняя награда, которую вычитают, чтобы «хорошо» значило «лучше обычного». Подробно: «Градиент политики: REINFORCE», шаг 13.
- **Дообучение.** Продолжить обучение готовой модели на своих примерах вместо обучения с нуля. Подробно: «Дообучение и LoRA», шаг 14.
- **LoRA.** Дообучение маленькой добавки рядом с замороженными весами. Её можно снять. Подробно: «Дообучение и LoRA», шаг 14.
- **RLHF.** Обучение с подкреплением на сравнениях ответов, которые сделали люди. Подробно: «RLHF: обучение на предпочтениях людей», шаг 14.
- **Модель награды.** Модель, которая ставит ответам оценки, похожие на выбор людей. Подробно: «RLHF: обучение на предпочтениях людей», шаг 14.
- **Поводок.** Штраф за слишком далёкий уход модели от исходной при RLHF. Подробно: «RLHF: обучение на предпочтениях людей», шаг 14.
- **RLVR.** Награда за ответ, который программа может проверить сама, например в задаче с точным числом. Подробно: «Рассуждение и награда по проверке», шаг 14.
- **Конституционный ИИ.** Сравнения ответов делает модель по записанным правилам, а не люди. Подробно: «Правила вместо людей и DPO», шаг 14.
- **DPO.** Прямая оптимизация предпочтений: модель сдвигают по парам «лучше и хуже» без отдельной модели награды. Подробно: «Правила вместо людей и DPO», шаг 14.
- **RAG.** «найди, потом отвечай»: программа ищет подходящие куски текста и даёт их модели. Подробно: «RAG с нуля: поиск и ответ», шаг 15.
- **Агент с инструментами.** Модель в цикле пишет действия, программа их выполняет и возвращает результат. Подробно: «Агенты и инструменты: цикл своими руками», шаг 15.
- **Бенчмарк.** Общий набор задач, по которому сравнивают модели. Подробно: «Оценка, которая что-то значит», шаг 15.
- **Доверительный интервал.** Насколько число результата может гулять от случая. Подробно: «Оценка, которая что-то значит», шаг 15.
- **Закон Гудхарта.** Когда число становится целью, оно перестаёт хорошо мерить. Подробно: «Оценка, которая что-то значит», шаг 15.
- **Степенной закон.** Ошибка падает как степень от размера: на графике в логарифмах это прямая. Подробно: «Законы масштабирования и цена обучения», шаг 16.
- **Дедупликация.** Удаление повторов из обучающих текстов. Подробно: «Данные для языковой модели: фильтры и повторы», шаг 16.
- **Активация.** Число, которое выдал нейрон на этот вход. Подробно: «Зонды: что знает сеть внутри», шаг 17.
- **Зонд.** Маленькая модель, которая по активациям угадывает свойство входа. Показывает, что сведения там есть. Подробно: «Зонды: что знает сеть внутри», шаг 17.
- **Суперпозиция.** Сеть хранит больше понятий, чем у неё нейронов, раскладывая их по направлениям. Подробно: «Суперпозиция: больше понятий, чем нейронов», шаг 17.
- **Разреженный автокодировщик.** Сеть, которая раскладывает активации на много признаков, из которых одновременно включены немногие. Подробно: «Разреженные признаки: автокодировщик», шаг 17.
- **Цепь.** Небольшой набор частей сети, который делает конкретную работу. Подробно: «Цепи: какие части сети делают работу», шаг 17.
- **Обман награды.** Агент находит лазейку и получает награду, не делая того, чего хотели. Подробно: «Безопасность: что идёт не так», шаг 18.
- **Поддакивание.** Модель соглашается с человеком, даже когда он неправ. Подробно: «Безопасность: что идёт не так», шаг 18.
- **Подмена инструкций.** Текст из письма или страницы командует агентом вместо хозяина. Подробно: «Безопасность: что идёт не так», шаг 18.

**Этап 4. Путь к AGI**

- **AGI.** Общий искусственный интеллект. Одного принятого определения нет. Подробно: «Что такое интеллект: три определения», шаг 19.
- **ARC.** Головоломки на сетке: угадать правило по нескольким примерам. Проверяют освоение нового. Подробно: «Как мерить общий интеллект: ARC», шаг 19.
- **Модель мира.** Внутренняя «карта» того, что будет после действия. С ней можно учиться в воображении. Подробно: «Модели мира: учиться в воображении», шаг 20.
- **Поиск по дереву.** Перебор возможных ходов и ответов вперёд, чтобы выбрать лучший ход сейчас. Подробно: «Планирование: поиск по дереву», шаг 20.
- **Катастрофическое забывание.** Сеть, выучив новую задачу, теряет старую. Подробно: «Непрерывное обучение: как сеть забывает», шаг 21.
- **Повторение.** Лечение забывания: подмешивать старые примеры к новым. Подробно: «Непрерывное обучение: как сеть забывает», шаг 21.
- **Законы масштабирования.** Измеренная связь между размером модели, данными, вычислениями и ошибкой. Подробно: «Спор о масштабировании», шаг 22.

**Этап 5. Сознание**

- **Доступ и переживание.** Доступ: сведения можно использовать для речи и действий; переживание: каково это изнутри. Подробно: «Сознание: что известно и что нет», шаг 23.
- **Трудная проблема.** Почему за работой мозга вообще что-то переживается. Спорно, есть ли она. Подробно: «Трудная проблема сознания», шаг 23.
- **Глобальное рабочее пространство.** Теория: сознательно то, что разослано сразу многим частям мозга. Подробно: «Глобальное рабочее пространство», шаг 24.
- **Вспышка.** Резкий переход сигнала в самоподдерживающуюся активность, «всё или ничего». Подробно: «Глобальное рабочее пространство», шаг 24.
- **IIT и Φ.** Теория интегрированной информации и её мера неделимости системы. Спорная теория. Подробно: «Интегрированная информация», шаг 24.
- **Метапознание.** Знание о своём знании, например умение понять, что ты, скорее всего, ошибся. Подробно: «Мысль о мысли и предсказание», шаг 24.
- **Предсказательная обработка.** Взгляд, что мозг всё время предсказывает вход и исправляет ошибки предсказания. Подробно: «Мысль о мысли и предсказание», шаг 24.
- **Маскировка.** Опыт: стимул показывают на миг и сразу закрывают узором, и его замечают не всегда. Подробно: «Опыты о сознании», шаг 25.
- **d′.** Мера чувствительности, отделённая от смелости говорить «вижу». Подробно: «Опыты о сознании», шаг 25.
- **Индикаторы сознания.** Признаки устройства системы, важные для нескольких теорий. Их сумма не вероятность. Подробно: «Индикаторы: проверка настоящей системы», шаг 25.
- **Самоотчёт.** Что система говорит о себе. У языковой модели он сильно зависит от обучения и подсказки. Подробно: «Что говорят о себе языковые модели», шаг 25.
- **Функционализм.** Взгляд, что для сознания важно, что система делает, а не из чего сделана. Подробно: «Биология или функция», шаг 26.
- **Биологический взгляд.** Взгляд, что сознание связано с жизнью и телом, и одной функции мало. Подробно: «Биология или функция», шаг 26.
- **Моральный статус.** Есть ли у системы интересы, которые нужно учитывать. Зависит от того, может ли она переживать. Подробно: «Моральный статус и цена двух ошибок», шаг 26.

### Исследуй и потренируйся

В тренажёре ниже напиши часть слова в поле поиска или выбери этап, и список сузится. Затем нажми «Проверь себя»: тренажёр покажет объяснение, а ты выбери слово из четырёх. Цель: пять верных ответов подряд.

### Вопрос

Ты встретил в уроке слово «градиент» и не понял его. Что лучше всего сделать?

### Варианты

- Найти слово в словаре, а потом открыть урок из ссылки и посчитать там пример
- Читать дальше, не останавливаясь: смысл слова станет ясен сам собой позже
- Сразу перейти к следующему этапу пути, где это слово больше не встретится

### Ответ

1

### Разбор

Короткое объяснение даёт опору, а пример с числами в уроке даёт понимание. Пропускать слово опасно: в этом курсе каждое следующее понятие опирается на прошлые, и пробел растёт. Слово «градиент» встречается и на следующих этапах, например в RLHF и дообучении.

### Границы модели

Словарь упрощает. Он не заменяет уроки и не даёт строгих определений. Спорные слова описаны так, как их используют в курсе, а у разных авторов значения бывают другие.

## English

### In plain words

This is a reference, not an ordinary lesson. It has 112 words of the AI path, each with one or two plain sentences and a link to the lesson that covers it in detail. Like the glossary at the back of a textbook: you do not read it straight through, you look in when you stumble. Words go by path stage, in the order they appear.

**What to know first.** Nothing.

**If something is unclear.** If the short explanation is not enough, open the linked lesson: there the word is explained on an example with numbers.

### Goal

Quickly find what a word on the AI path means and which lesson covers it in detail. Test yourself: recognise a word from its explanation.

### Idea and mechanism

The explanations here are short and so they simplify. The exact meaning is always in the linked lesson. Where a word is disputed, such as "AGI" or "consciousness", a working meaning is given here, not a final one.

**Stage 1. Hands on first**

- **Language model.** A program that guesses the next token from the start of a text. It writes text by repeating this guess many times. In detail: «A live model on your Mac: tokens and temperature», step 1.
- **Weights, or parameters.** The numbers inside a model, chosen during training. Everything the model "can do" is stored only in them. In detail: «A live model on your Mac: tokens and temperature», step 1.
- **Ollama.** A Mac program that loads a model file into memory and computes with it. It works offline. In detail: «A live model on your Mac: tokens and temperature», step 1.
- **Token.** A piece of text a model works with: a word, part of a word or a symbol. In detail: «A live model on your Mac: tokens and temperature», step 1.
- **Temperature.** A number that decides how boldly a model picks a token. Lower means closer to the most likely one, higher means rare ones more often. In detail: «A live model on your Mac: tokens and temperature», step 1.
- **Role.** A mark in chat text saying who speaks: the system, the user or the assistant. In detail: «A chat is text: roles and the memory that is not there», step 1.
- **System prompt.** Text at the start of a chat with rules for the model. It is not a wall: the model can break it. In detail: «A chat is text: roles and the memory that is not there», step 1.
- **Context window.** How many tokens a model can read at once. Whatever does not fit, it does not see. In detail: «A chat is text: roles and the memory that is not there», step 1.
- **Hallucination.** A confident but made-up answer. A model writes plausible text, not a checked fact. In detail: «How a model errs and how to check it», step 1.
- **Confidence versus accuracy.** A high probability for an answer does not mean it is right. You check with questions whose answers are known. In detail: «How a model errs and how to check it», step 1.
- **Prompt.** The text you give a model: the request, rules and examples. In detail: «How to ask: instructions, examples, JSON», step 1.
- **JSON.** A strict way of writing data as "name: value" pairs. A program reads it without guessing. In detail: «How to ask: instructions, examples, JSON», step 1.

**Stage 2. Building**

- **Variable.** A name bound to a value, like a label on a box. In detail: «Variables and Data Types», step 2.
- **Function.** A named piece of a program: it takes data and returns a result. In detail: «Conditions, Loops, and Functions», step 2.
- **Loop.** Repeating the same steps while there is data or a condition holds. In detail: «Conditions, Loops, and Functions», step 2.
- **List and index.** A list is a row of values in order; an index is a place number, counted from zero. In detail: «Collections and Loops», step 2.
- **Exception.** Python's "there is an error here" signal with its name. It can be caught and handled. In detail: «Strings, Files, and Exceptions», step 2.
- **Class and object.** A class is a blueprint; an object is a thing built from it with its own data. In detail: «Python Classes: Objects, Inheritance, and Composition», step 2.
- **Vector.** A row of numbers, for example `(3, 4)`. It describes a point, a direction or a word. In detail: «Vectors and Matrices: The Dot Product and a Neural-Network Layer», step 3.
- **Dot product.** Multiply two vectors' numbers in pairs and add them. It is large when the vectors point the same way. In detail: «Vectors and Matrices: The Dot Product and a Neural-Network Layer», step 3.
- **Matrix.** A table of numbers. Multiplying a matrix by a vector is exactly what one network layer does. In detail: «Vectors and Matrices: The Dot Product and a Neural-Network Layer», step 3.
- **Derivative.** The rate of change right now, like a speedometer reading. In detail: «The Derivative as an Instantaneous Rate of Change», step 4.
- **Gradient.** The set of partial derivatives. It points where a function grows fastest. In detail: «Partial Derivatives and the Gradient: How a Neural Network Learns», step 4.
- **Gradient descent.** Lowering the error in small steps against the gradient. In detail: «Gradient Descent and the Learning Rate», step 4.
- **Learning rate.** How far to step in descent. Too small is slow, too large blows up. In detail: «Gradient Descent and the Learning Rate», step 4.
- **Median.** The middle number of a row sorted in order. It is barely affected by outliers. In detail: «Describing data: center, spread, and potential outliers», step 5.
- **Conditional probability.** A share of cases within part of the cases: "among the sick, how many test positive". In detail: «Probability and Bayes' Rule», step 5.
- **Bayes' rule.** A way to flip a conditional probability and account for how common something is overall. In detail: «Probability and Bayes' Rule», step 5.
- **Expected value.** The average outcome over very many repeats. In detail: «Random Variables and Sampling», step 5.
- **Variance.** How widely the outcomes scatter around the average. In detail: «Random Variables and Sampling», step 5.
- **Entropy.** A source's average surprise in bits. The larger it is, the harder to guess. In detail: «Information, Entropy, and Cross-Entropy», step 6.
- **Cross-entropy.** A model's average surprise at real data. Training a language model lowers exactly this. In detail: «Information, Entropy, and Cross-Entropy», step 6.
- **Softmax.** A rule that turns any scores into probabilities adding up to 1. In detail: «Classification and Softmax», step 7.
- **Neuron.** Multiplies inputs by weights, adds them up with a bias and passes the sum through an activation function. In detail: «A Neural Network Learns: Backpropagation», step 8.
- **Backpropagation.** A way to find how much each weight is to blame for the error, going back from the error by the chain rule. In detail: «A Neural Network Learns: Backpropagation», step 8.
- **Hidden layer.** Neurons between input and output. They build new features that make the task simple. In detail: «The Hidden Layer: A Network Learns XOR», step 8.
- **Sigmoid.** A function that squeezes any number into the range from 0 to 1. In detail: «The Hidden Layer: A Network Learns XOR», step 8.
- **Gradient engine, autograd.** A program that computes derivatives itself: each number remembers how it was made. In detail: «Your own gradient engine», step 8.
- **Baseline.** The simplest solution to compare against. A model worse than it has learned nothing. In detail: «Machine Learning: Baselines and Held-out Evaluation», step 9.
- **Held-out evaluation.** Data hidden from the model during training. Only on it can you see whether it learned. In detail: «Machine Learning: Baselines and Held-out Evaluation», step 9.
- **Overfitting.** The model has memorised the training examples but errs on new ones. In detail: «Mini-Batches and Overfitting», step 9.
- **Mini-batch.** A small packet of examples for one training step. In detail: «Mini-Batches and Overfitting», step 9.
- **Optimizer.** The rule for a training step: plain descent, momentum, Adam. In detail: «Optimizers: momentum and Adam», step 9.
- **Adam.** An optimizer with inertia and its own step size for each number. In detail: «Optimizers: momentum and Adam», step 9.
- **Normalization.** Rescaling a layer's numbers to mean 0 and spread 1, so the signal neither fades nor blows up. In detail: «Initialization and normalization», step 9.
- **BPE.** A way to build a token vocabulary: repeatedly glue the most frequent pair of pieces. In detail: «Your own tokenizer», step 10.
- **Bigram, pair counter.** The simplest language model: it counts which character most often follows which. In detail: «A pair counter: the first language model», step 10.
- **Embedding.** A list of numbers a model uses to stand for a token. Tokens with similar meaning get similar lists. In detail: «Embeddings and Similarity», step 10.
- **Cosine similarity.** How much two vectors point the same way: 1 the same, 0 at a right angle. In detail: «Embeddings and Similarity», step 10.
- **Attention.** The way each token itself chooses which earlier tokens to look at. In detail: «The Attention Mechanism», step 11.
- **Query, key, value.** What a token looks for, what it offers, and what it passes on if chosen. In detail: «The Attention Mechanism», step 11.
- **Future mask.** A ban on looking at tokens not yet written. In detail: «The Attention Mechanism», step 11.
- **Transformer.** The design of large language models: many identical blocks with attention and a small network. In detail: «The Transformer Block», step 11.
- **ReLU.** An activation function: it keeps a positive number as it is and replaces a negative one with zero. In detail: «The Transformer Block», step 11.
- **Residual connection.** The form `x + F(x)`: the new is added to the old, and the error easily reaches the lower layers. In detail: «The Transformer Block», step 11.
- **Top-k and top-p.** Choosing the next token only from the most likely few: the best `k`, or the best that together reach share `p`. In detail: «How a model picks words: top-k, top-p and beam search», step 12.
- **Beam search.** Keeping several best continuations at once and picking the most likely one as a whole. In detail: «How a model picks words: top-k, top-p and beam search», step 12.

**Stage 3. Improving**

- **Reinforcement learning.** Learning not from given answers but from the reward for your own actions. In detail: «Slot machines: explore or exploit», step 13.
- **Agent and environment.** The agent acts; the environment answers with a new situation and a reward. In detail: «Slot machines: explore or exploit», step 13.
- **Exploration and exploitation.** The dilemma: try something new or take what already seems best. In detail: «Slot machines: explore or exploit», step 13.
- **Regret.** How much reward was lost compared with the best choice. In detail: «Slot machines: explore or exploit», step 13.
- **State and policy.** The state is where the agent is now; the policy is its rule for choosing an action. In detail: «A grid world and the Bellman equation», step 13.
- **Value.** How much reward you can get starting from this state. In detail: «A grid world and the Bellman equation», step 13.
- **Discount.** A number below 1: a reward later is worth a little less than a reward now. In detail: «A grid world and the Bellman equation», step 13.
- **Bellman equation.** A state's value equals the step's reward plus the discount times the next state's value. In detail: «A grid world and the Bellman equation», step 13.
- **Q-learning.** The agent learns an estimate `Q` for each "state and action" pair from its own experience only. In detail: «Q-learning: an agent learns on its own», step 13.
- **REINFORCE.** A method that makes actions with good reward more likely and those with bad reward less likely. In detail: «The policy gradient: REINFORCE», step 13.
- **Baseline (in RL).** The average reward subtracted so that "good" means "better than usual". In detail: «The policy gradient: REINFORCE», step 13.
- **Fine-tuning.** Continuing to train a ready model on your own examples instead of training from scratch. In detail: «Fine-tuning and LoRA», step 14.
- **LoRA.** Fine-tuning a small add-on beside frozen weights. It can be removed. In detail: «Fine-tuning and LoRA», step 14.
- **RLHF.** Reinforcement learning on comparisons of answers made by people. In detail: «RLHF: learning from human preferences», step 14.
- **Reward model.** A model that scores answers in a way that matches people's choices. In detail: «RLHF: learning from human preferences», step 14.
- **Leash.** A penalty for the model moving too far from the original during RLHF. In detail: «RLHF: learning from human preferences», step 14.
- **RLVR.** A reward for an answer a program can check itself, for example a task with an exact number. In detail: «Reasoning and verifiable rewards», step 14.
- **Constitutional AI.** A model, not people, compares answers according to written rules. In detail: «Rules instead of people, and DPO», step 14.
- **DPO.** Direct preference optimization: the model is shifted on "better and worse" pairs without a separate reward model. In detail: «Rules instead of people, and DPO», step 14.
- **RAG.** "find, then answer": a program searches for suitable pieces of text and gives them to the model. In detail: «RAG from scratch: search and answer», step 15.
- **Tool-using agent.** A model in a loop writes actions; a program runs them and returns the result. In detail: «Agents and tools: the loop by hand», step 15.
- **Benchmark.** A shared set of tasks used to compare models. In detail: «Evaluation that means something», step 15.
- **Confidence interval.** How far a result can drift by chance. In detail: «Evaluation that means something», step 15.
- **Goodhart's law.** When a number becomes a target, it stops measuring well. In detail: «Evaluation that means something», step 15.
- **Power law.** Error falls as a power of size: on a log graph it is a straight line. In detail: «Scaling laws and the cost of training», step 16.
- **Deduplication.** Removing repeats from training texts. In detail: «Data for a language model: filters and duplicates», step 16.
- **Activation.** The number a neuron gave for this input. In detail: «Probes: what a network knows inside», step 17.
- **Probe.** A small model that guesses a property of the input from activations. It shows the information is there. In detail: «Probes: what a network knows inside», step 17.
- **Superposition.** A network stores more concepts than it has neurons by laying them along directions. In detail: «Superposition: more features than neurons», step 17.
- **Sparse autoencoder.** A network that splits activations into many features, only a few of which are on at a time. In detail: «Sparse features: an autoencoder», step 17.
- **Circuit.** A small set of a network's parts that does a specific job. In detail: «Circuits: which parts of a network do the work», step 17.
- **Reward hacking.** The agent finds a loophole and gets reward without doing what was wanted. In detail: «Safety: what goes wrong», step 18.
- **Sycophancy.** The model agrees with the person even when they are wrong. In detail: «Safety: what goes wrong», step 18.
- **Prompt injection.** Text from an email or a page commands the agent instead of its owner. In detail: «Safety: what goes wrong», step 18.

**Stage 4. The road to AGI**

- **AGI.** Artificial general intelligence. There is no single accepted definition. In detail: «What is intelligence: three definitions», step 19.
- **ARC.** Grid puzzles: guess the rule from a few examples. They test learning something new. In detail: «Measuring general intelligence: ARC», step 19.
- **World model.** An inner "map" of what happens after an action. With it you can learn in imagination. In detail: «World models: learning in imagination», step 20.
- **Tree search.** Looking ahead through possible moves and replies to choose the best move now. In detail: «Planning: tree search», step 20.
- **Catastrophic forgetting.** A network that learns a new task loses the old one. In detail: «Continual learning: how a network forgets», step 21.
- **Replay.** A cure for forgetting: mixing old examples in with new ones. In detail: «Continual learning: how a network forgets», step 21.
- **Scaling laws.** The measured link between model size, data, compute and error. In detail: «The scaling debate», step 22.

**Stage 5. Consciousness**

- **Access and experience.** Access: information can be used for speech and action; experience: what it is like from inside. In detail: «Consciousness: What Is Known and What Is Not», step 23.
- **Hard problem.** Why the brain's work is experienced at all. Whether it exists is disputed. In detail: «The hard problem of consciousness», step 23.
- **Global workspace.** A theory: what is broadcast at once to many parts of the brain is conscious. In detail: «The global workspace», step 24.
- **Ignition.** A sudden switch of a signal into self-sustaining activity, "all or nothing". In detail: «The global workspace», step 24.
- **IIT and Φ.** Integrated information theory and its measure of how indivisible a system is. A disputed theory. In detail: «Integrated information», step 24.
- **Metacognition.** Knowledge about one's own knowledge, for example sensing that you are probably wrong. In detail: «Thoughts about thoughts and prediction», step 24.
- **Predictive processing.** The view that the brain constantly predicts its input and corrects prediction errors. In detail: «Thoughts about thoughts and prediction», step 24.
- **Masking.** An experiment: a stimulus is flashed and at once covered by a pattern, so it is not always noticed. In detail: «Experiments on consciousness», step 25.
- **d′.** A measure of sensitivity separated from boldness in saying "I see it". In detail: «Experiments on consciousness», step 25.
- **Consciousness indicators.** Features of a system's design that matter to several theories. Their sum is not a probability. In detail: «Indicators: checking a real system», step 25.
- **Self-report.** What a system says about itself. In a language model it depends heavily on training and the prompt. In detail: «What language models say about themselves», step 25.
- **Functionalism.** The view that what matters for consciousness is what a system does, not what it is made of. In detail: «Biology or function», step 26.
- **Biological view.** The view that consciousness is tied to life and the body, and function alone is not enough. In detail: «Biology or function», step 26.
- **Moral status.** Whether a system has interests that must be taken into account. It depends on whether it can have experiences. In detail: «Moral status and the cost of two errors», step 26.

### Explore and practise

In the lab below, type part of a word in the search field or pick a stage, and the list narrows. Then press "Test yourself": the lab shows an explanation, and you pick the word out of four. Goal: five right answers in a row.

### Question

You met the word "gradient" in a lesson and did not understand it. What is the best thing to do?

### Options

- Find the word in the glossary, then open the linked lesson and work its example there
- Keep reading without stopping: the meaning of the word will become clear later on
- Move straight on to the next stage of the path, where the word will not appear again

### Answer

1

### Explanation

The short explanation gives a foothold, and the worked example in the lesson gives understanding. Skipping the word is risky: in this course each new idea rests on earlier ones, and the gap grows. The word "gradient" appears in later stages too, for example in RLHF and fine-tuning.

### Limits

The glossary simplifies. It does not replace the lessons and does not give strict definitions. Disputed words are described as this course uses them, and other authors may use them differently.

## Sources

- The explanations are short paraphrases of this course's own lessons, written for this glossary on 2026-11-07. The primary sources for each term are listed in the linked lesson.
- Google, "Machine Learning Glossary", a fuller English glossary of machine learning terms for further reading, page opened 2026-11-07: [developers.google.com](https://developers.google.com/machine-learning/glossary)
- Stanford Encyclopedia of Philosophy, "Consciousness", a survey of consciousness terms for further reading, also linked from «Experiments on consciousness»: [plato.stanford.edu](https://plato.stanford.edu/entries/consciousness/)

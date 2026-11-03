import Foundation

@main
enum NotebookLessonExportVerification {
    static func main() {
        let english = NotebookLessonExport(
            title: "Cell cycle",
            subjectLabel: "Biology",
            isRussian: false,
            sourceCheckedOn: "2026-10-08",
            objective: "Trace DNA replication.",
            theory: "DNA is copied during S phase.",
            practice: "Follow the stages.",
            answer: "DNA synthesis occurs during S phase.",
            checkQuestion: "When is DNA copied?",
            checkOptions: ["During S phase"],
            checkAnswerIndex: 0,
            limitations: "This is a simplified model.",
            sources: "- OpenStax Biology 2e",
            videoActivity: NotebookLessonVideoActivityExport(
                title: "Static and kinetic friction",
                lessonURL: URL(string: "https://www.khanacademy.org/science/physics/forces-newtons-laws/inclined-planes-friction/v/static-and-kinetic-friction-example")!,
                youtubeURL: URL(string: "https://www.youtube.com/watch?v=ZA_D4O6l1lo")!,
                beforeWatching: "Predict what changes when the block starts moving.",
                afterWatching: "Explain why kinetic friction is usually lower."
            )
        ).markdown

        precondition(
            english.contains("**Sources in this lesson last editorially reviewed:** 2026-10-08"),
            "English NotebookLM exports must include the lesson's editorial source-review date. / В экспорт NotebookLM на английском должна попадать дата редакторской проверки источников урока."
        )
        precondition(
            english.range(of: "Sources in this lesson last editorially reviewed")!.lowerBound
                < english.range(of: "## Sources")!.lowerBound,
            "The review date must appear before the source list. / Дата проверки должна стоять перед списком источников."
        )
        precondition(
            english.contains("- OpenStax Biology 2e"),
            "NotebookLM export must preserve the lesson's citations. / Экспорт NotebookLM должен сохранять ссылки урока."
        )
        precondition(
            english.contains("## Video and observation")
                && english.contains("[Open lesson source](https://www.khanacademy.org/science/physics/forces-newtons-laws/inclined-planes-friction/v/static-and-kinetic-friction-example)")
                && english.contains("[Open video on YouTube](https://www.youtube.com/watch?v=ZA_D4O6l1lo)")
                && english.contains("**Before watching:** Predict what changes when the block starts moving.")
                && english.contains("**After watching:** Explain why kinetic friction is usually lower.")
                && english.contains("Caption text is not included in this file")
                && english.contains("when supported captions are available"),
            "NotebookLM export must retain video links and both prompts without claiming captions are present. / Экспорт должен сохранять ссылки и оба вопроса, не утверждая, что субтитры доступны."
        )
        precondition(
            english.contains("## Knowledge check\nWhen is DNA copied?")
                && english.contains("1. During S phase")
                && english.contains("Correct option: 1."),
            "NotebookLM export must retain the question, choices, and answer mapping. / Экспорт NotebookLM должен сохранять вопрос, варианты и соответствие правильного ответа."
        )

        let russian = NotebookLessonExport(
            title: "Клеточный цикл",
            subjectLabel: "Биология",
            isRussian: true,
            sourceCheckedOn: "2026-10-08",
            objective: "Проследить копирование ДНК.",
            theory: "ДНК копируется в S-фазе.",
            practice: "Проследить стадии.",
            answer: "Синтез ДНК происходит в S-фазе.",
            checkQuestion: "Когда копируется ДНК?",
            checkOptions: ["В S-фазе"],
            checkAnswerIndex: 0,
            limitations: "Это упрощённая модель.",
            sources: "- OpenStax Biology 2e",
            videoActivity: NotebookLessonVideoActivityExport(
                title: "Статическое и скользящее трение",
                lessonURL: URL(string: "https://ru.khanacademy.org/science/physics/forces-newtons-laws/inclined-planes-friction/v/static-and-kinetic-friction-example")!,
                youtubeURL: URL(string: "https://www.youtube.com/watch?v=ZA_D4O6l1lo")!,
                beforeWatching: "Предскажи, что изменится при начале движения бруска.",
                afterWatching: "Объясни, почему трение скольжения обычно меньше."
            )
        ).markdown

        precondition(
            russian.contains("**Дата редакторской проверки источников урока:** 2026-10-08"),
            "Russian NotebookLM exports must include the lesson's editorial source-review date. / В экспорт NotebookLM на русском должна попадать дата редакторской проверки источников урока."
        )
        precondition(
            russian.contains("## Проверка понимания\nКогда копируется ДНК?")
                && russian.contains("Правильный вариант: 1."),
            "Russian NotebookLM exports must retain the quiz and its answer mapping. / Экспорт NotebookLM на русском должен сохранять проверочный вопрос и соответствие правильного ответа."
        )
        precondition(
            russian.contains("## Видео и наблюдение")
                && russian.contains("[Открыть материал урока](https://ru.khanacademy.org/science/physics/forces-newtons-laws/inclined-planes-friction/v/static-and-kinetic-friction-example)")
                && russian.contains("[Открыть видео на YouTube](https://www.youtube.com/watch?v=ZA_D4O6l1lo)")
                && russian.contains("**Перед просмотром:** Предскажи, что изменится при начале движения бруска.")
                && russian.contains("**После просмотра:** Объясни, почему трение скольжения обычно меньше.")
                && russian.contains("Текст субтитров не включён в этот файл"),
            "Russian NotebookLM export must retain the video activity and explain transcript availability. / Русский экспорт должен сохранять сценарий видео и пояснение о доступности расшифровки."
        )

        let undated = NotebookLessonExport(
            title: "Topic",
            subjectLabel: "Mathematics",
            isRussian: false,
            sourceCheckedOn: nil,
            objective: "Understand the topic.",
            theory: "",
            practice: "",
            answer: "",
            checkQuestion: "",
            checkOptions: [],
            checkAnswerIndex: nil,
            limitations: "",
            sources: "",
            videoActivity: nil
        ).markdown
        precondition(
            !undated.contains("editorially reviewed")
                && !undated.contains("Video and observation"),
            "An unknown review date must not be invented, and lessons without video must not gain a video section. / Нельзя выдумывать дату проверки и добавлять видео-раздел в урок без видео."
        )

        let invalidDate = NotebookLessonExport(
            title: "Topic",
            subjectLabel: "Mathematics",
            isRussian: false,
            sourceCheckedOn: "2026-10-08\n**Injected heading**",
            objective: "Understand the topic.",
            theory: "",
            practice: "",
            answer: "",
            checkQuestion: "",
            checkOptions: [],
            checkAnswerIndex: nil,
            limitations: "",
            sources: "",
            videoActivity: nil
        ).markdown
        precondition(
            !invalidDate.contains("Sources in this lesson last editorially reviewed")
                && !invalidDate.contains("Injected heading"),
            "Invalid review metadata must not be rendered into Markdown. / Некорректные метаданные проверки нельзя помещать в Markdown."
        )

        let suite = "colidev.verify.obsidian.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        precondition(
            ObsidianLessonCopyMemory.savedPath(subject: "physics", resource: "intro", language: "ru", defaults: defaults) == nil,
            "A lesson that was never saved must offer the save button. / Несохранённый урок должен показывать кнопку сохранения."
        )
        ObsidianLessonCopyMemory.remember(path: "a.md", subject: "physics", resource: "intro", language: "ru", defaults: defaults)
        precondition(
            ObsidianLessonCopyMemory.savedPath(subject: "physics", resource: "intro", language: "ru", defaults: defaults) == "a.md",
            "A saved copy must be remembered. / Сохранённая копия должна запоминаться."
        )
        precondition(
            ObsidianLessonCopyMemory.savedPath(subject: "physics", resource: "intro", language: "en", defaults: defaults) == nil,
            "The English copy is a separate one. / Английская копия отдельная."
        )
        defaults.removePersistentDomain(forName: suite)

        print("NotebookLM lesson export provenance checks passed. / Проверки источников и даты в экспорте NotebookLM прошли.")
    }
}

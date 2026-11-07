import Foundation

struct NotebookLessonVideoActivityExport {
    let title: String
    let lessonURL: URL
    let youtubeURL: URL?
    let beforeWatching: String
    let afterWatching: String
}

struct NotebookLessonExport {
    let title: String
    let subjectLabel: String
    let isRussian: Bool
    let sourceCheckedOn: String?
    let objective: String
    let theory: String
    let practice: String
    let answer: String
    let checkQuestion: String
    let checkOptions: [String]
    let checkAnswerIndex: Int?
    let limitations: String
    let sources: String
    let videoActivity: NotebookLessonVideoActivityExport?

    var markdown: String {
        let goalHeading = isRussian ? "Цель" : "Learning goal"
        let theoryHeading = isRussian ? "Теория и механизм" : "Theory and mechanism"
        let practiceHeading = isRussian ? "Практика" : "Practice"
        let checkHeading = isRussian ? "Проверка понимания" : "Knowledge check"
        let answerHeading = isRussian ? "Правильный ответ и разбор" : "Correct answer and explanation"
        let limitsHeading = isRussian ? "Ограничения" : "Limitations"
        let sourcesHeading = isRussian ? "Источники" : "Sources"
        let videoHeading = isRussian ? "Видео и наблюдение" : "Video and observation"
        let origin = isRussian ? "Экспортировано из Cause & Course" : "Exported from Cause & Course"

        var sections = [
            "# \(title)",
            "**\(isRussian ? "Предмет" : "Subject"): \(subjectLabel)**",
            "*\(origin)*",
        ]
        if let sourceReviewLine {
            sections.append(sourceReviewLine)
        }
        sections.append("## \(goalHeading)\n\(objective)")
        sections.append("## \(theoryHeading)\n\(theory)")

        if !practice.isEmpty {
            sections.append("## \(practiceHeading)\n\(practice)")
        }
        if let videoActivity {
            let lessonLinkLabel = isRussian ? "Открыть материал урока" : "Open lesson source"
            let youtubeLinkLabel = isRussian ? "Открыть видео на YouTube" : "Open video on YouTube"
            let beforeLabel = isRussian ? "Перед просмотром" : "Before watching"
            let afterLabel = isRussian ? "После просмотра" : "After watching"
            let transcriptNote = isRussian
                ? "Текст субтитров не включён в этот файл. Gemini Notebook может импортировать расшифровку из публичного видео YouTube, если для него доступны поддерживаемые субтитры."
                : "Caption text is not included in this file. Gemini Notebook may import a transcript from a public YouTube video when supported captions are available."
            var videoSection = "## \(videoHeading)\n\n**\(videoActivity.title)**\n\n[\(lessonLinkLabel)](\(videoActivity.lessonURL.absoluteString))"
            if let youtubeURL = videoActivity.youtubeURL {
                videoSection += "\n\n[\(youtubeLinkLabel)](\(youtubeURL.absoluteString))"
            }
            videoSection += "\n\n**\(beforeLabel):** \(videoActivity.beforeWatching)\n\n**\(afterLabel):** \(videoActivity.afterWatching)\n\n> \(transcriptNote)"
            sections.append(videoSection)
        }
        if !checkQuestion.isEmpty {
            var check = "## \(checkHeading)\n\(checkQuestion)"
            for (index, option) in checkOptions.enumerated() {
                check += "\n\n\(index + 1). \(option)"
            }
            sections.append(check)
        }
        if let checkAnswerIndex {
            let answerLabel = isRussian ? "Правильный вариант" : "Correct option"
            sections.append("## \(answerHeading)\n\(answerLabel): \(checkAnswerIndex + 1).\n\n\(answer)")
        } else if !answer.isEmpty {
            sections.append("## \(answerHeading)\n\(answer)")
        }
        if !limitations.isEmpty {
            sections.append("## \(limitsHeading)\n\(limitations)")
        }
        if !sources.isEmpty {
            sections.append("## \(sourcesHeading)\n\(sources)")
        }
        return sections.joined(separator: "\n\n") + "\n"
    }

    private var sourceReviewLine: String? {
        guard let date = sourceCheckedOn?.trimmingCharacters(in: .whitespacesAndNewlines),
              date.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else {
            return nil
        }
        let label = isRussian
            ? "Дата редакторской проверки источников урока"
            : "Sources in this lesson last editorially reviewed"
        return "**\(label):** \(date)"
    }
}

/// Remembers the vault path of a lesson's saved copy, so that a second click cannot quietly add another file.
/// Помнит путь сохранённой копии урока в vault, чтобы повторное нажатие не добавляло новый файл незаметно.
enum ObsidianLessonCopyMemory {
    private static func key(subject: String, resource: String, language: String) -> String {
        "colidev.obsidianCopy.\(subject).\(resource).\(language)"
    }

    static func savedPath(subject: String, resource: String, language: String, defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key(subject: subject, resource: resource, language: language))
    }

    static func remember(path: String, subject: String, resource: String, language: String, defaults: UserDefaults = .standard) {
        defaults.set(path, forKey: key(subject: subject, resource: resource, language: language))
    }
}

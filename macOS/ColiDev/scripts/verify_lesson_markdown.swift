import Foundation

@main
enum LessonMarkdownVerification {
    static func main() {
        let paragraphs = """
        Единица частоты — герц (Гц): одно колебание в секунду.

        У простого маятника — груза на нити — период равен `T = 2π√(L/g)`.
        """
        let paragraphText = LessonMarkdown.plainText(paragraphs)
        precondition(
            paragraphText.contains("в секунду.\n\nУ простого маятника"),
            "Paragraphs must stay separated instead of gluing into \"секунду.У\". / Абзацы не должны склеиваться в «секунду.У»: \(paragraphText)"
        )
        precondition(
            paragraphText.contains("T = 2π√(L/g)") && !paragraphText.contains("`"),
            "Inline code must render without backticks. / Инлайн-код должен отображаться без обратных кавычек."
        )

        let withCode = "Первый абзац.\n\nВторой абзац.\n\n```bash\nollama list\n```\n\nТретий."
        precondition(
            LessonMarkdown.segments(withCode) == [.prose("Первый абзац.\n\nВторой абзац."), .code("ollama list"), .prose("Третий.")],
            "Code blocks must be separate segments, and paragraphs must stay together. / Блоки кода отделяются, абзацы остаются вместе."
        )

        let list = """
        Дальше идут три коротких абзаца:

        1. Зачем ты пишешь: `I just wanted to say thank you for the weekend.`
        2. Подробности или пример: `Your family was so kind.`
        """
        let listText = LessonMarkdown.plainText(list)
        precondition(
            listText.contains("абзаца:\n\n1. Зачем ты пишешь: I just wanted to say thank you for the weekend.\n2. Подробности"),
            "List items must keep their own lines. / Пункты списка должны оставаться на отдельных строках: \(listText)"
        )

        let quiz = "На ровной поверхности лежит тело массой `5 кг`; `μ_s = 0,4`, а толчок равен **`15 Н`**."
        let quizText = LessonMarkdown.plainText(quiz)
        precondition(
            quizText == "На ровной поверхности лежит тело массой 5 кг; μ_s = 0,4, а толчок равен 15 Н.",
            "Check questions and options must not show raw Markdown. / Вопросы и варианты не должны показывать сырой Markdown: \(quizText)"
        )
        let quizAttributed = LessonMarkdown.attributed(quiz)
        precondition(
            quizAttributed.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true },
            "Inline code must keep its code styling. / Инлайн-код должен сохранить оформление кода."
        )

        let code = """
        Тот же опыт на чистом Python:

        ```python
        def loss(w):
            return w * w


        print(loss(2))
        ```

        Точки придуманы для урока.
        """
        let codeAttributed = LessonMarkdown.attributed(code)
        let codeText = String(codeAttributed.characters)
        precondition(
            codeText == "Тот же опыт на чистом Python:\n\ndef loss(w):\n    return w * w\n\n\nprint(loss(2))\n\nТочки придуманы для урока.",
            "Fenced code must keep indentation and blank lines without the fence markers. / Блок кода должен сохранить отступы и пустые строки без ограничителей: \(codeText)"
        )
        precondition(
            codeAttributed.runs.contains { run in
                run.inlinePresentationIntent?.contains(.code) == true
                    && String(codeAttributed[run.range].characters).contains("return w * w")
            },
            "Fenced code must render as code. / Блок кода должен отображаться как код."
        )

        precondition(
            LessonMarkdown.plainText("Plain text without Markdown.") == "Plain text without Markdown.",
            "Plain text must pass through unchanged. / Обычный текст должен остаться без изменений."
        )
        precondition(LessonMarkdown.plainText("") == "", "Empty text stays empty. / Пустой текст остаётся пустым.")

        print("Lesson Markdown verification passed / Проверка Markdown уроков пройдена")
    }
}

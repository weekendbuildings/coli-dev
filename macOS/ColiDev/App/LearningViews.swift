import Foundation
import Combine
import SwiftUI
import AppKit
import AVFoundation
import SceneKit
import WebKit
import UniformTypeIdentifiers

struct SubjectOverviewView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var levels: [CurriculumLevel] = []
    @State private var showingCustomTopicEditor = false
    @State private var customTopicParentID: UUID?
    @State private var pendingCustomTopicID: UUID?
    @State private var showingCustomTopicDelete = false
    @AppStorage(StudyProgressionPolicy.previewLockedLessonsDefaultsKey) private var previewLockedLessons = false

    let subject: Subject
    let openCourseLesson: (String) -> Void
    let openCustomTopic: (UUID) -> Void
    let startLesson: () -> Void

    private var studyRoadmap: StudyRoadmap {
        let progressionLevels = levels.map { $0.topics.compactMap(\.lessonResource) }
        return StudyRoadmap(
            subjectID: subject.rawValue,
            lessonResources: progressionLevels.flatMap { $0 },
            progressionLevels: progressionLevels
        )
    }

    private func isCourseLessonAvailable(_ resource: String) -> Bool {
        StudyProgressionPolicy.isAvailable(
            StudyLessonRoute(subjectID: subject.rawValue, resource: resource),
            in: studyRoadmap,
            evidence: store.studyProgressionEvidence
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("roadmap.eyebrow", store.language))
                        .font(.caption.weight(.semibold))
                        .tracking(1.3)
                        .foregroundStyle(subject.tint)
                    Text(subject.title(in: store.language))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(subject.subtitle(in: store.language))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("roadmap.title", store.language))
                        .font(.title2.weight(.semibold))
                        .padding(.top, 6)
                    Text(L10n.text("roadmap.description", store.language))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: startLesson) {
                        Label {
                            Text(L10n.text("roadmap.start", store.language))
                        } icon: {
                            Image(systemName: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(subject.tint)
                    .padding(.top, 4)
                }
                .padding(.top, 26)

                if levels.isEmpty {
                    Label {
                        Text(L10n.text("roadmap.unavailable", store.language))
                    } icon: {
                        Image(systemName: "doc.questionmark")
                    }
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    ForEach(levels) { level in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(level.title.value(in: store.language))
                                    .font(.title2.weight(.semibold))
                                Spacer()
                                Text(L10n.text("roadmap.topicCount", store.language) + "\(level.topics.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if level.topics.contains(where: { topic in
                                guard let resource = topic.lessonResource else { return false }
                                return !isCourseLessonAvailable(resource)
                            }) {
                                Label(
                                    L10n.text("roadmap.prerequisiteCheck", store.language),
                                    systemImage: "lock.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            ForEach(level.topics) { topic in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(topic.name.value(in: store.language))
                                        .font(.headline)
                                    Text(topic.learningOutcome.value(in: store.language))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let lessonResource = topic.lessonResource {
                                        let isAvailable = isCourseLessonAvailable(lessonResource)
                                        let isPreview = !isAvailable
                                            && (previewLockedLessons || StudyProgressionPolicy.previewLockedLessonsForUITest)
                                        Button { openCourseLesson(lessonResource) } label: {
                                            Label(
                                                L10n.text(isPreview ? "roadmap.previewLesson" : "roadmap.openFullLesson", store.language),
                                                systemImage: isAvailable
                                                    ? (store.isComplete(lessonID: "\(subject.rawValue).\(lessonResource)")
                                                        ? "checkmark.circle.fill"
                                                        : "book.closed")
                                                    : (isPreview ? "eye" : "lock.fill")
                                            )
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(!isAvailable && !isPreview)
                                        .padding(.top, 3)
                                        .accessibilityIdentifier("roadmap.lesson.\(subject.rawValue).\(lessonResource)")
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, lineWidth: 1))
                            }
                        }
                        .padding(18)
                        .background(subject.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.text("custom.myTopics", store.language)).font(.title2.weight(.semibold))
                        Spacer()
                        Button {
                            customTopicParentID = nil
                            showingCustomTopicEditor = true
                        } label: {
                            Label(L10n.text("custom.addTopic", store.language), systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                    if store.customCurriculum.topics(builtInSubjectID: subject.rawValue).isEmpty {
                        Text(L10n.text("custom.addToBuiltInHint", store.language))
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.customCurriculum.topics(builtInSubjectID: subject.rawValue)) { topic in
                            CustomTopicBranch(
                                topic: topic,
                                language: store.language,
                                lessonID: { CustomTopicStudyRoute.builtInTopic(subjectID: subject.rawValue, topicID: $0).lessonID },
                                open: { openCustomTopic($0) },
                                addChild: { customTopicParentID = $0; showingCustomTopicEditor = true },
                                delete: { pendingCustomTopicID = $0; showingCustomTopicDelete = true }
                            )
                        }
                    }
                }
                .padding(18)
                .background(subject.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 32)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(Text(subject.title(in: store.language)))
        .onAppear { levels = CurriculumCatalog.roadmap(for: subject) }
        .sheet(isPresented: $showingCustomTopicEditor) {
            CustomTopicEditor(builtInSubject: subject, parentTopicID: customTopicParentID) {}
                .environmentObject(store)
        }
        .confirmationDialog(
            L10n.text("custom.deleteTopic", store.language),
            isPresented: $showingCustomTopicDelete,
            titleVisibility: .visible
        ) {
            Button(L10n.text("custom.deleteTopic", store.language), role: .destructive) {
                if let pendingCustomTopicID {
                    store.removeCustomTopic(builtInSubject: subject, topicID: pendingCustomTopicID)
                }
                pendingCustomTopicID = nil
            }
            Button(L10n.text("common.cancel", store.language), role: .cancel) { pendingCustomTopicID = nil }
        } message: {
            Text(L10n.text("custom.confirmDeleteTopic", store.language))
        }
    }
}

private struct CurriculumLessonDocument {
    let title: String
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
    let videoActivity: CurriculumLessonVideoActivity?

    static func load(subject: Subject, resource: String, language: AppLanguage) -> CurriculumLessonDocument? {
        guard let raw = CurriculumCatalog.lessonMarkdown(for: subject, resource: resource) else { return nil }
        let sourceCheckedOn = raw.components(separatedBy: .newlines)
            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("source_checked:") })?
            .split(separator: ":", maxSplits: 1)
            .last
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
        var lines = raw.components(separatedBy: .newlines)
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            lines = Array(lines.dropFirst(end + 1))
        }
        guard let titleLine = lines.first(where: { $0.hasPrefix("# ") }) else { return nil }
        let titleValue = String(titleLine.dropFirst(2))
        let titleParts = titleValue.components(separatedBy: " / ")
        let title = language == .ru ? titleParts.first ?? titleValue : titleParts.last ?? titleValue

        let languageHeader = language == .ru ? "## Русский" : "## English"
        guard let languageStart = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == languageHeader }) else {
            return nil
        }
        let languageLines = Array(lines.dropFirst(languageStart + 1))
            .prefix(while: { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("## ") })
        let section = languageLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let objective = extract(section, headings: language == .ru ? ["Цель"] : ["Goal"])
        let theory = extract(section, headings: language == .ru ? ["Идея и механизм"] : ["Idea and mechanism"])
        var practice = extract(section, headings: language == .ru
            ? ["Исследуй и потренируйся"]
            : ["Explore and practise", "Explore and practice"])
        let checkQuestion = extract(section, headings: language == .ru ? ["Вопрос"] : ["Question"])
        let checkOptions = parseOptions(extract(section, headings: language == .ru ? ["Варианты"] : ["Options"]))
        let checkAnswer = Int(extract(section, headings: language == .ru ? ["Ответ"] : ["Answer"]).trimmingCharacters(in: .whitespacesAndNewlines))
        let checkAnswerIndex = checkAnswer.map { $0 - 1 }.flatMap { checkOptions.indices.contains($0) ? $0 : nil }
        let answer = extract(section, headings: language == .ru ? ["Разбор"] : ["Explanation"])
        let limitations = extract(section, headings: language == .ru
            ? ["Границы модели", "Границы правила", "Границы вывода", "Границы и безопасный запуск"]
            : ["Limits", "Limits of the inference", "Limits and safe execution"])
        let sourceLines = lines.drop { $0.trimmingCharacters(in: .whitespaces) != "## Sources" }.dropFirst()
        let sources = sourceLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let videoSection = extract(
            section,
            headings: language == .ru ? ["Видео и наблюдение"] : ["Video and observation"]
        )
        return CurriculumLessonDocument(
            title: title,
            sourceCheckedOn: sourceCheckedOn,
            objective: objective,
            theory: theory,
            practice: practice,
            answer: answer,
            checkQuestion: checkQuestion,
            checkOptions: checkOptions,
            checkAnswerIndex: checkAnswerIndex,
            limitations: limitations,
            sources: sources,
            videoActivity: CurriculumLessonVideoActivity.parse(videoSection, language: language)
        )
    }

    var tutorContext: LessonContent {
        LessonContent(
            title: title,
            objective: objective,
            explanation: theory,
            mechanism: practice,
            example: answer,
            limitations: limitations,
            question: "",
            options: [],
            answerIndex: 0,
            feedback: answer
        )
    }

    func notebookSource(subject: Subject, language: AppLanguage) -> String {
        NotebookLessonExport(
            title: title,
            subjectLabel: subject.title(in: language),
            isRussian: language == .ru,
            sourceCheckedOn: sourceCheckedOn,
            objective: objective,
            theory: theory,
            practice: practice,
            answer: answer,
            checkQuestion: checkQuestion,
            checkOptions: checkOptions,
            checkAnswerIndex: checkAnswerIndex,
            limitations: limitations,
            sources: sources,
            videoActivity: videoActivity.map { activity in
                NotebookLessonVideoActivityExport(
                    title: activity.title,
                    lessonURL: activity.url,
                    youtubeURL: activity.youtubeVideoID.flatMap { URL(string: "https://www.youtube.com/watch?v=\($0)") },
                    beforeWatching: activity.beforeWatching,
                    afterWatching: activity.afterWatching
                )
            }
        ).markdown
    }

    private static func extract(_ markdown: String, headings: [String]) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("### ") && headings.contains(String(trimmed.dropFirst(4)))
        }) else { return "" }
        let body = lines.dropFirst(start + 1).prefix(while: {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("### ")
        })
        return body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseOptions(_ markdown: String) -> [String] {
        markdown.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            guard let range = trimmed.range(of: "^\\d+[.)]\\s+", options: .regularExpression) else { return nil }
            return String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
    }
}

private struct CurriculumLessonVideoActivity {
    let title: String
    let url: URL
    let youtubeVideoID: String?
    let beforeWatching: String
    let afterWatching: String

    static func parse(_ section: String, language: AppLanguage) -> CurriculumLessonVideoActivity? {
        let pattern = #"\[([^\]]+)\]\((https://[^\s)]+)\)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: section,
                range: NSRange(section.startIndex..<section.endIndex, in: section)
              ),
              let titleRange = Range(match.range(at: 1), in: section),
              let urlRange = Range(match.range(at: 2), in: section) else {
            return nil
        }

        let rawURL = String(section[urlRange])
        guard let components = URLComponents(string: rawURL),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              ["ru.khanacademy.org", "www.khanacademy.org"].contains(host),
              let url = components.url else {
            return nil
        }

        let beforeLabel = language == .ru ? "**Перед просмотром:**" : "**Before watching:**"
        let afterLabel = language == .ru ? "**После просмотра:**" : "**After watching:**"
        func value(after label: String) -> String? {
            section.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { $0.hasPrefix(label) })
                .map { String($0.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 }
        }
        guard let beforeWatching = value(after: beforeLabel),
              let afterWatching = value(after: afterLabel) else {
            return nil
        }
        let youtubePattern = #"https://(?:www\.)?youtube\.com/watch\?(?:[^\s)]*&)?v=([A-Za-z0-9_-]{11})"#
        let youtubeExpression = try? NSRegularExpression(pattern: youtubePattern)
        let youtubeRange = NSRange(section.startIndex..<section.endIndex, in: section)
        let youtubeVideoID = youtubeExpression?
            .firstMatch(in: section, range: youtubeRange)
            .flatMap { Range($0.range(at: 1), in: section) }
            .map { String(section[$0]) }
        return CurriculumLessonVideoActivity(
            title: String(section[titleRange]),
            url: url,
            youtubeVideoID: youtubeVideoID,
            beforeWatching: beforeWatching,
            afterWatching: afterWatching
        )
    }
}

private struct CurriculumLessonVideoCard: View {
    let activity: CurriculumLessonVideoActivity
    let tint: Color
    let language: AppLanguage
    @Binding var reflection: String
    @Binding var hasConfirmedWatching: Bool
    @State private var hasConsentedToYouTube = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.text("lesson.video.title", language), systemImage: "play.rectangle.fill")
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("lesson.video.title")

            Text(activity.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text("lesson.video.beforeLabel", language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(LessonMarkdown.attributed(activity.beforeWatching))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("lesson.video.before")
            }

            if let videoID = activity.youtubeVideoID {
                if hasConsentedToYouTube {
                    YouTubeLessonPlayer(videoID: videoID, captionLanguage: language)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(minHeight: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(L10n.text("lesson.video.privacyNotice", language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("lesson.video.privacyNotice")

                    if let privacyURL = URL(string: "https://policies.google.com/privacy") {
                        Link(destination: privacyURL) {
                            Text(L10n.text("lesson.video.googlePrivacy", language))
                        }
                        .font(.caption)
                    }

                    Button {
                        hasConsentedToYouTube = true
                    } label: {
                        Label(L10n.text("lesson.video.enablePlayback", language), systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .accessibilityIdentifier("lesson.video.enablePlayback")
                }
            }

            Link(destination: activity.url) {
                Label(L10n.text("lesson.video.open", language), systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .accessibilityIdentifier("lesson.video.open")

            Text(L10n.text("lesson.video.attribution", language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.text("lesson.video.captionHelp", language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lesson.video.captionHelp")

            if !hasConfirmedWatching && (activity.youtubeVideoID == nil || hasConsentedToYouTube) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasConfirmedWatching = true
                    }
                } label: {
                    Label(L10n.text("lesson.video.markWatched", language), systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("lesson.video.markWatched")
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson.video.activity")
    }
}

private struct YouTubeLessonPlayer: NSViewRepresentable {
    let videoID: String
    let captionLanguage: AppLanguage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setAccessibilityIdentifier("lesson.video.player")
        webView.underPageBackgroundColor = .black
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.load(videoID, captionLanguage: captionLanguage, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(videoID, captionLanguage: captionLanguage, into: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var loadedURL: URL?

        func load(_ videoID: String, captionLanguage: AppLanguage, into webView: WKWebView) {
            guard let url = YouTubeEmbedURLBuilder.make(
                videoID: videoID,
                captionLanguage: captionLanguage.rawValue
            ), loadedURL != url else {
                return
            }
            loadedURL = url
            var request = URLRequest(url: url)
            request.setValue(YouTubeEmbedURLBuilder.appReferer, forHTTPHeaderField: "Referer")
            webView.load(request)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  navigationAction.targetFrame?.isMainFrame ?? true,
                  let url = navigationAction.request.url,
                  url.scheme?.lowercased() == "https" else {
                decisionHandler(.allow)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url,
                  url.scheme?.lowercased() == "https" else {
                return nil
            }
            NSWorkspace.shared.open(url)
            return nil
        }
    }
}

private struct CurriculumCheckOptionButton: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                Text(LessonMarkdown.attributed(title))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.quaternary, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LessonMarkdown.plainText(title)))
        .disabled(isDisabled)
    }
}

struct CurriculumModuleView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var document: CurriculumLessonDocument?
    @State private var showingTutor = false
    @State private var learnerConfirmed = false
    @State private var reflection = ""
    @State private var hasConfirmedWatching = false
    // A learner who already saved an answer after the video sees it as soon as the lesson opens.
    // A new learner still watches first and answers the check before the question appears.
    @State private var showsSavedVideoReflection = false
    @State private var recallQuality = 4
    @State private var checkAttempt: CurriculumCheckAttempt?
    @State private var selectedErrorCategory = ""
    @State private var isCheckExplanationRevealed = false
    @State private var sourceInventory: TrustedSourceInventory?
    @State private var sourceInventoryUnavailable = false
    @State private var isLoadingSourceInventory = false
    @State private var isExportingNotebookSource = false
    @State private var notebookExportDocument: NotebookLMSourceFile?
    @State private var notebookExportFilename = "ColiDev-lesson.md"
    @State private var notebookExportStatus: String?
    @State private var isSavingObsidianNote = false
    @State private var obsidianSaveStatus: String?

    let subject: Subject
    let resource: String
    let progressLessonID: String?
    let focusPracticeOnOpen: Bool
    let onPracticeFocusCompleted: () -> Void

    private var lessonID: String { progressLessonID ?? "\(subject.rawValue).\(resource)" }
    private var isComplete: Bool { store.isComplete(lessonID: lessonID) }
    // UI tests of a first visit start as a new learner even when an earlier test in the same run saved an answer.
    private static var startsAsNewLearnerForUITest: Bool {
        ProcessInfo.processInfo.environment["COLIDEV_UI_TEST_NEW_LEARNER"] == "1"
    }
    private var isReviewDue: Bool { store.isReviewDue(lessonID: lessonID) }
    private var hasPendingReview: Bool { store.hasPendingReview(lessonID: lessonID) }

    init(
        subject: Subject,
        resource: String,
        progressLessonID: String? = nil,
        focusPracticeOnOpen: Bool = false,
        onPracticeFocusCompleted: @escaping () -> Void = {}
    ) {
        self.subject = subject
        self.resource = resource
        self.progressLessonID = progressLessonID
        self.focusPracticeOnOpen = focusPracticeOnOpen
        self.onPracticeFocusCompleted = onPracticeFocusCompleted
    }

    @ViewBuilder
    private var videoActivityContent: some View {
        if let activity = document?.videoActivity {
            CurriculumLessonVideoCard(
                activity: activity,
                tint: subject.tint,
                language: store.language,
                reflection: $reflection,
                // A saved answer means the video was already watched, so the "I finished watching" button is not needed.
                hasConfirmedWatching: showsSavedVideoReflection ? .constant(true) : $hasConfirmedWatching
            )
        }
    }

    @ViewBuilder
    private var postVideoReflectionContent: some View {
        if let activity = document?.videoActivity,
           showsSavedVideoReflection || (hasConfirmedWatching && checkAttempt?.hasAnswered == true) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("lesson.video.afterLabel", store.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(subject.tint)
                Text(LessonMarkdown.attributed(activity.afterWatching))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("lesson.video.after")

                TextField(L10n.text("lesson.video.responsePlaceholder", store.language), text: $reflection, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("lesson.video.response")
                    .onChange(of: reflection) { value in
                        if value.unicodeScalars.count > 500 {
                            reflection = String(String.UnicodeScalarView(value.unicodeScalars.prefix(500)))
                        }
                    }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(subject.tint.opacity(0.25), lineWidth: 1))
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let document {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("session.lesson", store.language))
                            .font(.caption.weight(.semibold))
                            .tracking(1.3)
                            .foregroundStyle(subject.tint)
                        Text(document.title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subject.title(in: store.language) + " · " + L10n.text("roadmap.fullModule", store.language))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    LessonSourceFreshnessCard(
                        inventory: sourceInventory,
                        unavailable: sourceInventoryUnavailable,
                        isLoading: isLoadingSourceInventory,
                        lessonPath: "02_Areas/\(subject.rawValue.capitalized)/lessons/\(resource).md",
                        authorCheckedOn: document.sourceCheckedOn,
                        language: store.language,
                        onRetry: { Task { await loadSourceInventory() } }
                    )

                    Button { showingTutor = true } label: {
                        Label(L10n.text("tutor.title", store.language), systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)

                    ModuleTextCard(title: L10n.text("session.goal", store.language), text: document.objective, tint: subject.tint)
                    ModuleTextCard(title: L10n.text("session.theory", store.language), text: document.theory, tint: subject.tint)
                        .accessibilityIdentifier("lesson.theory")
                    videoActivityContent
                    if !document.practice.isEmpty {
                        ModuleTextCard(title: L10n.text("session.lab", store.language), text: document.practice, tint: subject.tint)
                    }
                    PracticeLab(subject: subject, moduleResource: resource)
                        .id("module-interactive-practice")

                    if !document.checkQuestion.isEmpty, !document.checkOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.text("module.check", store.language))
                                .font(.title2.weight(.semibold))
                            Text(LessonMarkdown.attributed(document.checkQuestion))
                                .font(.headline)
                            if let checkAttempt {
                                ForEach(Array(checkAttempt.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayedIndex, originalIndex in
                                    CurriculumCheckOptionButton(
                                        title: document.checkOptions[originalIndex],
                                        isSelected: checkAttempt.selectedOriginalIndex == originalIndex,
                                        isDisabled: checkAttempt.hasAnswered,
                                        action: { selectCheckAnswer(displayedIndex: displayedIndex) }
                                    )
                                    .accessibilityIdentifier("lesson.check.option.\(originalIndex)")
                                }

                                if checkAttempt.hasAnswered {
                                    let isCorrect = checkAttempt.isCorrect
                                    let feedback = LessonAnswerFeedback.presentation(
                                        isCorrect: isCorrect,
                                        explanationRevealed: isCheckExplanationRevealed,
                                        explanation: document.answer,
                                        correctPrompt: L10n.text("module.correct", store.language),
                                        retryPrompt: L10n.text("module.incorrect", store.language)
                                    )
                                    Label(
                                        feedback.statusMessage,
                                        systemImage: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                                    )
                                    .foregroundStyle(isCorrect ? Color.green : Color.orange)
                                    .accessibilityIdentifier("lesson.check.feedback")

                                    if !isCorrect {
                                        Text(L10n.text("module.errorCategoryPrompt", store.language))
                                            .font(.callout.weight(.medium))
                                        Picker(L10n.text("module.errorCategoryLabel", store.language), selection: $selectedErrorCategory) {
                                            Text(L10n.text("module.errorCategorySkip", store.language)).tag("")
                                            ForEach(StudyErrorCategory.allCases) { category in
                                                Text(L10n.text(category.titleKey, store.language)).tag(category.rawValue)
                                            }
                                        }
                                        .pickerStyle(.menu)

                                        if let category = StudyErrorCategory(rawValue: selectedErrorCategory) {
                                            Text(L10n.text(category.guidanceKey, store.language))
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }

                                        Button {
                                            isCheckExplanationRevealed = true
                                        } label: {
                                            Label(L10n.text("module.showAnswer", store.language), systemImage: "eye")
                                        }
                                        .buttonStyle(.borderless)
                                    }

                                    if isCorrect || isCheckExplanationRevealed {
                                        if !isCorrect {
                                            Text(LessonMarkdown.inline(String(
                                                format: L10n.text("module.correctOption", store.language),
                                                document.checkOptions[checkAttempt.answerOriginalIndex]
                                            )))
                                                .font(.callout.weight(.medium))
                                        }

                                        if let explanation = feedback.explanation {
                                            Text(LessonMarkdown.attributed(explanation))
                                                .textSelection(.enabled)
                                                .padding(.top, 2)
                                        } else {
                                            Text(L10n.text("module.explanationUnavailable", store.language))
                                                .font(.callout)
                                                .foregroundStyle(.orange)
                                        }
                                    }

                                    if checkAttempt.canRetry {
                                        Button(action: retryKnowledgeCheck) {
                                            Label(L10n.text("module.tryAgain", store.language), systemImage: "arrow.counterclockwise")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            } else {
                                Label(L10n.text("module.quizUnavailable", store.language), systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        Label(L10n.text("module.quizUnavailable", store.language), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }

                    postVideoReflectionContent

                    if !document.limitations.isEmpty {
                        ModuleTextCard(title: L10n.text("session.limitations", store.language), text: document.limitations, tint: subject.tint)
                    }
                    if !document.sources.isEmpty {
                        ModuleTextCard(title: L10n.text("module.sources", store.language), text: document.sources, tint: subject.tint)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("module.obsidianTitle", store.language))
                            .font(.headline)
                        Button(action: saveLessonToObsidian) {
                            if isSavingObsidianNote {
                                Label(L10n.text("module.obsidianSaving", store.language), systemImage: "arrow.triangle.2.circlepath")
                            } else {
                                Label(L10n.text("module.obsidianSave", store.language), systemImage: "externaldrive.badge.plus")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            isSavingObsidianNote
                                || store.providerSecretStatuses["obsidian"]?.configured != true
                                || store.aiHealth?.isObsidianEndpointLocal != true
                        )
                        Text(L10n.text("module.obsidianPrivacy", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let obsidianSaveStatus {
                            Text(obsidianSaveStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("module.notebookTitle", store.language))
                            .font(.headline)
                        HStack(spacing: 12) {
                            Button(action: copyNotebookLessonSource) {
                                Label(L10n.text("module.notebookCopy", store.language), systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("lesson.notebook.copy")

                            Button {
                                notebookExportDocument = NotebookLMSourceFile(
                                    text: document.notebookSource(subject: subject, language: store.language)
                                )
                                notebookExportFilename = "ColiDev-\(subject.rawValue)-\(resource)-\(store.language.rawValue).md"
                                notebookExportStatus = nil
                                isExportingNotebookSource = true
                            } label: {
                                Label(L10n.text("module.notebookExport", store.language), systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                if let url = URL(string: "https://notebooklm.google.com") {
                                    if !NSWorkspace.shared.open(url) {
                                        notebookExportStatus = L10n.text("module.notebookOpenFailed", store.language)
                                    }
                                }
                            } label: {
                                Label(L10n.text("module.notebookOpen", store.language), systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.bordered)
                        }
                        Text(L10n.text("module.notebookPrivacy", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let notebookExportStatus {
                            Text(notebookExportStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("lesson.notebook.status")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 12) {
                        StudyReflectionFields(
                            language: store.language,
                            reflection: $reflection,
                            learnerConfirmed: $learnerConfirmed,
                            showsReflectionInput: document.videoActivity == nil
                        )
                        if learnerConfirmed, checkAttempt?.canComplete == true {
                            StudyFormatFeedbackCard(
                                language: store.language,
                                selectedChoice: store.studyFormatPreferenceProfile.selectedChoice(
                                    for: lessonID,
                                    subjectID: subject.rawValue
                                ),
                                onSelect: {
                                    store.recordStudyFormatPreference(
                                        $0,
                                        lessonID: lessonID,
                                        subjectID: subject.rawValue
                                    )
                                }
                            )
                        }
                        Picker(L10n.text("session.recallQuality", store.language), selection: $recallQuality) {
                            Text(L10n.text("session.recallHard", store.language)).tag(2)
                            Text(L10n.text("session.recallGood", store.language)).tag(4)
                            Text(L10n.text("session.recallEasy", store.language)).tag(5)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    Button {
                        if isComplete {
                            store.recordReview(
                                lessonID: lessonID,
                                quality: recallQuality,
                                reflection: reflection,
                                assessment: checkAttempt?.assessmentEvidence
                            )
                        } else {
                            store.markComplete(
                                lessonID: lessonID,
                                quality: recallQuality,
                                reflection: reflection,
                                assessment: checkAttempt?.assessmentEvidence
                            )
                        }
                    } label: {
                        let title = hasPendingReview
                            ? "session.reviewSaved"
                            : (isComplete
                                ? (isReviewDue
                                    ? "session.recordReview"
                                    : (checkAttempt?.assessmentEvidence != nil
                                        ? "session.recordPractice"
                                        : "session.completed"))
                                : "session.complete")
                        Label(L10n.text(title, store.language), systemImage: isComplete ? "checkmark.circle.fill" : "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lesson.completion.action")
                    .disabled(
                        !learnerConfirmed
                            || checkAttempt?.canComplete != true
                            || hasPendingReview
                            || !StudyReviewActionPolicy.canRecord(
                                isComplete: isComplete,
                                isReviewDue: isReviewDue,
                                hasAssessment: checkAttempt?.assessmentEvidence != nil
                            )
                    )
                    // Leave enough scrollable space for the completion action to clear
                    // the macOS Dock / bottom safe area in compact CI and laptop windows.
                    .padding(.bottom, 88)
                } else {
                    Label(L10n.text("module.unavailable", store.language), systemImage: "doc.questionmark")
                        .foregroundStyle(.secondary)
                        .padding(24)
                }
            }
            .padding(.horizontal, 34)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityIdentifier("lesson.scrollView")
        .onChange(of: document?.title) { title in
            guard title != nil, focusPracticeOnOpen else { return }
            DispatchQueue.main.async {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo("module-interactive-practice", anchor: .top)
                }
                onPracticeFocusCompleted()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(Text(document?.title ?? L10n.text("module.title", store.language)))
        .onAppear { loadDocument() }
        .onChange(of: lessonID) { _ in loadDocument() }
        .task(id: lessonID) { await loadSourceInventory() }
        .onChange(of: store.language) { _ in loadDocument() }
        .onChange(of: store.studyProgress[lessonID]?.reflection) { savedReflection in
            guard store.studyReflectionDrafts[lessonID] == nil, !Self.startsAsNewLearnerForUITest else { return }
            reflection = savedReflection ?? ""
            revealSavedVideoReflectionIfNeeded()
        }
        .onChange(of: reflection) { value in
            store.saveReflectionDraft(value, lessonID: lessonID)
        }
        .fileExporter(
            isPresented: $isExportingNotebookSource,
            document: notebookExportDocument,
            contentType: NotebookLMFileType.markdown,
            defaultFilename: notebookExportFilename
        ) { result in
            switch result {
            case .success(let url):
                notebookExportStatus = String(
                    format: L10n.text("module.notebookExported", store.language),
                    url.lastPathComponent
                )
            case .failure(let error):
                if (error as? CocoaError)?.code == .userCancelled {
                    notebookExportStatus = nil
                } else {
                    notebookExportStatus = L10n.text("module.notebookExportFailed", store.language)
                }
            }
        }
        .sheet(isPresented: $showingTutor) {
            if let document {
                TutorChatView(subject: subject, lesson: document.tutorContext, language: store.language, mode: store.aiMode)
                    .environmentObject(store)
                    .frame(minWidth: 680, minHeight: 520)
            }
        }
        }
    }

    private func loadDocument() {
        let loadedDocument = CurriculumLessonDocument.load(subject: subject, resource: resource, language: store.language)
        document = loadedDocument
        selectedErrorCategory = ""
        isCheckExplanationRevealed = false
        checkAttempt = loadedDocument.flatMap { lesson in
            guard let answerIndex = lesson.checkAnswerIndex else { return nil }
            return CurriculumCheckAttempt(
                optionCount: lesson.checkOptions.count,
                answerOriginalIndex: answerIndex,
                itemID: "\(lessonID).knowledge_check"
            )
        }
        learnerConfirmed = isComplete
        reflection = Self.startsAsNewLearnerForUITest
            ? ""
            : store.studyReflectionDrafts[lessonID] ?? store.studyProgress[lessonID]?.reflection ?? ""
        showsSavedVideoReflection = false
        revealSavedVideoReflectionIfNeeded()
    }

    // Only a non-empty saved answer counts; clearing the text later keeps the field open while editing.
    private func revealSavedVideoReflectionIfNeeded() {
        guard document?.videoActivity != nil,
              !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        showsSavedVideoReflection = true
    }

    private func copyNotebookLessonSource() {
        guard let document else { return }
        let markdown = document.notebookSource(subject: subject, language: store.language)
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(markdown, forType: .string) {
            notebookExportStatus = L10n.text("module.notebookCopied", store.language)
        } else {
            notebookExportStatus = L10n.text("module.notebookCopyFailed", store.language)
        }
    }

    private func selectCheckAnswer(displayedIndex: Int) {
        guard var attempt = checkAttempt else { return }
        attempt.select(displayedIndex: displayedIndex)
        if attempt.isCorrect,
           let evidence = attempt.currentAnswerEventEvidence() {
            store.recordStudyAssessment(lessonID: lessonID, evidence: evidence)
        }
        checkAttempt = attempt
    }

    private func retryKnowledgeCheck() {
        guard var attempt = checkAttempt else { return }
        let errorCategory = StudyErrorCategory(rawValue: selectedErrorCategory)
        if let evidence = attempt.currentAnswerEventEvidence(errorCategory: errorCategory) {
            store.recordStudyAssessment(lessonID: lessonID, evidence: evidence)
        }
        attempt.retry(errorCategory: errorCategory)
        checkAttempt = attempt
        selectedErrorCategory = ""
        isCheckExplanationRevealed = false
    }

    @MainActor
    private func loadSourceInventory() async {
        isLoadingSourceInventory = true
        defer { isLoadingSourceInventory = false }
        sourceInventoryUnavailable = false
        do {
            sourceInventory = try await OrchestratorClient.trustedSourceInventory()
        } catch {
            sourceInventory = nil
            sourceInventoryUnavailable = true
        }
    }

    private func saveLessonToObsidian() {
        guard let document, !isSavingObsidianNote else { return }
        let timestampFormatter = DateFormatter()
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        timestampFormatter.timeZone = TimeZone.current
        timestampFormatter.dateFormat = "yyyyMMdd-HHmmssSSS"
        let timestamp = timestampFormatter.string(from: Date())
        let uniqueSuffix = String(UUID().uuidString.prefix(8)).lowercased()
        let path = "ColiDev/Lessons/\(subject.rawValue)/\(resource)-\(timestamp)-\(uniqueSuffix).md"
        let source = document.notebookSource(subject: subject, language: store.language)
        isSavingObsidianNote = true
        obsidianSaveStatus = nil

        Task { @MainActor in
            defer { isSavingObsidianNote = false }
            do {
                try await OrchestratorClient.saveObsidianNote(path: path, content: source)
                obsidianSaveStatus = String(
                    format: L10n.text("module.obsidianSaved", store.language),
                    path
                )
            } catch {
                obsidianSaveStatus = L10n.text("module.obsidianSaveFailed", store.language)
            }
        }
    }
}

private struct LessonSourceFreshnessCard: View {
    let inventory: TrustedSourceInventory?
    let unavailable: Bool
    let isLoading: Bool
    let lessonPath: String
    let authorCheckedOn: String?
    let language: AppLanguage
    let onRetry: () -> Void

    private var matchingSources: [TrustedSourceInventoryItem] {
        let target = lessonPath.lowercased()
        return (inventory?.sources ?? []).filter { source in
            (source.lessonPaths ?? [source.lessonPath]).contains { $0.lowercased() == target }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(L10n.text("module.sourceStatusTitle", language), systemImage: "checkmark.icloud")
                .font(.headline)

            if let authorCheckedOn {
                Text(String(format: L10n.text("module.sourceAuthorDate", language), authorCheckedOn))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.text("module.sourceAuthorDateMissing", language))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if unavailable {
                HStack {
                    Label(L10n.text("module.sourceMonitorUnavailable", language), systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button(action: onRetry) {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(L10n.text("management.retry", language), systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoading)
                }
            } else if inventory != nil, matchingSources.isEmpty {
                Label(L10n.text("module.sourceNotMonitored", language), systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if inventory != nil {
                ForEach(matchingSources) { source in
                    VStack(alignment: .leading, spacing: 3) {
                        Label(
                            L10n.text(sourceStateKey(source.state), language),
                            systemImage: sourceStateSymbol(source.state)
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(sourceStateColor(source.state))

                        Text(source.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if let checkedAt = source.contentCheckedAt ?? source.lastCheckedAt {
                            Text(String(format: L10n.text("module.sourceLastChecked", language), formatDate(checkedAt)))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if let review = source.lessonReviews?.first(where: {
                            $0.lessonPath.lowercased() == lessonPath.lowercased()
                        }) {
                            Label(
                                L10n.text(editorialStatusKey(review.editorialReviewStatus), language),
                                systemImage: editorialStatusSymbol(review.editorialReviewStatus)
                            )
                            .font(.caption2)
                            .foregroundStyle(editorialStatusColor(review.editorialReviewStatus))
                        }
                    }
                    .padding(.top, 3)
                }
            } else if isLoading {
                ProgressView(L10n.text("module.sourceStatusLoading", language))
                    .controlSize(.small)
            }

            Text(L10n.text("module.sourceStatusCaveat", language))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
    }

    private func sourceStateKey(_ state: String) -> String {
        switch state {
        case "not_checked": return "management.sourceNotChecked"
        case "available_untracked": return "management.sourceAvailable"
        case "content_baseline": return "management.sourceContentBaseline"
        case "unchanged": return "management.sourceUnchanged"
        case "changed": return "management.sourceChanged"
        case "content_unavailable": return "management.sourceContentUnavailable"
        case "content_too_large": return "management.sourceContentTooLarge"
        case "unsupported_content_type": return "management.sourceUnsupportedContent"
        case "redirect_review": return "management.sourceRedirect"
        case "unexpected_not_modified": return "management.sourceUnexpected304"
        case "unavailable": return "management.sourceUnavailable"
        case "network_error": return "management.sourceNetworkError"
        default: return "management.sourceUnknown"
        }
    }

    private func sourceStateSymbol(_ state: String) -> String {
        switch state {
        case "changed", "content_baseline", "content_unavailable", "content_too_large",
             "unsupported_content_type", "redirect_review", "unexpected_not_modified",
             "unavailable", "network_error": return "exclamationmark.triangle.fill"
        case "unchanged": return "checkmark.circle"
        case "available_untracked": return "questionmark.circle"
        default: return "clock"
        }
    }

    private func sourceStateColor(_ state: String) -> Color {
        switch state {
        case "changed", "content_baseline", "content_unavailable", "content_too_large",
             "unsupported_content_type", "redirect_review", "unexpected_not_modified",
             "unavailable", "network_error": return .orange
        default: return .secondary
        }
    }

    private func editorialStatusKey(_ status: String) -> String {
        switch status {
        case "review_due": return "management.editorialReviewDue"
        case "review_scheduled": return "management.editorialReviewScheduled"
        case "review_missing": return "management.editorialReviewMissing"
        case "review_unscheduled": return "management.editorialReviewUnscheduled"
        default: return "management.editorialReviewUnknown"
        }
    }

    private func editorialStatusSymbol(_ status: String) -> String {
        status == "review_due" || status == "review_missing"
            ? "exclamationmark.circle.fill"
            : status == "review_scheduled" ? "calendar" : "calendar.badge.exclamationmark"
    }

    private func editorialStatusColor(_ status: String) -> Color {
        status == "review_due" || status == "review_missing" ? .orange : .secondary
    }

    private func formatDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}

private struct NotebookLMSourceFile: FileDocument {
    static var readableContentTypes: [UTType] { [NotebookLMFileType.markdown] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private enum NotebookLMFileType {
    static let markdown = UTType(filenameExtension: "md") ?? .plainText
}

private struct ModuleTextCard: View {
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
            Text(LessonMarkdown.attributed(text))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct LessonSessionView: View {
    @EnvironmentObject private var store: LearningStore
    let subject: Subject
    let showRoadmap: () -> Void

    @State private var selectedAnswer: Int?
    @State private var optionOrder = AnswerChoiceOrder(optionCount: 3)
    @State private var isLessonFeedbackRevealed = false
    @State private var learnerConfirmed = false
    @State private var reflection = ""
    @State private var showingTutor = false

    private var content: LessonContent {
        LearningCatalog.lesson(for: subject, language: store.language)
    }

    private var answerIsCorrect: Bool {
        guard let selectedAnswer else { return false }
        return optionOrder.isCorrect(
            displayedIndex: selectedAnswer,
            answerOriginalIndex: content.answerIndex
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("session.lesson", store.language))
                        .font(.caption.weight(.semibold))
                        .tracking(1.3)
                        .foregroundStyle(subject.tint)
                    Text(content.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subject.title(in: store.language) + " · " + subject.subtitle(in: store.language))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Button(action: showRoadmap) {
                        Label(L10n.text("roadmap.open", store.language), systemImage: "list.bullet.rectangle")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.top, 24)

                Button { showingTutor = true } label: {
                    Label(L10n.text("tutor.title", store.language), systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("session.goal", store.language))
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(content.objective)
                        .font(.title3.weight(.medium))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(subject.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))

                LessonConceptCard(
                    title: L10n.text("session.theory", store.language),
                    text: content.explanation,
                    symbol: "text.book.closed",
                    tint: subject.tint
                )
                LessonConceptCard(
                    title: L10n.text("session.mechanism", store.language),
                    text: content.mechanism,
                    symbol: "gearshape.2",
                    tint: subject.tint
                )
                LessonConceptCard(
                    title: L10n.text("session.example", store.language),
                    text: content.example,
                    symbol: "lightbulb",
                    tint: subject.tint
                )
                LessonConceptCard(
                    title: L10n.text("session.limitations", store.language),
                    text: content.limitations,
                    symbol: "scope",
                    tint: subject.tint
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("session.lab", store.language))
                        .font(.title2.weight(.semibold))
                    Text(L10n.text("session.labHint", store.language))
                        .foregroundStyle(.secondary)
                    PracticeLab(subject: subject)
                }

                quizCard

                if answerIsCorrect || store.isComplete(subject) {
                    StudyReflectionFields(
                        language: store.language,
                        reflection: $reflection,
                        learnerConfirmed: $learnerConfirmed,
                        showsReflectionInput: true
                    )
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    Button {
                        if store.isComplete(subject) {
                            store.recordReview(for: subject, reflection: reflection)
                        } else {
                            store.markComplete(subject, reflection: reflection)
                        }
                    } label: {
                        let title = store.hasPendingReview(subject)
                            ? "session.reviewSaved"
                            : (store.isComplete(subject)
                                ? (store.isReviewDue(subject) ? "session.recordReview" : "session.completed")
                                : "session.complete")
                        Label {
                            Text(L10n.text(title, store.language))
                        } icon: {
                            Image(systemName: store.isComplete(subject) ? "checkmark.circle.fill" : "checkmark")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !learnerConfirmed
                            || store.hasPendingReview(subject)
                            || (store.isComplete(subject) && !store.isReviewDue(subject))
                    )
                    .padding(.bottom, 32)
                }
            }
            .padding(.horizontal, 34)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            learnerConfirmed = store.isComplete(subject)
            reflection = store.studyReflectionDrafts[subject.lessonID]
                ?? store.studyProgress[subject.lessonID]?.reflection
                ?? ""
        }
        .onChange(of: store.studyProgress[subject.lessonID]?.reflection) { savedReflection in
            guard store.studyReflectionDrafts[subject.lessonID] == nil else { return }
            reflection = savedReflection ?? ""
        }
        .onChange(of: reflection) { value in
            store.saveReflectionDraft(value, lessonID: subject.lessonID)
        }
        .navigationTitle(Text(subject.title(in: store.language)))
        .sheet(isPresented: $showingTutor) {
            TutorChatView(subject: subject, lesson: content, language: store.language, mode: store.aiMode)
                .environmentObject(store)
                .frame(minWidth: 680, minHeight: 520)
        }
    }

    private var quizCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("session.check", store.language))
                .font(.title2.weight(.semibold))
            Text(content.question)
                .font(.headline)
            ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                Button {
                    selectedAnswer = displayIndex
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedAnswer == displayIndex ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selectedAnswer == displayIndex ? subject.tint : Color.secondary)
                        Text(content.options[originalIndex])
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(selectedAnswer != nil)
            }
            if selectedAnswer != nil {
                let feedback = LessonAnswerFeedback.presentation(
                    isCorrect: answerIsCorrect,
                    explanationRevealed: isLessonFeedbackRevealed,
                    explanation: content.feedback,
                    correctPrompt: L10n.text("session.right", store.language),
                    retryPrompt: L10n.text("session.wrong", store.language)
                )
                Label {
                    Text(feedback.statusMessage)
                } icon: {
                    Image(systemName: answerIsCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle")
                }
                .font(.callout)
                .foregroundStyle(answerIsCorrect ? Color.green : Color.orange)
                .padding(.top, 4)
                if feedback.canRevealExplanation {
                    Button {
                        isLessonFeedbackRevealed = true
                    } label: {
                        Label(L10n.text("module.showAnswer", store.language), systemImage: "eye")
                    }
                    .buttonStyle(.borderless)
                }
                if let explanation = feedback.explanation {
                    Text(LessonMarkdown.attributed(explanation))
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !answerIsCorrect {
                    Button {
                        self.selectedAnswer = nil
                        self.isLessonFeedbackRevealed = false
                        self.optionOrder.reshuffle()
                    } label: {
                        Text(L10n.text("session.retry", store.language))
                    }
                        .buttonStyle(.link)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct StudyReflectionFields: View {
    let language: AppLanguage
    @Binding var reflection: String
    @Binding var learnerConfirmed: Bool
    let showsReflectionInput: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("session.listen", language))
                .font(.headline)
            if showsReflectionInput {
                TextField(L10n.text("session.reflectionPlaceholder", language), text: $reflection, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .onChange(of: reflection) { value in
                        if value.unicodeScalars.count > 500 {
                            reflection = String(String.UnicodeScalarView(value.unicodeScalars.prefix(500)))
                        }
                    }
            }
            Text(L10n.text("session.reflectionPrivacy", language))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Toggle(L10n.text("session.doneCheck", language), isOn: $learnerConfirmed)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("lesson.completion.confirmed")
        }
    }

}

private struct StudyFormatFeedbackCard: View {
    let language: AppLanguage
    let selectedChoice: StudyFormatFeedbackChoice?
    let onSelect: (StudyFormatFeedbackChoice) -> Void

    private let columns = [GridItem(.adaptive(minimum: 190), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("studyFormat.feedbackTitle", language))
                .font(.headline)
            Text(L10n.text("studyFormat.feedbackHint", language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(StudyFormatFeedbackChoice.allCases) { choice in
                    let isSelected = selectedChoice == choice
                    Button { onSelect(choice) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: choice.symbol)
                            Text(L10n.text(choice.titleKey, language))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("study-format-feedback.\(choice.rawValue)")
                }
            }
            if selectedChoice != nil {
                Label(L10n.text("studyFormat.feedbackSaved", language), systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("study-format-feedback.card")
    }
}

private struct LessonConceptCard: View {
    let title: String
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.body)
                .lineSpacing(5)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct PracticeLab: View {
    let subject: Subject
    let moduleResource: String?

    init(subject: Subject, moduleResource: String? = nil) {
        self.subject = subject
        self.moduleResource = moduleResource
    }

    @ViewBuilder
    var body: some View {
        if subject == .mathematics, moduleResource == "solving_linear_equations" {
            LinearEquationLab()
        } else if let lessonID = LinearFunctionPracticeRoute.lessonID(
            subjectID: subject.rawValue,
            resource: moduleResource
        ) {
            LinearFunctionLab(lessonID: lessonID)
        } else if subject == .mathematics, moduleResource == "systems_of_linear_equations" {
            LinearSystemLab()
        } else if subject == .mathematics, moduleResource == "rational_expressions_and_restrictions" {
            RationalExpressionLab()
        } else if subject == .mathematics, moduleResource == "geometry_area_perimeter" {
            GeometryMeasureLab()
        } else if subject == .mathematics, moduleResource == "numbers_fractions_and_percentages" {
            PercentRepresentationLab()
        } else if subject == .mathematics, moduleResource == "domain_and_range" {
            DomainRangeLab()
        } else if subject == .mathematics, moduleResource == "quadratic_functions_and_transformations" {
            QuadraticFunctionLab()
        } else if subject == .mathematics, moduleResource == "trigonometry_and_periodic_functions" {
            TrigonometryUnitCircleLab()
        } else if subject == .mathematics, moduleResource == "constrained_optimization_and_lagrange_multipliers" {
            ConstrainedOptimizationLab()
        } else if subject == .mathematics, moduleResource == "descriptive_statistics_and_potential_outliers" {
            StatisticsPracticeLab()
        } else if subject == .mathematics, moduleResource == "rates_of_change_and_derivative" {
            DerivativeRateLab()
        } else if subject == .english, moduleResource == "present_simple_and_continuous" {
            TenseContrastLab()
        } else if subject == .english, moduleResource == "present_perfect_simple_continuous" {
            PresentPerfectAspectLab()
        } else if subject == .english, moduleResource == "subject_pronouns_and_be" {
            EnglishBeLab()
        } else if subject == .english, moduleResource == "sounds_stress_rhythm" {
            EnglishWordStressLab()
        } else if subject == .english, moduleResource == "zero_first_second_conditionals" {
            ConditionalsLab()
        } else if subject == .english, moduleResource == "daily_routines_and_collocations" {
            DailyRoutineVocabularyLab()
        } else if subject == .english, moduleResource == "reading_for_gist_and_detail" {
            ReadingStrategyLab()
        } else if subject == .english, moduleResource == "reported_speech_questions_and_backshift" {
            ReportedSpeechLab()
        } else if subject == .zoology, moduleResource == "animals_as_a_group" {
            AnimalGroupLab()
        } else if subject == .zoology, moduleResource == "major_animal_lineages" {
            AnimalLineageLab()
        } else if subject == .biology, moduleResource == "intro" {
            EukaryoticCellLab()
        } else if subject == .biology, moduleResource == "passive_transport_osmosis" {
            OsmosisLab()
        } else if subject == .biology, moduleResource == "mendelian_inheritance" {
            PunnettLab()
        } else if subject == .biology, moduleResource == "dna_genes_and_traits" {
            GeneRegulationLab()
        } else if subject == .biology, moduleResource == "gene_expression_and_regulation" {
            GeneExpressionLab()
        } else if subject == .biology, moduleResource == "photosynthesis_energy_and_carbon" {
            PhotosynthesisLab()
        } else if subject == .biology, moduleResource == "scientific_method_and_experiments" {
            BiologyInvestigationLab()
        } else if subject == .biology, moduleResource == "eukaryotic_cell_organelles" {
            EukaryoticCellLab()
        } else if subject == .biology, moduleResource == "biomolecules_and_building_blocks" {
            BiomoleculeLab()
        } else if subject == .biology, moduleResource == "natural_selection_and_population_change" {
            NaturalSelectionLab(lessonID: "biology.natural_selection_and_population_change")
        } else if subject == .zoology, moduleResource == "adaptation_and_behavior" {
            NaturalSelectionLab(lessonID: "zoology.adaptation_and_behavior")
        } else if subject == .zoology, moduleResource == "animal_function_and_environment" {
            AnimalFunctionLab()
        } else if subject == .zoology, moduleResource == "thermoregulation_and_heat_exchange" {
            ThermalStrategyLab()
        } else if subject == .zoology, moduleResource == "comparative_thermoregulation_and_heat_stress" {
            ThermoregulationLab()
        } else if subject == .biology, moduleResource == "cell_cycle_and_differentiation" {
            CellCycleLab()
        } else if subject == .biology, moduleResource == "ecosystem_energy_flow" {
            EcosystemEnergyLab()
        } else if subject == .biology, moduleResource == "food_webs_and_matter_cycles" {
            FoodWebLab()
        } else if subject == .physics, moduleResource == "work_and_kinetic_energy" {
            KineticEnergyLab()
        } else if subject == .physics, moduleResource == "measurement_units_and_uncertainty" {
            LengthMeasurementLab()
        } else if subject == .physics, moduleResource == "static_and_kinetic_friction" {
            FrictionLab()
        } else if subject == .physics, moduleResource == "impulse_and_momentum" {
            MomentumCollisionLab()
        } else if subject == .physics, moduleResource == "elastic_collisions" {
            MomentumCollisionLab(initialMode: .elastic)
        } else if subject == .physics, moduleResource == "projectile_motion" {
            ProjectileMotionLab()
        } else if subject == .physics, moduleResource == "vectors_and_kinematics" {
            VectorKinematicsLab()
        } else if subject == .physics, moduleResource == "intro" {
            ForceLab(lessonID: "intro.physics")
        } else if subject == .physics, moduleResource == "net_force_and_acceleration" {
            ForceLab(lessonID: "physics.net_force_and_acceleration")
        } else if subject == .programming, moduleResource == "collections_and_loops" {
            CollectionsLoopsLab()
        } else if subject == .programming, moduleResource == "conditions_loops_functions" {
            LoopTraceLab()
        } else if subject == .programming, moduleResource == "strings_files_and_exceptions" {
            FileReadingLab()
        } else if subject == .programming, moduleResource == "debugging_tests_and_git" {
            DebuggingLab()
        } else if subject == .programming, moduleResource == "sql_transactions" {
            VStack(alignment: .leading, spacing: 14) {
                SQLSchemaQueryLab()
                TransactionLab()
            }
        } else if subject == .programming, moduleResource == "search_and_complexity" {
            AlgorithmComplexityLab()
            DataStructureChoiceLab()
        } else if subject == .programming, moduleResource == "variables_and_types" {
            VariablesTypesLab()
        } else if subject == .programming, moduleResource == "computational_thinking" {
            AlgorithmicThinkingLab()
        } else if subject == .programming, moduleResource == "ml_baseline_and_holdout" {
            HeldOutEvaluationLab()
        } else if subject == .biology, moduleResource == "neurons_and_action_potentials" {
            NeuronSignalLab()
        } else if subject == .zoology, moduleResource == "comparative_gas_exchange_and_circulation" {
            CirculationRouteLab()
        } else if subject == .programming, moduleResource == "gradient_descent_and_learning_rate" {
            GradientDescentLab()
        } else if subject == .programming, moduleResource == "neural_network_backpropagation" {
            NeuronTrainingLab()
        } else if subject == .biology, moduleResource == "synapses_and_signal_summation" {
            SynapticSummationLab()
        } else if subject == .biology, moduleResource == "what_is_life_and_its_origin" {
            ReplicatorErrorThresholdLab()
        } else if subject == .physics, moduleResource == "entropy_and_the_second_law" {
            CoinEntropyLab()
        } else if subject == .biology, moduleResource == "population_genetics_hardy_weinberg" {
            HardyWeinbergLab()
        } else if subject == .physics, moduleResource == "fitting_pendulum_data_least_squares" {
            LeastSquaresFitLab()
        } else if subject == .biology, moduleResource == "synaptic_plasticity_and_learning" {
            SynapticPlasticityLab()
        } else if subject == .chemistry, moduleResource == "enzyme_kinetics_michaelis_menten" {
            MichaelisMentenLab()
        } else if subject == .mathematics, moduleResource == "euler_method_numerical_modeling" {
            EulerMethodLab()
        } else if subject == .chemistry, moduleResource == "prebiotic_chemistry_and_autocatalysis" {
            AutocatalysisLab()
        } else if subject == .mathematics, moduleResource == "vectors_and_matrices" {
            NeuralLayerLab()
        } else if subject == .mathematics, moduleResource == "gradient_and_partial_derivatives" {
            GradientDescent2DLab()
        } else if subject == .biology, moduleResource == "dna_replication_fidelity_and_repair" {
            GenomeFidelityLab()
        } else if subject == .biology, moduleResource == "sequence_comparison_hamming_distance" {
            HammingDistanceLab()
        } else if subject == .physics, moduleResource == "radioactive_decay_and_dating" {
            RadioactiveDatingLab()
        } else if subject == .biology, moduleResource == "homeostasis_and_feedback" {
            FeedbackLoopLab()
        } else if subject == .chemistry, moduleResource == "thermodynamics_of_living_systems" {
            EnergyCouplingLab()
        } else if subject == .chemistry, moduleResource == "reaction_rate_and_equilibrium" {
            ReactionQuotientLab()
        } else if subject == .physics, moduleResource == "special_relativity_time_dilation" {
            TimeDilationLab()
        } else if subject == .physics, moduleResource == "quantum_energy_levels_and_shells" {
            HydrogenSpectrumLab()
        } else if subject == .physics, moduleResource == "maxwell_and_electromagnetic_waves" {
            ElectromagneticWaveLab()
        } else if subject == .physics, moduleResource == "circuits_and_ohms_law" {
            CircuitLab()
        } else if subject == .physics, moduleResource == "refraction_of_light" {
            RefractionLab()
        } else if subject == .physics, moduleResource == "torque_and_rotational_equilibrium" {
            SeesawLab()
        } else if subject == .zoology, moduleResource == "logistic_population_growth" {
            LogisticGrowthLab()
        } else if subject == .zoology, moduleResource == "mark_recapture_population_estimate" {
            MarkRecaptureLab()
        } else if subject == .zoology, moduleResource == "surface_volume_and_body_size" {
            SurfaceVolumeLab()
        } else if subject == .physics, moduleResource == "oscillations_and_waves" {
            PendulumLab()
        } else if subject == .physics, moduleResource == "temperature_and_heat" {
            HeatMixingLab()
        } else if subject == .english, moduleResource == "short_message_to_a_friend" {
            ShortMessageLab()
        } else {
            switch subject {
        case .mathematics:
            SlopeLab()
        case .english:
            SentenceLab()
        case .physics:
            ForceLab()
        case .chemistry:
            if moduleResource == "water_hydrogen_bonds_and_ph" {
                PHScaleLab()
            } else if moduleResource == "atoms_electrons_and_chemical_bonds" {
                MoleculeBuilderLab()
            } else if moduleResource == "reaction_energy_and_catalysis" {
                ReactionEnergyLab()
            } else {
                // The intro lesson has no lab: its practice task and question carry the module.
                EmptyView()
            }
        case .biology:
            CellLab()
        case .zoology:
            if moduleResource == "animals_as_a_group" {
                AnimalGroupLab()
            } else if moduleResource == "symmetry_and_body_plans" {
                SymmetryLab()
            } else {
                AdaptationLab()
            }
        case .programming:
            ConditionalLab()
            }
        }
    }
}

private struct RoutineVocabularyQuestion {
    let id: String
    let promptKey: String
    let optionKeys: [String]
    let answerIndex: Int
    let explanationKey: String
}

private struct ReadingStrategyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var index = 0
    @State private var selection: Int?
    @State private var wasCorrect: Bool?
    @State private var complete = false
    @State private var assessmentTracker = EnglishReadingAssessmentTracker()
    @State private var optionOrders = QuizAnswerOrder.balancedSequence(
        optionCount: 3,
        answerOriginalIndices: EnglishReadingPractice.questions.map(\.correctOption)
    )

    private let questions = [
        ConditionalPracticeQuestion(id: EnglishReadingPractice.questions[0].id, promptKey: "lab.readingQuestion0", feedbackKey: "lab.readingFeedback0"),
        ConditionalPracticeQuestion(id: EnglishReadingPractice.questions[1].id, promptKey: "lab.readingQuestion1", feedbackKey: "lab.readingFeedback1"),
        ConditionalPracticeQuestion(id: EnglishReadingPractice.questions[2].id, promptKey: "lab.readingQuestion2", feedbackKey: "lab.readingFeedback2")
    ]

    var body: some View {
        LabCard {
            Text(L10n.text("lab.readingHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if complete {
                Label(L10n.text("lab.readingComplete", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("lab.readingRestart", store.language), systemImage: "arrow.counterclockwise") {
                    reset()
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.readingProgress", store.language), index + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                Text(L10n.text(questions[index].promptKey, store.language))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(optionOrders[index].displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selection = displayIndex
                        wasCorrect = nil
                    } label: {
                        Label(
                            L10n.text("lab.readingOption\(index * 3 + originalIndex)", store.language),
                            systemImage: selection == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selection == displayIndex ? .accentColor : .secondary)
                    .accessibilityAddTraits(selection == displayIndex ? .isSelected : [])
                }

                if let wasCorrect {
                    Label(
                        wasCorrect
                            ? L10n.text(questions[index].feedbackKey, store.language)
                            : L10n.text("lab.readingTryAgain", store.language),
                        systemImage: wasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(wasCorrect ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    if wasCorrect == true {
                        if index == questions.count - 1 {
                            complete = true
                        } else {
                            index += 1
                            selection = nil
                            wasCorrect = nil
                        }
                    } else if let selection {
                        let isCorrect = optionOrders[index].isCorrect(displayedIndex: selection)
                        wasCorrect = isCorrect
                        let originalOption = optionOrders[index].displayedOriginalIndices[selection]
                        if let evidence = assessmentTracker.recordSubmission(
                            option: originalOption,
                            for: questions[index].id
                        ) {
                            store.recordStudyAssessment(
                                lessonID: "english.reading_for_gist_and_detail",
                                evidence: evidence
                            )
                        }
                    }
                } label: {
                    Text(L10n.text(
                        wasCorrect == true
                            ? (index == questions.count - 1 ? "lab.readingFinish" : "lab.readingNext")
                            : "lab.readingCheck",
                        store.language
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection == nil && wasCorrect != true)
            }
        }
    }

    private func reset() {
        index = 0
        selection = nil
        wasCorrect = nil
        complete = false
        assessmentTracker.reset()
        optionOrders = QuizAnswerOrder.balancedSequence(
            optionCount: 3,
            answerOriginalIndices: EnglishReadingPractice.questions.map(\.correctOption)
        )
    }
}

private struct DailyRoutineVocabularyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var questionIndex = 0
    @State private var selectedOption: Int?
    @State private var lastWasCorrect: Bool?
    @State private var isComplete = false
    @State private var optionOrders: [[Int]] = Self.makeOptionOrders()
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(itemIDs: Self.questionSet.map(\.id))

    private static let questionSet = [
        RoutineVocabularyQuestion(
            id: "daily-routines.question-1",
            promptKey: "lab.routinePrompt1",
            optionKeys: ["lab.routineGoToBed", "lab.routineHaveBreakfast", "lab.routineHaveDinner"],
            answerIndex: 1,
            explanationKey: "lab.routineExplanation1"
        ),
        RoutineVocabularyQuestion(
            id: "daily-routines.question-2",
            promptKey: "lab.routinePrompt2",
            optionKeys: ["lab.routineHaveDinner", "lab.routineWakeUp", "lab.routineGoToBed"],
            answerIndex: 1,
            explanationKey: "lab.routineExplanation2"
        ),
        RoutineVocabularyQuestion(
            id: "daily-routines.question-3",
            promptKey: "lab.routinePrompt3",
            optionKeys: ["lab.routineHaveLunch", "lab.routineGoToBed", "lab.routineGetDressed"],
            answerIndex: 2,
            explanationKey: "lab.routineExplanation3"
        ),
        RoutineVocabularyQuestion(
            id: "daily-routines.question-4",
            promptKey: "lab.routinePrompt4",
            optionKeys: ["lab.routineHaveBreakfast", "lab.routineWakeUp", "lab.routineHaveLunch"],
            answerIndex: 2,
            explanationKey: "lab.routineExplanation4"
        ),
        RoutineVocabularyQuestion(
            id: "daily-routines.question-5",
            promptKey: "lab.routinePrompt5",
            optionKeys: ["lab.routineWakeUp", "lab.routineGoToBed", "lab.routineGetDressed"],
            answerIndex: 1,
            explanationKey: "lab.routineExplanation5"
        )
    ]

    private var questions: [RoutineVocabularyQuestion] { Self.questionSet }
    private var currentQuestion: RoutineVocabularyQuestion { questions[questionIndex] }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.routineHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isComplete {
                Label(L10n.text("lab.routineComplete", store.language), systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    reset()
                } label: {
                    Label(L10n.text("lab.routineRestart", store.language), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.routineProgress", store.language), questionIndex + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(questionIndex + 1), total: Double(questions.count))
                Text(L10n.text(currentQuestion.promptKey, store.language))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(optionOrders[questionIndex].enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selectedOption = displayIndex
                        lastWasCorrect = nil
                    } label: {
                        Label(
                            L10n.text(currentQuestion.optionKeys[originalIndex], store.language),
                            systemImage: selectedOption == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedOption == displayIndex ? .accentColor : .secondary)
                    .accessibilityAddTraits(selectedOption == displayIndex ? .isSelected : [])
                }

                if let lastWasCorrect {
                    Label(
                        L10n.text(lastWasCorrect ? "lab.routineCorrect" : "lab.routineIncorrect", store.language),
                        systemImage: lastWasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .font(.callout)
                    .foregroundStyle(lastWasCorrect ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text(currentQuestion.explanationKey, store.language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    advanceOrCheck()
                } label: {
                    Text(checkButtonTitle)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedOption == nil && lastWasCorrect != true)
            }
        }
    }

    private var checkButtonTitle: String {
        guard lastWasCorrect == true else { return L10n.text("lab.routineCheck", store.language) }
        return questionIndex == questions.count - 1
            ? L10n.text("lab.routineFinish", store.language)
            : L10n.text("lab.routineNext", store.language)
    }

    private func advanceOrCheck() {
        if lastWasCorrect == true {
            guard questionIndex < questions.count - 1 else {
                isComplete = true
                return
            }
            questionIndex += 1
            selectedOption = nil
            lastWasCorrect = nil
            return
        }

        guard let selectedOption else { return }
        let selectedOriginalIndex = optionOrders[questionIndex][selectedOption]
        lastWasCorrect = selectedOriginalIndex == currentQuestion.answerIndex
        if let evidence = assessmentTracker.recordSubmission(
            selectedAnswerIndex: selectedOriginalIndex,
            correctAnswerIndex: currentQuestion.answerIndex,
            optionCount: currentQuestion.optionKeys.count,
            itemID: currentQuestion.id
        ) {
            store.recordStudyAssessment(lessonID: "english.daily_routines_and_collocations", evidence: evidence)
        }
    }

    private func reset() {
        questionIndex = 0
        selectedOption = nil
        lastWasCorrect = nil
        isComplete = false
        optionOrders = Self.makeOptionOrders()
        assessmentTracker.reset()
    }

    private static func makeOptionOrders() -> [[Int]] {
        QuizAnswerOrder.balancedSequence(
            optionCount: 3,
            answerOriginalIndices: questionSet.map(\.answerIndex)
        ).map(\.displayedOriginalIndices)
    }
}

private struct AnimalGroupQuestion {
    let id: String
    let promptKey: String
    let options: [String]
    let answerIndex: Int
    let explanationKey: String
}

private struct AnimalGroupLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var index = 0
    @State private var selection: Int?
    @State private var wasCorrect: Bool?
    @State private var complete = false
    @State private var optionOrders: [[Int]] = Self.makeOptionOrders()
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(itemIDs: Self.questionSet.map(\.id))

    private static let questionSet = [
        AnimalGroupQuestion(id: "animals-as-a-group.question-1", promptKey: "lab.animalGroupQ1", options: ["lab.animalGroupQ1A", "lab.animalGroupQ1B", "lab.animalGroupQ1C"], answerIndex: 0, explanationKey: "lab.animalGroupExplanation1"),
        AnimalGroupQuestion(id: "animals-as-a-group.question-2", promptKey: "lab.animalGroupQ2", options: ["lab.animalGroupQ2A", "lab.animalGroupQ2B", "lab.animalGroupQ2C"], answerIndex: 1, explanationKey: "lab.animalGroupExplanation2"),
        AnimalGroupQuestion(id: "animals-as-a-group.question-3", promptKey: "lab.animalGroupQ3", options: ["lab.animalGroupQ3A", "lab.animalGroupQ3B", "lab.animalGroupQ3C"], answerIndex: 2, explanationKey: "lab.animalGroupExplanation3"),
        AnimalGroupQuestion(id: "animals-as-a-group.question-4", promptKey: "lab.animalGroupQ4", options: ["lab.animalGroupQ4A", "lab.animalGroupQ4B", "lab.animalGroupQ4C"], answerIndex: 1, explanationKey: "lab.animalGroupExplanation4")
    ]

    private var questions: [AnimalGroupQuestion] { Self.questionSet }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.animalGroupHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if complete {
                Label(L10n.text("lab.animalGroupComplete", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button(L10n.text("lab.animalGroupRestart", store.language), systemImage: "arrow.counterclockwise") {
                    index = 0
                    selection = nil
                    wasCorrect = nil
                    complete = false
                    optionOrders = Self.makeOptionOrders()
                    assessmentTracker.reset()
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.animalGroupProgress", store.language), index + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                Text(L10n.text(questions[index].promptKey, store.language))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(optionOrders[index].enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selection = displayIndex
                        wasCorrect = nil
                    } label: {
                        Label(
                            L10n.text(questions[index].options[originalIndex], store.language),
                            systemImage: selection == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selection == displayIndex ? .accentColor : .secondary)
                    .accessibilityAddTraits(selection == displayIndex ? .isSelected : [])
                }

                if let wasCorrect {
                    Label(
                        L10n.text(wasCorrect ? "lab.animalGroupCorrect" : "lab.animalGroupTryAgain", store.language),
                        systemImage: wasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(wasCorrect ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text(questions[index].explanationKey, store.language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    if wasCorrect == true {
                        if index == questions.count - 1 {
                            complete = true
                        } else {
                            index += 1
                            selection = nil
                            wasCorrect = nil
                        }
                    } else if let selection {
                        let question = questions[index]
                        let selectedOriginalIndex = optionOrders[index][selection]
                        wasCorrect = selectedOriginalIndex == question.answerIndex
                        if let evidence = assessmentTracker.recordSubmission(
                            selectedAnswerIndex: selectedOriginalIndex,
                            correctAnswerIndex: question.answerIndex,
                            optionCount: question.options.count,
                            itemID: question.id
                        ) {
                            store.recordStudyAssessment(lessonID: "zoology.animals_as_a_group", evidence: evidence)
                        }
                    }
                } label: {
                    Text(L10n.text(wasCorrect == true ? (index == questions.count - 1 ? "lab.animalGroupFinish" : "lab.animalGroupNext") : "lab.animalGroupCheck", store.language))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection == nil && wasCorrect != true)
            }
        }
    }
    private static func makeOptionOrders() -> [[Int]] {
        QuizAnswerOrder.balancedSequence(
            optionCount: 3,
            answerOriginalIndices: questionSet.map(\.answerIndex)
        ).map(\.displayedOriginalIndices)
    }
}

private struct AnimalLineageLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var index = 0
    @State private var selection: Int?
    @State private var wasCorrect: Bool?
    @State private var complete = false
    @State private var optionOrders: [[Int]] = Self.makeOptionOrders()
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(itemIDs: Self.questionSet.map(\.id))

    private static let questionSet = [
        AnimalGroupQuestion(id: "major-animal-lineages.question-1", promptKey: "lab.lineageQ1", options: ["lab.lineageQ1A", "lab.lineageQ1B", "lab.lineageQ1C"], answerIndex: 1, explanationKey: "lab.lineageExplanation1"),
        AnimalGroupQuestion(id: "major-animal-lineages.question-2", promptKey: "lab.lineageQ2", options: ["lab.lineageQ2A", "lab.lineageQ2B", "lab.lineageQ2C"], answerIndex: 0, explanationKey: "lab.lineageExplanation2"),
        AnimalGroupQuestion(id: "major-animal-lineages.question-3", promptKey: "lab.lineageQ3", options: ["lab.lineageQ3A", "lab.lineageQ3B", "lab.lineageQ3C"], answerIndex: 2, explanationKey: "lab.lineageExplanation3"),
        AnimalGroupQuestion(id: "major-animal-lineages.question-4", promptKey: "lab.lineageQ4", options: ["lab.lineageQ4A", "lab.lineageQ4B", "lab.lineageQ4C"], answerIndex: 1, explanationKey: "lab.lineageExplanation4")
    ]

    private var questions: [AnimalGroupQuestion] { Self.questionSet }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.lineageHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                Label(L10n.text("lab.lineageBilateria", store.language), systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                Text(L10n.text("lab.lineageProtostomes", store.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 12) {
                    lineageBranch(title: "lab.lineageEcdysozoa", members: "lab.lineageArthropodsNematodes")
                    lineageBranch(title: "lab.lineageLophotrochozoa", members: "lab.lineageAnnelidsMolluscs")
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)

            if complete {
                Label(L10n.text("lab.lineageComplete", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button(L10n.text("lab.lineageRestart", store.language), systemImage: "arrow.counterclockwise") {
                    index = 0
                    selection = nil
                    wasCorrect = nil
                    complete = false
                    optionOrders = Self.makeOptionOrders()
                    assessmentTracker.reset()
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.lineageProgress", store.language), index + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                Text(L10n.text(questions[index].promptKey, store.language))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(optionOrders[index].enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selection = displayIndex
                        wasCorrect = nil
                    } label: {
                        Label(
                            L10n.text(questions[index].options[originalIndex], store.language),
                            systemImage: selection == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selection == displayIndex ? .accentColor : .secondary)
                    .accessibilityAddTraits(selection == displayIndex ? .isSelected : [])
                }

                if let wasCorrect {
                    Label(
                        L10n.text(wasCorrect ? "lab.lineageCorrect" : "lab.lineageTryAgain", store.language),
                        systemImage: wasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(wasCorrect ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text(questions[index].explanationKey, store.language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    if wasCorrect == true {
                        if index == questions.count - 1 {
                            complete = true
                        } else {
                            index += 1
                            selection = nil
                            wasCorrect = nil
                        }
                    } else if let selection {
                        let question = questions[index]
                        let selectedOriginalIndex = optionOrders[index][selection]
                        wasCorrect = selectedOriginalIndex == question.answerIndex
                        if let evidence = assessmentTracker.recordSubmission(
                            selectedAnswerIndex: selectedOriginalIndex,
                            correctAnswerIndex: question.answerIndex,
                            optionCount: question.options.count,
                            itemID: question.id
                        ) {
                            store.recordStudyAssessment(lessonID: "zoology.major_animal_lineages", evidence: evidence)
                        }
                    }
                } label: {
                    Text(L10n.text(wasCorrect == true ? (index == questions.count - 1 ? "lab.lineageFinish" : "lab.lineageNext") : "lab.lineageCheck", store.language))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection == nil && wasCorrect != true)
            }
        }
    }

    private static func makeOptionOrders() -> [[Int]] {
        QuizAnswerOrder.balancedSequence(
            optionCount: 3,
            answerOriginalIndices: questionSet.map(\.answerIndex)
        ).map(\.displayedOriginalIndices)
    }

    private func lineageBranch(title: String, members: String) -> some View {
        VStack(spacing: 8) {
            Text(L10n.text(title, store.language))
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(L10n.text(members, store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

private struct GeometryMeasureLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var shape = GeometryShape.rectangle
    @State private var base = 6.0
    @State private var height = 4.0

    private var measure: GeometryMeasure {
        GeometryMeasure(base: base, height: height, shape: shape)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.geometryHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
            Picker(L10n.text("lab.geometryShape", store.language), selection: $shape) {
                Text(L10n.text("lab.geometryRectangle", store.language)).tag(GeometryShape.rectangle)
                Text(L10n.text("lab.geometryTriangle", store.language)).tag(GeometryShape.rightTriangle)
            }
            .pickerStyle(.segmented)

            Canvas { context, size in
                let inset: CGFloat = 24
                let availableWidth = max(size.width - 2 * inset, 0)
                let availableHeight = max(size.height - 2 * inset, 0)
                guard availableWidth > 0, availableHeight > 0 else { return }
                let scale = min(availableWidth / CGFloat(base), availableHeight / CGFloat(height))
                let width = CGFloat(base) * scale
                let drawnHeight = CGFloat(height) * scale
                let left = (size.width - width) / 2
                let bottom = size.height - (size.height - drawnHeight) / 2
                var path = Path()
                if shape == .rectangle {
                    path.addRect(CGRect(x: left, y: bottom - drawnHeight, width: width, height: drawnHeight))
                } else {
                    path.move(to: CGPoint(x: left, y: bottom))
                    path.addLine(to: CGPoint(x: left, y: bottom - drawnHeight))
                    path.addLine(to: CGPoint(x: left + width, y: bottom))
                    path.closeSubpath()
                    var rightAngle = Path()
                    let mark: CGFloat = min(12, scale * 0.2)
                    rightAngle.move(to: CGPoint(x: left, y: bottom - mark))
                    rightAngle.addLine(to: CGPoint(x: left + mark, y: bottom - mark))
                    rightAngle.addLine(to: CGPoint(x: left + mark, y: bottom))
                    context.stroke(rightAngle, with: .color(.secondary), lineWidth: 1.5)
                }
                context.fill(path, with: .color(Color.accentColor.opacity(0.18)))
                context.stroke(path, with: .color(.accentColor), lineWidth: 3)
            }
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L10n.text("lab.geometryDiagram", store.language)))
            .accessibilityValue(Text(verbatim: "\(L10n.text(shape == .rectangle ? "lab.geometryRectangle" : "lab.geometryTriangle", store.language)); b = \(L10n.measurement(base, fractionDigits: 1, unit: "m", store.language)); h = \(L10n.measurement(height, fractionDigits: 1, unit: "m", store.language))"))

            HStack {
                Text(verbatim: "b = " + L10n.measurement(base, fractionDigits: 1, unit: "m", store.language))
                Spacer()
                Text(verbatim: "h = " + L10n.measurement(height, fractionDigits: 1, unit: "m", store.language))
            }
            .font(.callout.monospacedDigit())

            slider("lab.geometryBase", value: $base)
            slider("lab.geometryHeight", value: $height)

            HStack(spacing: 20) {
                metric(
                    "lab.geometryArea",
                    value: measure.area,
                    unit: "m²",
                    isApproximate: measure.areaNeedsRoundingForDisplay
                )
                metric(
                    "lab.geometryPerimeter",
                    value: measure.perimeter,
                    unit: "m",
                    isApproximate: measure.perimeterNeedsRoundingForDisplay
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(L10n.text("lab.geometryRounding", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(L10n.text("lab.geometryScaling", store.language))
                .font(.callout)
            Text(L10n.text("lab.geometryLimits", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func slider(_ key: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.text(key, store.language))
                Spacer()
                Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 1, unit: "m", store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 1...10, step: 0.5)
                .accessibilityLabel(Text(L10n.text(key, store.language)))
                .accessibilityValue(Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 1, unit: "m", store.language)))
        }
    }

    private func metric(_ key: String, value: Double, unit: String, isApproximate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text(key, store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: (isApproximate ? "≈ " : "") + L10n.measurement(value, fractionDigits: 2, unit: unit, store.language))
                .font(.title3.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PercentRepresentationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var percent = 35.0
    @State private var whole = 240.0
    @State private var kilometres = 1.5

    private var representation: PercentRepresentation {
        PercentRepresentation(percent: Int(percent.rounded()))
    }

    private var formattedDecimal: String {
        L10n.number(representation.decimal, fractionDigits: 2, store.language)
    }

    private var formattedKilometres: String {
        L10n.number(kilometres, fractionDigits: 1, store.language)
    }

    private var formattedMetres: String {
        L10n.number(KilometreConversion(kilometres: kilometres).metres, fractionDigits: 0, store.language)
    }

    var body: some View {
        LabCard {
            Label(L10n.text("lab.percent.title", store.language), systemImage: "chart.pie.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)

            Text(L10n.text("lab.percent.help", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("\(representation.percent)%")
                Text("=")
                Text(representation.fractionDescription)
                Text("=")
                Text(formattedDecimal)
            }
            .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(
                format: L10n.text("lab.percent.representations", store.language),
                "\(representation.percent)%",
                representation.fractionDescription,
                formattedDecimal
            ))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.text("lab.percent.share", store.language))
                    Spacer()
                    Text("\(representation.percent)%")
                        .monospacedDigit()
                }
                Slider(value: $percent, in: 0...100, step: 1)
                    .tint(.orange)
                    .accessibilityLabel(L10n.text("lab.percent.share", store.language))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.16))
                    Capsule()
                        .fill(Color.orange.gradient)
                        .frame(width: geometry.size.width * CGFloat(representation.decimal))
                }
            }
            .frame(height: 18)
            .accessibilityElement()
            .accessibilityLabel(L10n.text("lab.percent.bar", store.language)
                .replacingOccurrences(of: "%@", with: "\(representation.percent)%"))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.text("lab.percent.whole", store.language))
                    Spacer()
                    Text("\(Int(whole))")
                        .monospacedDigit()
                }
                Slider(value: $whole, in: 100...1000, step: 50)
                    .tint(.orange)
                    .accessibilityLabel(L10n.text("lab.percent.whole", store.language))
            }

            Text(String(format: L10n.text("lab.percent.part", store.language), representation.part(of: Int(whole))))
                .font(.headline.monospacedDigit())
                .accessibilityElement(children: .combine)

            Divider()

            Text(L10n.text("lab.percent.unitsTitle", store.language))
                .font(.headline)

            HStack {
                Text(L10n.text("lab.percent.kilometres", store.language))
                Spacer()
                Text(formattedKilometres)
                    .monospacedDigit()
            }
            Slider(value: $kilometres, in: 0...10, step: 0.5)
                .tint(.teal)
                .accessibilityLabel(L10n.text("lab.percent.kilometres", store.language))

            Text(L10n.text("lab.percent.unitEquation", store.language)
                .replacingOccurrences(of: "%1", with: formattedKilometres)
                .replacingOccurrences(of: "%2", with: formattedMetres))
                .font(.headline.monospacedDigit())
                .accessibilityElement(children: .combine)
        }
    }
}

private struct LinearEquationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var equation: LinearEquation
    @State private var operationOrders: [QuizAnswerOrder]
    @State private var completedSteps = 0
    @State private var didCheckSolution = false
    @State private var feedbackKey: String?
    @State private var feedbackIsCorrect = false

    init() {
        let equation = LinearEquation.random()
        _equation = State(initialValue: equation)
        _operationOrders = State(initialValue: equation.operationChoiceOrders())
    }

    private var variableTerm: String {
        equation.coefficient == 1 ? "x" : "\(equation.coefficient)x"
    }

    private var initialLeftSide: String {
        let offsetTerm = equation.offset < 0
            ? "− \(abs(equation.offset))"
            : "+ \(equation.offset)"
        return "\(variableTerm) \(offsetTerm)"
    }

    private var visibleLeftSide: String {
        switch completedSteps {
        case 0: initialLeftSide
        case 1: variableTerm
        default: "x"
        }
    }

    private var visibleRightSide: String {
        switch completedSteps {
        case 0: "\(equation.rightSide)"
        case 1: "\(equation.isolatedVariableRightSide)"
        default: "\(equation.valueAfterDivision)"
        }
    }

    private var operationChoices: [LinearEquationOperation] {
        equation.operationChoices(at: completedSteps)
    }

    private var progressActionTitle: String {
        didCheckSolution
            ? L10n.text("lab.equation.newExample", store.language)
            : L10n.text("lab.equation.check", store.language)
    }

    private func operationTitle(_ operation: LinearEquationOperation) -> String {
        switch operation {
        case .add(let value):
            return localized("lab.equation.add", value: String(value))
        case .subtract(let value):
            return localized("lab.equation.subtract", value: String(value))
        case .divide(let value):
            return localized("lab.equation.divide", value: String(value))
        case .multiply(let value):
            return localized("lab.equation.multiply", value: String(value))
        }
    }

    private func choose(_ operation: LinearEquationOperation) {
        guard operation.isCorrect(for: equation, at: completedSteps) else {
            feedbackKey = "lab.equation.tryAgain"
            feedbackIsCorrect = false
            return
        }

        completedSteps += 1
        feedbackKey = completedSteps == 1 ? "lab.equation.firstCorrect" : "lab.equation.secondCorrect"
        feedbackIsCorrect = true
    }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.text("lab.equation.title", store.language), systemImage: "scalemass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.indigo)
                Text(L10n.text("lab.equation.help", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                equationSide(
                    title: L10n.text("lab.equation.left", store.language),
                    expression: visibleLeftSide
                )
                Text("=")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .accessibilityLabel(L10n.text("lab.equation.equals", store.language))
                equationSide(
                    title: L10n.text("lab.equation.right", store.language),
                    expression: visibleRightSide
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(visibleLeftSide) = \(visibleRightSide)")

            Text(L10n.text("lab.equation.operationHint", store.language))
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            if completedSteps < 2 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("lab.equation.chooseOperation", store.language))
                        .font(.callout.weight(.semibold))
                    ForEach(Array(operationOrders[completedSteps].displayedOriginalIndices.enumerated()), id: \.offset) { _, originalIndex in
                        let operation = operationChoices[originalIndex]
                        Button {
                            choose(operation)
                        } label: {
                            Text(operationTitle(operation))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if let feedbackKey {
                Label(
                    L10n.text(feedbackKey, store.language),
                    systemImage: feedbackIsCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(feedbackIsCorrect ? Color.green : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }

            HStack {
                Label(
                    String(
                        format: L10n.text("lab.equation.progress", store.language),
                        min(completedSteps, 2),
                        2
                    ),
                    systemImage: didCheckSolution ? "checkmark.seal.fill" : "equal.circle"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(didCheckSolution ? .green : .secondary)
                Spacer()
                if completedSteps == 2 {
                    Button {
                        if !didCheckSolution {
                            didCheckSolution = true
                        } else {
                            let nextEquation = LinearEquation.random()
                            equation = nextEquation
                            operationOrders = nextEquation.operationChoiceOrders()
                            completedSteps = 0
                            didCheckSolution = false
                            feedbackKey = nil
                            feedbackIsCorrect = false
                        }
                    } label: {
                        Label(
                            progressActionTitle,
                            systemImage: didCheckSolution ? "shuffle" : "checkmark.circle"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }

            if didCheckSolution {
                Label(
                    localized(
                        "lab.equation.substitution",
                        value: "\(equation.coefficient) × \(equation.solution) \(equation.offset < 0 ? "− \(abs(equation.offset))" : "+ \(equation.offset)") = \(equation.rightSide)"
                    ),
                    systemImage: equation.isSolution(equation.solution) ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(equation.isSolution(equation.solution) ? .green : .red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func equationSide(title: String, expression: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(expression)
                .font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(Color.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func localized(_ key: String, value: String) -> String {
        L10n.text(key, store.language).replacingOccurrences(of: "%@", with: value)
    }
}

private struct RationalExpressionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var input = 0.0

    private var originalValue: Double? {
        RationalExpressionPractice.originalValue(at: input)
    }

    private var simplifiedValue: Double {
        RationalExpressionPractice.simplifiedValue(at: input)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.rationalHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("f(x) = (x² − 9) / (x − 3)")
                .font(.title3.monospaced().weight(.semibold))
                .accessibilityLabel(L10n.text("lab.rationalFormula", store.language))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("−5")
                    Spacer()
                    Text(String(format: L10n.text("lab.rationalSelectedInput", store.language), L10n.number(input, fractionDigits: 2, store.language)))
                        .font(.caption.monospacedDigit().weight(.semibold))
                    Spacer()
                    Text("5")
                }
                Slider(value: $input, in: -5...5, step: 0.25)
                    .accessibilityLabel(L10n.text("lab.rationalInput", store.language))
                    .accessibilityValue(L10n.number(input, fractionDigits: 2, store.language))
            }

            HStack(alignment: .top, spacing: 12) {
                valueCard(
                    title: L10n.text("lab.rationalOriginal", store.language),
                    value: originalValue.map { L10n.number($0, fractionDigits: 2, store.language) }
                        ?? L10n.text("lab.rationalUndefined", store.language),
                    emphasized: originalValue == nil
                )
                valueCard(
                    title: L10n.text("lab.rationalReduced", store.language),
                    value: L10n.number(simplifiedValue, fractionDigits: 2, store.language),
                    emphasized: false
                )
            }

            Label(
                L10n.text(originalValue == nil ? "lab.rationalExcluded" : "lab.rationalDefined", store.language),
                systemImage: originalValue == nil ? "xmark.circle.fill" : "equal.circle.fill"
            )
            .foregroundStyle(originalValue == nil ? Color.orange : Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func valueCard(title: String, value: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(emphasized ? Color.orange : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct DerivativeRateLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var point = 2.0
    @State private var step = 1.0

    private var secantSlope: Double { 2 * point + step }
    private var tangentSlope: Double { 2 * point }

    var body: some View {
        LabCard {
            Text("f(x) = x²")
                .font(.system(.headline, design: .monospaced))

            Text(L10n.text("lab.derivativeHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                func location(_ x: Double, _ y: Double) -> CGPoint {
                    CGPoint(
                        x: CGFloat((x + 3) / 6) * size.width,
                        y: CGFloat((9 - y) / 12) * size.height
                    )
                }

                var grid = Path()
                for value in -3...3 {
                    let x = CGFloat(value + 3) / 6 * size.width
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for value in stride(from: -3, through: 9, by: 2) {
                    let y = CGFloat(9 - value) / 12 * size.height
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.secondary.opacity(0.16)), lineWidth: 1)

                var axes = Path()
                axes.move(to: location(-3, 0))
                axes.addLine(to: location(3, 0))
                axes.move(to: location(0, -3))
                axes.addLine(to: location(0, 9))
                context.stroke(axes, with: .color(.secondary.opacity(0.7)), lineWidth: 1.5)

                var curve = Path()
                for index in 0...120 {
                    let x = -3.0 + Double(index) * 0.05
                    let p = location(x, x * x)
                    if index == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
                }
                context.stroke(curve, with: .color(.indigo), lineWidth: 2.5)

                var tangent = Path()
                let tangentStart = point - 0.7
                let tangentEnd = point + 0.7
                tangent.move(to: location(tangentStart, tangentSlope * tangentStart - point * point))
                tangent.addLine(to: location(tangentEnd, tangentSlope * tangentEnd - point * point))
                context.stroke(tangent, with: .color(.green), lineWidth: 2.5)

                var secant = Path()
                secant.move(to: location(point, point * point))
                secant.addLine(to: location(point + step, (point + step) * (point + step)))
                context.stroke(secant, with: .color(.orange), lineWidth: 2.5)

                for x in [point, point + step] {
                    let p = location(x, x * x)
                    context.fill(
                        Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)),
                        with: .color(.orange)
                    )
                }
            }
            .frame(height: 230)
            .accessibilityLabel(L10n.text("lab.derivativeGraph", store.language))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.text("lab.derivativePoint", store.language))
                    Spacer()
                    Text(verbatim: "x = " + L10n.number(point, fractionDigits: 1, store.language)).monospacedDigit()
                }
                Slider(value: $point, in: -2.0...2.0, step: 0.1)
                    .accessibilityLabel(Text(L10n.text("lab.derivativePoint", store.language)))

                HStack {
                    Text(L10n.text("lab.derivativeStep", store.language))
                    Spacer()
                    Text(verbatim: "h = " + L10n.number(step, fractionDigits: 1, store.language)).monospacedDigit()
                }
                Slider(value: $step, in: 0.05...1.0, step: 0.05)
                    .accessibilityLabel(Text(L10n.text("lab.derivativeStep", store.language)))
            }

            HStack(spacing: 14) {
                Label(L10n.text("lab.derivativeFunction", store.language), systemImage: "waveform.path")
                    .foregroundStyle(.indigo)
                Label(L10n.text("lab.derivativeSecant", store.language), systemImage: "line.diagonal")
                    .foregroundStyle(.orange)
                Label(L10n.text("lab.derivativeTangent", store.language), systemImage: "line.diagonal")
                    .foregroundStyle(.green)
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)

            VStack(alignment: .leading, spacing: 5) {
                Text(String(format: L10n.text("lab.derivativeSecantValue", store.language), L10n.number(secantSlope, fractionDigits: 2, store.language)))
                Text(String(format: L10n.text("lab.derivativeTangentValue", store.language), L10n.number(tangentSlope, fractionDigits: 2, store.language)))
                    .fontWeight(.semibold)
            }
            .font(.callout.monospacedDigit())
        }
    }
}

private struct ConstrainedOptimizationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var angleRadians = Double.pi / 8
    @State private var showsSurface = false

    private var gradientAngleDegrees: Double? {
        LagrangeSurfaceModel.gradientAngleDegrees(x: point.x, y: point.y)
    }

    private var surfaceAccessibilityValue: String {
        let angle = gradientAngleDegrees.map { L10n.number($0, fractionDigits: 0, store.language) + "°" } ?? "—"
        return String(
            format: L10n.text("lab.optimization.surfaceValue", store.language),
            L10n.number(point.x, fractionDigits: 3, store.language),
            L10n.number(point.y, fractionDigits: 3, store.language),
            L10n.number(point.objective, fractionDigits: 3, store.language),
            angle
        )
    }

    private var point: ConstrainedOptimizationPoint {
        ConstrainedOptimizationPoint(angleRadians: angleRadians) ??
            ConstrainedOptimizationPoint(angleRadians: 0)!
    }

    private var statusKey: String {
        switch point.extremum {
        case .maximum: "lab.optimization.maximum"
        case .minimum: "lab.optimization.minimum"
        case .nonStationary: "lab.optimization.nonStationary"
        }
    }

    var body: some View {
        LabCard {
            Text("f(x, y) = xy     subject to     x² + y² = 1")
                .font(.system(.headline, design: .monospaced))

            Text(L10n.text("lab.optimization.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.optimization.viewMode", store.language), selection: $showsSurface) {
                Text(L10n.text("lab.optimization.view2D", store.language)).tag(false)
                Text(L10n.text("lab.optimization.view3D", store.language)).tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.optimization.viewMode")

            if showsSurface {
                ConstrainedOptimizationSurfaceView(
                    x: point.x,
                    y: point.y,
                    accessibilityLabel: L10n.text("lab.optimization.surfaceLabel", store.language),
                    accessibilityValue: surfaceAccessibilityValue
                )
                .frame(height: 340)
                .accessibilityIdentifier("lab.optimization.surface")

                Text(L10n.text("lab.optimization.surfaceHint", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 14) {
                    Label(L10n.text("lab.optimization.legendGradF", store.language), systemImage: "arrow.up.right")
                        .foregroundStyle(.orange)
                    Label(L10n.text("lab.optimization.legendGradG", store.language), systemImage: "arrow.up.right")
                        .foregroundStyle(.purple)
                    Label(L10n.text("lab.optimization.legendExtrema", store.language), systemImage: "circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.caption)
                .labelStyle(.titleAndIcon)
            } else {
                GeometryReader { geometry in
                    Canvas { context, size in
                        guard size.width > 0, size.height > 0 else { return }
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let radius = min(size.width, size.height) * 0.37
                        func location(_ x: Double, _ y: Double) -> CGPoint {
                            CGPoint(
                                x: center.x + CGFloat(x) * radius,
                                y: center.y - CGFloat(y) * radius
                            )
                        }

                        var axes = Path()
                        axes.move(to: location(-1.18, 0))
                        axes.addLine(to: location(1.18, 0))
                        axes.move(to: location(0, -1.18))
                        axes.addLine(to: location(0, 1.18))
                        context.stroke(axes, with: .color(.secondary.opacity(0.55)), lineWidth: 1.25)

                        var diagonals = Path()
                        diagonals.move(to: location(-1.1, -1.1))
                        diagonals.addLine(to: location(1.1, 1.1))
                        diagonals.move(to: location(-1.1, 1.1))
                        diagonals.addLine(to: location(1.1, -1.1))
                        context.stroke(
                            diagonals,
                            with: .color(.orange.opacity(0.58)),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                        )

                        var circle = Path()
                        for index in 0...180 {
                            let theta = Double(index) / 180 * 2 * Double.pi
                            let p = location(cos(theta), sin(theta))
                            if index == 0 { circle.move(to: p) } else { circle.addLine(to: p) }
                        }
                        context.stroke(circle, with: .color(.indigo), lineWidth: 3)

                        let stationaryAngles: [Double] = [45, 135, 225, 315]
                        for degrees in stationaryAngles {
                            let theta = degrees * Double.pi / 180
                            let p = location(cos(theta), sin(theta))
                            let marker = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                            context.fill(Path(ellipseIn: marker), with: .color(.green))
                        }

                        let selected = location(point.x, point.y)
                        let selection = CGRect(x: selected.x - 7, y: selected.y - 7, width: 14, height: 14)
                        context.fill(Path(ellipseIn: selection), with: .color(Color.accentColor))
                        context.stroke(Path(ellipseIn: selection), with: .color(.white), lineWidth: 1.5)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                var angle = atan2(center.y - value.location.y, value.location.x - center.x)
                                if angle < 0 { angle += 2 * Double.pi }
                                if angle.isFinite { angleRadians = angle }
                            }
                    )
                }
                .frame(height: 250)
                .accessibilityLabel(L10n.text("lab.optimization.graph", store.language))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.text("lab.optimization.angle", store.language))
                    Spacer()
                    Text(verbatim: L10n.measurement(angleRadians * 180 / Double.pi, fractionDigits: 0, unit: "°", store.language))
                        .monospacedDigit()
                }
                Slider(
                    value: $angleRadians,
                    in: 0...(2 * Double.pi - Double.pi / 180),
                    step: Double.pi / 180
                )
                    .accessibilityLabel(Text(L10n.text("lab.optimization.angle", store.language)))
            }

            if !showsSurface {
                HStack(spacing: 14) {
                    Label(L10n.text("lab.optimization.constraint", store.language), systemImage: "circle")
                        .foregroundStyle(.indigo)
                    Label(L10n.text("lab.optimization.candidates", store.language), systemImage: "line.diagonal")
                        .foregroundStyle(.orange)
                    Label(L10n.text("lab.optimization.selected", store.language), systemImage: "smallcircle.filled.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .font(.caption)
                .labelStyle(.titleAndIcon)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(String(
                    format: L10n.text("lab.optimization.point", store.language),
                    L10n.number(point.x, fractionDigits: 3, store.language),
                    L10n.number(point.y, fractionDigits: 3, store.language)
                ))
                Text(String(format: L10n.text("lab.optimization.objective", store.language), L10n.number(point.objective, fractionDigits: 3, store.language)))
                Text(String(format: L10n.text("lab.optimization.derivative", store.language), L10n.number(point.tangentDerivative, fractionDigits: 3, store.language)))
                if let gradientAngleDegrees {
                    Text(String(format: L10n.text("lab.optimization.gradientAngle", store.language), L10n.number(gradientAngleDegrees, fractionDigits: 0, store.language)))
                }
                Text(L10n.text(statusKey, store.language))
                    .fontWeight(.semibold)
                    .foregroundStyle(point.isStationary ? Color.green : Color.secondary)
                if let multiplier = point.lagrangeMultiplier {
                    Text(String(format: L10n.text("lab.optimization.multiplier", store.language), L10n.number(multiplier, fractionDigits: 3, store.language)))
                }
            }
            .font(.callout.monospacedDigit())

            Text(L10n.text("lab.optimization.limits", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DomainRangeLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedScenario = 0
    @State private var bound = 4.0

    private var integerBound: Int { Int(bound) }
    private var inputLowerBound: Double {
        selectedScenario == 1 ? -bound : 0
    }
    private var inputUpperBound: Double {
        selectedScenario == 2 ? bound * bound : bound
    }
    private var outputUpperBound: Double {
        switch selectedScenario {
        case 0: return 2 + 3 * bound
        case 1: return bound * bound
        default: return bound
        }
    }
    private var equation: String {
        switch selectedScenario {
        case 0: return "C(k) = 2 + 3k"
        case 1: return "f(x) = x²"
        default: return "g(x) = √x"
        }
    }
    private var inputInterval: String {
        switch selectedScenario {
        case 0: return "0 ≤ k ≤ \(integerBound)"
        case 1: return "−\(integerBound) ≤ x ≤ \(integerBound)"
        default: return "0 ≤ x ≤ \(integerBound * integerBound)"
        }
    }
    private var outputInterval: String {
        switch selectedScenario {
        case 0: return "2 ≤ C(k) ≤ \(2 + 3 * integerBound)"
        case 1: return "0 ≤ f(x) ≤ \(integerBound * integerBound)"
        default: return "0 ≤ g(x) ≤ \(integerBound)"
        }
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.domainHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedScenario) {
                Text(L10n.text("lab.domainTaxi", store.language)).tag(0)
                Text(L10n.text("lab.domainSquare", store.language)).tag(1)
                Text(L10n.text("lab.domainRoot", store.language)).tag(2)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Text(L10n.text("session.lab", store.language)))

            Text(equation)
                .font(.system(.headline, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(L10n.text("lab.domainInput", store.language)): \(inputInterval)")
                Text("\(L10n.text("lab.domainOutput", store.language)): \(outputInterval)")
            }
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)

            Canvas { context, size in
                guard size.width > 0, size.height > 0, inputUpperBound > inputLowerBound else { return }

                var grid = Path()
                for step in 0...4 {
                    let fraction = CGFloat(step) / 4
                    let x = size.width * fraction
                    let y = size.height * fraction
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.secondary.opacity(0.14)), lineWidth: 1)

                var axes = Path()
                axes.move(to: CGPoint(x: 0, y: size.height))
                axes.addLine(to: CGPoint(x: size.width, y: size.height))
                let zeroXFraction = (0 - inputLowerBound) / (inputUpperBound - inputLowerBound)
                let zeroX = CGFloat(zeroXFraction) * size.width
                axes.move(to: CGPoint(x: zeroX, y: 0))
                axes.addLine(to: CGPoint(x: zeroX, y: size.height))
                context.stroke(axes, with: .color(.secondary.opacity(0.55)), lineWidth: 1)

                var curve = Path()
                for sample in 0...80 {
                    let fraction = Double(sample) / 80
                    let input = inputLowerBound + fraction * (inputUpperBound - inputLowerBound)
                    let output: Double
                    switch selectedScenario {
                    case 0: output = 2 + 3 * input
                    case 1: output = input * input
                    default: output = input.squareRoot()
                    }
                    let yFraction = min(max(output / outputUpperBound, 0), 1)
                    let point = CGPoint(
                        x: CGFloat(fraction) * size.width,
                        y: size.height * (1 - CGFloat(yFraction))
                    )
                    if sample == 0 {
                        curve.move(to: point)
                    } else {
                        curve.addLine(to: point)
                    }
                }
                context.stroke(curve, with: .color(.indigo), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .frame(height: 150)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(
                format: L10n.text("lab.domainGraphLabel", store.language),
                inputInterval,
                outputInterval
            )))

            HStack {
                Text("\(L10n.text("lab.domainBound", store.language)): N = \(integerBound)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1…8")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Slider(value: $bound, in: 1...8, step: 1)
                .accessibilityLabel(Text(L10n.text("lab.domainBound", store.language)))
        }
    }
}

private struct TenseContrastLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var scenario = 0
    @State private var selectedAnswer: Int?
    @State private var optionOrder = QuizAnswerOrder(optionCount: 2, answerOriginalIndex: 0)
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(
        itemIDs: ["present-simple-continuous.scenario-0", "present-simple-continuous.scenario-1"]
    )

    var body: some View {
        LabCard {
            Text(L10n.text("lab.tensePrompt", store.language))
                .font(.headline)
            Picker("", selection: $scenario) {
                Text(L10n.text("lab.tenseScenario0", store.language)).tag(0)
                Text(L10n.text("lab.tenseScenario1", store.language)).tag(1)
            }
            .pickerStyle(.segmented)
            .onChange(of: scenario) { newScenario in
                selectedAnswer = nil
                optionOrder = QuizAnswerOrder(optionCount: 2, answerOriginalIndex: newScenario)
            }

            HStack(spacing: 10) {
                ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selectedAnswer = displayIndex
                        if let selectedOriginalIndex = optionOrder.originalIndex(forDisplayedIndex: displayIndex),
                           let evidence = assessmentTracker.recordSubmission(
                            selectedAnswerIndex: selectedOriginalIndex,
                            correctAnswerIndex: scenario,
                            optionCount: 2,
                            itemID: "present-simple-continuous.scenario-\(scenario)"
                           ) {
                            store.recordStudyAssessment(
                                lessonID: "english.present_simple_and_continuous",
                                evidence: evidence
                            )
                        }
                    } label: {
                        Text(L10n.text("lab.tenseOption\(scenario)\(originalIndex)", store.language))
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(
                                selectedAnswer == displayIndex
                                    ? (optionOrder.isCorrect(displayedIndex: displayIndex) ? Color.green.opacity(0.16) : Color.orange.opacity(0.16))
                                    : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedAnswer {
                let isCorrect = optionOrder.isCorrect(displayedIndex: selectedAnswer)
                Label(
                    L10n.text(isCorrect ? "lab.tenseCorrect" : "lab.tenseIncorrect", store.language),
                    systemImage: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .foregroundStyle(isCorrect ? Color.green : Color.orange)

                if let explanationKey = TenseContrastFeedback.explanationKey(
                    scenario: scenario,
                    isCorrect: isCorrect
                ) {
                    Text(L10n.text(explanationKey, store.language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct PresentPerfectAspectLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var scenario = 0
    @State private var selectedAnswer: Int?

    private let correctAnswers = [1, 1, 0]
    private static let questionIDs = [
        "present-perfect.question-0",
        "present-perfect.question-1",
        "present-perfect.question-2"
    ]
    @State private var optionOrder = QuizAnswerOrder(optionCount: 2, answerOriginalIndex: 1)
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(itemIDs: Self.questionIDs)

    var body: some View {
        LabCard {
            Text(L10n.text("lab.perfectPrompt", store.language))
                .font(.headline)

            Picker(L10n.text("lab.perfectSituation", store.language), selection: $scenario) {
                ForEach(0..<3, id: \.self) { index in
                    Text(L10n.text("lab.perfectScenario\(index)", store.language)).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: scenario) { newScenario in
                selectedAnswer = nil
                optionOrder = QuizAnswerOrder(optionCount: 2, answerOriginalIndex: correctAnswers[newScenario])
            }

            Text(L10n.text("lab.perfectSentence\(scenario)", store.language))
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selectedAnswer = displayIndex
                        if let selectedOriginalIndex = optionOrder.originalIndex(forDisplayedIndex: displayIndex),
                           let evidence = assessmentTracker.recordSubmission(
                            selectedAnswerIndex: selectedOriginalIndex,
                            correctAnswerIndex: correctAnswers[scenario],
                            optionCount: 2,
                            itemID: Self.questionIDs[scenario]
                           ) {
                            store.recordStudyAssessment(
                                lessonID: "english.present_perfect_simple_continuous",
                                evidence: evidence
                            )
                        }
                    } label: {
                        Text(L10n.text("lab.perfectOption\(scenario)\(originalIndex)", store.language))
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(answerColor(forDisplayedIndex: displayIndex), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedAnswer {
                let isCorrect = optionOrder.isCorrect(displayedIndex: selectedAnswer)
                Label(
                    L10n.text("lab.perfectFeedback\(scenario)\(isCorrect ? 1 : 0)", store.language),
                    systemImage: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .foregroundStyle(isCorrect ? Color.green : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func answerColor(forDisplayedIndex displayIndex: Int) -> Color {
        guard let selectedAnswer, selectedAnswer == displayIndex else {
            return Color.secondary.opacity(0.08)
        }
        return optionOrder.isCorrect(displayedIndex: displayIndex) ? Color.green.opacity(0.16) : Color.orange.opacity(0.16)
    }
}

private struct ConditionalPracticeQuestion {
    let id: String
    let promptKey: String
    let feedbackKey: String
}

private final class EnglishWordStressSpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?

    @Published private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ sentence: String, voice: AVSpeechSynthesisVoice) {
        stop()
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        currentUtterance = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        currentUtterance = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.currentUtterance = nil
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.currentUtterance = nil
            self.isSpeaking = false
        }
    }
}

private struct EnglishWordStressLab: View {
    @EnvironmentObject private var store: LearningStore
    @StateObject private var speechPlayer = EnglishWordStressSpeechPlayer()
    @State private var index = 0
    @State private var selection: Int?
    @State private var wasCorrect: Bool?
    @State private var complete = false
    @State private var selectedAccent = EnglishSpeechAccent.british
    @State private var assessmentTracker = EnglishWordStressAssessmentTracker()
    @State private var optionOrders = QuizAnswerOrder.balancedSequence(
        optionCount: 2,
        answerOriginalIndices: EnglishWordStressPractice.questions.map(\.correctOption)
    )

    private let questions = EnglishWordStressPractice.questions
    private let lessonID = "english.sounds_stress_rhythm"

    private var installedVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    private var installedAccents: [EnglishSpeechAccent] {
        EnglishSpeechAccent.available(in: installedVoices.map(\.language))
    }

    private var activeAccent: EnglishSpeechAccent? {
        installedAccents.contains(selectedAccent) ? selectedAccent : installedAccents.first
    }

    private var activeVoice: AVSpeechSynthesisVoice? {
        guard let activeAccent else { return nil }
        return installedVoices.first(where: { $0.language == activeAccent.rawValue })
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.stressHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if complete {
                Label(L10n.text("lab.stressComplete", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("lab.stressRestart", store.language), systemImage: "arrow.counterclockwise") {
                    reset()
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.stressProgress", store.language), index + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                Text(L10n.text("lab.stressQuestion\(index)", store.language))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        if speechPlayer.isSpeaking {
                            speechPlayer.stop()
                        } else if let activeVoice {
                            speechPlayer.speak(questions[index].spokenSentence, voice: activeVoice)
                        }
                    } label: {
                        Label(
                            L10n.text(speechPlayer.isSpeaking ? "lab.stressStopAudio" : "lab.stressListen", store.language),
                            systemImage: speechPlayer.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(activeVoice == nil)
                    .accessibilityIdentifier("english.stress.listen")

                    Menu {
                        ForEach(installedAccents) { accent in
                            Button {
                                selectedAccent = accent
                                speechPlayer.stop()
                            } label: {
                                if activeAccent == accent {
                                    Label(
                                        L10n.text(accent == .british ? "lab.stressBritishVoice" : "lab.stressAmericanVoice", store.language),
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text(L10n.text(accent == .british ? "lab.stressBritishVoice" : "lab.stressAmericanVoice", store.language))
                                }
                            }
                        }
                    } label: {
                        Label(
                            L10n.text(
                                activeAccent == .american ? "lab.stressAmericanVoice" : "lab.stressBritishVoice",
                                store.language
                            ),
                            systemImage: "globe"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(installedAccents.count < 2)
                    .accessibilityIdentifier("english.stress.voice")
                }

                Text(L10n.text(activeVoice == nil ? "lab.stressVoiceUnavailable" : "lab.stressSyntheticAudioNote", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(optionOrders[index].displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selection = displayIndex
                        wasCorrect = nil
                    } label: {
                        Label(
                            L10n.text("lab.stressOption.\(questions[index].word).\(originalIndex)", store.language),
                            systemImage: selection == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.bordered)
                    .tint(selection == displayIndex ? .accentColor : .secondary)
                    .accessibilityAddTraits(selection == displayIndex ? .isSelected : [])
                    .accessibilityIdentifier("english.stress.option.\(questions[index].id).\(originalIndex)")
                }

                if let wasCorrect {
                    Label(
                        wasCorrect
                            ? L10n.text("lab.stressFeedback\(index)", store.language)
                            : L10n.text("lab.stressTryAgain", store.language),
                        systemImage: wasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(wasCorrect ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: advanceOrCheck) {
                    Text(L10n.text(
                        wasCorrect == true
                            ? (index == questions.count - 1 ? "lab.stressFinish" : "lab.stressNext")
                            : "lab.stressCheck",
                        store.language
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection == nil && wasCorrect != true)
                .accessibilityIdentifier("english.stress.check")
            }
        }
        .onDisappear { speechPlayer.stop() }
        .accessibilityIdentifier("english.word-stress-lab")
    }

    private func advanceOrCheck() {
        speechPlayer.stop()
        if wasCorrect == true {
            guard index < questions.count - 1 else {
                complete = true
                return
            }
            index += 1
            selection = nil
            wasCorrect = nil
            return
        }

        guard let selection,
              let originalOption = optionOrders[index].originalIndex(forDisplayedIndex: selection) else { return }
        wasCorrect = EnglishWordStressPractice.isCorrect(originalOption, for: questions[index].id)
        if let evidence = assessmentTracker.recordSubmission(option: originalOption, for: questions[index].id) {
            store.recordStudyAssessment(lessonID: lessonID, evidence: evidence)
        }
    }

    private func reset() {
        speechPlayer.stop()
        index = 0
        selection = nil
        wasCorrect = nil
        complete = false
        assessmentTracker.reset()
        optionOrders = QuizAnswerOrder.balancedSequence(
            optionCount: 2,
            answerOriginalIndices: questions.map(\.correctOption)
        )
    }
}

private struct EnglishBeLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var index = 0
    @State private var selection: Int?
    @State private var wasCorrect: Bool?
    @State private var complete = false
    @State private var assessmentTracker = EnglishBeAssessmentTracker()
    @State private var optionOrders = QuizAnswerOrder.balancedSequence(
        optionCount: 3,
        answerOriginalIndices: EnglishBePractice.questions.map(\.correctOption)
    )

    private let questions = EnglishBePractice.questions
    private let lessonID = "english.subject_pronouns_and_be"

    private var question: EnglishBeQuestion { questions[index] }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.beHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if complete {
                Label(L10n.text("lab.beComplete", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("lab.beRestart", store.language), systemImage: "arrow.counterclockwise") {
                    reset()
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.beProgress", store.language), index + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                Text(question.prompt)
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("english.be.prompt.\(question.id)")
                if store.language == .ru {
                    Text(question.translation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(optionOrders[index].displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selection = displayIndex
                        wasCorrect = nil
                    } label: {
                        Label(
                            question.options[originalIndex],
                            systemImage: selection == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.bordered)
                    .tint(selection == displayIndex ? .accentColor : .secondary)
                    .disabled(wasCorrect == true)
                    .accessibilityAddTraits(selection == displayIndex ? .isSelected : [])
                    .accessibilityIdentifier("english.be.option.\(question.id).\(originalIndex)")
                }

                if let wasCorrect {
                    if wasCorrect {
                        Text(store.language == .ru ? question.explanationRussian : question.explanationEnglish)
                            .font(.callout)
                            .foregroundStyle(.green)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(L10n.text("lab.beTryAgain", store.language), systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.orange)
                            Text(store.language == .ru ? question.hintRussian : question.hintEnglish)
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button(action: advanceOrCheck) {
                    Text(L10n.text(
                        wasCorrect == true
                            ? (index == questions.count - 1 ? "lab.beFinish" : "lab.beNext")
                            : "lab.beCheck",
                        store.language
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection == nil && wasCorrect != true)
                .accessibilityIdentifier("english.be.check")
            }
        }
        .accessibilityIdentifier("english.subject-pronouns-be-lab")
    }

    private func advanceOrCheck() {
        if wasCorrect == true {
            guard index < questions.count - 1 else {
                complete = true
                return
            }
            index += 1
            selection = nil
            wasCorrect = nil
            return
        }

        guard let selection,
              let originalOption = optionOrders[index].originalIndex(forDisplayedIndex: selection) else { return }
        wasCorrect = EnglishBePractice.isCorrect(originalOption, for: question.id)
        if let evidence = assessmentTracker.recordSubmission(option: originalOption, for: question.id) {
            store.recordStudyAssessment(lessonID: lessonID, evidence: evidence)
        }
    }

    private func reset() {
        index = 0
        selection = nil
        wasCorrect = nil
        complete = false
        assessmentTracker.reset()
        optionOrders = QuizAnswerOrder.balancedSequence(
            optionCount: 3,
            answerOriginalIndices: questions.map(\.correctOption)
        )
    }
}

private struct ConditionalsLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var index = 0
    @State private var selection: Int?
    @State private var wasCorrect: Bool?
    @State private var complete = false
    @State private var assessmentTracker = EnglishConditionalAssessmentTracker()
    @State private var optionOrders = Self.makeOptionOrders()

    private var optionOrder: QuizAnswerOrder { optionOrders[index] }

    private let questions = [
        ConditionalPracticeQuestion(id: EnglishConditionalPractice.scenarios[0].id, promptKey: "lab.conditionalScenario0", feedbackKey: "lab.conditionalFeedback0"),
        ConditionalPracticeQuestion(id: EnglishConditionalPractice.scenarios[1].id, promptKey: "lab.conditionalScenario1", feedbackKey: "lab.conditionalFeedback1"),
        ConditionalPracticeQuestion(id: EnglishConditionalPractice.scenarios[2].id, promptKey: "lab.conditionalScenario2", feedbackKey: "lab.conditionalFeedback2")
    ]

    var body: some View {
        LabCard {
            Text(L10n.text("lab.conditionalHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if complete {
                Label(L10n.text("lab.conditionalComplete", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("lab.conditionalRestart", store.language), systemImage: "arrow.counterclockwise") {
                    reset()
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.conditionalProgress", store.language), index + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                Text(L10n.text(questions[index].promptKey, store.language))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selection = displayIndex
                        wasCorrect = nil
                    } label: {
                        Label(
                            L10n.text("lab.conditionalOption\(originalIndex)", store.language),
                            systemImage: selection == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selection == displayIndex ? .accentColor : .secondary)
                    .accessibilityAddTraits(selection == displayIndex ? .isSelected : [])
                }

                if let wasCorrect {
                    Label(
                        wasCorrect
                            ? L10n.text(questions[index].feedbackKey, store.language)
                            : L10n.text("lab.conditionalTryAgain", store.language),
                        systemImage: wasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(wasCorrect ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    if wasCorrect == true {
                        if index == questions.count - 1 {
                            complete = true
                        } else {
                            index += 1
                            selection = nil
                            wasCorrect = nil
                        }
                    } else if let selection {
                        let isCorrect = optionOrder.isCorrect(displayedIndex: selection)
                        wasCorrect = isCorrect
                        if let form = EnglishConditionalForm(rawValue: optionOrder.displayedOriginalIndices[selection]),
                           let evidence = assessmentTracker.recordSubmission(form: form, for: questions[index].id) {
                            store.recordStudyAssessment(
                                lessonID: "english.zero_first_second_conditionals",
                                evidence: evidence
                            )
                        }
                    }
                } label: {
                    Text(L10n.text(
                        wasCorrect == true
                            ? (index == questions.count - 1 ? "lab.conditionalFinish" : "lab.conditionalNext")
                            : "lab.conditionalCheck",
                        store.language
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection == nil && wasCorrect != true)
            }
        }
    }

    private func reset() {
        index = 0
        selection = nil
        wasCorrect = nil
        complete = false
        assessmentTracker.reset()
        optionOrders = Self.makeOptionOrders()
    }

    private static func makeOptionOrders() -> [QuizAnswerOrder] {
        QuizAnswerOrder.balancedSequence(
            optionCount: EnglishConditionalForm.allCases.count,
            answerOriginalIndices: EnglishConditionalPractice.scenarios.map { $0.correctForm.rawValue }
        )
    }
}

private struct ReportedSpeechLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var index = 0
    @State private var selection: Int?
    @State private var wasCorrect: Bool?
    @State private var incorrectAnswerOption: Int?
    @State private var complete = false
    @State private var attemptsForQuestion = 0
    @State private var optionOrders = Self.makeOptionOrders()

    private var optionOrder: QuizAnswerOrder { optionOrders[index] }

    private let questions = EnglishReportedSpeechPractice.questions
    private let lessonID = "english.reported_speech_questions_and_backshift"

    var body: some View {
        LabCard {
            Text(L10n.text("lab.reportedHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if complete {
                Label(L10n.text("lab.reportedComplete", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("lab.reportedRestart", store.language), systemImage: "arrow.counterclockwise") {
                    reset()
                }
                .buttonStyle(.bordered)
            } else {
                Text(String(format: L10n.text("lab.reportedProgress", store.language), index + 1, questions.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index + 1), total: Double(questions.count))
                Text(L10n.text("lab.reportedQuestion\(index)", store.language))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Button {
                        selection = displayIndex
                        wasCorrect = nil
                        incorrectAnswerOption = nil
                    } label: {
                        Label(
                            L10n.text("lab.reportedOption\(index).\(originalIndex)", store.language),
                            systemImage: selection == displayIndex ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.bordered)
                    .tint(selection == displayIndex ? .accentColor : .secondary)
                    .accessibilityAddTraits(selection == displayIndex ? .isSelected : [])
                }

                if let wasCorrect {
                    let feedbackKey = wasCorrect
                        ? "lab.reportedFeedback\(index)"
                        : (incorrectAnswerOption.map { "lab.reportedWrong\(index).\($0)" } ?? "lab.reportedTryAgain")
                    Label(
                        L10n.text(feedbackKey, store.language),
                        systemImage: wasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(wasCorrect ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: advanceOrCheck) {
                    Text(L10n.text(
                        wasCorrect == true
                            ? (index == questions.count - 1 ? "lab.reportedFinish" : "lab.reportedNext")
                            : (attemptsForQuestion > 0 ? "lab.reportedCheckAgain" : "lab.reportedCheck"),
                        store.language
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection == nil && wasCorrect != true)
            }
        }
    }

    private func advanceOrCheck() {
        if wasCorrect == true {
            guard index < questions.count - 1 else {
                complete = true
                return
            }
            index += 1
            selection = nil
            wasCorrect = nil
            attemptsForQuestion = 0
            return
        }

        guard let selectedDisplayIndex = selection else { return }
        attemptsForQuestion += 1
        let isCorrect = optionOrder.isCorrect(displayedIndex: selectedDisplayIndex)
        wasCorrect = isCorrect
        if !isCorrect {
            incorrectAnswerOption = optionOrder.displayedOriginalIndices[selectedDisplayIndex]
            selection = nil
        } else {
            incorrectAnswerOption = nil
        }
        store.recordStudyAssessment(
            lessonID: lessonID,
            evidence: StudyAssessmentEvidence(
                taskType: "knowledge_check",
                attempts: attemptsForQuestion,
                firstTryCorrect: isCorrect && attemptsForQuestion == 1,
                hintsUsed: 0,
                passed: isCorrect,
                itemID: questions[index].id
            )
        )
    }

    private func reset() {
        index = 0
        selection = nil
        wasCorrect = nil
        incorrectAnswerOption = nil
        complete = false
        attemptsForQuestion = 0
        optionOrders = Self.makeOptionOrders()
    }

    private static func makeOptionOrders() -> [QuizAnswerOrder] {
        QuizAnswerOrder.balancedSequence(
            optionCount: 3,
            answerOriginalIndices: EnglishReportedSpeechPractice.questions.map(\.correctOption)
        )
    }
}

private struct OsmosisLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var insideConcentration = 4.0
    @State private var outsideConcentration = 6.0
    @State private var prediction: InteractivePredictionAttempt
    @State private var selectedDisplayIndex = -1

    private let predictionOptionKeys = [
        "lab.osmosisOptionEnters",
        "lab.osmosisOptionLeaves",
        "lab.osmosisOptionBalanced"
    ]
    private static let predictionItemID = "biology.passive_transport_osmosis.water_flow"

    init() {
        _prediction = State(initialValue: Self.makePrediction(insideSolute: 4, outsideSolute: 6))
    }

    private var flow: OsmosisWaterFlow {
        OsmosisWaterFlow.predict(
            insideSolute: Int(insideConcentration.rounded()),
            outsideSolute: Int(outsideConcentration.rounded())
        )
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.osmosisHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 14) {
                concentrationDisplay(
                    title: L10n.text("lab.osmosisOutside", store.language),
                    value: outsideConcentration
                )
                Image(systemName: prediction.hasAnswered && prediction.isCorrect ? flow.arrowSymbol : "questionmark.circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .accessibilityLabel(Text(L10n.text(
                        prediction.hasAnswered && prediction.isCorrect ? flow.explanationKey : "lab.osmosisArrowHidden",
                        store.language
                    )))
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.12))
                        .frame(width: 118, height: 118)
                    Circle()
                        .strokeBorder(Color.cyan.opacity(0.75), lineWidth: 3)
                        .frame(width: 118, height: 118)
                    VStack(spacing: 5) {
                        Text(L10n.text("lab.osmosisInside", store.language))
                            .font(.caption.weight(.semibold))
                        Text("\(insideConcentration, specifier: "%.0f")")
                            .font(.title2.monospacedDigit().weight(.bold))
                        soluteDots(insideConcentration)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(L10n.text("lab.osmosisInside", store.language) + ", \(Int(insideConcentration))"))
            }
            .frame(maxWidth: .infinity)

            concentrationSlider(title: L10n.text("lab.osmosisOutside", store.language), value: $outsideConcentration)
                .onChange(of: outsideConcentration) { _ in startNewPrediction() }
            concentrationSlider(title: L10n.text("lab.osmosisInside", store.language), value: $insideConcentration)
                .onChange(of: insideConcentration) { _ in startNewPrediction() }

            Text(L10n.text("lab.osmosisPredictionPrompt", store.language))
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.osmosisPredictionPrompt", store.language), selection: $selectedDisplayIndex) {
                ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Text(L10n.text(predictionOptionKeys[originalIndex], store.language)).tag(displayIndex)
                }
            }
            .pickerStyle(.segmented)
            .disabled(prediction.hasAnswered)

            Button(L10n.text("lab.osmosisCheckPrediction", store.language)) {
                prediction.select(displayedIndex: selectedDisplayIndex)
                guard let evidence = prediction.currentAnswerEventEvidence() else { return }
                store.recordStudyAssessment(lessonID: "biology.passive_transport_osmosis", evidence: evidence)
            }
            .buttonStyle(.borderedProminent)
            .disabled(prediction.hasAnswered || selectedDisplayIndex < 0)

            if prediction.hasAnswered {
                if prediction.isCorrect {
                    Label(L10n.text("lab.osmosisCorrect", store.language), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                    Label(L10n.text(flow.explanationKey, store.language), systemImage: flow.arrowSymbol)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("lab.osmosisNewPrediction", store.language)) {
                        startNewPrediction()
                    }
                    .buttonStyle(.link)
                } else {
                    Label(L10n.text("lab.osmosisIncorrect", store.language), systemImage: "arrow.uturn.backward.circle")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                    Text(L10n.text("lab.osmosisHintAfterWrong", store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("lab.osmosisRetry", store.language)) {
                        prediction.retry()
                        selectedDisplayIndex = -1
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private static func makePrediction(insideSolute: Int, outsideSolute: Int) -> InteractivePredictionAttempt {
        guard let attempt = InteractivePredictionAttempt(
            optionCount: 3,
            answerOriginalIndex: OsmosisWaterFlow.predict(insideSolute: insideSolute, outsideSolute: outsideSolute).answerOriginalIndex,
            itemID: Self.predictionItemID
        ) else {
            preconditionFailure("An osmosis prediction must have one valid answer.")
        }
        return attempt
    }

    private func startNewPrediction() {
        prediction = Self.makePrediction(
            insideSolute: Int(insideConcentration.rounded()),
            outsideSolute: Int(outsideConcentration.rounded())
        )
        selectedDisplayIndex = -1
    }

    private func concentrationDisplay(title: String, value: Double) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
            Text("\(value, specifier: "%.0f")")
                .font(.title2.monospacedDigit().weight(.bold))
            soluteDots(value)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func soluteDots(_ value: Double) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<Int(value), id: \.self) { _ in
                Circle().fill(Color.purple.opacity(0.78)).frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func concentrationSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...10, step: 1)
        }
    }
}

private struct BiologyInvestigationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var design = BiologyExperimentDesign(
        factorToChange: .waterAmount,
        outcomeToMeasure: .leafCount,
        controls: [],
        independentUnitsPerCondition: 1,
        plantsPerUnit: 3
    )
    @State private var didReviewDesign = false

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 6) {
                Label(L10n.text("lab.investigation.title", store.language), systemImage: "leaf")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                Text(L10n.text("lab.investigation.scenario", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                lightGroup(
                    title: L10n.text("lab.investigation.groupA", store.language),
                    hours: "4"
                )
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                lightGroup(
                    title: L10n.text("lab.investigation.groupB", store.language),
                    hours: "8"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Picker(
                    L10n.text("lab.investigation.change", store.language),
                    selection: Binding(
                        get: { design.factorToChange },
                        set: { design.factorToChange = $0; didReviewDesign = false }
                    )
                ) {
                    ForEach(BiologyStudyFactor.allCases, id: \.self) { factor in
                        Text(L10n.text(factorTitleKey(factor), store.language)).tag(factor)
                    }
                }
                .pickerStyle(.menu)

                Picker(
                    L10n.text("lab.investigation.measure", store.language),
                    selection: Binding(
                        get: { design.outcomeToMeasure },
                        set: { design.outcomeToMeasure = $0; didReviewDesign = false }
                    )
                ) {
                    ForEach(BiologyStudyOutcome.allCases, id: \.self) { outcome in
                        Text(L10n.text(outcomeTitleKey(outcome), store.language)).tag(outcome)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("lab.investigation.keepSame", store.language))
                    .font(.callout.weight(.semibold))
                ForEach(BiologyStudyControl.allCases, id: \.self) { control in
                    Toggle(
                        L10n.text(controlTitleKey(control), store.language),
                        isOn: Binding(
                            get: { design.controls.contains(control) },
                            set: { isSelected in
                                if isSelected {
                                    design.controls.insert(control)
                                } else {
                                    design.controls.remove(control)
                                }
                                didReviewDesign = false
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                }
            }

            Stepper(
                value: Binding(
                    get: { design.independentUnitsPerCondition },
                    set: { design.independentUnitsPerCondition = $0; didReviewDesign = false }
                ),
                in: 1...12
            ) {
                Text(
                    String(
                        format: L10n.text("lab.investigation.replicates", store.language),
                        design.independentUnitsPerCondition
                    )
                )
                .monospacedDigit()
            }

            Stepper(
                value: Binding(
                    get: { design.plantsPerUnit },
                    set: { design.plantsPerUnit = $0; didReviewDesign = false }
                ),
                in: 1...12
            ) {
                Text(
                    String(
                        format: L10n.text("lab.investigation.plantsPerUnit", store.language),
                        design.plantsPerUnit
                    )
                )
                .monospacedDigit()
            }

            Text(L10n.text("lab.investigation.replicationHint", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                didReviewDesign = true
            } label: {
                Label(
                    L10n.text("lab.investigation.check", store.language),
                    systemImage: "checkmark.magnifyingglass"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            if didReviewDesign {
                if design.isReadyToCollectData {
                    Label(
                        L10n.text("lab.investigation.ready", store.language),
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text("lab.investigation.noResults", store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            L10n.text("lab.investigation.review", store.language),
                            systemImage: "exclamationmark.circle"
                        )
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.orange)
                        ForEach(design.issues, id: \.self) { issue in
                            Label(
                                L10n.text(issueTitleKey(issue), store.language),
                                systemImage: "arrow.turn.down.right"
                            )
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func lightGroup(title: String, hours: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: "sun.max.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.medium))
            Text(
                String(
                    format: L10n.text("lab.investigation.hours", store.language),
                    hours
                )
            )
            .font(.callout.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func factorTitleKey(_ factor: BiologyStudyFactor) -> String {
        switch factor {
        case .lightExposure:
            return "lab.investigation.factor.light"
        case .waterAmount:
            return "lab.investigation.factor.water"
        case .plantType:
            return "lab.investigation.factor.plant"
        }
    }

    private func outcomeTitleKey(_ outcome: BiologyStudyOutcome) -> String {
        switch outcome {
        case .heightChange:
            return "lab.investigation.outcome.height"
        case .leafCount:
            return "lab.investigation.outcome.leaves"
        case .soilMoisture:
            return "lab.investigation.outcome.soil"
        }
    }

    private func controlTitleKey(_ control: BiologyStudyControl) -> String {
        switch control {
        case .waterAmount:
            return "lab.investigation.control.water"
        case .seedType:
            return "lab.investigation.control.seed"
        case .potAndSoil:
            return "lab.investigation.control.pot"
        case .temperatureAndDuration:
            return "lab.investigation.control.conditions"
        }
    }

    private func issueTitleKey(_ issue: BiologyStudyIssue) -> String {
        "lab.investigation.issue.\(issue.rawValue)"
    }
}

private struct PhotosynthesisLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var light = 70.0
    @State private var carbonDioxide = 45.0

    private var rate: Double { min(light, carbonDioxide) }
    private var limitingFactorKey: String {
        if light == carbonDioxide { return "lab.photosynthesisBalanced" }
        return light < carbonDioxide ? "lab.photosynthesisLightLimits" : "lab.photosynthesisCO2Limits"
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.photosynthesisHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                stageCard(
                    symbol: "sun.max.fill",
                    color: .orange,
                    title: L10n.text("lab.photosynthesisLightStage", store.language),
                    detail: L10n.text("lab.photosynthesisEnergyProducts", store.language)
                )
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                stageCard(
                    symbol: "leaf.fill",
                    color: .green,
                    title: L10n.text("lab.photosynthesisCarbonStage", store.language),
                    detail: L10n.text("lab.photosynthesisCarbonProduct", store.language)
                )
            }

            factorSlider(title: L10n.text("lab.photosynthesisLight", store.language), value: $light)
            factorSlider(title: L10n.text("lab.photosynthesisCO2", store.language), value: $carbonDioxide)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.text("lab.photosynthesisRelativeRate", store.language))
                    Spacer()
                    Text("\(Int(rate))%")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
                ProgressView(value: rate, total: 100)
                    .tint(.green)
                Label(L10n.text(limitingFactorKey, store.language), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
            }
            .padding(12)
            .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func stageCard(symbol: String, color: Color, title: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 94)
        .padding(9)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func factorSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...100, step: 5)
                .accessibilityLabel(Text(title))
        }
    }
}

private struct SymmetryLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var bodyPlan = 1
    @State private var cutAngle = 0.0

    private var interpretationKey: String {
        if bodyPlan == 0 { return "lab.symmetryAsymmetrical" }
        if bodyPlan == 2 { return "lab.symmetryRadial" }
        return cutAngle < 5 ? "lab.symmetryBilateralMatch" : "lab.symmetryBilateralNoMatch"
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.symmetryHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker(L10n.text("lab.symmetryPlan", store.language), selection: $bodyPlan) {
                Text(L10n.text("lab.symmetryOptionAsym", store.language)).tag(0)
                Text(L10n.text("lab.symmetryOptionBilateral", store.language)).tag(1)
                Text(L10n.text("lab.symmetryOptionRadial", store.language)).tag(2)
            }
            .pickerStyle(.segmented)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width * 0.22, size.height * 0.36)
                var body = Path()
                if bodyPlan == 0 {
                    body.move(to: CGPoint(x: center.x - radius * 0.8, y: center.y - radius * 0.45))
                    body.addCurve(to: CGPoint(x: center.x + radius * 0.75, y: center.y - radius * 0.3),
                                  control1: CGPoint(x: center.x - radius * 0.15, y: center.y - radius * 1.05),
                                  control2: CGPoint(x: center.x + radius * 1.15, y: center.y - radius * 0.85))
                    body.addCurve(to: CGPoint(x: center.x + radius * 0.35, y: center.y + radius * 0.75),
                                  control1: CGPoint(x: center.x + radius * 1.0, y: center.y + radius * 0.15),
                                  control2: CGPoint(x: center.x + radius * 0.75, y: center.y + radius * 0.95))
                    body.addCurve(to: CGPoint(x: center.x - radius * 0.8, y: center.y - radius * 0.45),
                                  control1: CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.95),
                                  control2: CGPoint(x: center.x - radius * 1.2, y: center.y + radius * 0.25))
                    body.closeSubpath()
                } else {
                    body.addEllipse(in: CGRect(x: center.x - radius * 0.62,
                                               y: center.y - radius,
                                               width: radius * 1.24,
                                               height: radius * 2))
                }
                context.fill(body, with: .color(bodyPlan == 0 ? .teal.opacity(0.5) : .green.opacity(0.28)))
                context.stroke(body, with: .color(bodyPlan == 0 ? .teal : .green), lineWidth: 2)

                var planes = Path()
                let angles = bodyPlan == 2
                    ? stride(from: 0.0, to: 180.0, by: 45.0).map { $0 + cutAngle }
                    : [cutAngle]
                for angle in angles {
                    let radians = angle * .pi / 180
                    let dx = cos(radians) * radius * 1.25
                    let dy = sin(radians) * radius * 1.25
                    planes.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
                    planes.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
                }
                context.stroke(planes, with: .color(.orange), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
            .frame(height: 180)
            .accessibilityLabel(Text(L10n.text(interpretationKey, store.language)))

            if bodyPlan == 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("lab.symmetryRotatePlane", store.language))
                    Slider(value: $cutAngle, in: 0...90, step: 5)
                        .accessibilityLabel(Text(L10n.text("lab.symmetryRotatePlane", store.language)))
                }
            }

            Label(L10n.text(interpretationKey, store.language), systemImage: "view.2d")
                .font(.callout.weight(.medium))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct LabCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct LinearFunctionLab: View {
    @EnvironmentObject private var store: LearningStore
    let lessonID: String
    @State private var slope = 2.0
    @State private var intercept = -1.0
    @State private var input = 3.0
    @State private var predictionText = ""
    @State private var round = LinearFunctionPredictionRound(
        function: LinearFunctionModel(slope: 2, intercept: -1)!,
        input: 3
    )

    init(lessonID: String = LinearFunctionPredictionRound.lessonID) {
        self.lessonID = lessonID
    }

    private var function: LinearFunctionModel {
        LinearFunctionModel(slope: slope, intercept: intercept)!
    }

    private var formula: String {
        let slopeTerm = slope < 0 ? "− \(format(abs(slope)))x" : "\(format(slope))x"
        let interceptTerm = intercept < 0 ? "− \(format(abs(intercept)))" : "+ \(format(intercept))"
        return "y = \(slopeTerm) \(interceptTerm)"
    }

    private var parsedAnswer: Double? {
        let normalized = predictionText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private var solutionText: String {
        String(
            format: L10n.text("lab.linear.solution", store.language),
            format(slope),
            format(input),
            format(intercept),
            format(function.value(at: input)!)
        )
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.linear.prompt", store.language))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text(formula)
                .font(.system(.title2, design: .monospaced, weight: .semibold))
                .accessibilityLabel(Text(String(format: L10n.text("lab.linear.formula", store.language), formula)))

            LinearFunctionPlot(function: function, input: input, language: store.language)
                .frame(height: 230)

            Text(String(format: L10n.text("lab.linear.currentInput", store.language), format(input)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                parameterRow("lab.linear.slope", value: $slope, range: -2...2, step: 0.5)
                parameterRow("lab.linear.intercept", value: $intercept, range: -4...4, step: 0.5)
                parameterRow("lab.linear.input", value: $input, range: -3...3, step: 0.5)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(L10n.text("lab.linear.placeholder", store.language), text: $predictionText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                    .accessibilityLabel(Text(L10n.text("lab.linear.prediction", store.language)))
                    .onSubmit { checkPrediction() }
                    .disabled(round.lastAnswerCorrect == true || round.attempts >= 2)

                if round.submittedAnswer == nil {
                    Button(L10n.text("lab.linear.check", store.language)) {
                        checkPrediction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedAnswer == nil)
                } else if round.lastAnswerCorrect == false && round.attempts < 2 {
                    Button(L10n.text("lab.linear.retry", store.language)) {
                        retryPrediction()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let isCorrect = round.lastAnswerCorrect {
                Label(
                    L10n.text(isCorrect ? "lab.linear.correct" : "lab.linear.incorrect", store.language),
                    systemImage: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .foregroundStyle(isCorrect ? Color.green : Color.orange)
                .fixedSize(horizontal: false, vertical: true)

                if isCorrect || round.attempts >= 2 {
                    Text(solutionText)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(L10n.text("lab.linear.hint", store.language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onChange(of: slope) { _ in resetPrediction() }
        .onChange(of: intercept) { _ in resetPrediction() }
        .onChange(of: input) { _ in resetPrediction() }
    }

    private func parameterRow(
        _ labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 10) {
            Text(L10n.text(labelKey, store.language))
                .frame(width: 146, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(Text(L10n.text(labelKey, store.language)))
            Text(format(value.wrappedValue))
                .font(.callout.monospacedDigit())
                .frame(width: 54, alignment: .trailing)
        }
    }

    private func checkPrediction() {
        guard let answer = parsedAnswer,
              round.submit(answer: answer) != nil,
              let evidence = round.evidence else { return }
        store.recordStudyAssessment(lessonID: lessonID, evidence: evidence)
    }

    private func retryPrediction() {
        round.retry()
        predictionText = ""
    }

    private func resetPrediction() {
        round = LinearFunctionPredictionRound(function: function, input: input)
        predictionText = ""
    }

    private func format(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: store.language == .ru ? "ru_RU" : "en_US"))
                .precision(.fractionLength(0...2))
        )
    }
}

private struct LinearFunctionPlot: View {
    let function: LinearFunctionModel
    let input: Double
    let language: AppLanguage

    private let xRange: ClosedRange<Double> = -4...4
    private let yRange: ClosedRange<Double> = -12...12

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 34, y: 10, width: max(0, size.width - 46), height: max(0, size.height - 26))
            guard plot.width > 0, plot.height > 0 else { return }

            var clippingPath = Path()
            clippingPath.addRect(plot)
            context.clip(to: clippingPath)

            func location(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(
                    x: plot.minX + CGFloat((x - xRange.lowerBound) / (xRange.upperBound - xRange.lowerBound)) * plot.width,
                    y: plot.maxY - CGFloat((y - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)) * plot.height
                )
            }

            var grid = Path()
            for xTick in -4...4 {
                let x = location(Double(xTick), 0).x
                grid.move(to: CGPoint(x: x, y: plot.minY))
                grid.addLine(to: CGPoint(x: x, y: plot.maxY))
            }
            for yTick in stride(from: -12, through: 12, by: 4) {
                let y = location(0, Double(yTick)).y
                grid.move(to: CGPoint(x: plot.minX, y: y))
                grid.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            context.stroke(grid, with: .color(.secondary.opacity(0.16)), lineWidth: 1)

            var axes = Path()
            axes.move(to: location(xRange.lowerBound, 0))
            axes.addLine(to: location(xRange.upperBound, 0))
            axes.move(to: location(0, yRange.lowerBound))
            axes.addLine(to: location(0, yRange.upperBound))
            context.stroke(axes, with: .color(.secondary.opacity(0.65)), lineWidth: 1.5)

            var line = Path()
            for index in 0...160 {
                let x = xRange.lowerBound + Double(index) / 160 * (xRange.upperBound - xRange.lowerBound)
                guard let y = function.value(at: x) else { continue }
                let point = location(x, y)
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.stroke(line, with: .color(.indigo), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            if let output = function.value(at: input), yRange.contains(output) {
                let point = location(input, output)
                let marker = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                context.fill(marker, with: .color(.teal))
                context.stroke(marker, with: .color(.primary.opacity(0.9)), lineWidth: 1.5)
            }
        }
        .accessibilityLabel(L10n.text("lab.linear.graph", language))
    }
}

private struct SlopeLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var slope = 1.5

    var body: some View {
        LabCard {
            HStack {
                Label("y = ax", systemImage: "function")
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Text(verbatim: "a = " + L10n.number(slope, fractionDigits: 1, store.language))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Canvas { context, size in
                var grid = Path()
                for step in 0...4 {
                    let x = size.width * CGFloat(step) / 4
                    let y = size.height * CGFloat(step) / 4
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.secondary.opacity(0.14)), lineWidth: 1)
                var axis = Path()
                axis.move(to: CGPoint(x: 0, y: size.height / 2))
                axis.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(axis, with: .color(.secondary.opacity(0.55)), lineWidth: 1)
                var line = Path()
                for step in 0...60 {
                    let unitX = CGFloat(step) / 60
                    let xValue = (unitX * 2) - 1
                    let yValue = CGFloat(slope) * xValue
                    let point = CGPoint(x: unitX * size.width, y: size.height / 2 - yValue * size.height / 2.4)
                    if step == 0 { line.move(to: point) } else { line.addLine(to: point) }
                }
                context.stroke(line, with: .color(.indigo), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .frame(height: 150)
            Slider(value: $slope, in: 0.5...3.0, step: 0.5)
            HStack(spacing: 4) {
                Text(L10n.text("lab.slope", store.language))
                Text(":")
                Text(slope, format: .number.precision(.fractionLength(1)))
            }
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SentenceLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedWords: [Int] = []
    private let wordOrder = [3, 2, 0, 1]

    var body: some View {
        LabCard {
            Text(L10n.text("lab.buildSentence", store.language))
                .font(.headline)
            HStack {
                ForEach(wordOrder, id: \.self) { index in
                    Button { selectedWords.append(index) } label: { Text(L10n.text("english.word\(index)", store.language)) }
                    .buttonStyle(.bordered)
                    .disabled(selectedWords.contains(index))
                }
            }
            Text(selectedWords.map { L10n.text("english.word\($0)", store.language) }.joined(separator: " "))
                .font(.title3.weight(.medium))
                .frame(minHeight: 32, alignment: .leading)
            HStack {
                Label { Text(L10n.text("practice.words", store.language)) } icon: { Image(systemName: "textformat") }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { selectedWords.removeAll() } label: { Text(L10n.text("lab.clear", store.language)) }
                    .buttonStyle(.link)
            }
        }
    }
}

private struct ForceLab: View {
    let lessonID: String?

    @EnvironmentObject private var store: LearningStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var force = 12.0
    @State private var mass = 3.0
    @State private var elapsed = 0.0
    @State private var elapsedAtStart = 0.0
    @State private var startedAt: ContinuousClock.Instant?
    @State private var prediction: InteractivePredictionAttempt
    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    init(lessonID: String? = nil) {
        self.lessonID = lessonID
        _prediction = State(initialValue: Self.makePrediction())
    }

    private var motion: ForceMotion { ForceMotion(force: force, mass: mass, time: elapsed) }
    private var isRunning: Bool { startedAt != nil }

    var body: some View {
        LabCard {
            if lessonID != nil {
                predictionView
            }
            Force3DVisualization(force: force, mass: mass, displacement: motion.displacement, language: store.language)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(Text(L10n.text("lab.force3DHint", store.language)))
            Text(L10n.text("lab.force3DHint", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("F = ma   ·   v = at   ·   x = ½at²")
                .font(.system(.headline, design: .monospaced))
            Text(L10n.text("lab.forceAssumptions", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
            valueSlider(title: L10n.text("lab.force", store.language), value: $force, range: -30...30, unit: "N")
            valueSlider(title: L10n.text("lab.mass", store.language), value: $mass, range: 1...10, unit: "kg")
            HStack {
                Button {
                    if isRunning { pause() } else { start() }
                } label: {
                    Label(L10n.text(isRunning ? "lab.motionPause" : "lab.motionPlay", store.language),
                          systemImage: isRunning ? "pause.fill" : "play.fill")
                }
                .disabled(reduceMotion || scenePhase != .active)
                Button(L10n.text("lab.motionStep", store.language)) {
                    elapsed = min(ForceMotion.duration, elapsed + 0.1)
                }
                .disabled(isRunning || motion.hasFinished)
                Button(L10n.text("lab.motionReset", store.language), action: reset)
            }
            ProgressView(value: elapsed, total: ForceMotion.duration)
                .accessibilityLabel(Text(L10n.text("lab.motionTime", store.language)))
                .accessibilityValue(Text(verbatim: L10n.number(elapsed, fractionDigits: 1, store.language) + " / " + L10n.measurement(ForceMotion.duration, fractionDigits: 0, unit: "s", store.language)))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .leading)], alignment: .leading, spacing: 12) {
                reading("lab.motionTime", value: elapsed, unit: "s")
                reading("lab.acceleration", value: motion.acceleration, unit: "m/s²")
                reading("lab.motionVelocity", value: motion.velocity, unit: "m/s")
                reading("lab.motionDisplacement", value: motion.displacement, unit: "m")
            }
            if reduceMotion {
                Text(L10n.text("lab.motionReduced", store.language)).font(.caption).foregroundStyle(.secondary)
            }
            if motion.hasFinished {
                Text(L10n.text("lab.motionFinished", store.language)).font(.callout)
            }
            Text(L10n.text("lab.forceExperiment", store.language)).font(.callout)
        }
        .onReceive(timer) { _ in advance() }
        .onChange(of: force) { _ in reset() }
        .onChange(of: mass) { _ in reset() }
        .onChange(of: scenePhase) { phase in if phase != .active { pause() } }
        .onChange(of: reduceMotion) { enabled in if enabled { pause() } }
        .onDisappear(perform: pause)
    }

    private var predictionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("lab.forcePredictionPrompt", store.language))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(0..<prediction.choiceOrder.displayedOriginalIndices.count, id: \.self) { displayedIndex in
                let optionIndex = prediction.choiceOrder.originalIndex(forDisplayedIndex: displayedIndex) ?? displayedIndex
                Button {
                    submitPrediction(displayedIndex: displayedIndex)
                } label: {
                    HStack {
                        if prediction.selectedOriginalIndex == optionIndex {
                            Image(systemName: prediction.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        }
                        Text(L10n.text("lab.forcePredictionOption.\(optionIndex)", store.language))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(prediction.hasAnswered)
            }
            if prediction.hasAnswered {
                if prediction.isCorrect {
                    Label(L10n.text("lab.forcePredictionCorrect", store.language), systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                    Button(L10n.text("lab.forcePredictionNew", store.language), action: startNewPrediction)
                        .buttonStyle(.link)
                } else {
                    Label(L10n.text("lab.forcePredictionWrong", store.language), systemImage: "arrow.counterclockwise.circle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                    Text(L10n.text("lab.forcePredictionHint", store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("lab.forcePredictionRetry", store.language), action: retryPrediction)
                        .buttonStyle(.link)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
    }

    private func submitPrediction(displayedIndex: Int) {
        prediction.select(displayedIndex: displayedIndex)
        guard let lessonID,
              let evidence = prediction.currentAnswerEventEvidence() else { return }
        store.recordStudyAssessment(lessonID: lessonID, evidence: evidence)
    }

    private func retryPrediction() {
        prediction.retry()
    }

    private func startNewPrediction() {
        prediction = Self.makePrediction()
        reset()
    }

    private static func makePrediction() -> InteractivePredictionAttempt {
        guard let attempt = InteractivePredictionAttempt(
            optionCount: 3,
            answerOriginalIndex: 2,
            itemID: "physics.net_force_and_acceleration.force_doubling_prediction"
        ) else {
            preconditionFailure("The force-law prediction must have a valid correct option.")
        }
        return attempt
    }

    private func reading(_ key: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text(key, store.language)).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: L10n.measurement(value, fractionDigits: 2, unit: unit, store.language)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func start() {
        guard !reduceMotion, scenePhase == .active else { return }
        if motion.hasFinished { elapsed = 0 }
        elapsedAtStart = elapsed
        startedAt = ContinuousClock.now
    }

    private func advance() {
        guard let startedAt else { return }
        let duration = startedAt.duration(to: ContinuousClock.now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        elapsed = min(ForceMotion.duration, elapsedAtStart + max(0, seconds))
        if motion.hasFinished { self.startedAt = nil }
    }

    private func pause() {
        advance()
        startedAt = nil
    }

    private func reset() {
        startedAt = nil
        elapsedAtStart = 0
        elapsed = 0
    }

    private func valueSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 0, unit: unit, store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
                .accessibilityLabel(Text(title))
        }
    }
}

private struct LengthMeasurementLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var length = 12.4
    @State private var uncertainty = 0.2

    private let scaleCentimetres = 32.0

    private var measurement: LengthMeasurement {
        LengthMeasurement(centimetres: length, uncertaintyCentimetres: uncertainty)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.measurementTitle", store.language))
                .font(.headline)
            Text(L10n.text("lab.measurementHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                let trackWidth = max(geometry.size.width - 12, 0)
                let lowerX = measurement.lowerCentimetres / scaleCentimetres * trackWidth
                let centreX = measurement.centimetres / scaleCentimetres * trackWidth
                let bandWidth = 2 * uncertainty / scaleCentimetres * trackWidth
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(.secondary.opacity(0.5))
                        .frame(width: trackWidth, height: 3)
                        .offset(x: 6, y: 25)
                    Capsule()
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: bandWidth, height: 18)
                        .offset(x: 6 + lowerX, y: 17)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                        .offset(x: 1 + centreX, y: 21)
                }
            }
            .frame(height: 54)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L10n.text("lab.measurementBand", store.language)))
            .accessibilityValue(Text(verbatim: L10n.number(measurement.lowerCentimetres, fractionDigits: 1, store.language)
                + "–" + L10n.measurement(measurement.upperCentimetres, fractionDigits: 1, unit: "cm", store.language)))

            HStack {
                Text(verbatim: L10n.measurement(0, fractionDigits: 0, unit: "cm", store.language))
                Spacer()
                Text(verbatim: L10n.measurement(scaleCentimetres, fractionDigits: 0, unit: "cm", store.language))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("lab.measurementLength", store.language))
                Slider(value: $length, in: 3...30, step: 0.1)
                    .accessibilityLabel(Text(L10n.text("lab.measurementLength", store.language)))
                    .accessibilityValue(Text(verbatim: L10n.measurement(length, fractionDigits: 1, unit: "cm", store.language)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("lab.measurementUncertainty", store.language))
                Slider(value: $uncertainty, in: 0.1...2, step: 0.1)
                    .accessibilityLabel(Text(L10n.text("lab.measurementUncertainty", store.language)))
                    .accessibilityValue(Text(verbatim: L10n.measurement(uncertainty, fractionDigits: 1, unit: "cm", store.language)))
            }

            Text(verbatim: L10n.number(length, fractionDigits: 1, store.language)
                + " ± " + L10n.measurement(uncertainty, fractionDigits: 1, unit: "cm", store.language)
                + " = " + L10n.number(measurement.metres, fractionDigits: 3, store.language)
                + " ± " + L10n.measurement(measurement.uncertaintyMetres, fractionDigits: 3, unit: "m", store.language))
                .font(.headline.monospacedDigit())
                .textSelection(.enabled)
            Text(verbatim: L10n.text("lab.measurementRelative", store.language) + ": "
                + L10n.measurement(measurement.relativeUncertaintyPercent, fractionDigits: 1, unit: "%", store.language))
                .font(.callout.monospacedDigit())
            Text(L10n.text("lab.measurementLimits", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FrictionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var mass = 5.0
    @State private var appliedForce = 15.0
    @State private var staticCoefficient = 0.4
    @State private var kineticCoefficient = 0.3
    @State private var time = 2.0
    @State private var predictionPractice = FrictionPredictionPracticeSession()

    private var motion: FrictionMotion {
        FrictionMotion(
            mass: mass,
            appliedForce: appliedForce,
            staticCoefficient: staticCoefficient,
            kineticCoefficient: min(kineticCoefficient, staticCoefficient),
            time: time
        )
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.frictionHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lesson.friction.model")

            GeometryReader { geometry in
                let width = max(geometry.size.width - 64, 0)
                let travel = min(width, motion.displacement * 16)
                ZStack(alignment: .leading) {
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(.secondary.opacity(0.45))
                            .frame(height: 3)
                    }
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.gradient)
                        .overlay {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(.white)
                        }
                        .frame(width: 54, height: 42)
                        .offset(x: travel, y: 0)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(L10n.text("lab.frictionBlock", store.language)))
                .accessibilityValue(Text(motion.isSliding
                    ? L10n.text("lab.frictionSliding", store.language)
                    : L10n.text("lab.frictionResting", store.language)))
            }
            .frame(height: 64)
            .accessibilityElement(children: .contain)

            HStack(spacing: 14) {
                Label("F = " + L10n.measurement(appliedForce, fractionDigits: 1, unit: "N", store.language), systemImage: "arrow.right")
                Label("f = " + L10n.measurement(motion.frictionForce, fractionDigits: 1, unit: "N", store.language), systemImage: "arrow.left")
            }
            .font(.callout.monospacedDigit())
            .accessibilityElement(children: .combine)

            Text(L10n.text(motion.isSliding ? "lab.frictionSliding" : "lab.frictionResting", store.language))
                .font(.headline)
                .foregroundStyle(motion.isSliding ? Color.orange : Color.primary)
                .accessibilityIdentifier("lesson.friction.motion-state")
            Text(verbatim: L10n.text("lab.frictionThreshold", store.language) + ": "
                + L10n.measurement(motion.maximumStaticFriction, fractionDigits: 2, unit: "N", store.language))
                .font(.callout.monospacedDigit())
                .accessibilityIdentifier("lesson.friction.threshold")

            slider("lab.mass", value: $mass, range: 1...10, step: 0.5, unit: "kg", identifier: "mass")
            slider("lab.frictionPush", value: $appliedForce, range: 0...60, step: 1, unit: "N", identifier: "push")
            slider("lab.frictionStaticCoefficient", value: $staticCoefficient, range: 0.1...0.8, step: 0.05, unit: "", identifier: "static-coefficient")
            slider("lab.frictionKineticCoefficient", value: $kineticCoefficient, range: 0.05...staticCoefficient, step: 0.05, unit: "", identifier: "kinetic-coefficient")
            slider("lab.frictionTime", value: $time, range: 0...FrictionMotion.duration, step: 0.1, unit: "s", identifier: "time")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 12) {
                reading("lab.frictionNormal", value: motion.normalForce, unit: "N", identifier: "normal")
                reading("lab.frictionForce", value: motion.frictionForce, unit: "N", identifier: "force")
                reading("lab.frictionAcceleration", value: motion.acceleration, unit: "m/s²", identifier: "acceleration")
                reading("lab.frictionVelocity", value: motion.velocity, unit: "m/s", identifier: "velocity")
                reading("lab.frictionDisplacement", value: motion.displacement, unit: "m", identifier: "displacement")
            }

            Text(L10n.text("lab.frictionPrediction", store.language))
                .font(.callout)
            predictionPracticeView
            Text(L10n.text("lab.frictionLimits", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: staticCoefficient) { newValue in
            kineticCoefficient = min(kineticCoefficient, newValue)
        }
    }

    private var predictionPracticeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            if let question = predictionPractice.currentQuestion {
                Text(L10n.text("lab.frictionPredictionTitle", store.language))
                    .font(.subheadline.weight(.semibold))
                Text(String(format: L10n.text("lab.frictionPredictionQuestion", store.language), question.appliedForce))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(predictionPractice.currentOptionOriginalIndices.indices, id: \.self) { displayedIndex in
                    let originalIndex = predictionPractice.currentOptionOriginalIndices[displayedIndex]
                    let isSelected = predictionPractice.selectedDisplayedIndex == displayedIndex
                    Button {
                        predictionPractice.selectOption(at: displayedIndex)
                    } label: {
                        HStack {
                            Text(L10n.text(
                                originalIndex == 0 ? "lab.frictionPredictionRest" : "lab.frictionPredictionSlide",
                                store.language
                            ))
                            Spacer(minLength: 8)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : nil)
                    .disabled(predictionPractice.feedback == .correct)
                    .accessibilityIdentifier("lesson.friction.prediction.option.\(question.id).\(originalIndex)")
                }

                if let feedback = predictionPractice.feedback {
                    let caseKey = question.expectedSliding ? "slide" : "rest"
                    let resultKey = feedback == .correct ? "correct" : "review"
                    Label(
                        L10n.text("lab.frictionPrediction.\(caseKey).\(resultKey)", store.language),
                        systemImage: feedback == .correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(feedback == .correct ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("lesson.friction.prediction.feedback")
                }

                let buttonTitleKey = predictionPractice.feedback == .correct
                    ? (question.id == FrictionPredictionPracticeSession.questions.last?.id
                        ? "lab.frictionPredictionFinish"
                        : "lab.frictionPredictionNext")
                    : "lab.frictionPredictionCheck"
                Button {
                    if predictionPractice.feedback == .correct {
                        predictionPractice.advance()
                    } else if let evidence = predictionPractice.checkAnswer() {
                        store.recordStudyAssessment(
                            lessonID: "physics.static_and_kinetic_friction",
                            evidence: evidence
                        )
                    }
                } label: {
                    Text(L10n.text(buttonTitleKey, store.language))
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("lesson.friction.prediction.action")
                .disabled(predictionPractice.selectedDisplayedIndex == nil && predictionPractice.feedback != .correct)
            } else {
                Text(L10n.text("lab.frictionPredictionComplete", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("lesson.friction.prediction.complete")
                Button(L10n.text("lab.frictionPredictionRestart", store.language)) {
                    predictionPractice.restart()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 4)
    }

    private func slider(
        _ titleKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.text(titleKey, store.language))
                Spacer(minLength: 8)
                Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 2, unit: unit, store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(Text(L10n.text(titleKey, store.language)))
                .accessibilityValue(Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 2, unit: unit, store.language)))
                .accessibilityIdentifier("lesson.friction.slider.\(identifier)")
        }
    }

    private func reading(_ key: String, value: Double, unit: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text(key, store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: L10n.measurement(value, fractionDigits: 2, unit: unit, store.language))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lesson.friction.reading.\(identifier)")
    }
}

private struct ProjectileMotionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var launchSpeed = 20.0
    @State private var angleDegrees = 35.0
    @State private var elapsed = 0.0
    @State private var comparesComplement = true

    private var motion: ProjectileMotion {
        ProjectileMotion(launchSpeed: launchSpeed, angleDegrees: angleDegrees)
    }
    private var complement: ProjectileMotion {
        ProjectileMotion(launchSpeed: launchSpeed, angleDegrees: 90 - angleDegrees)
    }
    private var displayedMaximumRange: Double {
        max(max(motion.horizontalRange, comparesComplement ? complement.horizontalRange : 0), 1) * 1.12
    }
    private var displayedMaximumHeight: Double {
        max(max(motion.maximumHeight, comparesComplement ? complement.maximumHeight : 0), 1) * 1.16
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.projectile.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.projectile.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let inset: CGFloat = 12
                func location(_ x: Double, _ y: Double) -> CGPoint {
                    CGPoint(
                        x: inset + CGFloat(x / displayedMaximumRange) * (size.width - 2 * inset),
                        y: size.height - inset - CGFloat(y / displayedMaximumHeight) * (size.height - 2 * inset)
                    )
                }

                var grid = Path()
                for step in 0...4 {
                    let fraction = CGFloat(step) / 4
                    let x = inset + fraction * (size.width - 2 * inset)
                    let y = inset + fraction * (size.height - 2 * inset)
                    grid.move(to: CGPoint(x: x, y: inset))
                    grid.addLine(to: CGPoint(x: x, y: size.height - inset))
                    grid.move(to: CGPoint(x: inset, y: y))
                    grid.addLine(to: CGPoint(x: size.width - inset, y: y))
                }
                context.stroke(grid, with: .color(.secondary.opacity(0.14)), lineWidth: 1)

                func trajectoryPath(for model: ProjectileMotion) -> Path {
                    var path = Path()
                    let samples = 100
                    for index in 0...samples {
                        let t = model.flightTime * Double(index) / Double(samples)
                        let point = model.position(at: t)
                        let plotted = location(point.x, point.y)
                        if index == 0 { path.move(to: plotted) } else { path.addLine(to: plotted) }
                    }
                    return path
                }

                if comparesComplement {
                    context.stroke(
                        trajectoryPath(for: complement),
                        with: .color(.orange.opacity(0.85)),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                }
                context.stroke(trajectoryPath(for: motion), with: .color(.accentColor), lineWidth: 3)
                let current = motion.position(at: elapsed)
                let point = location(current.x, current.y)
                context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(.accentColor))
            }
            .frame(height: 230)
            .accessibilityLabel(Text(L10n.text("lab.projectile.chart", store.language)))

            HStack(spacing: 16) {
                Label(L10n.text("lab.projectile.current", store.language), systemImage: "circle.fill")
                    .foregroundStyle(.tint)
                if comparesComplement {
                    Label("90° − θ", systemImage: "line.diagonal")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button(L10n.text(comparesComplement ? "lab.projectile.hideCompare" : "lab.projectile.compare", store.language)) {
                    comparesComplement.toggle()
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)

            projectileSlider(title: L10n.text("lab.projectile.speed", store.language), value: $launchSpeed, range: 5...30, unit: "m/s")
            projectileSlider(title: L10n.text("lab.projectile.angle", store.language), value: $angleDegrees, range: 15...75, unit: "°")

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("lab.projectile.time", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $elapsed, in: 0...max(motion.flightTime, 0.05), step: 0.05)
                    .accessibilityLabel(Text(L10n.text("lab.projectile.time", store.language)))
                Text(verbatim: "t = " + L10n.measurement(elapsed, fractionDigits: 2, unit: "s", store.language))
                    .monospacedDigit()
                    .font(.caption)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 12) {
                projectileReading("lab.projectile.range", value: motion.horizontalRange, unit: "m")
                projectileReading("lab.projectile.height", value: motion.maximumHeight, unit: "m")
                projectileReading("lab.projectile.flight", value: motion.flightTime, unit: "s")
                projectileReading("lab.projectile.position", value: motion.position(at: elapsed).x, unit: "m")
            }
            Text(L10n.text("lab.projectile.compareTask", store.language))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("lab.projectile.limits", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: angleDegrees) { _ in elapsed = min(elapsed, motion.flightTime) }
        .onChange(of: launchSpeed) { _ in elapsed = min(elapsed, motion.flightTime) }
    }

    private func projectileSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 0, unit: unit, store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
                .accessibilityLabel(Text(title))
        }
    }

    private func projectileReading(_ key: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text(key, store.language)).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: L10n.measurement(value, fractionDigits: 2, unit: unit, store.language)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Force3DVisualization: NSViewRepresentable {
    let force: Double
    let mass: Double
    let displacement: Double
    let language: AppLanguage

    final class Coordinator {
        var sceneLanguage: AppLanguage?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.makeScene(language: language)
        context.coordinator.sceneLanguage = language
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .windowBackgroundColor
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        // The distance labels are baked into the scene, so rebuild it when the interface language changes.
        if context.coordinator.sceneLanguage != language {
            view.scene = Self.makeScene(language: language)
            context.coordinator.sceneLanguage = language
        }
        guard let scene = view.scene else { return }
        Self.update(scene: scene, force: force, mass: mass, displacement: displacement)
    }

    private static func makeScene(language: AppLanguage) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.windowBackgroundColor

        let box = SCNBox(width: 1, height: 0.72, length: 0.72, chamferRadius: 0.08)
        let boxMaterial = SCNMaterial()
        boxMaterial.diffuse.contents = NSColor.systemBlue
        boxMaterial.metalness.contents = 0.08
        boxMaterial.roughness.contents = 0.42
        box.materials = [boxMaterial]
        let boxNode = SCNNode(geometry: box)
        boxNode.name = "mass-block"
        scene.rootNode.addChildNode(boxNode)

        let ground = SCNBox(width: 16, height: 0.06, length: 2.6, chamferRadius: 0.02)
        ground.firstMaterial?.diffuse.contents = NSColor.tertiaryLabelColor
        let groundNode = SCNNode(geometry: ground)
        groundNode.position = SCNVector3(0, -0.04, 0)
        scene.rootNode.addChildNode(groundNode)

        // Fixed spatial scale: one scene unit represents ten metres.
        for metres in stride(from: -60, through: 60, by: 20) {
            let marker = SCNNode(geometry: SCNBox(width: 0.02, height: 0.02, length: 2.5, chamferRadius: 0))
            marker.geometry?.firstMaterial?.diffuse.contents = NSColor.secondaryLabelColor
            marker.position = SCNVector3(Float(metres) / 10, 0.005, 0)
            scene.rootNode.addChildNode(marker)
            let label = SCNText(string: L10n.measurement(Double(metres), fractionDigits: 0, unit: "m", language), extrusionDepth: 0)
            label.font = .monospacedSystemFont(ofSize: 1, weight: .regular)
            label.firstMaterial?.diffuse.contents = NSColor.labelColor
            let labelNode = SCNNode(geometry: label)
            let (minimum, maximum) = labelNode.boundingBox
            labelNode.pivot = SCNMatrix4MakeTranslation((minimum.x + maximum.x) / 2, 0, 0)
            labelNode.scale = SCNVector3(0.3, 0.3, 0.3)
            labelNode.position = SCNVector3(Float(metres) / 10, 0.05, 1.45)
            scene.rootNode.addChildNode(labelNode)
        }

        let arrowColor = NSColor.systemOrange

        let shaft = SCNCylinder(radius: 0.045, height: 1)
        shaft.firstMaterial?.diffuse.contents = arrowColor
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.name = "force-shaft"
        scene.rootNode.addChildNode(shaftNode)

        let arrowHead = SCNCone(topRadius: 0, bottomRadius: 0.14, height: 0.28)
        arrowHead.firstMaterial?.diffuse.contents = arrowColor
        let arrowHeadNode = SCNNode(geometry: arrowHead)
        arrowHeadNode.name = "force-head"
        scene.rootNode.addChildNode(arrowHeadNode)

        let camera = SCNCamera()
        camera.fieldOfView = 48
        camera.usesOrthographicProjection = true
        camera.projectionDirection = .horizontal
        camera.orthographicScale = 10
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 6, 12)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 850
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.eulerAngles = SCNVector3(-0.75, 0.7, 0)
        scene.rootNode.addChildNode(keyLightNode)

        scene.lightingEnvironment.intensity = 0.7
        return scene
    }

    private static func update(scene: SCNScene, force: Double, mass: Double, displacement: Double) {
        let massScale = Float(0.75 + mass * 0.05)
        let arrowLength = Float(0.55 + abs(force) / 30)
        let direction: Float = force < 0 ? -1 : 1
        let position = Float(displacement / 10)
        let arrowBaseX = position + direction * 0.58 * massScale
        let arrowY = 0.36 * massScale

        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if let box = scene.rootNode.childNode(withName: "mass-block", recursively: false) {
            box.scale = SCNVector3(massScale, massScale, massScale)
            box.position = SCNVector3(position, arrowY, 0)
        }
        if let shaft = scene.rootNode.childNode(withName: "force-shaft", recursively: false) {
            shaft.isHidden = force == 0
            shaft.scale = SCNVector3(1, arrowLength, 1)
            shaft.eulerAngles.z = -CGFloat(direction) * .pi / 2
            shaft.position = SCNVector3(arrowBaseX + direction * arrowLength / 2, arrowY, 0)
        }
        if let head = scene.rootNode.childNode(withName: "force-head", recursively: false) {
            head.isHidden = force == 0
            head.eulerAngles.z = -CGFloat(direction) * .pi / 2
            head.position = SCNVector3(arrowBaseX + direction * (arrowLength + 0.14), arrowY, 0)
        }
        SCNTransaction.commit()
    }
}

private struct KineticEnergyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var mass = 2.0
    @State private var initialSpeed = 3.0
    @State private var netWork = 20.0

    private var initialEnergy: Double { 0.5 * mass * initialSpeed * initialSpeed }
    private var proposedFinalEnergy: Double { initialEnergy + netWork }
    private var finalEnergy: Double { max(0, proposedFinalEnergy) }
    private var finalSpeed: Double { sqrt(2 * finalEnergy / mass) }
    private var stopsBeforeWorkCompletes: Bool { proposedFinalEnergy < 0 }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.energyHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            Energy3DVisualization(mass: mass, speed: finalSpeed)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(Text(L10n.text("lab.energy3DHint", store.language)))
            Text(L10n.text("lab.energy3DHint", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                energyReadout(title: L10n.text("lab.energyInitial", store.language), value: initialEnergy, unit: "J")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                energyReadout(title: L10n.text("lab.energyFinal", store.language), value: finalEnergy, unit: "J")
                Spacer(minLength: 0)
                energyReadout(title: L10n.text("lab.energyFinalSpeed", store.language), value: finalSpeed, unit: "m/s")
            }

            valueSlider(title: L10n.text("lab.mass", store.language), value: $mass, range: 1...8, unit: "kg")
            valueSlider(title: L10n.text("lab.energyInitialSpeed", store.language), value: $initialSpeed, range: 0...12, unit: "m/s")
            valueSlider(title: L10n.text("lab.energyNetWork", store.language), value: $netWork, range: -80...120, unit: "J")

            if stopsBeforeWorkCompletes {
                Label(L10n.text("lab.energyStops", store.language), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func energyReadout(title: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: L10n.measurement(value, fractionDigits: 1, unit: unit, store.language))
                .font(.callout.monospacedDigit().weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func valueSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 0, unit: unit, store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
                .accessibilityLabel(Text(title))
        }
    }
}

private struct MomentumCollisionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var firstMass = 2.0
    @State private var firstVelocity = 4.0
    @State private var secondMass = 2.0
    @State private var secondVelocity = -2.0
    @State private var showingAfter = false
    @State private var prediction: Int?
    @State private var selectedMode: CollisionOutcomeMode

    init(initialMode: CollisionOutcomeMode = .perfectlyInelastic) {
        _selectedMode = State(initialValue: initialMode)
    }

    private var collision: MomentumCollision {
        MomentumCollision(
            firstMass: firstMass,
            firstVelocity: firstVelocity,
            secondMass: secondMass,
            secondVelocity: secondVelocity
        )
    }

    private var correctPrediction: Int {
        if abs(firstFinalVelocity) < 0.05 { return 1 }
        return firstFinalVelocity < 0 ? 0 : 2
    }

    private var elasticCollision: ElasticCollision {
        ElasticCollision(
            firstMass: firstMass,
            firstVelocity: firstVelocity,
            secondMass: secondMass,
            secondVelocity: secondVelocity
        )
    }

    private var firstFinalVelocity: Double {
        selectedMode == .elastic ? elasticCollision.firstFinalVelocity : collision.finalVelocity
    }

    private var secondFinalVelocity: Double {
        selectedMode == .elastic ? elasticCollision.secondFinalVelocity : collision.finalVelocity
    }

    private var momentumBefore: Double {
        selectedMode == .elastic ? elasticCollision.momentumBefore : collision.momentumBefore
    }

    private var momentumAfter: Double {
        selectedMode == .elastic ? elasticCollision.momentumAfter : collision.momentumAfter
    }

    private var kineticEnergyBefore: Double {
        selectedMode == .elastic ? elasticCollision.kineticEnergyBefore : collision.kineticEnergyBefore
    }

    private var kineticEnergyAfter: Double {
        selectedMode == .elastic ? elasticCollision.kineticEnergyAfter : collision.kineticEnergyAfter
    }

    private var kineticEnergyConverted: Double {
        max(0, kineticEnergyBefore - kineticEnergyAfter)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.momentumHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Canvas { context, size in
                let baseline = size.height * 0.69
                var track = Path()
                track.move(to: CGPoint(x: 18, y: baseline))
                track.addLine(to: CGPoint(x: size.width - 18, y: baseline))
                context.stroke(track, with: .color(.secondary.opacity(0.45)), lineWidth: 2)

                if showingAfter {
                    if selectedMode == .elastic {
                        let firstX = size.width * 0.31
                        let secondX = size.width * 0.69
                        drawBlock(
                            in: &context,
                            centerX: firstX,
                            baseline: baseline,
                            width: CGFloat(min(92, 34 + firstMass * 6)),
                            height: 38,
                            label: String(format: L10n.text("lab.momentumCart", store.language), 1, firstMass),
                            color: .blue
                        )
                        drawBlock(
                            in: &context,
                            centerX: secondX,
                            baseline: baseline,
                            width: CGFloat(min(92, 34 + secondMass * 6)),
                            height: 38,
                            label: String(format: L10n.text("lab.momentumCart", store.language), 2, secondMass),
                            color: .orange
                        )
                        drawVelocityArrow(in: &context, centerX: firstX, baseline: baseline, velocity: firstFinalVelocity, label: nil)
                        drawVelocityArrow(in: &context, centerX: secondX, baseline: baseline, velocity: secondFinalVelocity, label: nil)
                    } else {
                        drawBlock(
                            in: &context,
                            centerX: size.width * 0.5,
                            baseline: baseline,
                            width: CGFloat(min(128, 42 + collision.totalMass * 5)),
                            height: 43,
                            label: String(format: L10n.text("lab.momentumJoinedMass", store.language), collision.totalMass),
                            color: .purple
                        )
                        drawVelocityArrow(
                            in: &context,
                            centerX: size.width * 0.5,
                            baseline: baseline,
                            velocity: collision.finalVelocity,
                            label: String(
                                format: L10n.text("lab.momentumVelocity", store.language),
                                L10n.measurement(collision.finalVelocity, fractionDigits: 1, unit: "m/s", store.language)
                            )
                        )
                    }
                } else {
                    let firstX = size.width * 0.28
                    let secondX = size.width * 0.72
                    drawBlock(
                        in: &context,
                        centerX: firstX,
                        baseline: baseline,
                        width: CGFloat(min(92, 34 + firstMass * 6)),
                        height: 38,
                        label: String(format: L10n.text("lab.momentumCart", store.language), 1, firstMass),
                        color: .blue
                    )
                    drawBlock(
                        in: &context,
                        centerX: secondX,
                        baseline: baseline,
                        width: CGFloat(min(92, 34 + secondMass * 6)),
                        height: 38,
                        label: String(format: L10n.text("lab.momentumCart", store.language), 2, secondMass),
                        color: .orange
                    )
                    drawVelocityArrow(in: &context, centerX: firstX, baseline: baseline, velocity: firstVelocity, label: nil)
                    drawVelocityArrow(in: &context, centerX: secondX, baseline: baseline, velocity: secondVelocity, label: nil)
                }
            }
            .frame(height: 160)
            .accessibilityLabel(Text(L10n.text("lab.momentumCanvas", store.language)))

            Picker(L10n.text("lab.momentumStage", store.language), selection: $showingAfter) {
                Text(L10n.text("lab.momentumBefore", store.language)).tag(false)
                Text(L10n.text("lab.momentumAfter", store.language)).tag(true)
            }
            .pickerStyle(.segmented)

            Picker(L10n.text("lab.collisionType", store.language), selection: $selectedMode) {
                Text(L10n.text("lab.collisionInelastic", store.language)).tag(CollisionOutcomeMode.perfectlyInelastic)
                Text(L10n.text("lab.collisionElastic", store.language)).tag(CollisionOutcomeMode.elastic)
            }
            .pickerStyle(.segmented)

            Text(L10n.text(
                selectedMode == .elastic ? "lab.collisionElasticHint" : "lab.collisionInelasticHint",
                store.language
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text("p = mv   ·   J = Δp = Fₙₑₜ Δt")
                .font(.system(.headline, design: .monospaced))
            valueSlider(title: L10n.text("lab.momentumMassOne", store.language), value: $firstMass, range: 1...8, step: 1, unit: "kg")
            valueSlider(title: L10n.text("lab.momentumVelocityOne", store.language), value: $firstVelocity, range: -8...8, step: 1, unit: "m/s")
            valueSlider(title: L10n.text("lab.momentumMassTwo", store.language), value: $secondMass, range: 1...8, step: 1, unit: "kg")
            valueSlider(title: L10n.text("lab.momentumVelocityTwo", store.language), value: $secondVelocity, range: -8...8, step: 1, unit: "m/s")

            HStack(alignment: .firstTextBaseline, spacing: 18) {
                readout(title: L10n.text("lab.momentumBeforeValue", store.language), value: momentumBefore, unit: "kg·m/s")
                readout(title: L10n.text("lab.momentumAfterValue", store.language), value: momentumAfter, unit: "kg·m/s")
            }
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                readout(title: L10n.text("lab.momentumEnergyBefore", store.language), value: kineticEnergyBefore, unit: "J")
                readout(title: L10n.text("lab.momentumEnergyAfter", store.language), value: kineticEnergyAfter, unit: "J")
                readout(title: L10n.text("lab.momentumEnergyConverted", store.language), value: kineticEnergyConverted, unit: "J")
            }

            Text(L10n.text(
                selectedMode == .elastic ? "lab.collisionPredictFirst" : "lab.momentumPredict",
                store.language
            ))
                .font(.headline)
            HStack {
                predictionButton(title: L10n.text("lab.momentumLeft", store.language), tag: 0)
                predictionButton(title: L10n.text("lab.momentumRest", store.language), tag: 1)
                predictionButton(title: L10n.text("lab.momentumRight", store.language), tag: 2)
            }
            if let prediction {
                Label(
                    L10n.text(prediction == correctPrediction ? "lab.momentumCorrect" : "lab.momentumTryAgain", store.language),
                    systemImage: prediction == correctPrediction ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .font(.callout)
                .foregroundStyle(prediction == correctPrediction ? Color.green : Color.orange)
            }
            Text(L10n.text(
                selectedMode == .elastic ? "lab.collisionElasticLimit" : "lab.momentumLimit",
                store.language
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: firstMass) { _ in prediction = nil }
        .onChange(of: firstVelocity) { _ in prediction = nil }
        .onChange(of: secondMass) { _ in prediction = nil }
        .onChange(of: secondVelocity) { _ in prediction = nil }
        .onChange(of: selectedMode) { _ in prediction = nil }
    }

    private func drawBlock(
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        width: CGFloat,
        height: CGFloat,
        label: String,
        color: Color
    ) {
        let rect = CGRect(x: centerX - width / 2, y: baseline - height, width: width, height: height)
        context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(color.opacity(0.78)))
        context.draw(Text(label).font(.caption.weight(.semibold)).foregroundColor(.primary), at: CGPoint(x: centerX, y: rect.minY - 13))
    }

    private func drawVelocityArrow(
        in context: inout GraphicsContext,
        centerX: CGFloat,
        baseline: CGFloat,
        velocity: Double,
        label: String?
    ) {
        let direction: CGFloat = velocity < 0 ? -1 : 1
        let length = CGFloat(min(62, max(12, abs(velocity) * 8)))
        let start = CGPoint(x: centerX, y: baseline + 13)
        let end = CGPoint(x: centerX + direction * length, y: baseline + 13)
        var arrow = Path()
        arrow.move(to: start)
        arrow.addLine(to: end)
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(x: end.x - direction * 8, y: end.y - 5))
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(x: end.x - direction * 8, y: end.y + 5))
        context.stroke(arrow, with: .color(.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        if let label {
            context.draw(Text(label).font(.caption.monospacedDigit()).foregroundColor(.secondary), at: CGPoint(x: centerX, y: baseline + 34))
        }
    }

    private func valueSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 0, unit: unit, store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(Text(title))
        }
    }

    private func readout(title: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: L10n.measurement(value, fractionDigits: 1, unit: unit, store.language))
                .font(.callout.monospacedDigit().weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func predictionButton(title: String, tag: Int) -> some View {
        Button(title) { prediction = tag }
            .buttonStyle(.bordered)
            .tint(prediction == tag ? .accentColor : nil)
            .accessibilityAddTraits(prediction == tag ? .isSelected : [])
    }
}

private struct Energy3DVisualization: View {
    let mass: Double
    let speed: Double
    @State private var scene: SCNScene

    init(mass: Double, speed: Double) {
        self.mass = mass
        self.speed = speed
        _scene = State(initialValue: Self.makeScene(mass: mass, speed: speed))
    }

    var body: some View {
        SceneView(scene: scene, options: [.allowsCameraControl])
            .background(Color(nsColor: .windowBackgroundColor))
            .onChange(of: mass) { _ in updateScene() }
            .onChange(of: speed) { _ in updateScene() }
    }

    private static func makeScene(mass: Double, speed: Double) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.windowBackgroundColor

        let cartGeometry = SCNBox(width: 0.78, height: 0.46, length: 0.62, chamferRadius: 0.08)
        let cartMaterial = SCNMaterial()
        cartMaterial.diffuse.contents = NSColor.systemBlue
        cartMaterial.metalness.contents = 0.08
        cartMaterial.roughness.contents = 0.4
        cartGeometry.materials = [cartMaterial]
        let cart = SCNNode(geometry: cartGeometry)
        cart.name = "energy-cart"
        let wheelXPositions: [Float] = [-0.25, 0.25]
        let wheelZPositions: [Float] = [-0.34, 0.34]
        for x in wheelXPositions {
            for z in wheelZPositions {
                let wheel = SCNCylinder(radius: 0.12, height: 0.1)
                wheel.firstMaterial?.diffuse.contents = NSColor.darkGray
                let wheelNode = SCNNode(geometry: wheel)
                wheelNode.eulerAngles.x = .pi / 2
                wheelNode.position = SCNVector3(x, -0.26, z)
                cart.addChildNode(wheelNode)
            }
        }
        scene.rootNode.addChildNode(cart)

        let track = SCNBox(width: 3.8, height: 0.07, length: 1.8, chamferRadius: 0.02)
        track.firstMaterial?.diffuse.contents = NSColor.tertiaryLabelColor
        let trackNode = SCNNode(geometry: track)
        trackNode.position = SCNVector3(0, -0.08, 0)
        scene.rootNode.addChildNode(trackNode)

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 46
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(2.7, 1.9, 4.8)
        cameraNode.look(at: SCNVector3(0, 0.25, 0))
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .omni
        light.intensity = 850
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 4, 4)
        scene.rootNode.addChildNode(lightNode)

        update(scene: scene, mass: mass, speed: speed)
        return scene
    }

    private func updateScene() {
        Self.update(scene: scene, mass: mass, speed: speed)
    }

    private static func update(scene: SCNScene, mass: Double, speed: Double) {
        guard let cart = scene.rootNode.childNode(withName: "energy-cart", recursively: false) else { return }
        let scale = Float(0.82 + mass * 0.035)
        let start = SCNVector3(-1.15, 0.23 * scale, 0)
        cart.removeAction(forKey: "motion")
        cart.scale = SCNVector3(scale, scale, scale)
        cart.position = start

        guard speed > 0 else { return }
        let finish = SCNVector3(1.15, 0.23 * scale, 0)
        let travel = SCNAction.move(to: finish, duration: max(0.12, 2.3 / speed))
        let reset = SCNAction.run { node in node.position = start }
        cart.runAction(.repeatForever(.sequence([travel, reset])), forKey: "motion")
    }
}

private struct PunnettLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedCross = 0

    private var parentGenotypes: (String, String) {
        switch selectedCross {
        case 1: return ("Aa", "aa")
        case 2: return ("AA", "aa")
        default: return ("Aa", "Aa")
        }
    }

    private var firstParentGametes: [String] { parentGenotypes.0.map { String($0) } }
    private var secondParentGametes: [String] { parentGenotypes.1.map { String($0) } }

    private var genotypeCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for secondGamete in secondParentGametes {
            for firstGamete in firstParentGametes {
                counts[offspringGenotype(firstGamete, secondGamete), default: 0] += 1
            }
        }
        return counts
    }

    private var probabilitySummary: String {
        genotypeCounts.keys.sorted().map { genotype in
            "\(genotype): \(genotypeCounts[genotype, default: 0] * 25)%"
        }.joined(separator: " · ")
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.geneticsHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker(L10n.text("lab.geneticsCross", store.language), selection: $selectedCross) {
                Text(L10n.text("lab.geneticsCross0", store.language)).tag(0)
                Text(L10n.text("lab.geneticsCross1", store.language)).tag(1)
                Text(L10n.text("lab.geneticsCross2", store.language)).tag(2)
            }
            .pickerStyle(.menu)

            HStack(alignment: .top, spacing: 18) {
                Text("\(L10n.text("lab.geneticsParent1", store.language)): \(parentGenotypes.0)")
                Text("\(L10n.text("lab.geneticsParent2", store.language)): \(parentGenotypes.1)")
            }
            .font(.callout.monospacedDigit().weight(.medium))

            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    Color.clear.frame(width: 54, height: 34)
                    ForEach(firstParentGametes.indices, id: \.self) { column in
                        Text(firstParentGametes[column])
                            .font(.headline.monospaced())
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                ForEach(secondParentGametes.indices, id: \.self) { row in
                    HStack(spacing: 7) {
                        Text(secondParentGametes[row])
                            .font(.headline.monospaced())
                            .frame(width: 54, height: 54)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        ForEach(firstParentGametes.indices, id: \.self) { column in
                            let genotype = offspringGenotype(
                                firstParentGametes[column],
                                secondParentGametes[row]
                            )
                            Text(genotype)
                                .font(.title3.monospaced().weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(Color.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel(Text(
                                    "\(L10n.text("lab.geneticsOffspring", store.language)): \(genotype)"
                                ))
                        }
                    }
                }
            }

            LabeledContent(L10n.text("lab.geneticsOutcomes", store.language)) {
                Text(probabilitySummary)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func offspringGenotype(_ firstAllele: String, _ secondAllele: String) -> String {
        String((Array(firstAllele + secondAllele)).sorted { first, second in
            if first.isUppercase != second.isUppercase { return first.isUppercase }
            return first < second
        })
    }
}

private struct GeneRegulationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var variant = 0
    @State private var signalPresent = true
    @State private var prediction = GeneRegulationPractice.makePredictionAttempt(
        variant: 0,
        signalPresent: true
    )

    private var productMade: Bool {
        GeneRegulationPractice.isProductMade(variant: variant, signalPresent: signalPresent)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.dnaModelHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker(L10n.text("lab.dnaVariant", store.language), selection: $variant) {
                Text(L10n.text("lab.dnaVariant0", store.language)).tag(0)
                Text(L10n.text("lab.dnaVariant1", store.language)).tag(1)
            }
            .pickerStyle(.segmented)
            .onChange(of: variant) { _ in resetPrediction() }

            DNAHelixVisualization(variant: variant)
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(Text(L10n.text("lab.dna3DHint", store.language)))
            Text(L10n.text("lab.dna3DHint", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L10n.text(variant == 0 ? "lab.dnaPairAT" : "lab.dnaPairCG", store.language))
                .font(.callout.weight(.medium))
                .accessibilityLabel(Text(L10n.text(variant == 0 ? "lab.dnaPairAT" : "lab.dnaPairCG", store.language)))

            Toggle(L10n.text("lab.dnaSignal", store.language), isOn: $signalPresent)
                .onChange(of: signalPresent) { _ in resetPrediction() }

            let outcomeRevealed = prediction.isCorrect

            HStack(spacing: 8) {
                flowNode(title: L10n.text("lab.dnaSequence", store.language), value: "A · T · C · G")
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                flowNode(
                    title: L10n.text("lab.dnaGeneActivity", store.language),
                    value: L10n.text(
                        GeneRegulationPractice.geneActivityKey(
                            productMade: productMade,
                            outcomeRevealed: outcomeRevealed
                        ),
                        store.language
                    )
                )
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                flowNode(
                    title: L10n.text("lab.dnaProduct", store.language),
                    value: L10n.text(
                        GeneRegulationPractice.productKey(
                            productMade: productMade,
                            outcomeRevealed: outcomeRevealed
                        ),
                        store.language
                    )
                )
            }
            .accessibilityElement(children: .combine)

            Text(L10n.text("lab.dnaPredict", store.language))
                .font(.callout.weight(.medium))
            HStack {
                ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    answerButton(
                        displayIndex: displayIndex,
                        originalIndex: originalIndex,
                        key: originalIndex == 0 ? "lab.dnaPredictOption0" : "lab.dnaPredictOption1"
                    )
                }
            }

            if prediction.hasAnswered {
                let isCorrect = prediction.isCorrect
                Label(
                    L10n.text(
                        isCorrect ? "lab.dnaPredictCorrect" : "lab.dnaPredictIncorrect",
                        store.language
                    ),
                    systemImage: isCorrect ? "checkmark.circle.fill" : "arrow.clockwise.circle"
                )
                .font(.callout)
                .foregroundStyle(isCorrect ? Color.green : Color.secondary)

                Text(L10n.text(GeneRegulationPractice.explanationKey(isCorrect: isCorrect), store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if prediction.canRetry {
                    Button(L10n.text("lab.dnaRetry", store.language)) {
                        prediction.retry()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func resetPrediction() {
        prediction = GeneRegulationPractice.makePredictionAttempt(
            variant: variant,
            signalPresent: signalPresent
        )
    }

    private func flowNode(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }

    private func answerButton(displayIndex: Int, originalIndex: Int, key: String) -> some View {
        Button {
            prediction.select(displayedIndex: displayIndex)
            guard let evidence = prediction.currentAnswerEventEvidence() else { return }
            store.recordStudyAssessment(lessonID: "biology.dna_genes_and_traits", evidence: evidence)
        } label: {
            Text(L10n.text(key, store.language))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .tint(prediction.selectedOriginalIndex == originalIndex ? Color.accentColor : nil)
        .disabled(prediction.hasAnswered)
        .accessibilityAddTraits(prediction.selectedOriginalIndex == originalIndex ? .isSelected : [])
    }
}

private struct GeneExpressionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var transcriptionEnabled = true
    @State private var selectedStage = 0
    @State private var selectedAnswer = -1
    @State private var didCheckAnswer = false
    @State private var prediction = GeneExpressionPractice.makeStopCodonAttempt()

    private let answerOptionKeys = [
        "lab.geneExpressionOptionA",
        "lab.geneExpressionOptionB",
        "lab.geneExpressionOptionC"
    ]

    private var snapshot: GeneExpressionSnapshot {
        GeneExpressionPractice.snapshot(promoterIsActive: transcriptionEnabled)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.geneExpressionHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(L10n.text("lab.geneExpressionRegulator", store.language), isOn: $transcriptionEnabled)
                .onChange(of: transcriptionEnabled) { _ in
                    resetPrediction()
                }

            Picker(L10n.text("lab.geneExpressionStage", store.language), selection: $selectedStage) {
                Text(L10n.text("lab.geneExpressionDNA", store.language)).tag(0)
                Text(L10n.text("lab.geneExpressionRNA", store.language)).tag(1)
                Text(L10n.text("lab.geneExpressionProtein", store.language)).tag(2)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text(stageTitleKey, store.language))
                    .font(.headline)
                Text(stageValue)
                    .font(.title3.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text(stageExplanationKey, store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            Text(L10n.text("lab.geneExpressionQuiz", store.language))
                .font(.callout.weight(.medium))
            Picker(L10n.text("lab.geneExpressionQuiz", store.language), selection: $selectedAnswer) {
                ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Text(L10n.text(answerOptionKeys[originalIndex], store.language)).tag(displayIndex)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(prediction.hasAnswered)
            .onChange(of: selectedAnswer) { _ in didCheckAnswer = false }

            Button(L10n.text("lab.geneExpressionCheck", store.language)) {
                prediction.select(displayedIndex: selectedAnswer)
                guard let evidence = prediction.currentAnswerEventEvidence() else { return }
                store.recordStudyAssessment(
                    lessonID: "biology.gene_expression_and_regulation",
                    evidence: evidence
                )
                didCheckAnswer = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAnswer < 0 || prediction.hasAnswered)

            if didCheckAnswer {
                Label(
                    L10n.text(prediction.isCorrect ? "lab.geneExpressionCorrect" : "lab.geneExpressionReview", store.language),
                    systemImage: prediction.isCorrect ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(prediction.isCorrect ? .green : .orange)
                .fixedSize(horizontal: false, vertical: true)

                if prediction.canRetry {
                    Button(L10n.text("lab.geneExpressionRetry", store.language), action: retryPrediction)
                        .buttonStyle(.link)
                }
            }

            Text(L10n.text("lab.geneExpressionLimit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stageTitleKey: String {
        ["lab.geneExpressionDNA", "lab.geneExpressionRNA", "lab.geneExpressionProtein"][selectedStage]
    }

    private var stageExplanationKey: String {
        ["lab.geneExpressionDNAExplain", "lab.geneExpressionRNAExplain", "lab.geneExpressionProteinExplain"][selectedStage]
    }

    private var stageValue: String {
        switch selectedStage {
        case 0:
            return "3′ \(GeneExpressionPractice.templateStrand) 5′"
        case 1:
            guard let messengerRNA = snapshot.messengerRNA else {
                return L10n.text("lab.geneExpressionNoTranscript", store.language)
            }
            return "5′ \(messengerRNA) 3′"
        default:
            guard let peptide = snapshot.peptide else {
                return L10n.text("lab.geneExpressionNoProtein", store.language)
            }
            return peptide.joined(separator: " – ")
        }
    }

    private func retryPrediction() {
        prediction.retry()
        selectedAnswer = -1
        didCheckAnswer = false
    }

    private func resetPrediction() {
        prediction = GeneExpressionPractice.makeStopCodonAttempt()
        selectedAnswer = -1
        didCheckAnswer = false
    }
}

private struct CellCycleLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedStage: CellCycleStage = .g1
    @State private var selectedAnswer = -1
    @State private var didCheckAnswer = false
    @State private var prediction = CellCyclePractice.makeKnowledgeCheckAttempt()

    private let answerOptionKeys = [
        "lab.cellCycle.optionS",
        "lab.cellCycle.optionAnaphase",
        "lab.cellCycle.optionCytokinesis"
    ]

    var body: some View {
        LabCard {
            Text(L10n.text("lab.cellCycle.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.cellCycle.chooseStage", store.language), selection: $selectedStage) {
                ForEach(CellCycleStage.allCases) { stage in
                    Text(L10n.text(stage.localizationKey, store.language)).tag(stage)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text(selectedStage.localizationKey, store.language))
                    .font(.headline)
                Text(L10n.text("lab.cellCycle.explain.\(selectedStage.rawValue)", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text(statusKey, store.language))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            HStack {
                Button(L10n.text("lab.cellCycle.previous", store.language)) {
                    move(by: -1)
                }
                .disabled(selectedStage == CellCycleStage.allCases.first)
                Spacer()
                Text("\((CellCycleStage.allCases.firstIndex(of: selectedStage) ?? 0) + 1) / \(CellCycleStage.allCases.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.text("lab.cellCycle.position", store.language))
                Spacer()
                Button(L10n.text("lab.cellCycle.next", store.language)) {
                    move(by: 1)
                }
                .disabled(selectedStage == CellCycleStage.allCases.last)
            }

            VStack(alignment: .leading, spacing: 10) {
                conceptCard(
                    titleKey: "lab.cellCycle.cytokinesisTitle",
                    descriptionKey: "lab.cellCycle.cytokinesisDescription",
                    systemImage: "arrow.left.and.right"
                )
                conceptCard(
                    titleKey: "lab.cellCycle.differentiationTitle",
                    descriptionKey: "lab.cellCycle.differentiationDescription",
                    systemImage: "sparkles"
                )
            }

            Text(L10n.text("lab.cellCycle.quiz", store.language))
                .font(.callout.weight(.medium))
            Picker(L10n.text("lab.cellCycle.quiz", store.language), selection: $selectedAnswer) {
                ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Text(L10n.text(answerOptionKeys[originalIndex], store.language)).tag(displayIndex)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(prediction.hasAnswered)
            .onChange(of: selectedAnswer) { _ in didCheckAnswer = false }

            Button(L10n.text("lab.cellCycle.check", store.language)) {
                prediction.select(displayedIndex: selectedAnswer)
                didCheckAnswer = true
                if let evidence = prediction.currentAnswerEventEvidence() {
                    store.recordStudyAssessment(
                        lessonID: "biology.cell_cycle_and_differentiation",
                        evidence: evidence
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAnswer < 0 || prediction.hasAnswered)

            if didCheckAnswer {
                if prediction.isCorrect {
                    Label(L10n.text("lab.cellCycle.correct", store.language), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label(L10n.text("lab.cellCycle.review", store.language), systemImage: "arrow.uturn.backward.circle")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("lab.cellCycle.retry", store.language)) {
                        prediction.retry()
                        selectedAnswer = -1
                        didCheckAnswer = false
                    }
                    .buttonStyle(.link)
                }
            }

            Text(L10n.text("lab.cellCycle.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusKey: String {
        if CellCyclePractice.isDNAReplicationStage(selectedStage) { return "lab.cellCycle.statusDNA" }
        if CellCyclePractice.isNuclearDivision(selectedStage) { return "lab.cellCycle.statusNucleus" }
        return "lab.cellCycle.statusPrepare"
    }

    private func conceptCard(titleKey: String, descriptionKey: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text(titleKey, store.language), systemImage: systemImage)
                .font(.headline)
            Text(L10n.text(descriptionKey, store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func move(by offset: Int) {
        guard let index = CellCycleStage.allCases.firstIndex(of: selectedStage) else { return }
        let nextIndex = index + offset
        guard CellCycleStage.allCases.indices.contains(nextIndex) else { return }
        selectedStage = CellCycleStage.allCases[nextIndex]
    }
}

private struct AnimalFunctionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedFunction: AnimalFunction = .feeding
    @State private var selectedAnswer = -1
    @State private var didCheckAnswer = false
    @State private var prediction = AnimalFunctionPractice.makeComparisonAttempt()

    private let answerOptionKeys = [
        "lab.zoology.optionA",
        "lab.zoology.optionB",
        "lab.zoology.optionC"
    ]

    var body: some View {
        LabCard {
            Text(L10n.text("lab.zoology.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.zoology.chooseFunction", store.language), selection: $selectedFunction) {
                ForEach(AnimalFunction.allCases) { function in
                    Text(L10n.text(function.titleKey, store.language)).tag(function)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedFunction) { _ in resetPrediction() }

            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.text(selectedFunction.titleKey, store.language), systemImage: systemSymbol)
                    .font(.headline)
                Text(L10n.text(selectedFunction.exampleKey, store.language))
                    .font(.callout.weight(.medium))
                Text(L10n.text(selectedFunction.mechanismKey, store.language))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text(selectedFunction.limitationKey, store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            Text(L10n.text("lab.zoology.quiz", store.language))
                .font(.callout.weight(.medium))
            Picker(L10n.text("lab.zoology.quiz", store.language), selection: $selectedAnswer) {
                ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Text(L10n.text(answerOptionKeys[originalIndex], store.language)).tag(displayIndex)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(prediction.hasAnswered)
            .onChange(of: selectedAnswer) { _ in didCheckAnswer = false }

            Button(L10n.text("lab.zoology.check", store.language)) {
                prediction.select(displayedIndex: selectedAnswer)
                guard let evidence = prediction.currentAnswerEventEvidence() else { return }
                store.recordStudyAssessment(
                    lessonID: "zoology.animal_function_and_environment",
                    evidence: evidence
                )
                didCheckAnswer = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAnswer < 0 || prediction.hasAnswered)

            if didCheckAnswer {
                Label(
                    L10n.text(prediction.isCorrect ? "lab.zoology.correct" : "lab.zoology.review", store.language),
                    systemImage: prediction.isCorrect ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(prediction.isCorrect ? .green : .orange)
                .fixedSize(horizontal: false, vertical: true)

                if prediction.canRetry {
                    Button(L10n.text("lab.zoology.retry", store.language), action: retryPrediction)
                        .buttonStyle(.link)
                }
            }

            Text(L10n.text("lab.zoology.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var systemSymbol: String {
        switch selectedFunction {
        case .feeding: return "fork.knife"
        case .gasExchange: return "wind"
        case .movement: return "figure.walk"
        case .reproduction: return "leaf"
        }
    }

    private func retryPrediction() {
        prediction.retry()
        selectedAnswer = -1
        didCheckAnswer = false
    }

    private func resetPrediction() {
        prediction = AnimalFunctionPractice.makeComparisonAttempt()
        selectedAnswer = -1
        didCheckAnswer = false
    }
}

private struct ThermoregulationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedRangeID = ThermoregulationPractice.operativeTemperatureRange.id
    @State private var selectedAnswer = -1
    @State private var didCheckAnswer = false
    @State private var attemptCount = 0
    @State private var firstTryCorrect: Bool?
    @State private var answerSolved = false
    @State private var optionOrder = QuizAnswerOrder(
        optionCount: 3,
        answerOriginalIndex: ThermoregulationPractice.correctThresholdInterpretationAnswer
    )

    private let answerOptionKeys = [
        "lab.zoology.thermo.optionA",
        "lab.zoology.thermo.optionB",
        "lab.zoology.thermo.optionC",
    ]

    private var selectedRange: ThermalExposureRange {
        selectedRangeID == ThermoregulationPractice.ambientAirRange.id
            ? ThermoregulationPractice.ambientAirRange
            : ThermoregulationPractice.operativeTemperatureRange
    }

    private var selectedRangeNameKey: String {
        selectedRangeID == ThermoregulationPractice.ambientAirRange.id
            ? "lab.zoology.thermo.air"
            : "lab.zoology.thermo.operative"
    }

    private var selectedRangeValueKey: String {
        selectedRangeID == ThermoregulationPractice.ambientAirRange.id
            ? "lab.zoology.thermo.airRange"
            : "lab.zoology.thermo.operativeRange"
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.zoology.thermo.intro", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 16) {
                ThermalProxyBirdVisualization()
                    .frame(width: 220, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(L10n.text("lab.zoology.thermo.modelAccessibility", store.language))
                    .accessibilityHint(L10n.text("lab.zoology.thermo.rotate", store.language))

                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.text("lab.zoology.thermo.rotate", store.language), systemImage: "rotate.right")
                        .font(.callout.weight(.medium))
                    Text(L10n.text("lab.zoology.thermo.modelLimits", store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach([ThermoregulationPractice.ambientAirRange, ThermoregulationPractice.operativeTemperatureRange]) { range in
                    let isAir = range.id == ThermoregulationPractice.ambientAirRange.id
                    let isSelected = range.id == selectedRangeID
                    let nameKey = isAir ? "lab.zoology.thermo.air" : "lab.zoology.thermo.operative"
                    let valueKey = isAir ? "lab.zoology.thermo.airRange" : "lab.zoology.thermo.operativeRange"
                    Button {
                        selectedRangeID = range.id
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                L10n.text(nameKey, store.language),
                                systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.subheadline.weight(.semibold))
                            Text(L10n.text(valueKey, store.language))
                                .font(.title3.monospacedDigit().weight(.semibold))
                            ThermalRangeBar(range: range, color: isAir ? .blue : .orange)
                                .frame(height: 12)
                            HStack {
                                Text(L10n.text("lab.zoology.thermo.axisMinimum", store.language))
                                Spacer()
                                Text(L10n.text("lab.zoology.thermo.axisMaximum", store.language))
                            }
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            isSelected ? Color.teal.opacity(0.12) : Color.secondary.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color.teal.opacity(0.65) : Color.clear, lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text(isAir ? "lab.zoology.thermo.airAccessibility" : "lab.zoology.thermo.operativeAccessibility", store.language))
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "thermometer.high")
                    .foregroundStyle(selectedRangeID == ThermoregulationPractice.ambientAirRange.id ? Color.blue : Color.orange)
                Text(L10n.text(selectedRangeNameKey, store.language))
                    .font(.callout.weight(.medium))
                Spacer(minLength: 8)
                Text(L10n.text(selectedRangeValueKey, store.language))
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            Text(L10n.text("lab.zoology.thermo.rangeMeaning", store.language))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.text("lab.zoology.thermo.threshold", store.language), systemImage: "thermometer.sun.fill")
                    .font(.callout.weight(.medium))
                ProgressView(value: Double(ThermoregulationPractice.heatStressDayPercentage), total: 100)
                    .tint(.orange)
                Text(L10n.text("lab.zoology.thermo.stressDays", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            Divider()

            Text(L10n.text("lab.zoology.thermo.question", store.language))
                .font(.callout.weight(.medium))
            Picker(L10n.text("lab.zoology.thermo.question", store.language), selection: $selectedAnswer) {
                ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Text(L10n.text(answerOptionKeys[originalIndex], store.language)).tag(displayIndex)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(answerSolved)
            .onChange(of: selectedAnswer) { _ in didCheckAnswer = false }

            Button(L10n.text("lab.zoology.thermo.check", store.language)) {
                let correct = optionOrder.isCorrect(displayedIndex: selectedAnswer)
                attemptCount += 1
                if firstTryCorrect == nil { firstTryCorrect = correct }
                store.recordStudyAssessment(
                    lessonID: "zoology.comparative_thermoregulation_and_heat_stress",
                    evidence: StudyAssessmentEvidence(
                        taskType: "interactive_prediction",
                        attempts: attemptCount,
                        firstTryCorrect: firstTryCorrect ?? correct,
                        hintsUsed: 0,
                        itemID: ThermoregulationPractice.heatStressThresholdQuestionID
                    )
                )
                didCheckAnswer = true
                answerSolved = correct
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAnswer < 0 || didCheckAnswer || answerSolved)

            if didCheckAnswer {
                let correct = optionOrder.isCorrect(displayedIndex: selectedAnswer)
                Label(
                    L10n.text(correct ? "lab.zoology.thermo.correct" : "lab.zoology.thermo.review", store.language),
                    systemImage: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(correct ? .green : .orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

}

private struct ThermalRangeBar: View {
    let range: ThermalExposureRange
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let minimum = width * CGFloat(range.minimumCelsius / ThermoregulationPractice.chartMaximumCelsius)
            let maximum = width * CGFloat(range.maximumCelsius / ThermoregulationPractice.chartMaximumCelsius)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.14))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, maximum - minimum))
                    .offset(x: minimum)
            }
            .clipShape(Capsule())
        }
        .accessibilityHidden(true)
    }
}

private struct ThermalProxyBirdVisualization: NSViewRepresentable {
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.makeScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .controlBackgroundColor
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {}

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.controlBackgroundColor
        let bodyMaterial = material(color: .darkGray, roughness: 0.8)
        let wingMaterial = material(color: .gray, roughness: 0.82)
        let beakMaterial = material(color: .systemOrange, roughness: 0.62)
        let footMaterial = material(color: .systemOrange, roughness: 0.75)
        let eyeMaterial = material(color: .black, roughness: 0.35)
        let bird = SCNNode()

        let body = SCNNode(geometry: SCNSphere(radius: 1))
        body.scale = SCNVector3(0.59, 0.62, 1.05)
        body.position = SCNVector3(0, 0.02, -0.08)
        body.geometry?.firstMaterial = bodyMaterial
        bird.addChildNode(body)

        let head = SCNNode(geometry: SCNSphere(radius: 0.39))
        head.position = SCNVector3(0, 0.67, 0.54)
        head.geometry?.firstMaterial = bodyMaterial
        bird.addChildNode(head)

        let beak = SCNNode(geometry: SCNCone(topRadius: 0.015, bottomRadius: 0.12, height: 0.34))
        beak.position = SCNVector3(0, 0.57, 0.91)
        beak.eulerAngles.x = .pi / 2
        beak.geometry?.firstMaterial = beakMaterial
        bird.addChildNode(beak)

        for side in [Float(-1), Float(1)] {
            let wing = SCNNode(geometry: SCNSphere(radius: 0.58))
            wing.scale = SCNVector3(0.77, 0.14, 0.75)
            wing.position = SCNVector3(side * 0.46, 0.02, -0.06)
            wing.geometry?.firstMaterial = wingMaterial
            bird.addChildNode(wing)

            let eye = SCNNode(geometry: SCNSphere(radius: 0.038))
            eye.position = SCNVector3(side * 0.25, 0.73, 0.87)
            eye.geometry?.firstMaterial = eyeMaterial
            bird.addChildNode(eye)

            let foot = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.45))
            foot.position = SCNVector3(side * 0.21, -0.66, 0.03)
            foot.geometry?.firstMaterial = footMaterial
            bird.addChildNode(foot)
        }

        let tail = SCNNode(geometry: SCNSphere(radius: 0.3))
        tail.scale = SCNVector3(0.34, 0.24, 0.68)
        tail.position = SCNVector3(0, -0.05, -0.94)
        tail.geometry?.firstMaterial = wingMaterial
        bird.addChildNode(tail)
        scene.rootNode.addChildNode(bird)

        let camera = SCNCamera()
        camera.fieldOfView = 46
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.1, 4.5)
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .omni
        light.intensity = 650
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(-2, 3, 4)
        scene.rootNode.addChildNode(lightNode)
        return scene
    }

    private static func material(color: NSColor, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = roughness
        return material
    }
}

private struct DNAHelixVisualization: NSViewRepresentable {
    let variant: Int

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.makeScene(variant: variant)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .controlBackgroundColor
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let rung = view.scene?.rootNode.childNode(withName: "model-variant-rung", recursively: false) else { return }
        rung.geometry?.firstMaterial?.diffuse.contents = Self.variantColor(variant)
    }

    private static func makeScene(variant: Int) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.controlBackgroundColor

        let backboneMaterial = SCNMaterial()
        backboneMaterial.diffuse.contents = NSColor.systemBlue
        backboneMaterial.roughness.contents = 0.46

        let complementaryMaterial = SCNMaterial()
        complementaryMaterial.diffuse.contents = NSColor.systemOrange
        complementaryMaterial.roughness.contents = 0.46

        let rungMaterials = [backboneMaterial, complementaryMaterial]
        let stepCount = 20
        let radius: Float = 0.58
        let verticalStep: Float = 0.16
        let twist = 2 * Float.pi / 10
        var firstStrand: [SCNVector3] = []
        var secondStrand: [SCNVector3] = []

        for index in 0..<stepCount {
            let angle = Float(index) * twist
            let height = (Float(index) - Float(stepCount - 1) / 2) * verticalStep
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            let first = SCNVector3(x, y, height)
            let second = SCNVector3(-x, -y, height)
            firstStrand.append(first)
            secondStrand.append(second)

            let firstBead = SCNNode(geometry: SCNSphere(radius: 0.055))
            firstBead.geometry?.firstMaterial = backboneMaterial
            firstBead.position = first
            scene.rootNode.addChildNode(firstBead)

            let secondBead = SCNNode(geometry: SCNSphere(radius: 0.055))
            secondBead.geometry?.firstMaterial = complementaryMaterial
            secondBead.position = second
            scene.rootNode.addChildNode(secondBead)

            let rung = SCNCylinder(radius: 0.026, height: CGFloat(radius * 2))
            rung.firstMaterial = rungMaterials[index.isMultiple(of: 2) ? 0 : 1]
            let rungNode = segmentNode(from: first, to: second, geometry: rung)
            if index == stepCount / 2 {
                rungNode.name = "model-variant-rung"
                rung.firstMaterial = SCNMaterial()
                rung.firstMaterial?.diffuse.contents = variantColor(variant)
                rung.firstMaterial?.roughness.contents = 0.42
            }
            scene.rootNode.addChildNode(rungNode)
        }

        for index in 0..<(stepCount - 1) {
            let firstRail = SCNCylinder(radius: 0.018, height: distance(firstStrand[index], firstStrand[index + 1]))
            firstRail.firstMaterial = backboneMaterial
            scene.rootNode.addChildNode(segmentNode(from: firstStrand[index], to: firstStrand[index + 1], geometry: firstRail))

            let secondRail = SCNCylinder(radius: 0.018, height: distance(secondStrand[index], secondStrand[index + 1]))
            secondRail.firstMaterial = complementaryMaterial
            scene.rootNode.addChildNode(segmentNode(from: secondStrand[index], to: secondStrand[index + 1], geometry: secondRail))
        }

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 4.2
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, -5.2, 0.25)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .omni
        light.intensity = 620
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(-2, -3, 4)
        scene.rootNode.addChildNode(lightNode)
        scene.lightingEnvironment.intensity = 0.65
        return scene
    }

    private static func segmentNode(from start: SCNVector3, to end: SCNVector3, geometry: SCNGeometry) -> SCNNode {
        let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let length = distance(start, end)
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)

        let normalized = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
        let dot = normalized.y
        if dot < -0.9999 {
            node.orientation = SCNQuaternion(1, 0, 0, 0)
        } else {
            let cross = SCNVector3(normalized.z, 0, -normalized.x)
            let scale = sqrt(2 * (1 + dot))
            let inverseScale = 1 / scale
            node.orientation = SCNQuaternion(
                cross.x * inverseScale,
                cross.y * inverseScale,
                cross.z * inverseScale,
                scale / 2
            )
        }
        return node
    }

    private static func distance(_ first: SCNVector3, _ second: SCNVector3) -> CGFloat {
        let x = second.x - first.x
        let y = second.y - first.y
        let z = second.z - first.z
        let squaredDistance = x * x + y * y + z * z
        return sqrt(squaredDistance)
    }

    private static func variantColor(_ variant: Int) -> NSColor {
        variant == 0 ? .systemYellow : .systemPurple
    }
}

private struct CellLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selected = "mitochondria"
    private let parts = ["nucleus", "membrane", "mitochondria"]

    var body: some View {
        LabCard {
            HStack(spacing: 18) {
                ZStack {
                    Ellipse().fill(.green.opacity(0.12)).overlay(Ellipse().stroke(.green.opacity(0.5), lineWidth: 2))
                    Circle().fill(.purple.opacity(0.6)).frame(width: 36, height: 36)
                    Capsule().fill(.orange.opacity(0.8)).frame(width: 35, height: 14).rotationEffect(.degrees(-30)).offset(x: 34, y: 24)
                    Capsule().fill(.orange.opacity(0.8)).frame(width: 30, height: 12).rotationEffect(.degrees(30)).offset(x: -36, y: -20)
                    Text("DNA").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                }
                .frame(width: 140, height: 100)
                .accessibilityLabel(Text(L10n.text("lab.cellDiagram", store.language)))
                VStack(alignment: .leading, spacing: 8) {
                    Picker(selection: $selected, label: Text(L10n.text("lab.cellPart", store.language))) {
                        ForEach(parts, id: \.self) { part in
                            Text(L10n.text("biology.\(part)", store.language)).tag(part)
                        }
                    }
                    .labelsHidden()
                    Text(L10n.text("lab.function", store.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.text("biology.\(selected).function", store.language))
                        .font(.callout)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct BiomoleculeLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedExample: BiomoleculeExample = .enzyme
    @State private var selectedGroup: BiomoleculeGroup? = nil
    @State private var checkedGroup: BiomoleculeGroup?
    @State private var reactionJoins = true
    @State private var assessmentTracker = BiomoleculeAssessmentTracker()

    private var exampleInfoKey: String {
        "biology.moleculeLab.info.\(selectedExample.rawValue)"
    }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.teal)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("biology.moleculeLab.title", store.language))
                            .font(.headline)
                        Text(L10n.text("biology.moleculeLab.subtitle", store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker(L10n.text("biology.moleculeLab.example", store.language), selection: $selectedExample) {
                    ForEach(BiomoleculeExample.allCases, id: \.self) { example in
                        Text(L10n.text("biology.moleculeLab.\(example.rawValue)", store.language)).tag(example)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedExample) { _ in
                    selectedGroup = nil
                    checkedGroup = nil
                }

                Picker(L10n.text("biology.moleculeLab.chooseGroup", store.language), selection: $selectedGroup) {
                    Text(L10n.text("biology.moleculeLab.chooseGroupPrompt", store.language))
                        .tag(nil as BiomoleculeGroup?)
                    ForEach(BiomoleculeGroup.allCases, id: \.self) { group in
                        Text(L10n.text("biology.moleculeLab.group.\(group.rawValue)", store.language))
                            .tag(Optional(group))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedGroup) { _ in checkedGroup = nil }

                Button {
                    guard let selectedGroup,
                          let evidence = assessmentTracker.recordSubmission(
                            group: selectedGroup,
                            for: selectedExample
                          ) else { return }
                    store.recordStudyAssessment(
                        lessonID: "biology.biomolecules_and_building_blocks",
                        evidence: evidence
                    )
                    checkedGroup = selectedGroup
                } label: {
                    Label(L10n.text("biology.moleculeLab.check", store.language), systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedGroup == nil || selectedGroup == checkedGroup)

                if let checkedGroup {
                    let isCorrect = checkedGroup == selectedExample.correctGroup
                    Label(
                        L10n.text(isCorrect ? "biology.moleculeLab.correct" : "biology.moleculeLab.tryAgain", store.language),
                        systemImage: isCorrect ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isCorrect ? .green : .orange)
                }

                Text(L10n.text(exampleInfoKey, store.language))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 9))

                Divider()

                HStack {
                    Text(L10n.text("biology.moleculeLab.reaction", store.language))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Picker("", selection: $reactionJoins) {
                        Text(L10n.text("biology.moleculeLab.join", store.language)).tag(true)
                        Text(L10n.text("biology.moleculeLab.split", store.language)).tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                HStack(spacing: 10) {
                    Text(L10n.text(reactionJoins ? "biology.moleculeLab.components" : "biology.moleculeLab.polymer", store.language))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.background, in: RoundedRectangle(cornerRadius: 9))
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(L10n.text(reactionJoins ? "biology.moleculeLab.polymer" : "biology.moleculeLab.components", store.language))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.background, in: RoundedRectangle(cornerRadius: 9))
                    Text(L10n.text(reactionJoins ? "biology.moleculeLab.waterOut" : "biology.moleculeLab.waterIn", store.language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.teal)
                }
                .font(.caption)

                Text(L10n.text(
                    selectedExample.isPolymer
                        ? "biology.moleculeLab.polymerExample"
                        : "biology.moleculeLab.nonPolymerExample",
                    store.language
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("biology.moleculeLab.caveat", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct NaturalSelectionLab: View {
    @EnvironmentObject private var store: LearningStore
    let lessonID: String
    @State private var environmentOptimum = 75.0
    @State private var selectionStrength = 0.45
    @State private var heritability = 0.8
    @State private var population = NaturalSelectionPopulation(traitMean: 35, traitSpread: 20, generation: 0)
    @State private var prediction = NaturalSelectionPractice.makePredictionAttempt(for: .increase)
    @State private var selectedDisplayIndex = -1
    @State private var previousMean: Double?

    private let trendOptionKeys = [
        "lab.naturalSelection.option.decrease",
        "lab.naturalSelection.option.noChange",
        "lab.naturalSelection.option.increase"
    ]

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                distributionChart
                chartLegend
                populationSummary
                controls
                predictionPrompt
                predictionFeedback
                actions
                generationOutcome
                modelRule
                limitations
            }
        }
    }

    private var header: some View {
        Label(L10n.text("lab.naturalSelection.title", store.language), systemImage: "chart.xyaxis.line")
            .font(.headline)
    }

    private var distributionChart: some View {
        Canvas { context, size in
            var curve = Path()
            for step in 0...100 {
                let trait = Double(step)
                let distance = (trait - population.traitMean) / max(population.traitSpread, 1)
                let height = exp(-0.5 * distance * distance)
                let point = CGPoint(
                    x: CGFloat(step) / 100 * size.width,
                    y: size.height - 8 - CGFloat(height) * max(0, size.height - 18)
                )
                if step == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
            }
            context.stroke(curve, with: .color(.teal), lineWidth: 2.5)
            drawMarker(population.traitMean, color: .teal, context: context, size: size)
            drawMarker(environmentOptimum, color: .orange, context: context, size: size)
        }
        .frame(height: 116)
        .padding(.horizontal, 4)
        .accessibilityLabel(Text(L10n.text("lab.naturalSelection.chart", store.language)))
    }

    private var chartLegend: some View {
        HStack {
            Label(L10n.text("lab.naturalSelection.mean", store.language), systemImage: "line.diagonal")
                .foregroundStyle(.teal)
            Spacer()
            Label(L10n.text("lab.naturalSelection.environment", store.language), systemImage: "line.diagonal")
                .foregroundStyle(.orange)
        }
        .font(.caption)
    }

    private var populationSummary: some View {
        HStack {
            Text("\(L10n.text("lab.naturalSelection.generation", store.language)) \(population.generation)")
            Spacer()
            Text(verbatim: L10n.text("lab.naturalSelection.meanValue", store.language) + " " + L10n.number(population.traitMean, fractionDigits: 1, store.language))
        }
        .font(.subheadline.monospacedDigit())
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            parameterSlider(
                "lab.naturalSelection.environment",
                value: $environmentOptimum,
                range: 0...100,
                onChange: { startNewPrediction() }
            )
            parameterSlider(
                "lab.naturalSelection.strength",
                value: $selectionStrength,
                onChange: { startNewPrediction() }
            )
            parameterSlider(
                "lab.naturalSelection.heritable",
                value: $heritability,
                onChange: { startNewPrediction() }
            )
        }
    }

    private var predictionPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("lab.naturalSelection.predictionPrompt", store.language))
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.naturalSelection.predictionPrompt", store.language), selection: $selectedDisplayIndex) {
                ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Text(L10n.text(trendOptionKeys[originalIndex], store.language)).tag(displayIndex)
                }
            }
            .pickerStyle(.segmented)
            .disabled(prediction.hasAnswered)
        }
    }

    @ViewBuilder
    private var predictionFeedback: some View {
        if prediction.hasAnswered {
            if prediction.isCorrect {
                Label(L10n.text("lab.naturalSelection.correct", store.language), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(L10n.text(expectedTrend.explanationKey, store.language))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(L10n.text("lab.naturalSelection.review", store.language), systemImage: "arrow.uturn.backward.circle")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        HStack {
            if !prediction.hasAnswered {
                Button(action: checkPrediction) {
                    Label(L10n.text("lab.naturalSelection.check", store.language), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedDisplayIndex < 0)
            } else if prediction.canRetry {
                Button(action: retryPrediction) {
                    Label(L10n.text("lab.naturalSelection.retry", store.language), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: advanceGeneration) {
                    Label(L10n.text("lab.naturalSelection.next", store.language), systemImage: "forward.end.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Button(action: resetSimulation) {
                Label(L10n.text("lab.naturalSelection.reset", store.language), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var generationOutcome: some View {
        if let previousMean {
            HStack(spacing: 6) {
                Text(L10n.text("lab.naturalSelection.outcome", store.language))
                Text(verbatim: L10n.number(previousMean, fractionDigits: 1, store.language) + " → " + L10n.number(population.traitMean, fractionDigits: 1, store.language))
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private var limitations: some View {
        Text(L10n.text("lab.naturalSelection.limit", store.language))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var modelRule: some View {
        Text(L10n.text("lab.naturalSelection.rule", store.language))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func drawMarker(_ value: Double, color: Color, context: GraphicsContext, size: CGSize) {
        let x = CGFloat(value / 100) * size.width
        var marker = Path()
        marker.move(to: CGPoint(x: x, y: 0))
        marker.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(marker, with: .color(color.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }

    private var expectedTrend: NaturalSelectionTrend {
        NaturalSelectionPractice.expectedTrend(
            population: population,
            environmentOptimum: environmentOptimum,
            selectionStrength: selectionStrength,
            heritability: heritability
        )
    }

    private func checkPrediction() {
        prediction.select(displayedIndex: selectedDisplayIndex)
        guard let evidence = prediction.currentAnswerEventEvidence() else { return }
        store.recordStudyAssessment(lessonID: lessonID, evidence: evidence)
    }

    private func retryPrediction() {
        prediction.retry()
        selectedDisplayIndex = -1
    }

    private func advanceGeneration() {
        guard prediction.isCorrect else { return }
        previousMean = population.traitMean
        population = NaturalSelectionPractice.advanceGeneration(
            from: population,
            environmentOptimum: environmentOptimum,
            selectionStrength: selectionStrength,
            heritability: heritability
        )
        startNewPrediction(clearOutcome: false)
    }

    private func startNewPrediction(clearOutcome: Bool = true) {
        prediction = NaturalSelectionPractice.makePredictionAttempt(for: expectedTrend)
        selectedDisplayIndex = -1
        if clearOutcome {
            previousMean = nil
        }
    }

    private func resetSimulation() {
        environmentOptimum = 75
        selectionStrength = 0.45
        heritability = 0.8
        population = NaturalSelectionPopulation(traitMean: 35, traitSpread: 20, generation: 0)
        previousMean = nil
        startNewPrediction()
    }

    private func parameterSlider(
        _ labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        onChange: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(L10n.text(labelKey, store.language))
                Spacer()
                Text(verbatim: L10n.number(value.wrappedValue, fractionDigits: 2, store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, onEditingChanged: { isEditing in
                if !isEditing {
                    onChange()
                }
            })
                .accessibilityLabel(Text(L10n.text(labelKey, store.language)))
        }
        .font(.caption)
    }
}

private struct EcosystemEnergyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var producerEnergy = 8_000.0
    @State private var transferFraction = 0.12

    private let levels = ["producers", "primary", "secondary", "tertiary"]
    private var energies: [Double] {
        levels.indices.map { producerEnergy * pow(transferFraction, Double($0)) }
    }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("biology.energyLab.title", store.language), systemImage: "chart.bar.xaxis")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L10n.text("biology.energy.level.\(level)", store.language))
                                Spacer()
                                Text(verbatim: L10n.measurement(energies[index], fractionDigits: 1, unit: "kJ", store.language))
                                    .monospacedDigit()
                            }
                            .font(.caption.weight(.medium))
                            ProgressView(value: energies[index], total: producerEnergy)
                                .tint(levelColor(index))
                                .accessibilityLabel(Text(L10n.text("biology.energy.level.\(level)", store.language)))
                                .accessibilityValue(Text(verbatim: L10n.measurement(energies[index], fractionDigits: 1, unit: "kJ", store.language)))
                        }
                    }
                }
                .padding(12)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))

                energySlider(
                    key: "biology.energyLab.producerEnergy",
                    value: $producerEnergy,
                    range: 1_000...20_000,
                    unit: "kJ"
                )
                energySlider(
                    key: "biology.energyLab.transfer",
                    value: $transferFraction,
                    range: 0.05...0.30,
                    unit: "%",
                    scale: 100
                )

                Text(L10n.text("biology.energyLab.limit", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func energySlider(
        key: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        scale: Double = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(L10n.text(key, store.language))
                Spacer()
                Text(verbatim: L10n.measurement(value.wrappedValue * scale, fractionDigits: 0, unit: unit, store.language))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .accessibilityLabel(Text(L10n.text(key, store.language)))
        }
        .font(.caption)
    }

    private func levelColor(_ index: Int) -> Color {
        switch index {
        case 0: .green
        case 1: .teal
        case 2: .orange
        default: .purple
        }
    }
}

private struct FoodWebLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedNode = "algae"
    @State private var removedNode = "none"

    private let species = ["algae", "zooplankton", "snails", "smallFish", "heron"]

    private var visibleLinks: [PondFoodWebLink] {
        PondFoodWebModel.visibleLinks(excluding: removedNode)
    }

    private var directConsumers: [String] {
        PondFoodWebModel.directConsumers(of: removedNode)
    }

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("biology.foodWebLab.title", store.language), systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)

                Text(L10n.text("biology.foodWebLab.arrow", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                diagram
                    .frame(height: 280)
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .contain)

                selectedNodeDetails

                Picker(L10n.text("biology.foodWebLab.scenario", store.language), selection: $removedNode) {
                    Text(L10n.text("biology.foodWebLab.none", store.language)).tag("none")
                    ForEach(species, id: \.self) { id in
                        Text(nodeName(id)).tag(id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: removedNode) { newValue in
                    if selectedNode == newValue { selectedNode = "none" }
                }

                if removedNode != "none" {
                    removalSummary
                }

                Text(L10n.text("biology.foodWebLab.limit", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var diagram: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    for link in visibleLinks {
                        guard let from = PondFoodWebModel.nodes.first(where: { $0.id == link.from }),
                              let to = PondFoodWebModel.nodes.first(where: { $0.id == link.to }) else { continue }
                        let start = CGPoint(x: from.x * size.width, y: from.y * size.height)
                        let end = CGPoint(x: to.x * size.width, y: to.y * size.height)
                        let dx = end.x - start.x
                        let dy = end.y - start.y
                        let distance = max(hypot(dx, dy), 1)
                        let ux = dx / distance
                        let uy = dy / distance
                        let lineStart = CGPoint(x: start.x + ux * 50, y: start.y + uy * 22)
                        let tip = CGPoint(x: end.x - ux * 51, y: end.y - uy * 22)
                        let base = CGPoint(x: tip.x - ux * 9, y: tip.y - uy * 9)
                        let opacity = selectedNode == "none" || link.from == selectedNode || link.to == selectedNode ? 0.78 : 0.16
                        var shaft = Path()
                        shaft.move(to: lineStart)
                        shaft.addLine(to: tip)
                        let isMatterCycle = link.kind == .matterCycle
                        let linkColor = isMatterCycle ? Color.teal : Color.secondary
                        context.stroke(
                            shaft,
                            with: .color(linkColor.opacity(opacity)),
                            style: StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: isMatterCycle ? [4, 3] : [])
                        )

                        let wing = CGPoint(x: -uy * 4, y: ux * 4)
                        var arrow = Path()
                        arrow.move(to: tip)
                        arrow.addLine(to: CGPoint(x: base.x + wing.x, y: base.y + wing.y))
                        arrow.addLine(to: CGPoint(x: base.x - wing.x, y: base.y - wing.y))
                        arrow.closeSubpath()
                        context.fill(arrow, with: .color(linkColor.opacity(opacity)))
                    }
                }

                ForEach(PondFoodWebModel.nodes) { node in
                    if node.id != removedNode {
                        Button {
                            selectedNode = node.id
                        } label: {
                            Text(nodeName(node.id))
                                .font(.caption.weight(.medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .frame(width: 104, height: 42)
                                .background(node.id == selectedNode ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(nodeColor(node.kind).opacity(0.7), lineWidth: node.id == selectedNode ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(nodeName(node.id))
                        .accessibilityHint(Text(L10n.text("biology.foodWebLab.select", store.language)))
                        .position(x: node.x * geometry.size.width, y: node.y * geometry.size.height)
                    }
                }
            }
        }
        .accessibilityLabel(L10n.text("biology.foodWebLab.title", store.language))
    }

    private var selectedNodeDetails: some View {
        let incoming = PondFoodWebModel.incomingLinks(to: selectedNode, excluding: removedNode).map(\.from)
        let outgoing = PondFoodWebModel.outgoingLinks(from: selectedNode, excluding: removedNode).map(\.to)
        return VStack(alignment: .leading, spacing: 4) {
            Text(nodeName(selectedNode))
                .font(.subheadline.weight(.semibold))
            if !incoming.isEmpty {
                Text("\(L10n.text("biology.foodWebLab.incoming", store.language)): \(incoming.map(nodeName).joined(separator: ", "))")
            }
            if !outgoing.isEmpty {
                Text("\(L10n.text("biology.foodWebLab.outgoing", store.language)): \(outgoing.map(nodeName).joined(separator: ", "))")
            }
            if incoming.isEmpty && outgoing.isEmpty {
                Text(L10n.text("biology.foodWebLab.noDirectLinks", store.language))
            }
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var removalSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text("biology.foodWebLab.removal", store.language))
                .font(.caption.weight(.semibold))
            if directConsumers.isEmpty {
                Text(L10n.text("biology.foodWebLab.noConsumers", store.language))
                    .font(.caption)
            } else {
                Text(directConsumers.map(nodeName).joined(separator: ", "))
                    .font(.caption)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func nodeName(_ id: String) -> String {
        if id == "none" { return L10n.text("biology.foodWebLab.network", store.language) }
        return L10n.text("biology.foodweb.node.\(id)", store.language)
    }

    private func nodeColor(_ kind: PondFoodWebNodeKind) -> Color {
        switch kind {
        case .producer: .green
        case .consumer: .orange
        case .decomposer: .purple
        case .matter: .teal
        }
    }
}

private enum CellOrganelleID {
    static let all: [String] = ["membrane", "nucleus", "rough_er", "golgi", "mitochondria", "ribosomes", "lysosome"]

    static func from(sceneNodeName: String?) -> String? {
        guard let sceneNodeName, sceneNodeName.hasPrefix("organelle-") else { return nil }
        let part = String(sceneNodeName.dropFirst("organelle-".count))
        return all.contains(part) ? part : nil
    }
}

private struct EukaryoticCellLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedPart = "nucleus"
    @State private var sceneTapSequence = 0
    @State private var sceneTapDiagnostic = "not tapped"

    private var isCell3DUITestRoute: Bool {
        ProcessInfo.processInfo.arguments.contains("-colidev.uiTestCell3D")
    }

    private let parts = CellOrganelleID.all

    var body: some View {
        LabCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        L10n.text("lab.cell3d.title", store.language),
                        systemImage: "cube.transparent"
                    )
                    .font(.headline)
                    Spacer()
                    Text(L10n.text("lab.cell3d.interactionHint", store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                EukaryoticCellScene(
                    selectedPart: $selectedPart,
                    tapSequence: $sceneTapSequence,
                    tapDiagnostic: $sceneTapDiagnostic
                )
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(L10n.text("lab.cell3d.accessibility", store.language)))
                    .accessibilityValue(Text(L10n.text("biology.cell3d.\(selectedPart)", store.language)))
                    .accessibilityIdentifier("biology.cell3d.scene")
                    .overlay(alignment: .topLeading) {
                        if isCell3DUITestRoute {
                            let diagnostic = "tap=\(sceneTapSequence), part=\(selectedPart), \(sceneTapDiagnostic)"
                            Text(diagnostic)
                                .font(.system(size: 1))
                                .foregroundStyle(.clear)
                                .frame(width: 1, height: 1)
                                .accessibilityLabel(Text(diagnostic))
                                .accessibilityValue(Text(diagnostic))
                                .accessibilityIdentifier("biology.cell3d.tapState")

                        }
                    }

                Picker(L10n.text("lab.cellPart", store.language), selection: $selectedPart) {
                    ForEach(parts, id: \.self) { part in
                        Text(L10n.text("biology.cell3d.\(part)", store.language)).tag(part)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("biology.cell3d.organelles")

                Text(L10n.text("biology.cell3d.\(selectedPart).function", store.language))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("biology.cell3d.description")

                Text(L10n.text("lab.cell3d.scaleNote", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EukaryoticCellScene: NSViewRepresentable {
    @Binding var selectedPart: String
    @Binding var tapSequence: Int
    @Binding var tapDiagnostic: String

    fileprivate func makeCoordinator() -> Coordinator {
        Coordinator(selectedPart: $selectedPart, tapSequence: $tapSequence, tapDiagnostic: $tapDiagnostic)
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.makeScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .controlBackgroundColor
        view.antialiasingMode = .multisampling4X
        Self.highlight(selectedPart, in: view.scene)
        let clickGesture = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.selectOrganelle(_:))
        )
        clickGesture.delegate = context.coordinator
        view.addGestureRecognizer(clickGesture)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.selectedPart = $selectedPart
        context.coordinator.tapSequence = $tapSequence
        context.coordinator.tapDiagnostic = $tapDiagnostic
        Self.highlight(selectedPart, in: view.scene)
    }

    fileprivate final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var selectedPart: Binding<String>
        var tapSequence: Binding<Int>
        var tapDiagnostic: Binding<String>

        init(selectedPart: Binding<String>, tapSequence: Binding<Int>, tapDiagnostic: Binding<String>) {
            self.selectedPart = selectedPart
            self.tapSequence = tapSequence
            self.tapDiagnostic = tapDiagnostic
        }

        func gestureRecognizer(
            _ gestureRecognizer: NSGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
        ) -> Bool {
            // Keep selection available alongside SceneKit's camera controls.
            // Сохраняем выбор органеллы вместе с управлением камерой SceneKit.
            true
        }

        @objc func selectOrganelle(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            let (part, selectionDetails) = organelleCandidate(at: point, in: view)
            let testTargetDetails = ProcessInfo.processInfo.arguments.contains("-colidev.uiTestCell3D")
                ? " mitochondriaTarget=\(projectedTestTargetPoint(in: view))"
                : ""
            let diagnostic = "view=(\(Int(point.x)),\(Int(point.y))) size=(\(Int(view.bounds.width)),\(Int(view.bounds.height))) scale=\(view.window?.backingScaleFactor ?? 1) \(selectionDetails)\(testTargetDetails)"

            // Update SwiftUI state after the AppKit click recognizer finishes its event.
            // Обновляем состояние SwiftUI после завершения обработки щелчка AppKit.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.tapSequence.wrappedValue += 1
                if let part {
                    self.selectedPart.wrappedValue = part
                }
                let finalPart = part ?? self.selectedPart.wrappedValue
                self.tapDiagnostic.wrappedValue = "\(diagnostic) selected=\(finalPart)"
            }
        }

        private func projectedTestTargetPoint(in view: SCNView) -> String {
            guard let mitochondria = view.scene?.rootNode.childNode(
                withName: "organelle-mitochondria",
                recursively: false
            ),
                let body = mitochondria.childNodes.first(where: { $0.geometry != nil }) else {
                return "unavailable(no-mitochondrion)"
            }

            let projected = view.projectPoint(body.presentation.worldPosition)
            let backingBounds = view.convertToBacking(CGRect(origin: .zero, size: view.bounds.size))
            guard backingBounds.width > 0, backingBounds.height > 0 else {
                return "unavailable(backing-size)"
            }
            let normalizedX = CGFloat(projected.x) / backingBounds.width
            let normalizedY = 1 - CGFloat(projected.y) / backingBounds.height
            return String(format: "%.6f,%.6f", Double(normalizedX), Double(normalizedY))
        }

        private func organelleCandidate(at point: CGPoint, in view: SCNView) -> (String?, String) {
            // SceneKit hit testing and projectPoint use renderer-space pixels;
            // NSView event locations are in logical points.
            // Хит-тест и projectPoint в SceneKit используют пиксели рендерера,
            // а координаты событий NSView заданы в логических пунктах.
            let rendererPoint = view.convertToBacking(point)
            let pickRadius = 44 * (view.window?.backingScaleFactor ?? 1)
            let hits = view.hitTest(rendererPoint, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            let hitParts = hits.compactMap { hit -> String? in
                var node: SCNNode? = hit.node
                while let current = node {
                    if let part = CellOrganelleID.from(sceneNodeName: current.name) { return part }
                    node = current.parent
                }
                return nil
            }
            // The transparent outer membrane can be hit before the organelle behind it.
            // Прозрачная мембрана может определиться раньше органеллы за ней.
            if let part = hitParts.first(where: { $0 != "membrane" }) {
                return (part, "hit=\(hitParts.joined(separator: ","))")
            }

            let nearest = nearestOrganelle(to: rendererPoint, in: view)
            if let nearest, nearest.distance <= pickRadius {
                return (nearest.part, "renderer=(\(Int(rendererPoint.x)),\(Int(rendererPoint.y))) nearest=\(nearest.part)@\(Int(nearest.distance)) projected=(\(Int(nearest.projected.x)),\(Int(nearest.projected.y))) hit=\(hitParts.joined(separator: ","))")
            }
            let nearestDetails = nearest.map { "\($0.part)@\(Int($0.distance)) projected=(\(Int($0.projected.x)),\(Int($0.projected.y)))" } ?? "none"
            return (hitParts.first, "renderer=(\(Int(rendererPoint.x)),\(Int(rendererPoint.y))) nearest=\(nearestDetails) hit=\(hitParts.joined(separator: ","))")
        }

        private func nearestOrganelle(to point: CGPoint, in view: SCNView) -> (part: String, distance: CGFloat, projected: CGPoint)? {
            guard let scene = view.scene else { return nil }
            var nearest: (part: String, distance: CGFloat, projected: CGPoint)?

            func inspect(_ node: SCNNode, inheritedPart: String?) {
                let part = CellOrganelleID.from(sceneNodeName: node.name) ?? inheritedPart
                if let part, part != "membrane", node.geometry != nil {
                    let projected = view.projectPoint(node.presentation.worldPosition)
                    if (0...1).contains(projected.z) {
                        let projectedPoint = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                        let dx = projectedPoint.x - point.x
                        let dy = projectedPoint.y - point.y
                        let distance = hypot(dx, dy)
                        if let current = nearest {
                            if distance < current.distance {
                                nearest = (part, distance, projectedPoint)
                            }
                        } else {
                            nearest = (part, distance, projectedPoint)
                        }
                    }
                }
                for child in node.childNodes {
                    inspect(child, inheritedPart: part)
                }
            }

            for node in scene.rootNode.childNodes {
                inspect(node, inheritedPart: nil)
            }
            return nearest
        }
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.controlBackgroundColor

        let membrane = SCNNode(geometry: SCNSphere(radius: 1.42))
        membrane.name = "organelle-membrane"
        membrane.geometry?.firstMaterial = material(.systemTeal, roughness: 0.35, transparency: 0.14)
        membrane.geometry?.firstMaterial?.isDoubleSided = true
        membrane.geometry?.firstMaterial?.fillMode = .lines
        scene.rootNode.addChildNode(membrane)

        let nucleus = SCNNode(geometry: SCNSphere(radius: 0.52))
        nucleus.name = "organelle-nucleus"
        nucleus.position = SCNVector3(-0.25, 0.08, 0.05)
        nucleus.geometry?.firstMaterial = material(.systemPurple)
        scene.rootNode.addChildNode(nucleus)

        let nucleolus = SCNNode(geometry: SCNSphere(radius: 0.15))
        nucleolus.position = SCNVector3(0.14, 0.02, 0.38)
        nucleolus.geometry?.firstMaterial = material(.systemPink)
        nucleus.addChildNode(nucleolus)

        let roughER = SCNNode()
        roughER.name = "organelle-rough_er"
        let roughERFolds: [(Float, Float, Float)] = [
            (-0.50, 0.48, -0.06), (-0.56, 0.19, 0.01), (-0.52, -0.13, -0.08), (-0.37, -0.40, -0.02),
        ]
        for (index, offset) in roughERFolds.enumerated() {
            let fold = SCNNode(geometry: SCNTorus(ringRadius: 0.39 - CGFloat(index) * 0.025, pipeRadius: 0.035))
            fold.position = SCNVector3(offset.0, offset.1, offset.2)
            fold.geometry?.firstMaterial = material(.systemOrange)
            roughER.addChildNode(fold)
        }
        scene.rootNode.addChildNode(roughER)

        let golgi = SCNNode()
        golgi.name = "organelle-golgi"
        for index in 0..<4 {
            let cisterna = SCNNode(geometry: SCNCapsule(capRadius: 0.07, height: 0.72))
            cisterna.eulerAngles.z = .pi / 2
            cisterna.position = SCNVector3(0.56 + Float(index) * 0.045, -0.52 + Float(index) * 0.13, -0.18)
            cisterna.geometry?.firstMaterial = material(.systemPink)
            golgi.addChildNode(cisterna)
        }
        scene.rootNode.addChildNode(golgi)

        let mitochondria = SCNNode()
        mitochondria.name = "organelle-mitochondria"
        let mitochondrialPositions: [((Float, Float, Float), Float)] = [
            ((0.56, 0.47, 0.0), -0.55), ((-0.82, -0.50, 0.18), 0.65),
        ]
        for (position, angle) in mitochondrialPositions {
            let body = SCNNode(geometry: SCNCapsule(capRadius: 0.15, height: 0.54))
            body.eulerAngles.z = CGFloat(angle)
            body.position = SCNVector3(position.0, position.1, position.2)
            body.geometry?.firstMaterial = material(.systemRed)
            mitochondria.addChildNode(body)
            for foldIndex in 0..<3 {
                let crista = SCNNode(geometry: SCNCylinder(radius: 0.018, height: 0.19))
                crista.eulerAngles.z = .pi / 2
                crista.position = SCNVector3(position.0, position.1 + Float(foldIndex - 1) * 0.07, position.2 + 0.12)
                crista.geometry?.firstMaterial = material(.systemYellow)
                mitochondria.addChildNode(crista)
            }
        }
        scene.rootNode.addChildNode(mitochondria)

        let ribosomes = SCNNode()
        ribosomes.name = "organelle-ribosomes"
        let ribosomePositions: [(Float, Float, Float)] = [
            (-0.90, 0.35, 0.24), (-0.76, 0.72, -0.12), (-0.42, 0.86, 0.1),
            (-0.05, 0.90, -0.18), (0.28, 0.82, 0.26), (0.78, 0.65, -0.08),
            (0.93, 0.22, 0.12), (0.90, -0.20, -0.15), (0.62, -0.84, 0.09),
            (0.22, -0.91, -0.22), (-0.21, -0.89, 0.20), (-0.67, -0.74, -0.11),
            (-0.97, -0.17, -0.12), (0.38, 0.21, 0.66), (-0.64, 0.05, 0.68),
            (0.08, -0.57, 0.69),
        ]
        for position in ribosomePositions {
            let dot = SCNNode(geometry: SCNSphere(radius: 0.045))
            dot.position = SCNVector3(position.0, position.1, position.2)
            dot.geometry?.firstMaterial = material(.systemBlue)
            ribosomes.addChildNode(dot)
        }
        scene.rootNode.addChildNode(ribosomes)

        let lysosome = SCNNode()
        lysosome.name = "organelle-lysosome"
        let lysosomePositions: [(Float, Float, Float)] = [
            (-0.82, 0.08, -0.42), (0.78, -0.08, 0.44), (0.18, -0.74, -0.48),
        ]
        for position in lysosomePositions {
            let vesicle = SCNNode(geometry: SCNSphere(radius: 0.13))
            vesicle.position = SCNVector3(position.0, position.1, position.2)
            vesicle.geometry?.firstMaterial = material(.systemGreen)
            lysosome.addChildNode(vesicle)
        }
        scene.rootNode.addChildNode(lysosome)

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 3.8
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 5.2)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .omni
        light.intensity = 850
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(-2.5, 3.5, 5)
        scene.rootNode.addChildNode(lightNode)
        return scene
    }

    private static func highlight(_ selectedPart: String, in scene: SCNScene?) {
        guard let scene else { return }
        for part in CellOrganelleID.all {
            guard let node = scene.rootNode.childNode(withName: "organelle-\(part)", recursively: false) else { continue }
            setEmission(on: node, selected: part == selectedPart)
        }
    }

    private static func setEmission(on node: SCNNode, selected: Bool) {
        if let materials = node.geometry?.materials {
            for material in materials {
                material.emission.contents = selected ? NSColor.systemYellow : NSColor.black
            }
        }
        for child in node.childNodes {
            setEmission(on: child, selected: selected)
        }
    }

    private static func material(_ color: NSColor, roughness: CGFloat = 0.62, transparency: CGFloat = 1) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.transparency = transparency
        return result
    }
}

private struct AdaptationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var animal = "penguin"

    var body: some View {
        LabCard {
            HStack(spacing: 18) {
                Image(systemName: animal == "penguin" ? "bird.fill" : "sun.max.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(animal == "penguin" ? .blue : .orange)
                    .frame(width: 82, height: 82)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 8) {
                    Picker(selection: $animal, label: Text(L10n.text("lab.animal", store.language))) {
                        Text(L10n.text("zoology.penguin", store.language)).tag("penguin")
                        Text(L10n.text("zoology.camel", store.language)).tag("camel")
                    }
                    .labelsHidden()
                    Text(L10n.text("lab.adaptation", store.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.text("zoology.\(animal).feature", store.language))
                        .font(.callout)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct ConditionalLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var score = 7.0

    var body: some View {
        LabCard {
            Text("if score >= 5:")
                .font(.system(.body, design: .monospaced).weight(.semibold))
            HStack {
                Text(L10n.text("lab.score", store.language))
                Spacer()
                Text("score = \(score, specifier: "%.0f")")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $score, in: 0...10, step: 1)
            Label { Text(L10n.text(score >= 5 ? "lab.pass" : "lab.fail", store.language)) } icon: { Image(systemName: score >= 5 ? "checkmark.circle.fill" : "xmark.circle.fill") }
            .foregroundStyle(score >= 5 ? Color.green : Color.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct VariablesTypesLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var reassignToText = false
    @State private var inputText = "12"
    @State private var conversionResult: PythonInputPracticeResult?
    @State private var practiceTracker = PythonInputPracticeTracker()

    var body: some View {
        LabCard {
            Text(L10n.text("lab.variableCodeInitial", store.language))
                .font(.system(.body, design: .monospaced).weight(.medium))
            Toggle(L10n.text("lab.variableReassign", store.language), isOn: $reassignToText)
                .toggleStyle(.switch)
            Text(L10n.text("lab.variableCodeUpdate", store.language))
                .font(.system(.body, design: .monospaced).weight(.medium))
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("lab.variableCurrentBinding", store.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text("score")
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    Spacer()
                    Text(reassignToText ? "\"12\"" : "12")
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .textSelection(.enabled)
                    Text(reassignToText ? "str" : "int")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Label(
                    L10n.text(reassignToText ? "lab.variableAfter" : "lab.variableBefore", store.language),
                    systemImage: reassignToText ? "textformat" : "number"
                )
                .font(.callout)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            Divider()

            Text(L10n.text("lab.input.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.input.explanation", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("lab.input.practiceHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("lab.input.codeRead", store.language))
                .font(.system(.body, design: .monospaced).weight(.medium))
            Text("count = int(raw_text)")
                .font(.system(.body, design: .monospaced).weight(.medium))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(L10n.text("lab.input.placeholder", store.language), text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .accessibilityLabel(Text(L10n.text("lab.input.accessibility", store.language)))
                    .onSubmit(convertInput)

                Button(L10n.text("lab.input.convert", store.language), action: convertInput)
                    .buttonStyle(.borderedProminent)
            }

            if let conversionResult {
                switch conversionResult {
                case .integer(let value):
                    Label(
                        String(format: L10n.text("lab.input.integerResult", store.language), value),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                case .valueError:
                    Label(L10n.text("lab.input.valueError", store.language), systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                case .outsideSimulatorRange:
                    Label(L10n.text("lab.input.rangeLimit", store.language), systemImage: "info.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Text(L10n.text("lab.input.simulatorLimit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            PracticeMinutesRunner()
        }
    }

    private func convertInput() {
        conversionResult = PythonInputPractice.convert(inputText)
        if let evidence = practiceTracker.recordSubmission(text: inputText) {
            store.recordStudyAssessment(lessonID: "programming.variables_and_types", evidence: evidence)
        }
    }
}

private enum PracticeMinutesPractice {
    static let starterCode = """
    def solve(values):
        earlier_minutes = values[0]
        today_minutes = values[1]
        total_minutes = earlier_minutes + today_minutes
        return total_minutes
    """
}

private struct PracticeMinutesRunner: View {
    @EnvironmentObject private var store: LearningStore
    @AppStorage("colidev.pythonPractice.practiceMinutes.code") private var code = PracticeMinutesPractice.starterCode
    @AppStorage("colidev.pythonPractice.practiceMinutes.earlier") private var earlierMinutes = "12"
    @AppStorage("colidev.pythonPractice.practiceMinutes.today") private var todayMinutes = "8"
    @AppStorage("colidev.pythonPractice.practiceMinutes.lastRunCode") private var lastRunCode = ""
    @AppStorage("colidev.pythonPractice.practiceMinutes.lastRunEarlier") private var lastRunEarlier = ""
    @AppStorage("colidev.pythonPractice.practiceMinutes.lastRunToday") private var lastRunToday = ""
    @AppStorage("colidev.pythonPractice.practiceMinutes.lastResult") private var lastResult = ""
    @AppStorage("colidev.pythonPractice.practiceMinutes.lastErrorCode") private var lastErrorCode = ""
    @AppStorage("colidev.pythonPractice.practiceMinutes.lastPassed") private var lastPassed = false
    @State private var isRunning = false
    @State private var connectionErrorKey: String?
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(
        itemIDs: ["programming.variables_and_types.practice_minutes"]
    )

    private var submittedValues: [Int]? {
        guard let earlier = Int(earlierMinutes),
              let today = Int(todayMinutes),
              earlier >= 0,
              today >= 0 else {
            return nil
        }
        let (_, overflow) = earlier.addingReportingOverflow(today)
        return overflow ? nil : [earlier, today]
    }

    private var isResultCurrent: Bool {
        !lastResult.isEmpty
            && lastRunCode == code
            && lastRunEarlier == earlierMinutes
            && lastRunToday == todayMinutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("lab.practiceMinutes.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.practiceMinutes.description", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                TextField(L10n.text("lab.practiceMinutes.earlier", store.language), text: $earlierMinutes)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(Text(L10n.text("lab.practiceMinutes.earlier", store.language)))
                    .accessibilityIdentifier("python.minutes.earlier")
                    .disabled(isRunning)
                TextField(L10n.text("lab.practiceMinutes.today", store.language), text: $todayMinutes)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(Text(L10n.text("lab.practiceMinutes.today", store.language)))
                    .accessibilityIdentifier("python.minutes.today")
                    .disabled(isRunning)
            }

            Text(L10n.text("lab.practiceMinutes.editor", store.language))
                .font(.subheadline.weight(.semibold))
            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 110, maxHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
                .accessibilityLabel(Text(L10n.text("lab.practiceMinutes.editor", store.language)))
                .accessibilityIdentifier("python.minutes.code")
                .disabled(isRunning)

            HStack {
                Button(L10n.text("lab.practiceMinutes.reset", store.language)) {
                    code = PracticeMinutesPractice.starterCode
                }
                .buttonStyle(.bordered)
                .disabled(isRunning)

                Spacer()
                Button(action: runProject) {
                    Label(
                        L10n.text(isRunning ? "lab.practiceMinutes.running" : "lab.practiceMinutes.run", store.language),
                        systemImage: isRunning ? "hourglass" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || code.utf8.count > 8_192 || submittedValues == nil)
                .accessibilityIdentifier("python.minutes.run")
            }

            if submittedValues == nil {
                Text(L10n.text("lab.practiceMinutes.invalidInput", store.language))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if code.utf8.count > 8_192 {
                Text(L10n.text("lab.practiceMinutes.codeLimit", store.language))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if isResultCurrent {
                VStack(alignment: .leading, spacing: 7) {
                    Label(
                        L10n.text(lastPassed ? "lab.practiceMinutes.passed" : "lab.practiceMinutes.failed", store.language),
                        systemImage: lastPassed ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(lastPassed ? Color.green : Color.orange)

                    if lastErrorCode.isEmpty {
                        Text(String(format: L10n.text("lab.practiceMinutes.output", store.language), lastResult))
                            .font(.system(.callout, design: .monospaced))
                            .accessibilityIdentifier("python.minutes.result")
                    } else {
                        Text(L10n.text(errorMessageKey(lastErrorCode), store.language))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("python.minutes.result")
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
            }

            if let connectionErrorKey {
                Label(L10n.text(connectionErrorKey, store.language), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private func runProject() {
        guard !isRunning, code.utf8.count <= 8_192, let values = submittedValues else { return }
        isRunning = true
        connectionErrorKey = nil
        let submittedCode = code
        let expectedTotal = values[0] + values[1]

        Task { @MainActor in
            defer { isRunning = false }
            do {
                let response = try await OrchestratorClient.runPythonPractice(code: submittedCode, values: values)
                let passed = response.status == "ok" && response.resultText == String(expectedTotal)
                lastRunCode = submittedCode
                lastRunEarlier = earlierMinutes
                lastRunToday = todayMinutes
                lastPassed = passed
                lastResult = response.status == "ok" ? (response.resultText ?? "") : (response.code ?? response.status)
                lastErrorCode = response.status == "ok" ? "" : (response.code ?? response.status)

                if let evidence = assessmentTracker.recordSubmission(
                    selectedAnswerIndex: passed ? 1 : 0,
                    correctAnswerIndex: 1,
                    optionCount: 2,
                    itemID: "programming.variables_and_types.practice_minutes"
                ) {
                    store.recordStudyAssessment(lessonID: "programming.variables_and_types", evidence: evidence)
                }
                if passed {
                    store.saveReflectionDraft(
                        "\(values[0]) + \(values[1]) = \(expectedTotal)",
                        lessonID: "cause_and_corse.journey.python"
                    )
                    store.setJourneyProjectCompleted(true, stepID: "python")
                }
            } catch {
                connectionErrorKey = "lab.practiceMinutes.error.unavailable"
            }
        }
    }

    private func errorMessageKey(_ code: String) -> String {
        switch code {
        case "syntax_error": "lab.pythonRunner.error.syntax"
        case "unsupported_syntax": "lab.pythonRunner.error.unsupported"
        case "iteration_limit": "lab.pythonRunner.error.limit"
        case "code_too_large": "lab.pythonRunner.error.codeLimit"
        case "invalid_arguments": "lab.pythonRunner.error.invalidInput"
        case "invalid_result": "lab.pythonRunner.error.invalidResult"
        case "ValueError": "lab.pythonRunner.error.value"
        default: "lab.pythonRunner.error.runtime"
        }
    }
}

private struct AlgorithmicThinkingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var session = AlgorithmicThinkingPracticeSession()
    @State private var feedbackKey: String?
    @State private var feedbackIsSuccess = false
    @State private var a = 6
    @State private var b = 3

    private var completedSteps: [String] { session.completedStepKeys }

    private var stepOrder: [String] {
        AlgorithmicThinkingPractice.questions.map { $0.choiceKeys[$0.correctOptionIndex] }
    }

    private var result: Int { max(a, b) }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.algorithmHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let currentQuestion = session.currentQuestion {
                Text(L10n.text(currentQuestion.contextKey, store.language))
                    .font(.headline)

                if let stage = currentQuestion.maximumDebuggingStage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("lab.algorithmDebugSnippet", store.language))
                            .font(.callout.weight(.semibold))
                        Text("""
                        func maximum(values):
                            current_maximum = 0
                            for value in values:
                                if value > current_maximum:
                                    current_maximum = value
                            return current_maximum
                        """)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)

                        if stage == .repairInitialization {
                            let values = AlgorithmicThinkingPractice.maximumDebuggingCounterexampleValues
                            if let expected = AlgorithmicThinkingPractice.maximum(of: values),
                               let actual = AlgorithmicThinkingPractice.faultyMaximumInitializedAtZero(of: values) {
                                Text("\(L10n.text("lab.algorithmTestCaseInput", store.language)): [\(formattedValues(values))]")
                                    .font(.system(.callout, design: .monospaced))
                                Text(String(format: L10n.text("lab.algorithmDebugFaultyOutput", store.language), actual))
                                    .font(.system(.callout, design: .monospaced))
                                Text(String(format: L10n.text("lab.algorithmDebugExpectedOutput", store.language), expected))
                                    .font(.system(.callout, design: .monospaced))
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                } else if let scenario = AlgorithmicThinkingPractice.maximumTestCase(forQuestionID: currentQuestion.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("lab.algorithmMaximumListContract", store.language))
                            .font(.callout)
                        Text("\(L10n.text("lab.algorithmTestCaseInput", store.language)): [\(formattedValues(scenario.values))]")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                } else if currentQuestion.contextKey == "lab.algorithm.context.maximumList" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("lab.algorithmMaximumListContract", store.language))
                            .font(.callout)
                        Text("\(L10n.text("lab.algorithmTestCaseInput", store.language)): [\(formattedValues(AlgorithmicThinkingPractice.maximumListValues))]")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                } else if let scenario = AlgorithmicThinkingPractice.averageTestCase(forQuestionID: currentQuestion.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("lab.algorithmTestCaseContract", store.language))
                            .font(.callout)
                        Text("\(L10n.text("lab.algorithmTestCaseInput", store.language)): [\(formattedValues(scenario.values))]")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                } else if let scenario = AlgorithmicThinkingPractice.decompositionScenario(forQuestionID: currentQuestion.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text(scenario.promptKey, store.language))
                            .font(.callout)
                        Text(L10n.text(scenario.inputKey, store.language))
                            .font(.system(.callout, design: .monospaced))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                } else if let testCase = AlgorithmicThinkingPractice.eligibilityTestCase(forQuestionID: currentQuestion.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("lab.algorithmEligibilityRule", store.language))
                            .font(.callout)
                        Text(String(format: L10n.text("lab.algorithmEligibilityAge", store.language), testCase.age))
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            ForEach(Array(completedSteps.enumerated()), id: \.offset) { index, step in
                Label("\(index + 1). \(L10n.text(stepTitleKey(step), store.language))", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.green)
            }

            if completedSteps.count < stepOrder.count {
                Text(String(format: L10n.text("lab.algorithmProgress", store.language), completedSteps.count + 1, stepOrder.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)

                ForEach(Array(session.displayedChoiceKeys.enumerated()), id: \.offset) { displayIndex, choice in
                    Button {
                        select(displayedIndex: displayIndex)
                    } label: {
                        Label(L10n.text(stepTitleKey(choice), store.language), systemImage: "arrow.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let feedbackKey {
                Label(L10n.text(feedbackKey, store.language), systemImage: feedbackIsSuccess ? "checkmark.circle.fill" : "info.circle")
                    .font(.callout)
                    .foregroundStyle(feedbackIsSuccess ? Color.green : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if session.isComplete {
                Label(L10n.text("lab.algorithmComplete", store.language), systemImage: "checkmark.seal.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if AlgorithmicThinkingPractice.showsMaximumExperiment(completedQuestionCount: completedSteps.count) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("lab.algorithmInputs", store.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Stepper("a = \(a)", value: $a, in: -10...10)
                    Stepper("b = \(b)", value: $b, in: -10...10)
                    Text("\(L10n.text("lab.algorithmCondition", store.language)): \(a) > \(b) → \(L10n.text(a > b ? "lab.algorithmTrue" : "lab.algorithmFalse", store.language))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(String(format: L10n.text("lab.algorithmResult", store.language), result))
                        .font(.headline.monospacedDigit())
                    Text(L10n.text(a > b ? "lab.algorithmTraceGreater" : "lab.algorithmTraceOtherwise", store.language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
            }

            if AlgorithmicThinkingPractice.showsMaximumTestResults(completedQuestionCount: completedSteps.count) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("lab.algorithmMaximumTestCaseExamples", store.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(AlgorithmicThinkingPractice.maximumTestCases) { scenario in
                        HStack {
                            Text("[\(formattedValues(scenario.values))]")
                                .font(.system(.callout, design: .monospaced))
                            Spacer(minLength: 12)
                            if let maximum = AlgorithmicThinkingPractice.maximum(of: scenario.values) {
                                Text("→ \(maximum)")
                                    .font(.system(.callout, design: .monospaced))
                            } else {
                                Text(L10n.text("lab.algorithmMaximumInvalidOutcome", store.language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))

            }

            if session.isComplete {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("lab.algorithmTestCaseExamples", store.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(AlgorithmicThinkingPractice.averageTestCases) { scenario in
                        HStack {
                            Text("[\(formattedValues(scenario.values))]")
                                .font(.system(.callout, design: .monospaced))
                            Spacer(minLength: 12)
                            if let average = AlgorithmicThinkingPractice.average(of: scenario.values) {
                                Text("→ \(String(average))")
                                    .font(.system(.callout, design: .monospaced))
                            } else {
                                Text(L10n.text("lab.algorithmTestCaseInvalidOutcome", store.language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("lab.algorithmDecompositionSolutions", store.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(AlgorithmicThinkingPractice.decompositionScenarios) { scenario in
                        Text(L10n.text(scenario.solutionKey, store.language))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("lab.algorithmEligibilityTestResults", store.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(AlgorithmicThinkingPractice.eligibilityTestCases) { testCase in
                        HStack {
                            Text(String(format: L10n.text("lab.algorithmEligibilityAge", store.language), testCase.age))
                                .font(.system(.callout, design: .monospaced))
                            Spacer(minLength: 12)
                            Text(L10n.text(testCase.expectedResultKey, store.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    session.restart()
                    feedbackKey = nil
                    feedbackIsSuccess = false
                } label: {
                    Label(L10n.text("lab.algorithmRestart", store.language), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                PythonCodePracticeView()
            }
        }
    }

    private func select(displayedIndex: Int) {
        guard let submission = session.submit(displayedIndex: displayedIndex) else { return }
        if let evidence = submission.evidence {
            store.recordStudyAssessment(lessonID: "programming.computational_thinking", evidence: evidence)
        }
        guard submission.isCorrect else {
            if let stage = AlgorithmicThinkingPractice.maximumDebuggingStage(forQuestionID: submission.questionID) {
                feedbackKey = stage == .findCounterexample
                    ? "lab.algorithmDebugFindIncorrect"
                    : "lab.algorithmDebugRepairIncorrect"
            } else if AlgorithmicThinkingPractice.maximumTestCase(forQuestionID: submission.questionID) != nil {
                feedbackKey = "lab.algorithmMaximumTestCaseIncorrect"
            } else if AlgorithmicThinkingPractice.averageTestCase(forQuestionID: submission.questionID) != nil {
                feedbackKey = "lab.algorithmTestCaseIncorrect"
            } else if AlgorithmicThinkingPractice.eligibilityTestCase(forQuestionID: submission.questionID) != nil {
                feedbackKey = "lab.algorithmEligibilityIncorrect"
            } else {
                feedbackKey = "lab.algorithmIncorrect"
            }
            feedbackIsSuccess = false
            return
        }
        feedbackIsSuccess = true
        if let stage = AlgorithmicThinkingPractice.maximumDebuggingStage(forQuestionID: submission.questionID) {
            feedbackKey = stage == .findCounterexample
                ? "lab.algorithmDebugFindCorrect"
                : "lab.algorithmDebugRepairCorrect"
        } else if let testCase = AlgorithmicThinkingPractice.maximumTestCase(forQuestionID: submission.questionID) {
            feedbackKey = testCase.explanationKey
        } else if let testCase = AlgorithmicThinkingPractice.averageTestCase(forQuestionID: submission.questionID) {
            feedbackKey = testCase.explanationKey
        } else if let testCase = AlgorithmicThinkingPractice.eligibilityTestCase(forQuestionID: submission.questionID) {
            feedbackKey = testCase.explanationKey
        } else {
            feedbackKey = "lab.algorithmStepCorrect"
        }
    }

    private func stepTitleKey(_ step: String) -> String {
        switch step {
        case let key where key.hasPrefix("lab."): key
        case "input": "lab.algorithmInput"
        case "compare": "lab.algorithmCompare"
        case "otherwise": "lab.algorithmOtherwise"
        case "checkNonempty": "lab.algorithmCheckNonempty"
        case "checkNonemptyList": "lab.algorithmCheckNonempty"
        case "initializeCurrentMaximum": "lab.algorithmInitializeCurrentMaximum"
        case "initializeFromZero": "lab.algorithmInitializeFromZero"
        case "initializeFromLast": "lab.algorithmInitializeFromLast"
        case "inspectRemainingValues": "lab.algorithmInspectRemainingValues"
        case "updateIfGreater": "lab.algorithmUpdateIfGreater"
        case "returnMaximum": "lab.algorithmReturnMaximum"
        case "initializeTotal": "lab.algorithmInitializeTotal"
        case "accumulateValues": "lab.algorithmAccumulateValues"
        case "divideByCount": "lab.algorithmDivideByCount"
        case "returnAverage": "lab.algorithmReturnAverage"
        case "typical": "lab.algorithmCaseTypical"
        case "boundary": "lab.algorithmCaseBoundary"
        case "invalid": "lab.algorithmCaseInvalid"
        default: "lab.algorithmDisplay"
        }
    }

    private func formattedValues(_ values: [Int]) -> String {
        values.map(String.init).joined(separator: ", ")
    }
}

private struct PythonCodePracticeView: View {
    @EnvironmentObject private var store: LearningStore
    @AppStorage("colidev.pythonPractice.computationalThinking.code") private var code = AlgorithmicPythonPractice.startingCode
    @State private var selectedCaseID = AlgorithmicPythonPractice.testCases[2].id
    @State private var isRunning = false
    @State private var lastRunCode: String?
    @State private var lastRunCaseID: String?
    @State private var lastResponse: PythonPracticeRunResponse?
    @State private var lastPassed: Bool?
    @State private var connectionErrorKey: String?
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(
        itemIDs: AlgorithmicPythonPractice.testCases.map(\.evidenceID)
    )

    private var selectedCase: AlgorithmicPythonTestCase {
        AlgorithmicPythonPractice.testCases.first { $0.id == selectedCaseID }
            ?? AlgorithmicPythonPractice.testCases[0]
    }

    private var isResultCurrent: Bool {
        lastRunCode == code && lastRunCaseID == selectedCase.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("lab.pythonRunner.title", store.language))
                .font(.headline)

            Text(L10n.text("lab.pythonRunner.description", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.pythonRunner.testCase", store.language), selection: $selectedCaseID) {
                ForEach(AlgorithmicPythonPractice.testCases) { testCase in
                    Text(L10n.text(testCase.titleKey, store.language)).tag(testCase.id)
                }
            }
            .accessibilityIdentifier("pythonRunner.testCase")
            .disabled(isRunning)

            Text("\(L10n.text("lab.pythonRunner.input", store.language)): values = [\(selectedCase.values.map(String.init).joined(separator: ", "))]")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(L10n.text("lab.pythonRunner.editor", store.language))
                .font(.subheadline.weight(.semibold))

            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150, maxHeight: 250)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
                .accessibilityLabel(L10n.text("lab.pythonRunner.editor", store.language))
                .accessibilityIdentifier("pythonRunner.editor")
                .disabled(isRunning)

            HStack {
                Text(String(format: L10n.text("lab.pythonRunner.byteCount", store.language), code.utf8.count, 8_192))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(code.utf8.count > 8_192 ? Color.red : Color.secondary)
                Spacer()
                Button(action: runSelectedCase) {
                    Label(
                        L10n.text(isRunning ? "lab.pythonRunner.running" : "lab.pythonRunner.run", store.language),
                        systemImage: isRunning ? "hourglass" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || code.utf8.count > 8_192)
                .accessibilityIdentifier("pythonRunner.run")
            }

            if code.utf8.count > 8_192 {
                Text(L10n.text("lab.pythonRunner.codeLimit", store.language))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if isResultCurrent, let lastResponse, let lastPassed {
                VStack(alignment: .leading, spacing: 7) {
                    Label(
                        L10n.text(lastPassed ? "lab.pythonRunner.passed" : "lab.pythonRunner.failed", store.language),
                        systemImage: lastPassed ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(lastPassed ? Color.green : Color.orange)
                    .accessibilityIdentifier("pythonRunner.result")

                    Text("\(L10n.text("lab.pythonRunner.expected", store.language)): \(selectedCase.expectedMaximum.map(String.init) ?? "ValueError")")
                        .font(.system(.callout, design: .monospaced))

                    Text("\(L10n.text("lab.pythonRunner.output", store.language)): \(lastResponse.resultText ?? lastResponse.code ?? "—")")
                        .font(.system(.callout, design: .monospaced))
                    if !lastPassed, let errorCode = lastResponse.code {
                        Text(L10n.text(errorMessageKey(errorCode), store.language))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
            }

            if let connectionErrorKey {
                Label(L10n.text(connectionErrorKey, store.language), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pythonRunner.connectionError")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private func runSelectedCase() {
        guard !isRunning, code.utf8.count <= 8_192 else { return }
        isRunning = true
        connectionErrorKey = nil
        lastResponse = nil
        lastPassed = nil
        let submittedCode = code
        let submittedCase = selectedCase

        Task { @MainActor in
            defer { isRunning = false }
            do {
                let response = try await OrchestratorClient.runPythonPractice(
                    code: submittedCode,
                    values: submittedCase.values
                )
                let passed: Bool
                if let expectedMaximum = submittedCase.expectedMaximum {
                    passed = response.status == "ok" && response.resultText == String(expectedMaximum)
                } else {
                    passed = response.status == "error" && response.code == "ValueError"
                }
                if let evidence = assessmentTracker.recordSubmission(
                    selectedAnswerIndex: passed ? 1 : 0,
                    correctAnswerIndex: 1,
                    optionCount: 2,
                    itemID: submittedCase.evidenceID
                ) {
                    store.recordStudyAssessment(lessonID: "programming.computational_thinking", evidence: evidence)
                }
                lastRunCode = submittedCode
                lastRunCaseID = submittedCase.id
                lastResponse = response
                lastPassed = passed
            } catch {
                connectionErrorKey = "lab.pythonRunner.error.unavailable"
            }
        }
    }

    private func errorMessageKey(_ code: String) -> String {
        switch code {
        case "syntax_error": "lab.pythonRunner.error.syntax"
        case "unsupported_syntax": "lab.pythonRunner.error.unsupported"
        case "iteration_limit": "lab.pythonRunner.error.limit"
        case "code_too_large": "lab.pythonRunner.error.codeLimit"
        case "invalid_arguments": "lab.pythonRunner.error.invalidInput"
        case "invalid_result": "lab.pythonRunner.error.invalidResult"
        case "ValueError": "lab.pythonRunner.error.value"
        default: "lab.pythonRunner.error.runtime"
        }
    }
}

private struct FileReadingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var scenarioID = FileReadingPractice.scenarios[0].id
    @State private var selectedOutcome: FileReadingOutcome?
    @State private var hasCheckedAnswer = false
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(itemIDs: FileReadingPractice.scenarios.map(\.id))
    @State private var outcomeOrder = QuizAnswerOrder(
        optionCount: FileReadingOutcome.allCases.count,
        answerOriginalIndex: FileReadingPractice.scenarios[0].expectedOutcome.rawValue
    )

    private var scenario: FileReadingScenario {
        FileReadingPractice.scenario(id: scenarioID) ?? FileReadingPractice.scenarios[0]
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.fileTrace.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.fileTrace.scenario", store.language), selection: $scenarioID) {
                ForEach(FileReadingPractice.scenarios) { item in
                    Text(L10n.text("lab.fileTrace.scenario.\(item.id)", store.language)).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: scenarioID) { _ in
                selectedOutcome = nil
                hasCheckedAnswer = false
                outcomeOrder = QuizAnswerOrder(
                    optionCount: FileReadingOutcome.allCases.count,
                    answerOriginalIndex: scenario.expectedOutcome.rawValue
                )
            }

            Text("""
            with path.open("r", encoding="utf-8") as file:
                total = sum(int(line.strip()) for line in file if line.strip())
            """)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(Text(L10n.text("lab.fileTrace.code", store.language)))

            Text(L10n.text("lab.fileTrace.question", store.language))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(outcomeOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                let outcome = FileReadingPractice.outcomes[originalIndex]
                Button {
                    guard !hasCheckedAnswer else { return }
                    selectedOutcome = outcome
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedOutcome == outcome ? "largecircle.fill.circle" : "circle")
                        Text(L10n.text(outcome.localizationKey, store.language))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(
                        selectedOutcome == outcome ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
                .buttonStyle(.plain)
                .disabled(hasCheckedAnswer)
                .accessibilityAddTraits(selectedOutcome == outcome ? .isSelected : [])
            }

            if hasCheckedAnswer {
                let correct = selectedOutcome.map { FileReadingPractice.isCorrect($0, for: scenarioID) } ?? false
                Label(
                    L10n.text(correct ? "lab.fileTrace.correct" : "lab.fileTrace.incorrect", store.language),
                    systemImage: correct ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .foregroundStyle(correct ? Color.green : Color.orange)

                Label(
                    L10n.text(scenario.explanationKey, store.language),
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                if let selectedOutcome,
                   let evidence = assessmentTracker.recordSubmission(
                    selectedAnswerIndex: selectedOutcome.rawValue,
                    correctAnswerIndex: scenario.expectedOutcome.rawValue,
                    optionCount: FileReadingOutcome.allCases.count,
                    itemID: scenario.id
                   ) {
                    store.recordStudyAssessment(
                        lessonID: "programming.strings_files_and_exceptions",
                        evidence: evidence
                    )
                }
                hasCheckedAnswer = true
            } label: {
                Label(L10n.text("lab.fileTrace.check", store.language), systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedOutcome == nil || hasCheckedAnswer)
        }
    }
}

private struct TransactionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var scenario: TransactionScenario = .commitTransfer
    @State private var snapshot = TransactionPractice.initialSnapshot()

    var body: some View {
        LabCard {
            Text(L10n.text("lab.transaction.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.transaction.scenarioPicker", store.language), selection: $scenario) {
                ForEach(TransactionScenario.allCases) { item in
                    Text(L10n.text(item.titleKey, store.language)).tag(item)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: scenario) { _ in resetPractice() }

            Text("BEGIN;  UPDATE;  COMMIT / ROLLBACK")
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                balanceColumn(title: "lab.transaction.source", value: snapshot.sourceBalance, saved: snapshot.committedSourceBalance)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                balanceColumn(title: "lab.transaction.destination", value: snapshot.destinationBalance, saved: snapshot.committedDestinationBalance)
            }

            Label(L10n.text(snapshot.stage.titleKey, store.language), systemImage: snapshot.stage.isFinished ? "checkmark.circle.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.callout.weight(.medium))
                .foregroundStyle(snapshot.stage.isFinished ? Color.green : Color.accentColor)

            Text(L10n.text(snapshot.traceKey, store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("transaction-practice-feedback")

            Text(String(format: L10n.text("lab.transaction.savedTotal", store.language), snapshot.committedTotal))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    snapshot = TransactionPractice.advance(snapshot, scenario: scenario)
                } label: {
                    Label(
                        L10n.text(TransactionPractice.nextActionKey(for: snapshot, scenario: scenario) ?? "lab.transaction.done", store.language),
                        systemImage: snapshot.stage.isFinished ? "checkmark" : "arrow.right"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(snapshot.stage.isFinished)

                Button {
                    resetPractice()
                } label: {
                    Label(L10n.text("lab.transaction.reset", store.language), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func balanceColumn(title: String, value: Int, saved: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text(title, store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(value))
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
            Text(String(format: L10n.text("lab.transaction.persisted", store.language), saved))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func resetPractice() {
        snapshot = TransactionPractice.initialSnapshot()
    }
}

private struct SQLSchemaQueryLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var stepIndex = 0
    @State private var selectedDisplayIndex = -1
    @State private var feedbackCorrect: Bool?
    @State private var optionOrders = Self.makeOptionOrders()

    private var optionOrder: QuizAnswerOrder { optionOrders[stepIndex] }
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(
        itemIDs: SQLQueryPractice.steps.map(\.id)
    )

    private var currentStep: SQLQueryStep? {
        guard SQLQueryPractice.steps.indices.contains(stepIndex) else { return nil }
        return SQLQueryPractice.steps[stepIndex]
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.sql.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.sql.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("lab.sql.sampleTable", store.language))
                    .font(.caption.weight(.medium))
                Text(SQLQueryPractice.sampleSessions.map { "\($0.topic) | \($0.minutes)" }.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))

            if let step = currentStep {
                Text(String(format: L10n.text("lab.sql.progress", store.language), stepIndex + 1, SQLQueryPractice.steps.count))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(L10n.text(step.promptKey, store.language))
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Picker(L10n.text("lab.debugging.choicePicker", store.language), selection: $selectedDisplayIndex) {
                    ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                        Text(L10n.text(step.optionKeys[originalIndex], store.language))
                            .tag(displayIndex)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(feedbackCorrect == true)
                .onChange(of: selectedDisplayIndex) { _ in
                    if feedbackCorrect == false { feedbackCorrect = nil }
                }

                if let feedbackCorrect {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            L10n.text(feedbackCorrect ? "lab.sql.correct" : "lab.sql.incorrect", store.language),
                            systemImage: feedbackCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                        )
                        .font(.callout.weight(.medium))
                        .foregroundStyle(feedbackCorrect ? Color.green : Color.orange)
                        Text(L10n.text(step.explanationKey, store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.text(step.sqlKey, store.language))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        if step.id == "programming.sql_queries.filter_and_order" && feedbackCorrect {
                            Text(SQLQueryPractice.filteredSessions(minimumMinutes: 30).map { "\($0.topic) | \($0.minutes)" }.joined(separator: "\n"))
                                .font(.system(.caption, design: .monospaced))
                                .accessibilityIdentifier("sql-query-result")
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        check(step: step)
                    } label: {
                        Label(L10n.text("lab.sql.check", store.language), systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedDisplayIndex < 0 || feedbackCorrect == true)

                    if feedbackCorrect == true {
                        Button(action: advance) {
                            Label(L10n.text("lab.sql.next", store.language), systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Label(L10n.text("lab.sql.complete", store.language), systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                Button(action: restart) {
                    Label(L10n.text("lab.sql.restart", store.language), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            Text(L10n.text("lab.sql.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func check(step: SQLQueryStep) {
        guard let selectedOriginalIndex = optionOrder.originalIndex(forDisplayedIndex: selectedDisplayIndex) else { return }
        let isCorrect = SQLQueryPractice.isCorrect(selectedOriginalIndex, for: step.id)
        feedbackCorrect = isCorrect
        guard let evidence = assessmentTracker.recordSubmission(
            selectedAnswerIndex: selectedOriginalIndex,
            correctAnswerIndex: step.correctOptionIndex,
            optionCount: step.optionKeys.count,
            itemID: step.id
        ) else { return }
        store.recordStudyAssessment(lessonID: "programming.sql_transactions", evidence: evidence)
    }

    private func advance() {
        stepIndex += 1
        selectedDisplayIndex = -1
        feedbackCorrect = nil
        guard currentStep != nil else { return }
    }

    private func restart() {
        stepIndex = 0
        selectedDisplayIndex = -1
        feedbackCorrect = nil
        optionOrders = Self.makeOptionOrders()
        assessmentTracker.reset()
    }

    private static func makeOptionOrders() -> [QuizAnswerOrder] {
        QuizAnswerOrder.balancedSequence(
            optionCount: SQLQueryPractice.steps[0].optionKeys.count,
            answerOriginalIndices: SQLQueryPractice.steps.map(\.correctOptionIndex)
        )
    }
}

private struct DebuggingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var scenarioID = DebuggingPractice.scenarios[0].id
    @State private var selectedChoice = -1
    @State private var hasChecked = false
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(itemIDs: DebuggingPractice.scenarios.map(\.id))
    @State private var optionOrder = QuizAnswerOrder(
        optionCount: DebuggingPractice.scenarios[0].choiceKeys.count,
        answerOriginalIndex: DebuggingPractice.scenarios[0].correctChoice
    )

    private var scenario: DebuggingScenario {
        DebuggingPractice.scenario(id: scenarioID) ?? DebuggingPractice.scenarios[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabCard {
                Text(L10n.text("lab.debugging.hint", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker(L10n.text("lab.debugging.scenarioPicker", store.language), selection: $scenarioID) {
                    ForEach(DebuggingPractice.scenarios) { item in
                        Text(L10n.text(item.promptKey, store.language)).tag(item.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: scenarioID) { newScenarioID in
                    selectedChoice = -1
                    hasChecked = false
                    if let newScenario = DebuggingPractice.scenario(id: newScenarioID) {
                        optionOrder = QuizAnswerOrder(
                            optionCount: newScenario.choiceKeys.count,
                            answerOriginalIndex: newScenario.correctChoice
                        )
                    }
                }

                Text(scenario.code)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(Text(L10n.text("lab.debugging.code", store.language)))

                Label(scenario.traceback, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(L10n.text("lab.debugging.traceback", store.language)))

                Text(L10n.text("lab.debugging.choose", store.language))
                    .font(.callout.weight(.medium))

                Picker(L10n.text("lab.debugging.choicePicker", store.language), selection: $selectedChoice) {
                    ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                        Text(L10n.text(scenario.choiceKeys[originalIndex], store.language)).tag(displayIndex)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(hasChecked)

                if hasChecked {
                    Label(
                        L10n.text(scenario.explanationKey, store.language),
                        systemImage: optionOrder.isCorrect(displayedIndex: selectedChoice)
                            ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                    )
                    .font(.callout)
                    .foregroundStyle(optionOrder.isCorrect(displayedIndex: selectedChoice) ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    hasChecked = true
                    guard let selectedOriginalIndex = optionOrder.originalIndex(forDisplayedIndex: selectedChoice),
                          let evidence = assessmentTracker.recordSubmission(
                            selectedAnswerIndex: selectedOriginalIndex,
                            correctAnswerIndex: scenario.correctChoice,
                            optionCount: scenario.choiceKeys.count,
                            itemID: scenario.id
                          ) else {
                        return
                    }
                    store.recordStudyAssessment(
                        lessonID: "programming.debugging_tests_and_git",
                        evidence: evidence
                    )
                } label: {
                    Label(L10n.text("lab.debugging.check", store.language), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasChecked || selectedChoice < 0)
            }

            GitWorkflowLab()
        }
    }
}

private struct GitWorkflowLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var stepIndex = 0
    @State private var selectedDisplayIndex = -1
    @State private var feedbackCorrect: Bool?
    @State private var optionOrders = Self.makeOptionOrders()

    private var optionOrder: QuizAnswerOrder { optionOrders[stepIndex] }
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(
        itemIDs: GitWorkflowPractice.steps.map(\.id)
    )

    private var currentStep: GitWorkflowStep? {
        guard GitWorkflowPractice.steps.indices.contains(stepIndex) else { return nil }
        return GitWorkflowPractice.steps[stepIndex]
    }

    private var snapshotKey: String {
        switch GitWorkflowPractice.snapshotState(afterCompletedSteps: stepIndex) {
        case .unstaged:
            return "lab.git.snapshot.unstaged"
        case .staged:
            return "lab.git.snapshot.staged"
        case .committedWithUntrackedFile:
            return "lab.git.snapshot.committed"
        case .featureBranchWithChanges:
            return "lab.git.snapshot.featureBranch"
        case .featureBranchStaged:
            return "lab.git.snapshot.featureStaged"
        case .featureBranchCommitted:
            return "lab.git.snapshot.featureCommitted"
        case .featureBranchPublished:
            return "lab.git.snapshot.featurePublished"
        case .pullRequestOpen:
            return "lab.git.snapshot.pullRequest"
        }
    }

    private var snapshotInfoKey: String {
        switch GitWorkflowPractice.snapshotState(afterCompletedSteps: stepIndex) {
        case .unstaged:
            return "lab.git.snapshotInfo.unstaged"
        case .staged:
            return "lab.git.snapshotInfo.staged"
        case .committedWithUntrackedFile:
            return "lab.git.snapshotInfo.committed"
        case .featureBranchWithChanges:
            return "lab.git.snapshotInfo.featureBranch"
        case .featureBranchStaged:
            return "lab.git.snapshotInfo.featureStaged"
        case .featureBranchCommitted:
            return "lab.git.snapshotInfo.featureCommitted"
        case .featureBranchPublished:
            return "lab.git.snapshotInfo.featurePublished"
        case .pullRequestOpen:
            return "lab.git.snapshotInfo.pullRequest"
        }
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.git.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.git.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("lab.git.files", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("lab.git.snapshotLabel", store.language))
                    .font(.caption.weight(.medium))
                Text(L10n.text(snapshotKey, store.language))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                Text(L10n.text(snapshotInfoKey, store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))

            if let step = currentStep {
                Text(String(format: L10n.text("lab.git.progress", store.language), stepIndex + 1, GitWorkflowPractice.steps.count))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(L10n.text(step.promptKey, store.language))
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Picker(L10n.text("lab.debugging.choicePicker", store.language), selection: $selectedDisplayIndex) {
                    ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                        Text(L10n.text(step.commandKeys[originalIndex], store.language))
                            .font(.system(.callout, design: .monospaced))
                            .tag(displayIndex)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(feedbackCorrect == true)
                .onChange(of: selectedDisplayIndex) { _ in
                    if feedbackCorrect == false {
                        feedbackCorrect = nil
                    }
                }

                if let feedbackCorrect {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            L10n.text(feedbackCorrect ? "lab.git.correct" : "lab.git.incorrect", store.language),
                            systemImage: feedbackCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                        )
                        .font(.callout.weight(.medium))
                        .foregroundStyle(feedbackCorrect ? Color.green : Color.orange)
                        Text(L10n.text(step.explanationKey, store.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        check(step: step)
                    } label: {
                        Label(L10n.text("lab.git.check", store.language), systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedDisplayIndex < 0 || feedbackCorrect == true)

                    if feedbackCorrect == true {
                        Button {
                            advance()
                        } label: {
                            Label(L10n.text("lab.git.next", store.language), systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Label(L10n.text("lab.git.complete", store.language), systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                Button {
                    restart()
                } label: {
                    Label(L10n.text("lab.git.restart", store.language), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            Text(L10n.text("lab.git.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func check(step: GitWorkflowStep) {
        guard let selectedOriginalIndex = optionOrder.originalIndex(forDisplayedIndex: selectedDisplayIndex) else { return }
        let isCorrect = GitWorkflowPractice.isCorrect(selectedOriginalIndex, for: step.id)
        feedbackCorrect = isCorrect
        guard let evidence = assessmentTracker.recordSubmission(
            selectedAnswerIndex: selectedOriginalIndex,
            correctAnswerIndex: step.correctCommandIndex,
            optionCount: step.commandKeys.count,
            itemID: step.id
        ) else {
            return
        }
        store.recordStudyAssessment(lessonID: "programming.debugging_tests_and_git", evidence: evidence)
    }

    private func advance() {
        stepIndex += 1
        selectedDisplayIndex = -1
        feedbackCorrect = nil
        guard currentStep != nil else { return }
    }

    private func restart() {
        stepIndex = 0
        selectedDisplayIndex = -1
        feedbackCorrect = nil
        optionOrders = Self.makeOptionOrders()
        assessmentTracker.reset()
    }

    private static func makeOptionOrders() -> [QuizAnswerOrder] {
        QuizAnswerOrder.balancedSequence(
            optionCount: GitWorkflowPractice.steps[0].commandKeys.count,
            answerOriginalIndices: GitWorkflowPractice.steps.map(\.correctCommandIndex)
        )
    }
}

private struct LinearSystemLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var scenarioID = LinearSystemPractice.scenarios[0].id
    @State private var selectedDisplayIndex = -1
    @State private var prediction: InteractivePredictionAttempt
    private let predictionOptionKeys = ["lab.linearSystemOne", "lab.linearSystemNone", "lab.linearSystemInfinite"]

    init() {
        _prediction = State(initialValue: Self.makePrediction(for: LinearSystemPractice.scenarios[0]))
    }

    private var scenario: LinearSystemScenario {
        LinearSystemPractice.scenario(id: scenarioID)
    }

    private var equationOne: String {
        equation(scenario.first.x, scenario.first.y, scenario.first.result)
    }

    private var equationTwo: String {
        equation(scenario.second.x, scenario.second.y, scenario.second.result)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.linearSystemHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.linearSystemScenario", store.language), selection: $scenarioID) {
                Text(L10n.text("lab.linearSystemUnique", store.language)).tag("unique")
                Text(L10n.text("lab.linearSystemParallel", store.language)).tag("parallel")
                Text(L10n.text("lab.linearSystemSameLine", store.language)).tag("same-line")
            }
            .pickerStyle(.segmented)
            .disabled(prediction.hasAnswered)
            .onChange(of: scenarioID) { newScenarioID in
                selectedDisplayIndex = -1
                prediction = Self.makePrediction(for: LinearSystemPractice.scenario(id: newScenarioID))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(equationOne).font(.title3.monospaced())
                Text(equationTwo).font(.title3.monospaced())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Label(L10n.text("lab.linearSystemEliminate", store.language), systemImage: "arrow.down.to.line")
                .font(.callout.weight(.medium))
            Text(String(format: L10n.text("lab.linearSystemReduction", store.language), scenario.eliminationResult.x, scenario.eliminationResult.result))
                .font(.title3.monospaced())
                .accessibilityLabel(L10n.text("lab.linearSystemReduction", store.language))

            Picker(L10n.text("lab.linearSystemPredict", store.language), selection: $selectedDisplayIndex) {
                ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                    Text(L10n.text(predictionOptionKeys[originalIndex], store.language)).tag(displayIndex)
                }
            }
            .pickerStyle(.segmented)
            .disabled(prediction.hasAnswered)

            Button(L10n.text("lab.linearSystemCheck", store.language)) {
                prediction.select(displayedIndex: selectedDisplayIndex)
                guard let evidence = prediction.currentAnswerEventEvidence() else { return }
                store.recordStudyAssessment(lessonID: "mathematics.systems_of_linear_equations", evidence: evidence)
            }
            .buttonStyle(.borderedProminent)
            .disabled(prediction.hasAnswered || selectedDisplayIndex < 0)

            if prediction.hasAnswered {
                if prediction.isCorrect {
                    Label(L10n.text("lab.linearSystemCorrect", store.language), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                    Text(outcomeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("lab.linearSystemNew", store.language)) {
                        prediction = Self.makePrediction(for: scenario)
                        selectedDisplayIndex = -1
                    }
                    .buttonStyle(.link)
                } else {
                    Label(L10n.text("lab.linearSystemReview", store.language), systemImage: "arrow.uturn.backward.circle")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("lab.linearSystemRetry", store.language)) {
                        prediction.retry()
                        selectedDisplayIndex = -1
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private static func makePrediction(for scenario: LinearSystemScenario) -> InteractivePredictionAttempt {
        guard let attempt = InteractivePredictionAttempt(
            optionCount: 3,
            answerOriginalIndex: LinearSystemPractice.correctPredictionIndex(for: scenario),
            itemID: scenario.itemID
        ) else {
            preconditionFailure("A linear-system prediction must have one valid answer.")
        }
        return attempt
    }

    private var outcomeDescription: String {
        switch LinearSystemPractice.classify(scenario) {
        case let .oneSolution(x, y):
            return String(format: L10n.text("lab.linearSystemOutcomeOne", store.language), x, y)
        case .noSolution:
            return L10n.text("lab.linearSystemOutcomeNone", store.language)
        case .infinitelyManySolutions:
            return L10n.text("lab.linearSystemOutcomeInfinite", store.language)
        }
    }

    private func equation(_ x: Int, _ y: Int, _ result: Int) -> String {
        let xTerm = x == 1 ? "x" : (x == -1 ? "−x" : "\(x)x")
        let yMagnitude = abs(y) == 1 ? "y" : "\(abs(y))y"
        let yTerm = y >= 0 ? " + \(yMagnitude)" : " − \(yMagnitude)"
        return "\(xTerm)\(yTerm) = \(result)"
    }
}

private struct AlgorithmComplexityLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var sizeIndex = 2.0

    private var itemCount: Int {
        AlgorithmComplexityPractice.sampleSizes[Int(sizeIndex.rounded())]
    }

    private var linearCount: Int {
        AlgorithmComplexityPractice.linearSearchWorstCaseComparisons(for: itemCount)
    }

    private var binaryCount: Int {
        AlgorithmComplexityPractice.binarySearchWorstCaseComparisons(for: itemCount)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.complexityHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                Text(String(format: L10n.text("lab.complexitySize", store.language), itemCount))
                    .font(.headline.monospacedDigit())
                Slider(value: $sizeIndex, in: 0...3, step: 1)
                    .accessibilityLabel(L10n.text("lab.complexitySize", store.language))
                    .accessibilityValue(String(itemCount))
            }

            complexityBar(
                title: L10n.text("lab.complexityLinear", store.language),
                comparisons: linearCount,
                maximum: linearCount,
                tint: .blue
            )
            complexityBar(
                title: L10n.text("lab.complexityBinary", store.language),
                comparisons: binaryCount,
                maximum: linearCount,
                tint: .purple
            )

            Label(L10n.text("lab.complexityPrecondition", store.language), systemImage: "checkmark.seal")
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("lab.complexityLimit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func complexityBar(title: String, comparisons: Int, maximum: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .frame(width: 132, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(8, geometry.size.width * CGFloat(comparisons) / CGFloat(maximum)))
                }
            }
            .frame(height: 14)
            Text(String(format: L10n.text("lab.complexityComparisons", store.language), comparisons))
                .font(.caption.monospacedDigit())
                .frame(width: 82, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HeldOutEvaluationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var neighbourIndex = 0

    private typealias Model = HeldOutEvaluationPractice

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var neighbours: Int { Model.neighbourCounts[neighbourIndex] }

    var body: some View {
        let training = Model.accuracy(of: Model.trainingExamples, neighbours: neighbours)
        let heldOut = Model.accuracy(of: Model.heldOutExamples, neighbours: neighbours)
        let baseline = Model.baselineAccuracy(on: Model.heldOutExamples)
        let status: (LabStatusKind, String) = Model.showsOverfitting(neighbours: neighbours) ? (.bad, text("lab.holdout.overfit"))
            : Model.matchesBaseline(neighbours: neighbours) ? (.warning, text("lab.holdout.atBaseline")) : (.good, text("lab.holdout.generalizes"))
        LabCard {
            LabHeader(title: text("lab.holdout.title"), instruction: text("lab.holdout.subtitle"))
            timeline
                .frame(height: 170)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.holdout.chart"))
            Picker(text("lab.holdout.neighboursLabel"), selection: $neighbourIndex.animation()) {
                ForEach(Model.neighbourCounts.indices, id: \.self) { index in Text(verbatim: "k = \(Model.neighbourCounts[index])").tag(index) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.holdout.neighbours")
            VStack(alignment: .leading, spacing: 8) {
                bar(text("lab.holdout.training"), training, .blue)
                bar(text("lab.holdout.heldOut"), heldOut, .orange)
                bar(text("lab.holdout.baseline"), baseline, .secondary)
            }
            LabStatusBadge(kind: status.0, text: status.1, identifier: "lab.holdout.verdict")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.holdout.challenge"),
                         solved: neighbours == Model.bestHeldOutNeighbourCount, solvedText: text("lab.holdout.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.holdout.hint"), text("lab.holdout.limit")])
        }
    }

    private func bar(_ title: String, _ accuracy: HeldOutAccuracy, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.callout).frame(width: 200, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color.gradient).frame(width: max(6, proxy.size.width * CGFloat(accuracy.percent) / 100))
                }
            }
            .frame(height: 16)
            Text(String(format: text("lab.holdout.score"), accuracy.correct, accuracy.total, accuracy.percent)).font(.callout.monospacedDigit()).frame(width: 130, alignment: .trailing)
        }
        .animation(.easeInOut(duration: 0.25), value: accuracy.percent)
    }

    // Minutes of practice on a line: training examples above (green passed, red failed), held-out examples below
    // filled with the true answer and ringed with the model's prediction; wrong predictions get a cross.
    private var timeline: some View {
        Canvas { context, size in
            let left: CGFloat = 20, right = size.width - 20
            func x(_ minutes: Int) -> CGFloat { left + (right - left) * CGFloat(minutes) / 75 }
            let trainY = size.height * 0.28, testY = size.height * 0.68
            for (y, key) in [(trainY, "lab.holdout.training"), (testY, "lab.holdout.heldOut")] {
                var line = Path()
                line.move(to: CGPoint(x: left, y: y))
                line.addLine(to: CGPoint(x: right, y: y))
                context.stroke(line, with: .color(.secondary.opacity(0.4)), lineWidth: 1)
                context.draw(Text(text(key)).font(.caption2.weight(.semibold)).foregroundColor(.secondary), at: CGPoint(x: left, y: y - 22), anchor: .leading)
            }
            for example in Model.trainingExamples {
                context.fill(Path(ellipseIn: CGRect(x: x(example.minutes) - 7, y: trainY - 7, width: 14, height: 14)), with: .color(example.passed ? .green : .red))
            }
            for example in Model.heldOutExamples {
                let predicted = Model.predictsPass(minutes: example.minutes, neighbours: neighbours)
                let center = CGPoint(x: x(example.minutes), y: testY)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)), with: .color(example.passed ? .green : .red))
                context.stroke(Path(ellipseIn: CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22)), with: .color(predicted ? .green : .red), lineWidth: 2.5)
                if predicted != example.passed {
                    context.draw(Text(verbatim: "✗").font(.headline).foregroundColor(.red), at: CGPoint(x: center.x, y: center.y + 22))
                }
            }
            for minutes in stride(from: 0, through: 75, by: 15) {
                context.draw(Text(verbatim: "\(minutes)").font(.caption2).foregroundColor(.secondary), at: CGPoint(x: x(minutes), y: size.height - 8))
            }
        }
    }
}

private struct NeuronSignalLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var depolarization = 10.0
    @State private var progress = 1.0
    @State private var playing = false

    private typealias Model = NeuronSignalModel

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func millivolts(_ value: Double) -> String { L10n.measurement(value, fractionDigits: 0, unit: "mV", store.language) }

    var body: some View {
        let fires = Model.firesActionPotential(afterDepolarization: depolarization)
        LabCard {
            LabHeader(title: text("lab.neuron.title"), instruction: text("lab.neuron.subtitle"))
            trace(fires: fires)
                .frame(height: 260)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text(fires ? "lab.neuron.traceFires" : "lab.neuron.traceNoFire"))

            HStack(spacing: 12) {
                Button {
                    progress = 0
                    playing = true
                } label: { Label(text("lab.neuron.play"), systemImage: "bolt.fill") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.neuron.play")
                Text(String(format: text("lab.neuron.stimulus"), Int(depolarization.rounded()), millivolts(Model.membranePotential(afterDepolarization: depolarization))))
                    .monospacedDigit()
                    .frame(minWidth: 260, alignment: .leading)
                // Whole millivolts without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { depolarization }, set: { depolarization = $0.rounded() }), in: Model.stimulusRange)
                    .accessibilityLabel(text("lab.neuron.stimulusLabel"))
            }
            LabStatGrid {
                LabStat(label: text("lab.neuron.statMembrane"), value: millivolts(Model.membranePotential(afterDepolarization: depolarization)), tint: .accentColor)
                LabStat(label: text("lab.neuron.statPeak"), value: millivolts(Model.highestPotential(afterDepolarization: depolarization)), tint: fires ? .yellow : .secondary)
            }
            LabStatusBadge(kind: fires ? .good : .info, text: text(fires ? "lab.neuron.fires" : "lab.neuron.noFire"), identifier: "lab.neuron.outcome")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.neuron.challenge"),
                         solved: fires && !Model.firesActionPotential(afterDepolarization: depolarization - 1), solvedText: text("lab.neuron.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.neuron.hint"), text("lab.neuron.limit")])
        }
        .task(id: playing) {
            guard playing else { return }
            while progress < 1 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000)
                progress = min(progress + 0.02, 1)
            }
            playing = false
        }
    }

    // The membrane potential over time with the resting and threshold levels; Play draws it from left to right.
    private func trace(fires: Bool) -> some View {
        Canvas { context, size in
            let points = Model.trace(afterDepolarization: depolarization)
            let maxTime = points.last?.milliseconds ?? 5
            let plot = LabPlotGeometry(size: size, x: 0...maxTime, y: -90...50)
            plot.drawAxes(in: context, xLabel: text("lab.neuron.axisTime"), yLabel: text("lab.neuron.axisVoltage"), format: { L10n.number($0, fractionDigits: 0, store.language) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -4, dy: -4)))
            for (value, key, color) in [(Model.thresholdPotential, "lab.neuron.thresholdLine", Color.orange), (Model.restingPotential, "lab.neuron.restLine", Color.secondary)] {
                var line = Path()
                line.move(to: plot.point(0, value))
                line.addLine(to: plot.point(maxTime, value))
                clipped.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                clipped.draw(Text(text(key)).font(.caption2.weight(.semibold)).foregroundColor(color), at: plot.point(maxTime, value + 3), anchor: .bottomTrailing)
            }
            let visible = maxTime * progress
            var line = Path()
            var started = false
            for point in points where point.milliseconds <= visible {
                let location = plot.point(point.milliseconds, point.millivolts)
                if started { line.addLine(to: location) } else { line.move(to: location); started = true }
            }
            clipped.stroke(line, with: .color(fires ? .yellow : .accentColor), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
    }
}

private struct MembraneTraceView: View {
    let points: [MembraneTracePoint]
    let thresholdLabel: String
    let restLabel: String

    private let voltageRange = -90.0...50.0
    private let timeRange = 0.0...8.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
                horizontalLine(at: NeuronSignalModel.restingPotential, in: geometry.size)
                    .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1))
                horizontalLine(at: NeuronSignalModel.thresholdPotential, in: geometry.size)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                tracePath(in: geometry.size)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                Text(thresholdLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .position(x: geometry.size.width - 60, y: y(for: NeuronSignalModel.thresholdPotential, height: geometry.size.height) - 9)
                Text(restLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .position(x: geometry.size.width - 60, y: y(for: NeuronSignalModel.restingPotential, height: geometry.size.height) + 9)
            }
        }
    }

    private func x(for milliseconds: Double, width: CGFloat) -> CGFloat {
        CGFloat((milliseconds - timeRange.lowerBound) / (timeRange.upperBound - timeRange.lowerBound)) * width
    }

    private func y(for millivolts: Double, height: CGFloat) -> CGFloat {
        let fraction = (millivolts - voltageRange.lowerBound) / (voltageRange.upperBound - voltageRange.lowerBound)
        return height - CGFloat(fraction) * height
    }

    private func horizontalLine(at millivolts: Double, in size: CGSize) -> Path {
        Path { path in
            let lineY = y(for: millivolts, height: size.height)
            path.move(to: CGPoint(x: 0, y: lineY))
            path.addLine(to: CGPoint(x: size.width, y: lineY))
        }
    }

    private func tracePath(in size: CGSize) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: x(for: first.milliseconds, width: size.width), y: y(for: first.millivolts, height: size.height)))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: x(for: point.milliseconds, width: size.width), y: y(for: point.millivolts, height: size.height)))
            }
        }
    }
}

private struct VectorKinematicsLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var magnitude = 10.0
    @State private var angleDegrees = 30.0
    @State private var showsComponents = false

    private var vector: VectorKinematics {
        VectorKinematics(magnitude: magnitude, angleDegrees: angleDegrees)
    }

    private var vectorAccessibilityValue: String {
        let language = store.language
        var value = "r " + L10n.measurement(vector.magnitude, fractionDigits: 0, unit: "m", language)
            + ", θ " + L10n.measurement(vector.angleDegrees, fractionDigits: 0, unit: "°", language)
        if showsComponents {
            value += ", Δx " + L10n.measurement(vector.xComponent, fractionDigits: 2, unit: "m", language)
                + ", Δy " + L10n.measurement(vector.yComponent, fractionDigits: 2, unit: "m", language)
        }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("lab.vector.title", store.language))
                .font(.title3.weight(.semibold))
            Text(L10n.text("lab.vector.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 24) {
                vectorDiagram
                    .frame(minWidth: 260, idealWidth: 340, maxWidth: 420, minHeight: 240)
                VStack(alignment: .leading, spacing: 14) {
                    vectorSlider(
                        title: L10n.text("lab.vector.magnitude", store.language),
                        value: $magnitude,
                        range: 1...20,
                        step: 1,
                        unit: "m"
                    )
                    vectorSlider(
                        title: L10n.text("lab.vector.angle", store.language),
                        value: $angleDegrees,
                        range: 0...359,
                        step: 1,
                        unit: "°"
                    )
                    Toggle(isOn: $showsComponents) {
                        Text(L10n.text("lab.vector.showComponents", store.language))
                    }
                    .toggleStyle(.switch)
                    .accessibilityLabel(Text(L10n.text("lab.vector.showComponents", store.language)))
                    .help(L10n.text("lab.vector.revealHelp", store.language))

                    VStack(alignment: .leading, spacing: 6) {
                        if showsComponents {
                            vectorReading("lab.vector.xComponent", value: vector.xComponent)
                            vectorReading("lab.vector.yComponent", value: vector.yComponent)
                            vectorReading("lab.vector.magnitudeResult", value: vector.reconstructedMagnitude)
                        } else {
                            Text(L10n.text("lab.vector.predictFirst", store.language))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: 280)
            }

            Text(L10n.text("lab.vector.challenge", store.language))
                .font(.callout)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            Text(L10n.text("lab.vector.limits", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var vectorDiagram: some View {
        Canvas { context, size in
            let inset: CGFloat = 28
            let origin = CGPoint(x: size.width / 2, y: size.height / 2)
            let scale = min((size.width - inset * 2) / 40, (size.height - inset * 2) / 40)
            let tip = CGPoint(
                x: origin.x + vector.xComponent * scale,
                y: origin.y - vector.yComponent * scale
            )
            var axes = Path()
            axes.move(to: CGPoint(x: inset, y: origin.y))
            axes.addLine(to: CGPoint(x: size.width - inset, y: origin.y))
            axes.move(to: CGPoint(x: origin.x, y: size.height - inset))
            axes.addLine(to: CGPoint(x: origin.x, y: inset))
            context.stroke(axes, with: .color(.secondary.opacity(0.6)), lineWidth: 1)

            if showsComponents {
                var projections = Path()
                projections.move(to: origin)
                projections.addLine(to: CGPoint(x: tip.x, y: origin.y))
                projections.addLine(to: tip)
                context.stroke(projections, with: .color(.orange.opacity(0.8)), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }

            var arrow = Path()
            arrow.move(to: origin)
            arrow.addLine(to: tip)
            context.stroke(arrow, with: .color(.accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            let direction = CGVector(dx: tip.x - origin.x, dy: tip.y - origin.y)
            let length = max(hypot(direction.dx, direction.dy), 1)
            let unit = CGVector(dx: direction.dx / length, dy: direction.dy / length)
            let perpendicular = CGVector(dx: -unit.dy, dy: unit.dx)
            var head = Path()
            head.move(to: tip)
            head.addLine(to: CGPoint(x: tip.x - unit.dx * 12 + perpendicular.dx * 6, y: tip.y - unit.dy * 12 + perpendicular.dy * 6))
            head.move(to: tip)
            head.addLine(to: CGPoint(x: tip.x - unit.dx * 12 - perpendicular.dx * 6, y: tip.y - unit.dy * 12 - perpendicular.dy * 6))
            context.stroke(head, with: .color(.accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: origin.x - 3, y: origin.y - 3, width: 6, height: 6)), with: .color(.primary))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.text("lab.vector.diagram", store.language)))
        .accessibilityValue(Text(verbatim: vectorAccessibilityValue))
    }

    private func vectorSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: L10n.measurement(value.wrappedValue, fractionDigits: 0, unit: unit, store.language)).monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(Text(title))
        }
    }

    private func vectorReading(_ key: String, value: Double) -> some View {
        HStack {
            Text(L10n.text(key, store.language)).foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: L10n.measurement(value, fractionDigits: 2, unit: "m", store.language)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ThermalStrategyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var selectedAnimal: ThermalAnimalMode = .ectotherm
    @State private var selectedEnvironment: ThermalEnvironment = .cool
    @State private var selectedResponse: ThermoregulatoryResponse?
    @State private var didCheck = false

    var body: some View {
        LabCard {
            Text(L10n.text("lab.zoology.thermal.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("lab.zoology.thermal.modeTitle", store.language))
                    .font(.headline)
                Picker(L10n.text("lab.zoology.thermal.modeTitle", store.language), selection: $selectedAnimal) {
                    ForEach(ThermalAnimalMode.allCases) { animal in
                        Text(L10n.text(animal.titleKey, store.language)).tag(animal)
                    }
                }
                .pickerStyle(.segmented)
                Text(L10n.text(selectedAnimal.heatSourceKey, store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("lab.zoology.thermal.environmentTitle", store.language))
                    .font(.headline)
                Picker(L10n.text("lab.zoology.thermal.environmentTitle", store.language), selection: $selectedEnvironment) {
                    ForEach(ThermalEnvironment.allCases) { environment in
                        Text(L10n.text(environment.titleKey, store.language)).tag(environment)
                    }
                }
                .pickerStyle(.segmented)
            }

            Label(
                L10n.text(selectedAnimal == .ectotherm ? "lab.zoology.thermal.icon.ectotherm" : "lab.zoology.thermal.icon.endotherm", store.language),
                systemImage: selectedAnimal == .ectotherm ? "sun.max" : "thermometer.medium"
            )
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            Text(L10n.text("lab.zoology.thermal.responseTitle", store.language))
                .font(.headline)
            Picker(L10n.text("lab.zoology.thermal.responseTitle", store.language), selection: $selectedResponse) {
                Text(L10n.text("lab.zoology.thermal.chooseResponse", store.language)).tag(nil as ThermoregulatoryResponse?)
                ForEach(ThermoregulatoryResponse.allCases) { response in
                    Text(L10n.text(response.titleKey, store.language)).tag(response as ThermoregulatoryResponse?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedResponse) { _ in didCheck = false }

            Button(L10n.text("lab.zoology.thermal.check", store.language)) {
                didCheck = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedResponse == nil)

            if didCheck, let selectedResponse {
                let correct = ThermoregulationModel.isCorrect(
                    selectedAnimal,
                    environment: selectedEnvironment,
                    response: selectedResponse
                )
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        L10n.text(correct ? "lab.zoology.thermal.correct" : "lab.zoology.thermal.review", store.language),
                        systemImage: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(correct ? .green : .orange)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text(ThermoregulationModel.recommendedResponse(for: selectedAnimal, in: selectedEnvironment).explanationKey, store.language))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            Text(L10n.text("lab.zoology.thermal.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: selectedAnimal) { _ in resetPrediction() }
        .onChange(of: selectedEnvironment) { _ in resetPrediction() }
    }

    private func resetPrediction() {
        selectedResponse = nil
        didCheck = false
    }
}

private struct CirculationRouteLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var animal: CirculationAnimal = .fish
    @State private var predictedPasses: Int?
    @State private var didCheck = false

    var body: some View {
        LabCard {
            Text(L10n.text("lab.circulation.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.circulation.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.circulation.animalTitle", store.language), selection: $animal) {
                ForEach(CirculationAnimal.allCases) { option in
                    Text(L10n.text(option.titleKey, store.language)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.circulation.animal")

            VStack(alignment: .leading, spacing: 6) {
                Label(L10n.text(animal.routeKey, store.language), systemImage: "arrow.triangle.2.circlepath")
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text(animal.heartKey, store.language))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text(animal.exchangeKey, store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            Text(L10n.text("lab.circulation.predict", store.language))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Picker(L10n.text("lab.circulation.predict", store.language), selection: $predictedPasses) {
                Text(L10n.text("lab.circulation.choose", store.language)).tag(nil as Int?)
                ForEach(CirculationRouteModel.passOptions, id: \.self) { passes in
                    Text("\(passes)").tag(passes as Int?)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: predictedPasses) { _ in didCheck = false }

            Button(L10n.text("lab.circulation.check", store.language)) {
                didCheck = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(predictedPasses == nil)

            if didCheck, let predictedPasses {
                let correct = CirculationRouteModel.isCorrect(passes: predictedPasses, for: animal)
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        L10n.text(correct ? "lab.circulation.correct" : "lab.circulation.review", store.language),
                        systemImage: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(correct ? .green : .orange)
                    if correct {
                        Text(L10n.text(animal.explanationKey, store.language))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("lab.circulation.feedback")
            }

            Text(L10n.text("lab.circulation.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: animal) { _ in
            predictedPasses = nil
            didCheck = false
        }
    }
}

private struct GradientDescentLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var learningRateIndex = 1
    @State private var steps = 5.0
    @State private var playing = false

    private typealias Model = GradientDescentPractice

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var rate: Double { Model.learningRates[learningRateIndex] }

    var body: some View {
        let path = Model.trajectory(learningRate: rate, steps: Int(steps.rounded()))
        let last = path.last ?? GradientDescentStep(step: 0, weight: Model.initialWeight, loss: Model.loss(weight: Model.initialWeight))
        let status: (LabStatusKind, String) = !Model.converges(learningRate: rate) ? (.bad, text("lab.gd.diverges"))
            : Model.oscillates(learningRate: rate) ? (.warning, text("lab.gd.oscillates")) : (.good, text("lab.gd.converges"))
        LabCard {
            LabHeader(title: text("lab.gd.title"), instruction: text("lab.gd.subtitle"))
            HStack(spacing: 16) {
                dataPlot(weight: last.weight)
                lossPlot(path: path)
            }
            .frame(height: 260)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.gd.chart"))
            .accessibilityValue(Text(verbatim: number(last.loss, 3)))

            Picker(text("lab.gd.rate"), selection: $learningRateIndex) {
                ForEach(Model.learningRates.indices, id: \.self) { index in Text(verbatim: "η = " + number(Model.learningRates[index], 2)).tag(index) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.gd.rate")
            HStack(spacing: 12) {
                Button {
                    if Int(steps.rounded()) >= Model.maximumSteps { steps = 0 }
                    playing.toggle()
                } label: { Label(text(playing ? "lab.descent2d.pause" : "lab.descent2d.play"), systemImage: playing ? "pause.fill" : "play.fill") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.gd.play")
                Text(String(format: text("lab.gd.steps"), Int(steps.rounded()))).monospacedDigit().frame(minWidth: 130, alignment: .leading)
                // Whole iterations without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { steps }, set: { steps = $0.rounded() }), in: 0...Double(Model.maximumSteps))
                    .accessibilityLabel(text("lab.gd.stepsLabel"))
            }
            LabStatGrid {
                LabStat(label: "w", value: number(last.weight, 3), tint: .accentColor)
                LabStat(label: text("lab.gd.statLoss"), value: number(last.loss, 3), tint: .orange)
                LabStat(label: text("lab.gd.statFactor"), value: number(1 - 15 * rate, 2), tint: .purple)
            }
            Text(String(format: text("lab.gd.state"), number(last.weight, 3), number(last.loss, 3)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.gd.state")
            LabStatusBadge(kind: status.0, text: status.1)
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.gd.challenge"),
                         solved: Model.converges(learningRate: rate) && Model.oscillates(learningRate: rate), solvedText: text("lab.gd.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.gd.hint"), text("lab.gd.optimum"), text("lab.gd.limit")])
        }
        .task(id: playing) {
            guard playing else { return }
            while playing && !Task.isCancelled && Int(steps.rounded()) < Model.maximumSteps {
                try? await Task.sleep(nanoseconds: 380_000_000)
                withAnimation(.easeInOut(duration: 0.3)) { steps += 1 }
            }
            playing = false
        }
    }

    // The four data points with the current line y = w·x and the best line dashed.
    private func dataPlot(weight: Double) -> some View {
        Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...4.5, y: 0...10)
            plot.drawAxes(in: context, xLabel: "x", yLabel: "y", format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect))
            var best = Path()
            best.move(to: plot.point(0, 0))
            best.addLine(to: plot.point(4.5, 4.5 * Model.optimalWeight))
            clipped.stroke(best, with: .color(.green), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            var line = Path()
            line.move(to: plot.point(0, 0))
            line.addLine(to: plot.point(4.5, 4.5 * weight))
            clipped.stroke(line, with: .color(.accentColor), lineWidth: 3)
            for (x, y) in zip(Model.inputs, Model.targets) {
                let measured = plot.point(x, y), predicted = plot.point(x, weight * x)
                var residual = Path()
                residual.move(to: measured)
                residual.addLine(to: predicted)
                clipped.stroke(residual, with: .color(.orange.opacity(0.7)), lineWidth: 1.5)
                clipped.fill(Path(ellipseIn: CGRect(x: measured.x - 6, y: measured.y - 6, width: 12, height: 12)), with: .color(.orange))
            }
            context.draw(Text(verbatim: "y = " + number(weight, 2) + "·x").font(.caption.weight(.bold)).foregroundColor(.accentColor),
                         at: CGPoint(x: plot.rect.minX + 8, y: plot.rect.minY + 14), anchor: .leading)
        }
    }

    // The error parabola L(w) with each iteration as a dot hopping toward (or away from) the minimum.
    private func lossPlot(path: [GradientDescentStep]) -> some View {
        Canvas { context, size in
            let maxLoss = max(Model.loss(weight: Model.initialWeight), path.map(\.loss).max() ?? 0) * 1.05
            let plot = LabPlotGeometry(size: size, x: -0.5...4.5, y: 0...maxLoss)
            plot.drawAxes(in: context, xLabel: "w", yLabel: text("lab.gd.axisLoss"), format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -8, dy: -8)))
            var curve = Path()
            for index in 0...200 {
                let w = -0.5 + 5 * Double(index) / 200
                let location = plot.point(w, min(Model.loss(weight: w), maxLoss * 1.2))
                if index == 0 { curve.move(to: location) } else { curve.addLine(to: location) }
            }
            clipped.stroke(curve, with: .color(.secondary), lineWidth: 2)
            var hops = Path()
            for (index, step) in path.enumerated() {
                let location = plot.point(min(max(step.weight, -0.5), 4.5), min(step.loss, maxLoss))
                if index == 0 { hops.move(to: location) } else { hops.addLine(to: location) }
            }
            clipped.stroke(hops, with: .color(.orange), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            for (index, step) in path.enumerated() {
                let location = plot.point(min(max(step.weight, -0.5), 4.5), min(step.loss, maxLoss))
                let radius: CGFloat = index == path.count - 1 ? 7 : 4
                clipped.fill(Path(ellipseIn: CGRect(x: location.x - radius, y: location.y - radius, width: 2 * radius, height: 2 * radius)),
                             with: .color(index == path.count - 1 ? .accentColor : .orange))
            }
            let minimum = plot.point(Model.optimalWeight, Model.loss(weight: Model.optimalWeight))
            clipped.fill(Path(ellipseIn: CGRect(x: minimum.x - 5, y: minimum.y - 5, width: 10, height: 10)), with: .color(.green))
        }
    }
}

private struct SynapticSummationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var excitatory = 2
    @State private var inhibitory = 0

    private typealias Model = SynapticSummationModel

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var potentialDescription: String {
        L10n.measurement(Model.membranePotential(excitatory: excitatory, inhibitory: inhibitory), fractionDigits: 0, unit: "mV", store.language)
    }

    var body: some View {
        let fires = Model.reachesThreshold(excitatory: excitatory, inhibitory: inhibitory)
        LabCard {
            LabHeader(title: text("lab.synapse.title"), instruction: text("lab.synapse.subtitle"))
            HStack(spacing: 18) {
                cell(fires: fires)
                meter
                    .frame(width: 120)
            }
            .frame(height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.synapse.scale"))
            .accessibilityValue(String(format: text("lab.synapse.potential"), potentialDescription))

            HStack(spacing: 24) {
                Stepper(value: $excitatory.animation(.spring(response: 0.35)), in: Model.inputRange) {
                    Text(String(format: text("lab.synapse.excitatory"), excitatory)).foregroundStyle(.green)
                }
                .accessibilityLabel(Text(text("lab.synapse.excitatoryLabel")))
                .accessibilityIdentifier("lab.synapse.excitatory")
                Stepper(value: $inhibitory.animation(.spring(response: 0.35)), in: Model.inputRange) {
                    Text(String(format: text("lab.synapse.inhibitory"), inhibitory)).foregroundStyle(.red)
                }
                .accessibilityLabel(Text(text("lab.synapse.inhibitoryLabel")))
                .accessibilityIdentifier("lab.synapse.inhibitory")
            }
            Text(String(format: text("lab.synapse.potential"), potentialDescription))
                .font(.headline.monospacedDigit())
                .accessibilityIdentifier("lab.synapse.potential")
            LabStatusBadge(kind: fires ? .good : .info, text: text(fires ? "lab.synapse.fires" : "lab.synapse.noFire"))
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.synapse.challenge"),
                         solved: inhibitory == 2 && excitatory == Model.excitatoryInputsNeeded(inhibitory: 2), solvedText: text("lab.synapse.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.synapse.hint"), text("lab.synapse.limit")])
        }
    }

    // A neuron with excitatory (green) and inhibitory (red) synapses on its dendrites; the axon lights up when it fires.
    private func cell(fires: Bool) -> some View {
        Canvas { context, size in
            let soma = CGPoint(x: size.width * 0.42, y: size.height / 2)
            let dendrites = (0..<6).map { index -> CGPoint in
                let angle = Double.pi * (0.62 + Double(index) * 0.15)
                return CGPoint(x: soma.x + CGFloat(cos(angle)) * size.height * 0.46, y: soma.y - CGFloat(sin(angle)) * size.height * 0.46)
            }
            for (index, tip) in dendrites.enumerated() {
                var branch = Path()
                branch.move(to: soma)
                branch.addLine(to: tip)
                context.stroke(branch, with: .color(.secondary.opacity(0.6)), lineWidth: 4)
                let excitatoryHere = index < excitatory
                let inhibitoryHere = index < inhibitory
                if excitatoryHere {
                    let point = CGPoint(x: soma.x + (tip.x - soma.x) * 0.75, y: soma.y + (tip.y - soma.y) * 0.75)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(.green))
                    context.draw(Text(verbatim: "+").font(.caption.weight(.heavy)).foregroundColor(.white), at: point)
                }
                if inhibitoryHere {
                    let point = CGPoint(x: soma.x + (tip.x - soma.x) * 0.45, y: soma.y + (tip.y - soma.y) * 0.45)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(.red))
                    context.draw(Text(verbatim: "−").font(.caption.weight(.heavy)).foregroundColor(.white), at: point)
                }
            }
            context.fill(Path(ellipseIn: CGRect(x: soma.x - 34, y: soma.y - 34, width: 68, height: 68)), with: .color(.purple.opacity(0.8)))
            var axon = Path()
            axon.move(to: CGPoint(x: soma.x + 34, y: soma.y))
            axon.addLine(to: CGPoint(x: size.width - 10, y: soma.y))
            context.stroke(axon, with: .color(fires ? .yellow : .secondary.opacity(0.5)), lineWidth: fires ? 7 : 4)
            context.draw(Text(text(fires ? "lab.synapse.spike" : "lab.synapse.silent")).font(.caption.weight(.bold)).foregroundColor(fires ? .yellow : .secondary),
                         at: CGPoint(x: (soma.x + size.width) / 2 + 20, y: soma.y - 18))
        }
    }

    // The membrane potential on a scale from −94 to −46 mV with the resting and threshold levels.
    private var meter: some View {
        Canvas { context, size in
            let low = -94.0, high = -46.0
            func y(_ value: Double) -> CGFloat { 10 + (size.height - 20) * CGFloat((high - value) / (high - low)) }
            let bar = CGRect(x: 18, y: 10, width: 30, height: size.height - 20)
            context.fill(Path(roundedRect: bar, cornerRadius: 10), with: .color(.secondary.opacity(0.15)))
            let potential = Model.membranePotential(excitatory: excitatory, inhibitory: inhibitory)
            let top = y(potential)
            context.fill(Path(roundedRect: CGRect(x: bar.minX, y: top, width: bar.width, height: bar.maxY - top), cornerRadius: 10),
                         with: .color(potential >= Model.thresholdPotential ? .yellow : .accentColor))
            for (value, key, color) in [(Model.thresholdPotential, "lab.neuron.thresholdLine", Color.orange), (Model.restingPotential, "lab.neuron.restLine", Color.secondary)] {
                var line = Path()
                line.move(to: CGPoint(x: bar.minX - 6, y: y(value)))
                line.addLine(to: CGPoint(x: bar.maxX + 6, y: y(value)))
                context.stroke(line, with: .color(color), lineWidth: 2)
                context.draw(Text(text(key)).font(.caption2.weight(.semibold)).foregroundColor(color), at: CGPoint(x: bar.maxX + 10, y: y(value)), anchor: .leading)
            }
        }
    }
}

private struct ReplicatorErrorThresholdLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var length = 100.0
    @State private var errorPercent = 1.0
    @State private var advantage = 10.0

    private typealias Model = ReplicatorErrorThresholdModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var errorRate: Double { errorPercent / 100 }

    var body: some View {
        let offspring = Model.exactOffspring(length: length, errorRate: errorRate, advantage: advantage)
        let persists = Model.persists(length: length, errorRate: errorRate, advantage: advantage)
        let maximum = Model.maximumLength(errorRate: errorRate, advantage: advantage)
        LabCard {
            LabHeader(title: text("lab.replicator.title"), instruction: text("lab.replicator.subtitle"))
            HStack(spacing: 16) {
                GeometryReader { proxy in
                    let plot = LabPlotGeometry(size: proxy.size, x: Model.lengthRange, y: 0...max(2, advantage * 0.25))
                    chart(plot, maximum: maximum)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                            length = min(max(plot.value(at: drag.location).x.rounded(), Model.lengthRange.lowerBound), Model.lengthRange.upperBound)
                        })
                }
                colony
                    .frame(width: 200)
            }
            .frame(height: 250)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.replicator.scale"))
            .accessibilityValue(Text(verbatim: number(offspring, 2)))

            slider(String(format: text("lab.replicator.length"), number(length, 0)), "lab.replicator.lengthLabel", "lab.replicator.length",
                   Binding(get: { length }, set: { length = $0.rounded() }), Model.lengthRange)
            slider(String(format: text("lab.replicator.error"), number(errorPercent, 1)), "lab.replicator.errorLabel", "lab.replicator.error",
                   Binding(get: { errorPercent }, set: { errorPercent = ($0 * 10).rounded() / 10 }), (Model.errorRateRange.lowerBound * 100)...(Model.errorRateRange.upperBound * 100))
            slider(String(format: text("lab.replicator.advantage"), number(advantage, 0)), "lab.replicator.advantageLabel", "lab.replicator.advantage",
                   Binding(get: { advantage }, set: { advantage = $0.rounded() }), Model.advantageRange)
            LabStatGrid {
                LabStat(label: text("lab.replicator.statExact"), value: number(Model.exactCopyProbability(length: length, errorRate: errorRate) * 100, 1) + " %", tint: .green)
                LabStat(label: "σ · (1 − e)ᴸ", value: number(offspring, 2), tint: persists ? .green : .red, identifier: "lab.replicator.offspring")
                LabStat(label: text("lab.replicator.statMax"), value: maximum.map(String.init) ?? "0", tint: .purple)
            }
            LabStatusBadge(kind: persists ? .good : .bad, text: text(persists ? "lab.replicator.persists" : "lab.replicator.erased"))
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.replicator.challenge"),
                         solved: errorPercent == 1 && advantage == 10 && persists && length >= 200, solvedText: text("lab.replicator.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.replicator.hint"), text("lab.replicator.limit")])
        }
    }

    private func slider(_ title: String, _ labelKey: String, _ identifier: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title).monospacedDigit().frame(minWidth: 300, alignment: .leading)
            // Each slider rounds without `step:`, which would draw a dense row of tick marks.
            Slider(value: value, in: range)
                .accessibilityLabel(text(labelKey))
                .accessibilityIdentifier(identifier)
        }
    }

    // Exact offspring σ(1 − e)ᴸ against length: above the line at 1 the information survives (green), below it is erased.
    private func chart(_ plot: LabPlotGeometry, maximum: Int?) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: text("lab.replicator.axisLength"), yLabel: text("lab.replicator.axisOffspring"), format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect))
            let one = plot.point(0, 1).y
            clipped.fill(Path(CGRect(x: plot.rect.minX, y: plot.rect.minY, width: plot.rect.width, height: one - plot.rect.minY)), with: .color(.green.opacity(0.08)))
            clipped.fill(Path(CGRect(x: plot.rect.minX, y: one, width: plot.rect.width, height: plot.rect.maxY - one)), with: .color(.red.opacity(0.08)))
            var threshold = Path()
            threshold.move(to: CGPoint(x: plot.rect.minX, y: one))
            threshold.addLine(to: CGPoint(x: plot.rect.maxX, y: one))
            clipped.stroke(threshold, with: .color(.secondary), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            var curve = Path()
            for index in 0...200 {
                let l = plot.x.lowerBound + (plot.x.upperBound - plot.x.lowerBound) * Double(index) / 200
                let location = plot.point(l, min(Model.exactOffspring(length: l, errorRate: errorRate, advantage: advantage), plot.y.upperBound))
                if index == 0 { curve.move(to: location) } else { curve.addLine(to: location) }
            }
            clipped.stroke(curve, with: .color(.accentColor), lineWidth: 2.5)
            if let maximum {
                var mark = Path()
                mark.move(to: plot.point(Double(maximum), 0))
                mark.addLine(to: plot.point(Double(maximum), 1))
                clipped.stroke(mark, with: .color(.purple), lineWidth: 2)
                clipped.draw(Text(verbatim: "L max = \(maximum)").font(.caption.weight(.bold)).foregroundColor(.purple), at: plot.point(Double(maximum), 1.08), anchor: .bottomLeading)
            }
            let current = plot.point(length, min(Model.exactOffspring(length: length, errorRate: errorRate, advantage: advantage), plot.y.upperBound))
            clipped.fill(Path(ellipseIn: CGRect(x: current.x - 8, y: current.y - 8, width: 16, height: 16)), with: .color(.orange))
            clipped.stroke(Path(ellipseIn: CGRect(x: current.x - 8, y: current.y - 8, width: 16, height: 16)), with: .color(.white), lineWidth: 2)
        }
    }

    // Forty copies of the molecule: the exact-copy share is green, copies with at least one error are red.
    private var colony: some View {
        Canvas { context, size in
            let exact = Model.exactCopyProbability(length: length, errorRate: errorRate)
            let good = Int((exact * 40).rounded())
            let cell = min(size.width / 5, size.height / 8)
            for index in 0..<40 {
                let rect = CGRect(x: CGFloat(index % 5) * cell + cell * 0.12, y: CGFloat(index / 5) * cell + cell * 0.12, width: cell * 0.76, height: cell * 0.76)
                context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(index < good ? .green : .red.opacity(0.7)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: length)
        .accessibilityHidden(true)
    }
}

private struct PHScaleLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var pH = 4.0

    private var exponentDescription: String {
        let digits = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        let exponent = String(Int(pH)).compactMap { Int(String($0)) }.map { digits[$0] }.joined()
        return "10⁻" + exponent
    }

    private var comparisonDescription: String {
        let ratio = PHScaleModel.hydrogenRatio(pH: pH, comparedTo: PHScaleModel.neutralPH)
        let locale = Locale(identifier: store.language == .ru ? "ru_RU" : "en_US")
        switch PHScaleModel.acidity(pH: pH) {
        case .acidic:
            return String(format: L10n.text("lab.ph.more", store.language), Int(ratio.rounded()).formatted(.number.locale(locale)))
        case .basic:
            return String(format: L10n.text("lab.ph.fewer", store.language), Int((1 / ratio).rounded()).formatted(.number.locale(locale)))
        case .neutral:
            return L10n.text("lab.ph.same", store.language)
        }
    }

    private var acidityKey: String {
        switch PHScaleModel.acidity(pH: pH) {
        case .acidic: return "lab.ph.acidic"
        case .neutral: return "lab.ph.neutral"
        case .basic: return "lab.ph.basic"
        }
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.ph.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.ph.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: L10n.text("lab.ph.value", store.language), String(Int(pH))))
                    .font(.headline.monospacedDigit())
                Slider(value: snappedToWholeUnits, in: PHScaleModel.pHRange)
                    .accessibilityLabel(L10n.text("lab.ph.sliderLabel", store.language))
                    .accessibilityValue(Text(verbatim: String(Int(pH))))
                    .accessibilityIdentifier("lab.ph.slider")
            }
            pHScale
                .frame(height: 26)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.text("lab.ph.scale", store.language))
                .accessibilityValue(Text(verbatim: String(Int(pH))))

            Text(String(format: L10n.text("lab.ph.concentration", store.language), exponentDescription))
                .font(.callout.monospacedDigit())
            Label(L10n.text(acidityKey, store.language), systemImage: "drop.fill")
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.ph.acidity")
            Text(comparisonDescription)
                .font(.callout.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.ph.comparison")
            Text(L10n.text("lab.ph.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Whole pH units keep the powers of ten exact; `step:` would draw tick marks under the slider.
    private var snappedToWholeUnits: Binding<Double> {
        Binding(get: { pH }, set: { pH = $0.rounded() })
    }

    // Acidic red through neutral green to basic blue, with the current pH marked.
    private var pHScale: some View {
        GeometryReader { geometry in
            let fraction = pH / PHScaleModel.pHRange.upperBound
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [.red, .orange, .green, .teal, .blue], startPoint: .leading, endPoint: .trailing))
                Circle()
                    .strokeBorder(Color.primary, lineWidth: 3)
                    .background(Circle().fill(Color.white.opacity(0.85)))
                    .frame(width: 22, height: 22)
                    .offset(x: max(0, geometry.size.width * CGFloat(fraction) - 11))
            }
        }
    }
}

private struct MoleculeBuilderLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var central = MoleculeBuilderModel.CentralAtom.carbon
    @State private var hydrogens = 2

    private var status: MoleculeBuilderModel.Status {
        MoleculeBuilderModel.status(central: central, hydrogens: hydrogens)
    }

    private var atomName: String { L10n.text(central.nameKey, store.language) }

    private var statusDescription: String {
        switch status {
        case .complete:
            let name = MoleculeBuilderModel.moleculeKey(central: central, hydrogens: hydrogens).map { L10n.text($0, store.language) } ?? ""
            return String(format: L10n.text("lab.molecule.complete", store.language), name)
        case .missingBonds(let count):
            return String(format: L10n.text("lab.molecule.missing", store.language), String(count))
        case .tooManyBonds(let count):
            return String(format: L10n.text("lab.molecule.tooMany", store.language), String(count), atomName, String(central.valence))
        }
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.molecule.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.molecule.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L10n.text("lab.molecule.central", store.language), selection: $central) {
                ForEach(MoleculeBuilderModel.CentralAtom.allCases) { atom in
                    Text(atom.rawValue).tag(atom)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.molecule.central")
            Text(String(format: L10n.text("lab.molecule.electrons", store.language), atomName, String(central.electrons), String(central.outerElectrons), String(central.valence)))
                .font(.callout.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)

            Stepper(value: $hydrogens, in: MoleculeBuilderModel.hydrogenRange) {
                Text(String(format: L10n.text("lab.molecule.hydrogens", store.language), String(hydrogens)))
                    .monospacedDigit()
            }
            .accessibilityLabel(Text(L10n.text("lab.molecule.hydrogensLabel", store.language)))
            .accessibilityValue(Text(verbatim: String(hydrogens)))
            .accessibilityIdentifier("lab.molecule.hydrogens")

            HStack(alignment: .center, spacing: 18) {
                moleculeDrawing
                    .frame(width: 150, height: 150)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.text("lab.molecule.drawing", store.language))
                    .accessibilityValue(Text(verbatim: MoleculeBuilderModel.formula(central: central, hydrogens: hydrogens)))
                VStack(alignment: .leading, spacing: 8) {
                    Text(MoleculeBuilderModel.formula(central: central, hydrogens: hydrogens))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("lab.molecule.formula")
                    Label(statusDescription, systemImage: status == .complete ? "checkmark.seal" : "exclamationmark.circle")
                        .font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("lab.molecule.status")
                }
            }
            Text(L10n.text("lab.molecule.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // A flat sketch: bonds within the valence are solid, extra ones dashed red. Real 3D shapes and angles differ.
    private var moleculeDrawing: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 18
            for index in 0..<hydrogens {
                let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(max(hydrogens, 1))
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                var bond = Path()
                bond.move(to: center)
                bond.addLine(to: point)
                let fits = index < central.valence
                context.stroke(bond, with: .color(fits ? .secondary : .red), style: StrokeStyle(lineWidth: 3, dash: fits ? [] : [5, 4]))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)), with: .color(fits ? Color.accentColor.opacity(0.85) : .red.opacity(0.6)))
                context.draw(Text("H").font(.callout.weight(.bold)).foregroundColor(.white), at: point)
            }
            context.fill(Path(ellipseIn: CGRect(x: center.x - 22, y: center.y - 22, width: 44, height: 44)), with: .color(.indigo))
            context.draw(Text(central.rawValue).font(.title3.weight(.bold)).foregroundColor(.white), at: center)
        }
    }
}

private struct ReactionEnergyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var freeEnergy = -30.0
    @State private var activation = 80.0
    @State private var lowering = 20.0
    @State private var catalystOn = true

    private typealias Model = ReactionEnergyModel

    private var barrier: Double { Model.uncatalyzedBarrier(activation: activation, freeEnergyChange: freeEnergy) }
    private var catalyzedBarrier: Double {
        Model.catalyzedBarrier(activation: activation, lowering: catalystOn ? lowering : 0, freeEnergyChange: freeEnergy)
    }
    private var speedup: Double {
        Model.speedup(activation: activation, lowering: catalystOn ? lowering : 0, freeEnergyChange: freeEnergy)
    }

    private func energy(_ value: Double) -> String {
        L10n.measurement(value, fractionDigits: 0, unit: "kJ/mol", store.language)
    }

    private var kindDescription: String {
        let key: String
        switch Model.kind(freeEnergyChange: freeEnergy) {
        case .exergonic: key = "lab.energy.exergonic"
        case .endergonic: key = "lab.energy.endergonic"
        case .balanced: key = "lab.energy.balanced"
        }
        return String(format: L10n.text(key, store.language), energy(freeEnergy))
    }

    private var speedupDescription: String {
        let text: String
        if speedup < 10 {
            text = L10n.number(speedup, fractionDigits: 1, store.language)
        } else {
            let locale = Locale(identifier: store.language == .ru ? "ru_RU" : "en_US")
            text = Int(speedup.rounded()).formatted(.number.locale(locale))
        }
        return String(format: L10n.text("lab.energy.speedup", store.language), text)
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.energy.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.energy.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            labeledSlider("lab.energy.freeEnergy", "lab.energy.freeEnergyLabel", value: $freeEnergy, range: Model.freeEnergyRange, increment: 5)
            labeledSlider("lab.energy.activation", "lab.energy.activationLabel", value: $activation, range: Model.activationRange, increment: 5)
            Toggle(L10n.text("lab.energy.catalyst", store.language), isOn: $catalystOn)
                .accessibilityIdentifier("lab.energy.catalyst")
            if catalystOn {
                labeledSlider("lab.energy.lowering", "lab.energy.loweringLabel", value: $lowering, range: Model.loweringRange, increment: 1)
            }

            profileChart
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.text("lab.energy.chart", store.language))
                .accessibilityValue(Text(String(format: L10n.text("lab.energy.barriers", store.language), energy(barrier), energy(catalyzedBarrier))))
            HStack(spacing: 14) {
                Label(L10n.text("lab.energy.legendPlain", store.language), systemImage: "line.diagonal")
                    .foregroundStyle(.orange)
                if catalystOn {
                    Label(L10n.text("lab.energy.legendCatalyst", store.language), systemImage: "line.diagonal")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)

            Text(kindDescription)
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.energy.kind")
            Text(String(format: L10n.text("lab.energy.barriers", store.language), energy(barrier), energy(catalyzedBarrier)))
                .font(.callout.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.energy.barrierValues")
            Text(speedupDescription)
                .font(.headline.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.energy.speedup")
            if catalystOn {
                Text(String(format: L10n.text("lab.energy.sameFreeEnergy", store.language), energy(freeEnergy)))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if activation < Model.minimumBarrier(freeEnergyChange: freeEnergy)
                || (catalystOn && barrier - lowering < Model.minimumBarrier(freeEnergyChange: freeEnergy)) {
                Text(L10n.text("lab.energy.floor", store.language))
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.text("lab.energy.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Rounds without `step:`, which would draw a dense row of tick marks under the slider.
    private func labeledSlider(_ titleKey: String, _ labelKey: String, value: Binding<Double>, range: ClosedRange<Double>, increment: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: L10n.text(titleKey, store.language), energy(value.wrappedValue)))
                .monospacedDigit()
            Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = ($0 / increment).rounded() * increment }), in: range)
                .accessibilityLabel(L10n.text(labelKey, store.language))
                .accessibilityValue(Text(energy(value.wrappedValue)))
        }
    }

    // Energy on a fixed −70…125 kJ/mol axis so that changes stay comparable; reactants sit at 0.
    private var profileChart: some View {
        Canvas { context, size in
            let lower = -70.0
            let upper = 125.0
            func y(_ value: Double) -> CGFloat { size.height * CGFloat((upper - value) / (upper - lower)) }
            func path(barrier: Double) -> Path {
                var path = Path()
                for step in 0...60 {
                    let x = Double(step) / 60
                    let point = CGPoint(x: size.width * CGFloat(x), y: y(Model.profileEnergy(at: x, barrier: barrier, freeEnergyChange: freeEnergy)))
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                return path
            }
            for level in [0.0, freeEnergy] {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y(level)))
                line.addLine(to: CGPoint(x: size.width, y: y(level)))
                context.stroke(line, with: .color(.secondary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            context.stroke(path(barrier: barrier), with: .color(.orange), lineWidth: 3)
            if catalystOn {
                context.stroke(path(barrier: catalyzedBarrier), with: .color(.green), style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
            }
            // Labels sit under their levels, where the curve never goes; near the bottom edge they move above.
            let productLabelY = freeEnergy - 14 > lower ? y(freeEnergy) + 10 : y(freeEnergy) - 10
            context.draw(Text(L10n.text("lab.energy.reactants", store.language)).font(.caption), at: CGPoint(x: 6, y: y(0) + 10), anchor: .leading)
            context.draw(Text(L10n.text("lab.energy.products", store.language)).font(.caption), at: CGPoint(x: size.width - 6, y: productLabelY), anchor: .trailing)
        }
    }
}

private struct NeuronTrainingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var model = NeuronTrainingModel()
    @State private var learningRate = 0.05
    @State private var playing = false

    private typealias Model = NeuronTrainingModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let regime = Model.regime(learningRate: learningRate)
        let factor = number(Model.errorFactor(learningRate: learningRate), 2), limit = number(Model.stableLearningRateLimit, 2)
        let status: (LabStatusKind, String) = switch regime {
        case .converging: (.good, String(format: text("lab.neurontrain.converging"), factor, limit))
        case .oscillating: (.warning, String(format: text("lab.neurontrain.oscillating"), factor, limit))
        case .diverging: (.bad, String(format: text("lab.neurontrain.diverging"), factor, limit))
        }
        LabCard {
            LabHeader(title: text("lab.neurontrain.title"), instruction: text("lab.neurontrain.subtitle"))
            HStack(spacing: 16) {
                neuron
                    .frame(width: 360)
                lossChart
            }
            .frame(height: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.neurontrain.chart"))
            .accessibilityValue(Text(verbatim: number(model.loss, 4)))

            HStack(spacing: 12) {
                Text(String(format: text("lab.neurontrain.rate"), number(learningRate, 2))).monospacedDigit().frame(minWidth: 220, alignment: .leading)
                // Rounds to hundredths without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { learningRate }, set: { learningRate = ($0 * 100).rounded() / 100 }), in: Model.learningRateRange)
                    .accessibilityLabel(text("lab.neurontrain.rateLabel"))
                    .accessibilityIdentifier("lab.neurontrain.rate")
            }
            HStack(spacing: 10) {
                Button {
                    if model.lossHistory.count >= 30 { model.reset() }
                    playing.toggle()
                } label: { Label(text(playing ? "lab.descent2d.pause" : "lab.descent2d.play"), systemImage: playing ? "pause.fill" : "play.fill") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.neurontrain.play")
                Button(text("lab.neurontrain.step")) { withAnimation(.easeInOut(duration: 0.25)) { model.step(learningRate: learningRate) } }
                    .accessibilityIdentifier("lab.neurontrain.step")
                Button(text("lab.neurontrain.reset")) { playing = false; withAnimation { model.reset() } }
                    .accessibilityIdentifier("lab.neurontrain.reset")
            }
            LabStatGrid {
                LabStat(label: text("lab.neurontrain.statSteps"), value: String(model.lossHistory.count))
                LabStat(label: "w · b", value: number(model.weight, 3) + " · " + number(model.bias, 3), tint: .purple)
                LabStat(label: text("lab.neurontrain.statOutput"), value: number(model.output, 3), tint: .accentColor)
                LabStat(label: text("lab.neurontrain.statLoss"), value: number(model.loss, 4), tint: .orange, identifier: "lab.neurontrain.loss")
            }
            LabStatusBadge(kind: status.0, text: status.1)
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.neurontrain.challenge"),
                         solved: model.lossHistory.count == 1 && model.loss < 1e-9, solvedText: text("lab.neurontrain.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.neurontrain.hint"),
                String(format: text("lab.neurontrain.gradients"), number(model.loss, 4), number(model.weightGradient, 3), number(model.biasGradient, 3)),
                text("lab.neurontrain.limit"),
            ])
        }
        .task(id: playing) {
            guard playing else { return }
            while playing && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard playing else { break }
                withAnimation(.easeInOut(duration: 0.25)) { model.step(learningRate: learningRate) }
                if model.loss < 1e-8 || model.loss > 1e6 || model.lossHistory.count >= 30 { playing = false }
            }
        }
    }

    // x = 2 flows through ×w and +b into the output y, compared with the target 2; the gap is the error.
    private var neuron: some View {
        Canvas { context, size in
            let y = size.height * 0.45
            let input = CGPoint(x: 34, y: y), body = CGPoint(x: size.width * 0.55, y: y), output = CGPoint(x: size.width - 40, y: y)
            var wires = Path()
            wires.move(to: input)
            wires.addLine(to: body)
            wires.addLine(to: output)
            context.stroke(wires, with: .color(.secondary), lineWidth: 3)
            context.fill(Path(ellipseIn: CGRect(x: input.x - 26, y: y - 26, width: 52, height: 52)), with: .color(.teal))
            context.draw(Text(verbatim: "x = 2").font(.caption.weight(.bold)).foregroundColor(.white), at: input)
            context.fill(Path(ellipseIn: CGRect(x: body.x - 40, y: y - 40, width: 80, height: 80)), with: .color(.purple.opacity(0.85)))
            context.draw(Text(verbatim: "w·x + b").font(.caption.weight(.bold)).foregroundColor(.white), at: body)
            context.draw(Text(verbatim: "w = " + number(model.weight, 2)).font(.caption.weight(.semibold)).foregroundColor(.purple), at: CGPoint(x: (input.x + body.x) / 2, y: y - 16))
            context.draw(Text(verbatim: "b = " + number(model.bias, 2)).font(.caption.weight(.semibold)).foregroundColor(.purple), at: CGPoint(x: body.x, y: y + 54))
            let error = model.output - Model.target
            let color: Color = abs(error) < 0.01 ? .green : .orange
            context.fill(Path(ellipseIn: CGRect(x: output.x - 30, y: y - 30, width: 60, height: 60)), with: .color(color))
            context.draw(Text(verbatim: number(model.output, 2)).font(.headline).foregroundColor(.white), at: output)
            context.draw(Text(text("lab.neurontrain.target")).font(.caption.weight(.semibold)).foregroundColor(.green), at: CGPoint(x: output.x, y: y + 46))
            context.draw(Text(verbatim: "y − t = " + number(error, 3)).font(.caption.weight(.bold)).foregroundColor(color), at: CGPoint(x: output.x - 10, y: y - 44))
        }
    }

    // The error after every step: falling for a good rate, flat or rising for a bad one.
    private var lossChart: some View {
        Canvas { context, size in
            let values = model.lossHistory + [model.loss]
            let top = max(min(values.max() ?? 1, 50), 0.5)
            let plot = LabPlotGeometry(size: size, x: 0...Double(max(values.count - 1, 5)), y: 0...top * 1.1)
            plot.drawAxes(in: context, xLabel: text("lab.descent2d.lossX"), yLabel: "L", format: { number($0, $0 < 10 && $0 != $0.rounded() ? 1 : 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -4, dy: -4)))
            var line = Path()
            for (index, value) in values.enumerated() {
                let location = plot.point(Double(index), min(value, top * 1.1))
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
                clipped.fill(Path(ellipseIn: CGRect(x: location.x - 3, y: location.y - 3, width: 6, height: 6)), with: .color(.orange))
            }
            clipped.stroke(line, with: .color(.orange), lineWidth: 2)
        }
    }
}

private struct CoinEntropyLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var coins = 4
    @State private var toss: [Bool] = []

    private typealias Model = CoinMicrostateModel

    private var locale: Locale { Locale(identifier: store.language == .ru ? "ru_RU" : "en_US") }
    private func grouped(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
    private func percent(_ value: Double) -> String { L10n.number(value * 100, fractionDigits: value < 0.001 ? 4 : 1, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let mostLikely = Model.mostLikelyHeads(coins: coins)
        let total = Model.total(coins: coins)
        let tossHeads = toss.count == coins ? toss.filter { $0 }.count : nil
        LabCard {
            LabHeader(title: text("lab.entropy.title"), instruction: text("lab.entropy.subtitle"))
            HStack(spacing: 12) {
                Stepper(value: Binding(get: { coins }, set: { coins = $0; toss = [] }), in: Model.coinRange) {
                    Text(String(format: text("lab.entropy.coins"), String(coins), grouped(total))).monospacedDigit()
                }
                .accessibilityLabel(Text(text("lab.entropy.coinsLabel")))
                .accessibilityIdentifier("lab.entropy.coins")
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4)) { toss = (0..<coins).map { _ in Bool.random() } }
                } label: { Label(text("lab.entropy.toss"), systemImage: "circle.lefthalf.filled") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.entropy.toss")
            }
            if !toss.isEmpty {
                HStack(spacing: 4) {
                    ForEach(toss.indices, id: \.self) { index in
                        Text(verbatim: toss[index] ? text("lab.entropy.headShort") : text("lab.entropy.tailShort"))
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(toss[index] ? Color.orange : Color.secondary.opacity(0.35)))
                    }
                }
            }
            histogram(highlight: tossHeads)
                .frame(height: 230)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.entropy.chart"))
                .accessibilityValue(Text(verbatim: (0...coins).map { String(Model.microstates(coins: coins, heads: $0)) }.joined(separator: ", ")))
            LabStatGrid {
                LabStat(label: text("lab.entropy.statTotal"), value: grouped(total), tint: .purple)
                LabStat(label: String(format: text("lab.entropy.statMost"), String(mostLikely)), value: percent(Model.probability(coins: coins, heads: mostLikely)) + " %", tint: .orange)
                LabStat(label: text("lab.entropy.statAllHeads"), value: percent(Model.probability(coins: coins, heads: coins)) + " %", tint: .red)
            }
            Text(String(format: text("lab.entropy.mostLikely"), String(mostLikely), grouped(Model.microstates(coins: coins, heads: mostLikely)), grouped(total),
                        percent(Model.probability(coins: coins, heads: mostLikely))))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.entropy.mostLikely")
            Text(String(format: text("lab.entropy.allHeads"), grouped(total), percent(Model.probability(coins: coins, heads: coins))))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.entropy.allHeads")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.entropy.challenge"), solved: total > 1_000_000, solvedText: text("lab.entropy.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.entropy.hint"), text("lab.entropy.limit")])
        }
    }

    // Microstates per macrostate with axes; the most likely bars are orange and the last toss's macrostate is outlined.
    private func histogram(highlight: Int?) -> some View {
        Canvas { context, size in
            let counts = (0...coins).map { Model.microstates(coins: coins, heads: $0) }
            let peak = Double(counts.max() ?? 1)
            let plot = LabPlotGeometry(size: size, x: -0.5...(Double(coins) + 0.5), y: 0...peak * 1.1, leading: 60)
            let xTicks = coins <= 10 ? Array(0...coins).map(Double.init) : LabPlotGeometry.ticks(0...Double(coins), count: 5)
            plot.drawAxes(in: context, xLabel: text("lab.entropy.axisHeads"), yLabel: text("lab.entropy.axisWays"), xTicks: xTicks, format: { grouped(Int($0.rounded())) })
            let slot = plot.rect.width / CGFloat(counts.count)
            for (heads, count) in counts.enumerated() {
                let top = plot.point(Double(heads), Double(count))
                let rect = CGRect(x: top.x - slot * 0.35, y: top.y, width: slot * 0.7, height: plot.rect.maxY - top.y)
                let likely = heads == Model.mostLikelyHeads(coins: coins) || heads == coins - Model.mostLikelyHeads(coins: coins)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(likely ? .orange : .accentColor.opacity(0.55)))
                if heads == highlight {
                    context.stroke(Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 4), with: .color(.primary), lineWidth: 2.5)
                }
            }
        }
    }
}

private struct HardyWeinbergLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var recessiveAllele = 0.4

    private typealias Model = HardyWeinbergModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let genotypes = Model.genotypes(recessiveAllele: recessiveAllele)
        let ratio = Model.carriersPerAffected(recessiveAllele: recessiveAllele)
        LabCard {
            LabHeader(title: text("lab.hardy.title"), instruction: text("lab.hardy.subtitle"))
            HStack(spacing: 18) {
                population(genotypes)
                    .frame(width: 260, height: 260)
                VStack(alignment: .leading, spacing: 12) {
                    legend(text("lab.hardy.dominant"), genotypes.dominantHomozygous, .blue)
                    legend(text("lab.hardy.carrier"), genotypes.heterozygous, .purple)
                    legend(text("lab.hardy.recessive"), genotypes.recessiveHomozygous, .orange)
                }
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 12) {
                Text(String(format: text("lab.hardy.alleles"), number(1 - recessiveAllele, 2), number(recessiveAllele, 2))).monospacedDigit().frame(minWidth: 220, alignment: .leading)
                // Rounds to hundredths without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { recessiveAllele }, set: { recessiveAllele = ($0 * 100).rounded() / 100 }), in: Model.recessiveRange)
                    .accessibilityLabel(text("lab.hardy.sliderLabel"))
                    .accessibilityValue(Text(verbatim: number(recessiveAllele, 2)))
                    .accessibilityIdentifier("lab.hardy.q")
            }
            LabStatGrid {
                LabStat(label: text("lab.hardy.statRatio"), value: number(ratio, 1), tint: .purple, identifier: "lab.hardy.ratio")
                LabStat(label: "2pq", value: number(genotypes.heterozygous * 100, 1) + " %", tint: .purple)
                LabStat(label: "q²", value: number(genotypes.recessiveHomozygous * 100, 1) + " %", tint: .orange)
            }
            Text(String(format: text("lab.hardy.ratio"), number(ratio, 1)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.hardy.challenge"), solved: abs(ratio - 10) < 0.6, solvedText: text("lab.hardy.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.hardy.hint"), text("lab.hardy.limit")])
        }
    }

    private func legend(_ title: String, _ share: Double, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 16, height: 16)
            Text(verbatim: "\(title): \(number(share * 100, 1)) %").font(.callout.monospacedDigit())
        }
    }

    // A hundred individuals coloured by genotype in Hardy–Weinberg proportions p², 2pq, q².
    private func population(_ genotypes: HardyWeinbergModel.Genotypes) -> some View {
        Canvas { context, size in
            let dominant = Int((genotypes.dominantHomozygous * 100).rounded())
            let carriers = Int((genotypes.heterozygous * 100).rounded())
            let cell = min(size.width, size.height) / 10
            for index in 0..<100 {
                let color: Color = index < dominant ? .blue : (index < dominant + carriers ? .purple : .orange)
                let rect = CGRect(x: CGFloat(index % 10) * cell + cell * 0.12, y: CGFloat(index / 10) * cell + cell * 0.12, width: cell * 0.76, height: cell * 0.76)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: recessiveAllele)
        .accessibilityHidden(true)
    }
}

private struct LeastSquaresFitLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var slope = 3.0
    @State private var intercept = 0.3
    @State private var lengthOffset = 0.0
    @State private var revealBest = false
    @State private var draggedHandle: Int?

    private typealias Model = LeastSquaresFitModel
    private let handleX = [0.1, 1.05]

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let line = Model.Line(intercept: intercept, slope: slope)
        let best = Model.bestFit(lengthOffset: lengthOffset)
        let error = Model.sumOfSquaredErrors(line, lengthOffset: lengthOffset)
        LabCard {
            LabHeader(title: text("lab.lsq.title"), instruction: text("lab.lsq.subtitle"))

            GeometryReader { proxy in
                let plot = LabPlotGeometry(size: proxy.size, x: 0...1.1, y: 0...4.5)
                chart(plot, line: line, best: best)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let value = plot.value(at: drag.location)
                            if draggedHandle == nil { draggedHandle = value.x < 0.55 ? 0 : 1 }
                            guard let handle = draggedHandle else { return }
                            let other = 1 - handle
                            let otherY = line.value(at: handleX[other])
                            let newSlope = (handle == 1 ? value.y - otherY : otherY - value.y) / (handleX[1] - handleX[0])
                            slope = min(max(newSlope, Model.slopeRange.lowerBound), Model.slopeRange.upperBound)
                            intercept = min(max(otherY - slope * handleX[other], Model.interceptRange.lowerBound), Model.interceptRange.upperBound)
                        }
                        .onEnded { _ in draggedHandle = nil })
            }
            .frame(height: 300)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.lsq.chart"))
            .accessibilityValue(Text(verbatim: number(error, 4)))

            LabStatGrid {
                LabStat(label: text("lab.lsq.statSSE"), value: number(error, 4), tint: .orange, identifier: "lab.lsq.sse")
                LabStat(label: text("lab.lsq.statBest"), value: revealBest ? number(Model.sumOfSquaredErrors(best, lengthOffset: lengthOffset), 6) : "?", tint: .secondary)
                LabStat(label: text("lab.lsq.statSlope"), value: number(slope, 3))
                LabStat(label: text("lab.lsq.statGravity"), value: number(Model.gravity(slope: slope), 2) + " " + text("lab.lsq.unitG"), tint: .green, identifier: "lab.lsq.gravity")
            }
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        slope = best.slope
                        intercept = best.intercept
                        revealBest = true
                    }
                } label: { Label(text("lab.lsq.fit"), systemImage: "wand.and.stars") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.lsq.fit")
                Button(text("lab.lsq.reset")) {
                    withAnimation { slope = 3; intercept = 0.3; revealBest = false }
                }
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.lsq.challenge"), solved: error < 0.01, solvedText: text("lab.lsq.challengeSolved"))
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: text("lab.lsq.offset"), number(lengthOffset, 2))).monospacedDigit()
                // Rounds to centimetres without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { lengthOffset }, set: { lengthOffset = ($0 * 100).rounded() / 100 }), in: Model.offsetRange)
                    .accessibilityLabel(text("lab.lsq.offsetLabel"))
                    .accessibilityIdentifier("lab.lsq.offset")
                if revealBest {
                    Text(String(format: text("lab.lsq.best"), number(best.slope, 3), number(best.intercept, 3), number(Model.gravity(slope: best.slope), 2)))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("lab.lsq.best")
                }
            }
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.lsq.hint"), text("lab.lsq.limit")])
        }
    }

    // Measured points with each residual drawn as a square (SSE is their total area), the learner's line with
    // two drag handles, and the least-squares line once revealed.
    private func chart(_ plot: LabPlotGeometry, line: Model.Line, best: Model.Line) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: text("lab.lsq.axisX"), yLabel: text("lab.lsq.axisY"), format: { number($0, $0 == $0.rounded() ? 0 : 1) })
            var clipped = context
            clipped.clip(to: Path(plot.rect))
            for point in Model.points(lengthOffset: lengthOffset) {
                let measured = plot.point(point.x, point.y), onLine = plot.point(point.x, line.value(at: point.x))
                let side = abs(onLine.y - measured.y)
                let square = CGRect(x: measured.x, y: min(measured.y, onLine.y), width: side, height: side)
                clipped.fill(Path(square), with: .color(.orange.opacity(0.22)))
                clipped.stroke(Path(square), with: .color(.orange.opacity(0.8)), lineWidth: 1)
            }
            if revealBest {
                var bestPath = Path()
                bestPath.move(to: plot.point(0, best.value(at: 0)))
                bestPath.addLine(to: plot.point(1.1, best.value(at: 1.1)))
                clipped.stroke(bestPath, with: .color(.green), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }
            var userPath = Path()
            userPath.move(to: plot.point(0, line.value(at: 0)))
            userPath.addLine(to: plot.point(1.1, line.value(at: 1.1)))
            clipped.stroke(userPath, with: .color(.accentColor), lineWidth: 3)
            for point in Model.points(lengthOffset: lengthOffset) {
                let location = plot.point(point.x, point.y)
                clipped.fill(Path(ellipseIn: CGRect(x: location.x - 6, y: location.y - 6, width: 12, height: 12)), with: .color(.orange))
            }
            for (index, x) in handleX.enumerated() {
                let handle = plot.point(x, line.value(at: x))
                let radius: CGFloat = draggedHandle == index ? 11 : 9
                clipped.fill(Path(ellipseIn: CGRect(x: handle.x - radius, y: handle.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(.accentColor))
                clipped.stroke(Path(ellipseIn: CGRect(x: handle.x - radius, y: handle.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(.white), lineWidth: 2.5)
            }
        }
    }
}

private struct SynapticPlasticityLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var receptors = SynapticPlasticityModel.startingAMPAReceptors
    @State private var glutamate = true
    @State private var strongDepolarization = false
    @State private var lastOutcome: SynapticPlasticityModel.Outcome?
    @State private var history: [Int] = []

    private typealias Model = SynapticPlasticityModel

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    private var outcome: (kind: LabStatusKind, text: String) {
        switch lastOutcome {
        case nil: return (.info, text("lab.plasticity.ready"))
        case .noTransmitter: return (.warning, text("lab.plasticity.noTransmitter"))
        case .magnesiumBlock: return (.info, text("lab.plasticity.magnesiumBlock"))
        case .potentiation: return (.good, text("lab.plasticity.potentiation"))
        case .saturated: return (.info, text("lab.plasticity.saturated"))
        }
    }

    var body: some View {
        let calciumFlows = Model.nmdaPassesCalcium(glutamate: glutamate, strongDepolarization: strongDepolarization)
        LabCard {
            LabHeader(title: text("lab.plasticity.title"), instruction: text("lab.plasticity.subtitle"))

            synapse(calciumFlows: calciumFlows)
                .frame(height: 250)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.plasticity.diagram"))
                .accessibilityValue(Text(text(calciumFlows ? "lab.plasticity.nmdaOpen" : "lab.plasticity.nmdaBlocked")))

            HStack(spacing: 10) {
                Toggle(isOn: $glutamate.animation()) { Label(text("lab.plasticity.glutamateShort"), systemImage: "drop.fill") }
                    .toggleStyle(.button)
                    .accessibilityIdentifier("lab.plasticity.glutamate")
                Toggle(isOn: $strongDepolarization.animation()) { Label(text("lab.plasticity.depolarizationShort"), systemImage: "bolt.fill") }
                    .toggleStyle(.button)
                    .accessibilityIdentifier("lab.plasticity.depolarization")
                Spacer()
                Button {
                    let result = Model.stimulate(ampaReceptors: receptors, glutamate: glutamate, strongDepolarization: strongDepolarization)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        receptors = result.receptors
                        lastOutcome = result.outcome
                        history.append(Model.response(ampaReceptors: result.receptors, glutamate: true))
                    }
                } label: { Label(text("lab.plasticity.stimulate"), systemImage: "waveform.path.ecg") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.plasticity.stimulate")
                Button(text("lab.plasticity.reset")) {
                    withAnimation { receptors = Model.startingAMPAReceptors; lastOutcome = nil; history = [] }
                }
                .accessibilityIdentifier("lab.plasticity.reset")
            }
            Text(text(calciumFlows ? "lab.plasticity.nmdaOpen" : "lab.plasticity.nmdaBlocked"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabStatusBadge(kind: outcome.kind, text: outcome.text, identifier: "lab.plasticity.outcome")
            Text(String(format: text("lab.plasticity.strength"), String(receptors), String(Model.response(ampaReceptors: receptors, glutamate: true))))
                .font(.headline.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.plasticity.strength")
            if !history.isEmpty {
                historyBars
                    .frame(height: 70)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(text("lab.plasticity.history"))
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.plasticity.challenge"), solved: receptors >= 6, solvedText: text("lab.plasticity.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.plasticity.hint"), text("lab.plasticity.limit")])
        }
    }

    // Presynaptic terminal, glutamate in the cleft, the postsynaptic membrane with AMPA receptors and an NMDA channel
    // (plugged by magnesium unless both conditions hold), and a meter for the response to the same glutamate release.
    private func synapse(calciumFlows: Bool) -> some View {
        Canvas { context, size in
            let width = size.width * 0.78
            let terminal = CGRect(x: size.width * 0.06, y: 6, width: width, height: size.height * 0.28)
            context.fill(Path(roundedRect: terminal, cornerRadius: 30), with: .color(.teal.opacity(0.35)))
            context.draw(Text(text("lab.plasticity.pre")).font(.caption.weight(.semibold)).foregroundColor(.secondary),
                         at: CGPoint(x: terminal.minX + 14, y: terminal.minY + 14), anchor: .topLeading)
            let membraneY = size.height * 0.68
            context.fill(Path(CGRect(x: size.width * 0.06, y: membraneY, width: width, height: 14)), with: .color(.secondary.opacity(0.35)))
            context.draw(Text(text("lab.plasticity.post")).font(.caption.weight(.semibold)).foregroundColor(.secondary),
                         at: CGPoint(x: size.width * 0.06 + 14, y: membraneY + 34), anchor: .topLeading)
            if glutamate {
                for index in 0..<14 {
                    let x = size.width * 0.1 + CGFloat(index) * width / 14.5
                    let y = terminal.maxY + 10 + CGFloat((index * 37) % 5) * 9
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 8, height: 8)), with: .color(.green))
                }
            }
            let slot = width * 0.72 / CGFloat(Model.maximumAMPAReceptors)
            for index in 0..<Model.maximumAMPAReceptors {
                let rect = CGRect(x: size.width * 0.08 + CGFloat(index) * slot + slot * 0.18, y: membraneY - 18, width: slot * 0.64, height: 48)
                if index < receptors {
                    context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(.blue))
                } else {
                    context.stroke(Path(roundedRect: rect, cornerRadius: 5), with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            context.draw(Text(verbatim: "AMPA").font(.caption2.weight(.bold)).foregroundColor(.blue), at: CGPoint(x: size.width * 0.1, y: membraneY - 28), anchor: .leading)
            let channelX = size.width * 0.06 + width * 0.86
            let channel = CGRect(x: channelX - 16, y: membraneY - 22, width: 32, height: 56)
            context.stroke(Path(roundedRect: channel, cornerRadius: 6), with: .color(.purple), lineWidth: 3)
            context.draw(Text(verbatim: "NMDA").font(.caption2.weight(.bold)).foregroundColor(.purple), at: CGPoint(x: channelX, y: membraneY - 32))
            if calciumFlows {
                for step in 0..<4 {
                    let y = membraneY - 10 + CGFloat(step) * 18
                    context.fill(Path(ellipseIn: CGRect(x: channelX - 6, y: y, width: 12, height: 12)), with: .color(.orange))
                }
                context.draw(Text(verbatim: "Ca²⁺").font(.caption.weight(.bold)).foregroundColor(.orange), at: CGPoint(x: channelX + 26, y: membraneY + 40), anchor: .leading)
            } else {
                context.fill(Path(ellipseIn: CGRect(x: channelX - 12, y: membraneY - 6, width: 24, height: 24)), with: .color(.gray))
                context.draw(Text(verbatim: "Mg²⁺").font(.caption.weight(.bold)).foregroundColor(.secondary), at: CGPoint(x: channelX + 22, y: membraneY + 6), anchor: .leading)
            }
            let meter = CGRect(x: size.width * 0.9, y: 10, width: 26, height: size.height - 34)
            context.fill(Path(roundedRect: meter, cornerRadius: 8), with: .color(.secondary.opacity(0.15)))
            let share = CGFloat(receptors) / CGFloat(Model.maximumAMPAReceptors)
            context.fill(Path(roundedRect: CGRect(x: meter.minX, y: meter.maxY - meter.height * share, width: meter.width, height: meter.height * share), cornerRadius: 8),
                         with: .color(.blue))
            context.draw(Text(text("lab.plasticity.meter")).font(.caption2.weight(.semibold)).foregroundColor(.secondary), at: CGPoint(x: meter.midX, y: size.height - 10))
        }
    }

    // The response after every stimulation, so the strengthening over trials is visible at a glance.
    private var historyBars: some View {
        Canvas { context, size in
            let shown = Array(history.suffix(16))
            let slot = size.width / 16
            for (index, value) in shown.enumerated() {
                let height = (size.height - 14) * CGFloat(value) / CGFloat(Model.maximumAMPAReceptors)
                let rect = CGRect(x: CGFloat(index) * slot + slot * 0.15, y: size.height - 14 - height, width: slot * 0.7, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.blue.opacity(0.75)))
            }
            context.draw(Text(text("lab.plasticity.history")).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: 0, y: size.height), anchor: .bottomLeading)
        }
    }
}

private struct MichaelisMentenLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var substrate = 6.0
    @State private var michaelisConstant = 2.0
    @State private var maximumRate = 100.0

    private typealias Model = MichaelisMentenModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let rate = Model.rate(substrate: substrate, maximumRate: maximumRate, michaelisConstant: michaelisConstant)
        let share = Model.shareOfMaximum(substrate: substrate, michaelisConstant: michaelisConstant)
        LabCard {
            LabHeader(title: text("lab.enzyme.title"), instruction: text("lab.enzyme.subtitle"))

            GeometryReader { proxy in
                let plot = LabPlotGeometry(size: proxy.size, x: Model.substrateRange, y: 0...Model.maximumRateRange.upperBound * 1.05)
                curve(plot)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        let value = plot.value(at: drag.location).x
                        substrate = min(max((value * 2).rounded() / 2, Model.substrateRange.lowerBound), Model.substrateRange.upperBound)
                    })
            }
            .frame(height: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.enzyme.chart"))
            .accessibilityValue(Text(verbatim: "\(number(substrate, 1)); \(number(rate, 1))"))

            LabStatGrid {
                LabStat(label: text("lab.enzyme.statRate"), value: number(rate, 1), tint: .orange, identifier: "lab.enzyme.rate")
                LabStat(label: text("lab.enzyme.statShare"), value: number(share * 100, 0) + " %", tint: share >= 0.9 ? .green : .accentColor)
                LabStat(label: text("lab.enzyme.statRatio"), value: number(substrate / michaelisConstant, 1), tint: .purple)
            }
            busyBar(share: share)

            slider(String(format: text("lab.enzyme.substrate"), number(substrate, 1)), "lab.enzyme.substrateLabel", "lab.enzyme.substrate",
                   Binding(get: { substrate }, set: { substrate = ($0 * 2).rounded() / 2 }), Model.substrateRange)
            slider(String(format: text("lab.enzyme.km"), number(michaelisConstant, 1)), "lab.enzyme.kmLabel", "lab.enzyme.km",
                   Binding(get: { michaelisConstant }, set: { michaelisConstant = ($0 * 2).rounded() / 2 }), Model.michaelisRange)
            slider(String(format: text("lab.enzyme.vmax"), number(maximumRate, 0)), "lab.enzyme.vmaxLabel", "lab.enzyme.vmax",
                   Binding(get: { maximumRate }, set: { maximumRate = ($0 / 10).rounded() * 10 }), Model.maximumRateRange)

            LabChallenge(caption: text("lab.kit.task"), task: text("lab.enzyme.challenge"), solved: abs(share - 0.9) < 0.005, solvedText: text("lab.enzyme.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.enzyme.hint"),
                String(format: text("lab.enzyme.half"), number(michaelisConstant, 1), number(maximumRate / 2, 0)),
                text("lab.enzyme.limit"),
            ])
        }
    }

    private func slider(_ title: String, _ labelKey: String, _ identifier: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title).monospacedDigit().frame(minWidth: 290, alignment: .leading)
            // Each slider rounds without `step:`, which would draw a dense row of tick marks.
            Slider(value: value, in: range)
                .accessibilityLabel(text(labelKey))
                .accessibilityIdentifier(identifier)
        }
    }

    // How many enzyme molecules are busy at this concentration: twenty little enzymes, the busy share filled.
    private func busyBar(share: Double) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Double(index) < share * 20 ? Color.orange : Color.secondary.opacity(0.2))
                    .frame(height: 16)
            }
            Text(text("lab.enzyme.busy")).font(.caption).foregroundStyle(.secondary).fixedSize()
        }
        .animation(.easeInOut(duration: 0.2), value: share)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text("lab.enzyme.busy"))
        .accessibilityValue(Text(verbatim: number(share * 100, 0)))
    }

    // The saturation curve with Vmax and Vmax/2 marked, Km on the axis, and a draggable point at the chosen [S].
    private func curve(_ plot: LabPlotGeometry) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: text("lab.enzyme.axisX"), yLabel: text("lab.enzyme.axisY"), format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect))
            var levels = Path()
            levels.move(to: plot.point(0, maximumRate))
            levels.addLine(to: plot.point(plot.x.upperBound, maximumRate))
            levels.move(to: plot.point(0, maximumRate / 2))
            levels.addLine(to: plot.point(michaelisConstant, maximumRate / 2))
            levels.addLine(to: plot.point(michaelisConstant, 0))
            clipped.stroke(levels, with: .color(.secondary), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            clipped.draw(Text(verbatim: "Vmax").font(.caption.weight(.semibold)).foregroundColor(.secondary), at: plot.point(plot.x.upperBound - 1, maximumRate + 6), anchor: .bottomTrailing)
            clipped.draw(Text(verbatim: "Vmax/2").font(.caption.weight(.semibold)).foregroundColor(.secondary), at: plot.point(michaelisConstant + 0.6, maximumRate / 2 + 4), anchor: .bottomLeading)
            clipped.draw(Text(verbatim: "Km").font(.caption.weight(.bold)).foregroundColor(.purple), at: plot.point(michaelisConstant + 0.4, 6), anchor: .bottomLeading)
            var area = Path()
            area.move(to: plot.point(0, 0))
            var line = Path()
            for index in 0...200 {
                let x = plot.x.upperBound * Double(index) / 200
                let location = plot.point(x, Model.rate(substrate: x, maximumRate: maximumRate, michaelisConstant: michaelisConstant))
                area.addLine(to: location)
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
            }
            area.addLine(to: plot.point(plot.x.upperBound, 0))
            area.closeSubpath()
            clipped.fill(area, with: .color(.accentColor.opacity(0.12)))
            clipped.stroke(line, with: .color(.accentColor), lineWidth: 2.5)
            let current = plot.point(substrate, Model.rate(substrate: substrate, maximumRate: maximumRate, michaelisConstant: michaelisConstant))
            var guide = Path()
            guide.move(to: CGPoint(x: current.x, y: plot.rect.maxY))
            guide.addLine(to: current)
            guide.addLine(to: CGPoint(x: plot.rect.minX, y: current.y))
            clipped.stroke(guide, with: .color(.orange.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            clipped.fill(Path(ellipseIn: CGRect(x: current.x - 8, y: current.y - 8, width: 16, height: 16)), with: .color(.orange))
            clipped.stroke(Path(ellipseIn: CGRect(x: current.x - 8, y: current.y - 8, width: 16, height: 16)), with: .color(.white), lineWidth: 2)
        }
    }
}

private struct EulerMethodLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var stepIndex = 0
    @State private var endTime = 2

    private typealias Model = EulerMethodModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var stepSize: Double { Model.stepSizes[stepIndex] }
    private func stepLabel(_ index: Int) -> String { "h = " + number(Model.stepSizes[index], [0, 1, 2, 1][index]) }

    var body: some View {
        let euler = Model.eulerValue(stepSize: stepSize, endTime: endTime)
        let exact = Model.exactValue(at: Double(endTime))
        let relative = (exact - euler) / exact * 100
        LabCard {
            LabHeader(title: text("lab.euler.title"), instruction: text("lab.euler.subtitle"))

            chart
                .frame(height: 280)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.euler.chart"))
                .accessibilityValue(Text(verbatim: "\(number(euler, 2)); \(number(exact, 2))"))

            Picker(text("lab.euler.stepLabel"), selection: $stepIndex.animation(.easeInOut(duration: 0.3))) {
                ForEach(Model.stepSizes.indices, id: \.self) { index in Text(verbatim: stepLabel(index)).tag(index) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.euler.step")
            HStack(spacing: 12) {
                Text(String(format: text("lab.euler.endTime"), String(endTime))).monospacedDigit().frame(minWidth: 190, alignment: .leading)
                // Whole time units without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { Double(endTime) }, set: { endTime = Int($0.rounded()) }),
                       in: Double(Model.endTimeRange.lowerBound)...Double(Model.endTimeRange.upperBound))
                    .accessibilityLabel(text("lab.euler.endTimeLabel"))
                    .accessibilityValue(Text(verbatim: String(endTime)))
                    .accessibilityIdentifier("lab.euler.endTime")
            }

            LabStatGrid {
                LabStat(label: String(format: text("lab.euler.statEuler"), String(Model.stepCount(stepSize: stepSize, endTime: endTime))),
                        value: number(euler, 2), tint: .orange, identifier: "lab.euler.result")
                LabStat(label: text("lab.euler.statExact"), value: number(exact, 2), identifier: "lab.euler.exact")
                LabStat(label: text("lab.euler.statError"), value: "\(number(exact - euler, 2)) · \(number(relative, 2)) %", tint: relative < 1 ? .green : .red)
            }
            errorBars
                .frame(height: 96)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.euler.errorChart"))

            LabChallenge(caption: text("lab.kit.task"), task: text("lab.euler.challenge"), solved: endTime >= 10 && relative < 1, solvedText: text("lab.euler.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.euler.hint"), text("lab.euler.limit")])
        }
    }

    // The exact curve, Euler's broken line with a dot after each step, and the final error as a red bar.
    private var chart: some View {
        Canvas { context, size in
            let maxX = Double(endTime), maxY = Model.exactValue(at: maxX) * 1.08
            let plot = LabPlotGeometry(size: size, x: 0...maxX, y: 0...maxY)
            plot.drawAxes(in: context, xLabel: "t", yLabel: "N", format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -6, dy: -6)))
            var exactPath = Path()
            for index in 0...200 {
                let t = maxX * Double(index) / 200
                let location = plot.point(t, Model.exactValue(at: t))
                if index == 0 { exactPath.move(to: location) } else { exactPath.addLine(to: location) }
            }
            clipped.stroke(exactPath, with: .color(.accentColor), lineWidth: 2.5)
            let points = Model.eulerPoints(stepSize: stepSize, endTime: endTime)
            var eulerPath = Path()
            for (index, point) in points.enumerated() {
                let location = plot.point(point.t, point.value)
                if index == 0 { eulerPath.move(to: location) } else { eulerPath.addLine(to: location) }
            }
            clipped.stroke(eulerPath, with: .color(.orange), lineWidth: 2)
            if points.count <= 60 {
                for point in points {
                    let location = plot.point(point.t, point.value)
                    clipped.fill(Path(ellipseIn: CGRect(x: location.x - 3.5, y: location.y - 3.5, width: 7, height: 7)), with: .color(.orange))
                }
            }
            let last = plot.point(maxX, points.last?.value ?? 0), top = plot.point(maxX, Model.exactValue(at: maxX))
            var error = Path()
            error.move(to: last)
            error.addLine(to: top)
            clipped.stroke(error, with: .color(.red), lineWidth: 4)
        }
    }

    // The final error for every step size at the chosen end time: halving h roughly halves the error.
    private var errorBars: some View {
        Canvas { context, size in
            let errors = Model.stepSizes.map { Model.exactValue(at: Double(endTime)) - Model.eulerValue(stepSize: $0, endTime: endTime) }
            let top = errors.max() ?? 1
            let slot = size.width / CGFloat(errors.count)
            for (index, error) in errors.enumerated() {
                let height = (size.height - 34) * CGFloat(error / top)
                let rect = CGRect(x: CGFloat(index) * slot + slot * 0.25, y: size.height - 18 - height, width: slot * 0.5, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(index == stepIndex ? .red : .red.opacity(0.3)))
                context.draw(Text(verbatim: number(error, 2)).font(.caption2.weight(.semibold)).foregroundColor(.secondary), at: CGPoint(x: rect.midX, y: rect.minY - 7))
                context.draw(Text(verbatim: stepLabel(index)).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: rect.midX, y: size.height - 7))
            }
        }
    }
}

private struct AutocatalysisLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var hours = 10
    @State private var logarithmic = false
    @State private var playing = false

    private typealias Model = AutocatalysisModel

    private var locale: Locale { Locale(identifier: store.language == .ru ? "ru_RU" : "en_US") }
    private func grouped(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let ratio = Double(Model.autocatalytic(hours: hours)) / Double(Model.catalysed(hours: hours))
        LabCard {
            LabHeader(title: text("lab.autocatalysis.title"), instruction: text("lab.autocatalysis.subtitle"))

            chart
                .frame(height: 280)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.autocatalysis.chart"))
                .accessibilityValue(Text(verbatim: "\(grouped(Model.catalysed(hours: hours))); \(grouped(Model.autocatalytic(hours: hours)))"))

            HStack(spacing: 12) {
                Button {
                    if hours >= Model.hourRange.upperBound { hours = 0 }
                    playing.toggle()
                } label: {
                    Label(text(playing ? "lab.descent2d.pause" : "lab.autocatalysis.play"), systemImage: playing ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("lab.autocatalysis.play")
                Text(String(format: text("lab.autocatalysis.hours"), String(hours))).monospacedDigit().frame(minWidth: 140, alignment: .leading)
                // Whole hours without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { Double(hours) }, set: { hours = Int($0.rounded()) }),
                       in: Double(Model.hourRange.lowerBound)...Double(Model.hourRange.upperBound))
                    .accessibilityLabel(text("lab.autocatalysis.hoursLabel"))
                    .accessibilityValue(Text(verbatim: String(hours)))
                    .accessibilityIdentifier("lab.autocatalysis.hours")
            }
            Toggle(text("lab.autocatalysis.log"), isOn: $logarithmic.animation(.easeInOut(duration: 0.4)))
                .accessibilityIdentifier("lab.autocatalysis.log")

            LabStatGrid {
                LabStat(label: text("lab.autocatalysis.statCatalyst"), value: grouped(Model.catalysed(hours: hours)), tint: .secondary)
                LabStat(label: text("lab.autocatalysis.statAuto"), value: grouped(Model.autocatalytic(hours: hours)), tint: .accentColor)
                LabStat(label: text("lab.autocatalysis.statRatio"), value: "× " + L10n.number(ratio, fractionDigits: ratio < 10 ? 1 : 0, store.language), tint: .orange)
            }
            Text(String(format: text("lab.autocatalysis.counts"), String(hours), grouped(Model.catalysed(hours: hours)), grouped(Model.autocatalytic(hours: hours))))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.autocatalysis.counts")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.autocatalysis.challenge"), solved: ratio > 1000, solvedText: text("lab.autocatalysis.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.autocatalysis.hint"),
                String(format: text("lab.autocatalysis.overtake"), String(Model.overtakingHour)),
                text("lab.autocatalysis.logNote"),
                text("lab.autocatalysis.limit"),
            ])
        }
        .task(id: playing) {
            guard playing else { return }
            while playing && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard playing else { break }
                withAnimation(.easeInOut(duration: 0.35)) { hours += 1 }
                if hours >= Model.hourRange.upperBound { playing = false }
            }
        }
    }

    // Both processes from hour 0 to the chosen hour, on a linear axis or a log₂ axis labelled 1, 2, 4, 8, …
    private var chart: some View {
        Canvas { context, size in
            let maxX = Double(max(hours, 1))
            func scaled(_ count: Int) -> Double { logarithmic ? log2(Double(count)) : Double(count) }
            let top = max(scaled(Model.autocatalytic(hours: max(hours, 1))), 1) * 1.1
            let plot = LabPlotGeometry(size: size, x: 0...maxX, y: 0...top, leading: 64)
            let yTicks = logarithmic ? LabPlotGeometry.ticks(0...top, count: 5).map { $0.rounded() } : nil
            plot.drawAxes(in: context, xLabel: text("lab.autocatalysis.axisX"), yLabel: text("lab.autocatalysis.axisY"),
                          yTicks: yTicks, format: { value in
                              logarithmic && value <= top ? grouped(Int(pow(2, value).rounded())) : grouped(Int(value.rounded()))
                          })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -6, dy: -6)))
            for (series, color, label) in [(Model.catalysed, Color.secondary, "lab.autocatalysis.statCatalyst"), (Model.autocatalytic, Color.accentColor, "lab.autocatalysis.statAuto")] {
                var path = Path()
                for hour in 0...max(hours, 1) {
                    let location = plot.point(Double(hour), scaled(series(hour)))
                    if hour == 0 { path.move(to: location) } else { path.addLine(to: location) }
                    clipped.fill(Path(ellipseIn: CGRect(x: location.x - 3.5, y: location.y - 3.5, width: 7, height: 7)), with: .color(color))
                }
                clipped.stroke(path, with: .color(color), lineWidth: 2.5)
                let end = plot.point(maxX, scaled(series(max(hours, 1))))
                context.draw(Text(text(label)).font(.caption.weight(.semibold)).foregroundColor(color), at: CGPoint(x: end.x - 8, y: end.y - 12), anchor: .trailing)
            }
        }
    }
}

private struct NeuralLayerLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var weights = [[1, 2], [0, -1]]
    @State private var input = [3, 4]
    @State private var bias = [0, 0]
    @State private var useReLU = false

    private typealias Model = NeuralLayerModel

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func signed(_ value: Int) -> String { value < 0 ? "(−\(-value))" : String(value) }
    private func plain(_ value: Int) -> String { value < 0 ? "−\(-value)" : String(value) }

    var body: some View {
        let raw = Model.preActivation(weights: weights, input: input, bias: bias)
        let output = useReLU ? Model.relu(raw) : raw
        LabCard {
            LabHeader(title: text("lab.layer.title"), instruction: text("lab.layer.subtitle"))

            network(raw: raw, output: output)
                .frame(height: 240)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.layer.diagram"))
                .accessibilityValue(Text(verbatim: "(\(plain(output[0])), \(plain(output[1])))"))

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        Text(String(format: text("lab.layer.neuronLabel"), String(row + 1))).font(.callout.weight(.semibold))
                        stepper("w\(row + 1)1", $weights[row][0], Model.weightRange, "lab.layer.w\(row + 1)1")
                        stepper("w\(row + 1)2", $weights[row][1], Model.weightRange, "lab.layer.w\(row + 1)2")
                        stepper("b\(row + 1)", $bias[row], Model.biasRange, "lab.layer.b\(row + 1)")
                    }
                }
                GridRow {
                    Text(text("lab.layer.inputLabel")).font(.callout.weight(.semibold))
                    stepper("x1", $input[0], Model.inputRange, "lab.layer.x1")
                    stepper("x2", $input[1], Model.inputRange, "lab.layer.x2")
                }
            }
            Toggle(text("lab.layer.relu"), isOn: $useReLU.animation())
                .accessibilityIdentifier("lab.layer.relu")

            LabStatGrid {
                LabStat(label: text(useReLU ? "lab.layer.outputReLUShort" : "lab.layer.outputShort"),
                        value: "(\(plain(output[0])), \(plain(output[1])))", identifier: "lab.layer.output")
                ForEach(0..<2, id: \.self) { row in
                    LabStat(label: String(format: text("lab.layer.neuronLabel"), String(row + 1)),
                            value: "\(signed(weights[row][0]))·\(signed(input[0])) + \(signed(weights[row][1]))·\(signed(input[1])) + \(signed(bias[row])) = \(plain(raw[row]))",
                            tint: raw[row] >= 0 ? .blue : .red)
                }
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.layer.challenge"), solved: output == [0, 7], solvedText: text("lab.layer.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.layer.hint"), text("lab.layer.limit")])
        }
    }

    private func stepper(_ name: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, _ identifier: String) -> some View {
        Stepper(value: value.animation(.easeInOut(duration: 0.2)), in: range) {
            Text(verbatim: "\(name) = \(plain(value.wrappedValue))")
                .monospacedDigit()
                .frame(minWidth: 62, alignment: .leading)
        }
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(verbatim: plain(value.wrappedValue)))
        .accessibilityIdentifier(identifier)
    }

    // Inputs on the left, neurons on the right; each connection's thickness is |w|, blue for positive weights
    // (excitation) and red for negative (inhibition). A neuron silenced by ReLU is drawn grey.
    private func network(raw: [Int], output: [Int]) -> some View {
        Canvas { context, size in
            let inputs = [CGPoint(x: size.width * 0.18, y: size.height * 0.3), CGPoint(x: size.width * 0.18, y: size.height * 0.75)]
            let neurons = [CGPoint(x: size.width * 0.72, y: size.height * 0.3), CGPoint(x: size.width * 0.72, y: size.height * 0.75)]
            for (row, neuron) in neurons.enumerated() {
                for (column, source) in inputs.enumerated() {
                    let weight = weights[row][column]
                    var line = Path()
                    line.move(to: source)
                    line.addLine(to: neuron)
                    let color: Color = weight > 0 ? .blue : (weight < 0 ? .red : .secondary)
                    context.stroke(line, with: .color(color.opacity(weight == 0 ? 0.25 : 0.75)),
                                   style: StrokeStyle(lineWidth: 1 + 2.4 * CGFloat(abs(weight)), lineCap: .round, dash: weight == 0 ? [4, 4] : []))
                    let share: CGFloat = column == row ? 0.5 : 0.2
                    let label = CGPoint(x: source.x + (neuron.x - source.x) * share, y: source.y + (neuron.y - source.y) * share - 10)
                    context.draw(Text(verbatim: "w\(row + 1)\(column + 1) = \(plain(weight))").font(.caption.weight(.semibold)).foregroundColor(color), at: label)
                }
            }
            for (index, source) in inputs.enumerated() {
                context.fill(Path(ellipseIn: CGRect(x: source.x - 26, y: source.y - 26, width: 52, height: 52)), with: .color(.teal.opacity(0.85)))
                context.draw(Text(verbatim: plain(input[index])).font(.title3.weight(.bold)).foregroundColor(.white), at: source)
                context.draw(Text(verbatim: "x\(index + 1)").font(.caption.weight(.semibold)).foregroundColor(.secondary), at: CGPoint(x: source.x - 44, y: source.y))
            }
            for (index, neuron) in neurons.enumerated() {
                let silenced = useReLU && raw[index] < 0
                let fill: Color = silenced ? .gray : (output[index] >= 0 ? .blue : .red)
                context.fill(Path(ellipseIn: CGRect(x: neuron.x - 32, y: neuron.y - 32, width: 64, height: 64)), with: .color(fill.opacity(0.85)))
                context.draw(Text(verbatim: plain(output[index])).font(.title2.weight(.bold)).foregroundColor(.white), at: neuron)
                context.draw(Text(verbatim: "b\(index + 1) = \(plain(bias[index]))").font(.caption).foregroundColor(.secondary), at: CGPoint(x: neuron.x, y: neuron.y - 44))
                if silenced {
                    context.draw(Text(verbatim: "ReLU: \(plain(raw[index])) → 0").font(.caption.weight(.semibold)).foregroundColor(.secondary),
                                 at: CGPoint(x: neuron.x + 44, y: neuron.y), anchor: .leading)
                }
            }
        }
    }
}

private struct GradientDescent2DLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var rate = 0.1
    @State private var path = [GradientDescent2DModel.starts[0]]
    @State private var playing = false

    private typealias Model = GradientDescent2DModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var point: Model.Point { path.last ?? Model.starts[0] }
    private var settled: Bool { Model.value(point) < 1e-4 || Model.hasDiverged(point) || path.count > 60 }

    private var status: (kind: LabStatusKind, text: String) {
        if !Model.converges(rate: rate) { return (.bad, text("lab.descent2d.diverges")) }
        if Model.xFactor(rate: rate) < 0 || Model.yFactor(rate: rate) < 0 { return (.warning, text("lab.descent2d.oscillates")) }
        return (.good, text("lab.descent2d.converges"))
    }

    var body: some View {
        let slope = Model.gradient(point)
        LabCard {
            LabHeader(title: text("lab.descent2d.title"), instruction: text("lab.descent2d.subtitle"))

            GeometryReader { proxy in
                let plot = LabPlotGeometry(size: proxy.size, x: -3...3, y: -2...2)
                map(plot)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onEnded { drag in
                        let value = plot.value(at: drag.location)
                        playing = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            path = [Model.Point(x: min(max(value.x, -3), 3), y: min(max(value.y, -2), 2))]
                        }
                    })
            }
            .frame(height: 300)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.descent2d.chart"))
            .accessibilityValue(Text(verbatim: "(\(number(point.x, 3)); \(number(point.y, 3)))"))

            HStack(spacing: 12) {
                Text(String(format: text("lab.descent2d.rate"), number(rate, 2)))
                    .monospacedDigit()
                    .frame(minWidth: 190, alignment: .leading)
                // Rounds to hundredths without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { rate }, set: { rate = ($0 * 100).rounded() / 100 }), in: Model.rateRange)
                    .accessibilityLabel(text("lab.descent2d.rateLabel"))
                    .accessibilityValue(Text(verbatim: number(rate, 2)))
                    .accessibilityIdentifier("lab.descent2d.rate")
            }
            HStack(spacing: 10) {
                Button {
                    if settled { path = [path.first ?? Model.starts[0]] }
                    playing.toggle()
                } label: {
                    Label(text(playing ? "lab.descent2d.pause" : "lab.descent2d.play"), systemImage: playing ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("lab.descent2d.play")
                Button(text("lab.descent2d.step")) { advance() }
                    .accessibilityIdentifier("lab.descent2d.step")
                Button(text("lab.descent2d.reset")) {
                    playing = false
                    withAnimation { path = [path.first ?? Model.starts[0]] }
                }
                .accessibilityIdentifier("lab.descent2d.reset")
            }

            LabStatGrid {
                LabStat(label: text("lab.descent2d.statStep"), value: String(path.count - 1))
                LabStat(label: text("lab.descent2d.statPoint"), value: "(\(number(point.x, 3)); \(number(point.y, 3)))", identifier: "lab.descent2d.point")
                LabStat(label: text("lab.descent2d.statValue"), value: number(Model.value(point), 3), tint: .orange)
                LabStat(label: text("lab.descent2d.statGradient"), value: number((slope.x * slope.x + slope.y * slope.y).squareRoot(), 3), tint: .red)
            }

            lossChart
                .frame(height: 120)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.descent2d.lossChart"))

            LabStatusBadge(kind: status.kind, text: status.text, identifier: "lab.descent2d.verdict")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.descent2d.challenge"),
                         solved: Model.converges(rate: rate) && rate >= 0.33 - 1e-9, solvedText: text("lab.descent2d.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.descent2d.hint"),
                String(format: text("lab.descent2d.factors"), number(Model.xFactor(rate: rate), 2), number(Model.yFactor(rate: rate), 2)),
                text("lab.descent2d.limit"),
            ])
        }
        .task(id: playing) {
            guard playing else { return }
            while playing && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 320_000_000)
                guard playing else { break }
                advance()
                if settled { playing = false }
            }
        }
    }

    private func advance() {
        guard !Model.hasDiverged(point) else { playing = false; return }
        withAnimation(.easeInOut(duration: 0.25)) { path.append(Model.step(point, rate: rate)) }
    }

    // A heat map of f with level curves, the minimum, the path so far, and an arrow for the next step.
    private func map(_ plot: LabPlotGeometry) -> some View {
        Canvas { context, _ in
            let columns = 150, rows = 75
            let cellWidth = plot.rect.width / CGFloat(columns), cellHeight = plot.rect.height / CGFloat(rows)
            for column in 0..<columns {
                for row in 0..<rows {
                    let x = plot.x.lowerBound + (Double(column) + 0.5) / Double(columns) * 6
                    let y = plot.y.upperBound - (Double(row) + 0.5) / Double(rows) * 4
                    let cell = CGRect(x: plot.rect.minX + CGFloat(column) * cellWidth, y: plot.rect.minY + CGFloat(row) * cellHeight,
                                      width: cellWidth + 0.5, height: cellHeight + 0.5)
                    context.fill(Path(cell), with: .color(LabHeatScale.color((Model.value(Model.Point(x: x, y: y)) / 21).squareRoot())))
                }
            }
            var clipped = context
            clipped.clip(to: Path(plot.rect))
            for level in [0.25, 1, 2.5, 5, 9, 16] {
                let a = level.squareRoot(), b = (level / 3).squareRoot()
                let topLeft = plot.point(-a, b), bottomRight = plot.point(a, -b)
                clipped.stroke(Path(ellipseIn: CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)),
                               with: .color(.white.opacity(0.35)), lineWidth: 1)
            }
            plot.drawAxes(in: context, xLabel: "x", yLabel: "y", format: { number($0, 0) })
            let minimum = plot.point(0, 0)
            clipped.fill(Path(ellipseIn: CGRect(x: minimum.x - 6, y: minimum.y - 6, width: 12, height: 12)), with: .color(.green))
            clipped.draw(Text(text("lab.descent2d.minimum")).font(.caption.weight(.semibold)).foregroundColor(.white),
                         at: CGPoint(x: minimum.x + 10, y: minimum.y + 12), anchor: .topLeading)
            var trail = Path()
            for (index, p) in path.enumerated() {
                if index == 0 { trail.move(to: plot.point(p.x, p.y)) } else { trail.addLine(to: plot.point(p.x, p.y)) }
            }
            clipped.stroke(trail, with: .color(.orange), lineWidth: 2)
            for p in path.dropLast() {
                let location = plot.point(p.x, p.y)
                clipped.fill(Path(ellipseIn: CGRect(x: location.x - 3, y: location.y - 3, width: 6, height: 6)), with: .color(.orange))
            }
            let next = Model.step(point, rate: rate)
            let from = plot.point(point.x, point.y), to = plot.point(next.x, next.y)
            var arrow = Path()
            arrow.move(to: from)
            arrow.addLine(to: to)
            let angle = atan2(to.y - from.y, to.x - from.x)
            for side in [-0.45, 0.45] {
                arrow.move(to: to)
                arrow.addLine(to: CGPoint(x: to.x - 10 * cos(angle + side), y: to.y - 10 * sin(angle + side)))
            }
            clipped.stroke(arrow, with: .color(.red), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            clipped.fill(Path(ellipseIn: CGRect(x: from.x - 7, y: from.y - 7, width: 14, height: 14)), with: .color(.white))
            clipped.fill(Path(ellipseIn: CGRect(x: from.x - 5, y: from.y - 5, width: 10, height: 10)), with: .color(.accentColor))
        }
    }

    // f after each step: the loss curve a neural network's training plots in the same way.
    private var lossChart: some View {
        Canvas { context, size in
            let values = path.map(Model.value)
            let top = max(min(values.max() ?? 1, 50), 0.5)
            let plot = LabPlotGeometry(size: size, x: 0...Double(max(values.count - 1, 5)), y: 0...top * 1.1)
            plot.drawAxes(in: context, xLabel: text("lab.descent2d.lossX"), yLabel: "f", format: { number($0, $0 < 10 && $0 != $0.rounded() ? 1 : 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -4, dy: -4)))
            var line = Path()
            for (index, value) in values.enumerated() {
                let location = plot.point(Double(index), min(value, top * 1.1))
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
                clipped.fill(Path(ellipseIn: CGRect(x: location.x - 2.5, y: location.y - 2.5, width: 5, height: 5)), with: .color(.orange))
            }
            clipped.stroke(line, with: .color(.orange), lineWidth: 2)
        }
    }
}

private struct GenomeFidelityLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var exponent = 2
    @State private var advantage = 10.0

    private typealias Model = GenomeFidelityModel

    private var locale: Locale { Locale(identifier: store.language == .ru ? "ru_RU" : "en_US") }
    private func grouped(_ value: Double) -> String { Int(value.rounded()).formatted(.number.locale(locale)) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let exact = Model.exactLimit(exponent: exponent, advantage: advantage)
        LabCard {
            LabHeader(title: text("lab.fidelity.title"), instruction: text("lab.fidelity.subtitle"))

            ladder(limit: exact)
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.fidelity.ladder"))
                .accessibilityValue(Text(verbatim: grouped(exact)))

            LabStatGrid {
                LabStat(label: text("lab.fidelity.statError"), value: "1 / " + grouped(pow(10, Double(exponent))), tint: .red)
                LabStat(label: text("lab.fidelity.statLimit"), value: grouped(exact), tint: .green, identifier: "lab.fidelity.exact")
                LabStat(label: text("lab.fidelity.statApprox"), value: grouped(Model.approximateLimit(exponent: exponent, advantage: advantage)), tint: .secondary)
            }
            HStack(spacing: 12) {
                Text(String(format: text("lab.fidelity.error"), String(exponent), grouped(pow(10, Double(exponent))))).monospacedDigit().frame(minWidth: 330, alignment: .leading)
                // Whole exponents only, without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { Double(exponent) }, set: { exponent = Int($0.rounded()) }),
                       in: Double(Model.exponentRange.lowerBound)...Double(Model.exponentRange.upperBound))
                    .accessibilityLabel(text("lab.fidelity.errorLabel"))
                    .accessibilityValue(Text(verbatim: "10^−\(exponent)"))
                    .accessibilityIdentifier("lab.fidelity.exponent")
            }
            HStack(spacing: 12) {
                Text(String(format: text("lab.fidelity.advantage"), grouped(advantage))).monospacedDigit().frame(minWidth: 330, alignment: .leading)
                Slider(value: Binding(get: { advantage }, set: { advantage = $0.rounded() }), in: Model.advantageRange)
                    .accessibilityLabel(text("lab.fidelity.advantageLabel"))
                    .accessibilityValue(Text(verbatim: grouped(advantage)))
                    .accessibilityIdentifier("lab.fidelity.advantage")
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.fidelity.challenge"), solved: exact >= 1e9 && advantage == 10, solvedText: text("lab.fidelity.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.fidelity.hint"), text("lab.fidelity.note")])
        }
    }

    // A logarithmic ladder from 1 to 10¹¹ letters with the two lesson values pinned and the current limit as a bar.
    private func ladder(limit: Double) -> some View {
        Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...11, y: 0...1, leading: 16, bottom: 34, top: 44, trailing: 16)
            let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
            context.fill(Path(roundedRect: CGRect(x: plot.rect.minX, y: plot.rect.midY - 14, width: plot.rect.width, height: 28), cornerRadius: 14),
                         with: .color(.secondary.opacity(0.15)))
            let share = CGFloat(log10(max(limit, 1)) / 11)
            context.fill(Path(roundedRect: CGRect(x: plot.rect.minX, y: plot.rect.midY - 14, width: max(28, plot.rect.width * share), height: 28), cornerRadius: 14),
                         with: .color(.green.opacity(0.8)))
            for power in stride(from: 0, through: 11, by: 1) {
                let x = plot.point(Double(power), 0).x
                context.draw(Text(verbatim: "10" + String(String(power).map { superscripts[$0] ?? $0 })).font(.caption2).foregroundColor(.secondary),
                             at: CGPoint(x: x, y: plot.rect.maxY + 14))
            }
            for (value, key) in [(229.0, "lab.fidelity.pin1"), (2.302585e9, "lab.fidelity.pin9")] {
                let x = plot.point(log10(value), 0).x
                var pin = Path()
                pin.move(to: CGPoint(x: x, y: plot.rect.midY - 18))
                pin.addLine(to: CGPoint(x: x, y: plot.rect.minY - 4))
                context.stroke(pin, with: .color(.orange), lineWidth: 2)
                context.draw(Text(text(key)).font(.caption.weight(.semibold)).foregroundColor(.orange), at: CGPoint(x: x, y: plot.rect.minY - 10), anchor: .bottom)
            }
        }
    }
}

private struct HammingDistanceLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var first = "ATGCCGTA"
    @State private var second = "ATGACGTT"

    private typealias Model = HammingModel
    private let bases: [Character] = ["A", "T", "G", "C"]

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private var cleanFirst: String { first.uppercased().filter { !$0.isWhitespace } }
    private var cleanSecond: String { second.uppercased().filter { !$0.isWhitespace } }

    private func baseColor(_ base: Character) -> Color {
        switch base {
        case "A": return .green
        case "T": return .red
        case "G": return .orange
        case "C": return .blue
        default: return .gray
        }
    }

    var body: some View {
        let mismatches = Model.mismatchPositions(cleanFirst, cleanSecond)
        LabCard {
            LabHeader(title: text("lab.hamming.title"), instruction: text("lab.hamming.subtitle"))

            if let mismatches {
                tiles(mismatches: Set(mismatches))
                LabStatGrid {
                    LabStat(label: text("lab.hamming.statDistance"), value: String(mismatches.count), tint: .orange)
                    LabStat(label: text("lab.hamming.statIdentity"), value: L10n.number(Model.identity(cleanFirst, cleanSecond) ?? 0, fractionDigits: 1, store.language) + " %", tint: .green)
                    LabStat(label: text("lab.hamming.statLength"), value: String(cleanFirst.count), tint: .secondary)
                }
                Text(String(format: text("lab.hamming.result"), String(mismatches.count),
                            L10n.number(Model.identity(cleanFirst, cleanSecond) ?? 0, fractionDigits: 1, store.language)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("lab.hamming.result")
            } else {
                LabStatusBadge(kind: .warning,
                               text: !Model.isValid(cleanFirst) || !Model.isValid(cleanSecond)
                                   ? text("lab.hamming.invalid")
                                   : String(format: text("lab.hamming.lengths"), String(cleanFirst.count), String(cleanSecond.count)),
                               identifier: "lab.hamming.result")
            }
            HStack(spacing: 10) {
                TextField(text("lab.hamming.first"), text: $first)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .accessibilityIdentifier("lab.hamming.first")
                TextField(text("lab.hamming.second"), text: $second)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .accessibilityIdentifier("lab.hamming.second")
                Button(text("lab.hamming.reset")) { withAnimation { first = "ATGCCGTA"; second = "ATGACGTT" } }
                    .accessibilityIdentifier("lab.hamming.reset")
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.hamming.challenge"),
                         solved: Model.identity(cleanFirst, cleanSecond) == 50, solvedText: text("lab.hamming.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.hamming.hint"), text("lab.hamming.limit")])
        }
    }

    // Two rows of letter tiles; clicking a tile in the lower row mutates it to the next base. Differences glow.
    private func tiles(mismatches: Set<Int>) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(zip(cleanFirst, cleanSecond).enumerated()), id: \.offset) { index, pair in
                    let differs = mismatches.contains(index + 1)
                    VStack(spacing: 6) {
                        tile(pair.0, differs: differs)
                        Text(verbatim: differs ? "≠" : "=").font(.headline).foregroundStyle(differs ? Color.orange : Color.secondary)
                        Button {
                            var letters = Array(cleanSecond)
                            let next = bases[((bases.firstIndex(of: letters[index]) ?? 0) + 1) % bases.count]
                            letters[index] = next
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { second = String(letters) }
                        } label: { tile(pair.1, differs: differs) }
                            .buttonStyle(.plain)
                            .help(text("lab.hamming.tileHelp"))
                        Text(verbatim: String(index + 1)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text("lab.hamming.alignment"))
    }

    private func tile(_ base: Character, differs: Bool) -> some View {
        Text(String(base))
            .font(.system(.title2, design: .monospaced).weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(baseColor(base).opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(differs ? Color.orange : Color.clear, lineWidth: 3))
    }
}

private struct RadioactiveDatingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var isotopeIndex = 0
    @State private var remainingPercent = 25.0

    private typealias Model = RadioactiveDatingModel

    private var locale: Locale { Locale(identifier: store.language == .ru ? "ru_RU" : "en_US") }
    private var isotope: Model.Isotope { Model.isotopes[isotopeIndex] }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }

    private func years(_ value: Double) -> String {
        if value >= 1e9 { return String(format: text("lab.dating.billionYears"), number(value / 1e9, 2)) }
        return String(format: text("lab.dating.years"), Int(value.rounded()).formatted(.number.locale(locale)))
    }

    var body: some View {
        let halfLives = Model.halfLives(remainingPercent: remainingPercent)
        let age = Model.age(remainingPercent: remainingPercent, isotope: isotope)
        LabCard {
            LabHeader(title: text("lab.dating.title"), instruction: text("lab.dating.subtitle"))
            Picker(text("lab.dating.isotope"), selection: $isotopeIndex) {
                Text(text("lab.dating.carbon")).tag(0)
                Text(text("lab.dating.uranium")).tag(1)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.dating.isotope")

            HStack(alignment: .top, spacing: 16) {
                GeometryReader { proxy in
                    let plot = LabPlotGeometry(size: proxy.size, x: 0...7, y: 0...105)
                    curve(plot, halfLives: halfLives)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                            let x = min(max(plot.value(at: drag.location).x, 0), log2(100))
                            remainingPercent = min(max((pow(0.5, x) * 1000).rounded() / 10, Model.remainingPercentRange.lowerBound), 100)
                        })
                }
                atoms
                    .frame(width: 190, height: 190)
            }
            .frame(height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.dating.chart"))
            .accessibilityValue(Text(verbatim: number(remainingPercent, 1)))

            HStack(spacing: 12) {
                Text(String(format: text("lab.dating.remaining"), number(remainingPercent, 1))).monospacedDigit().frame(minWidth: 210, alignment: .leading)
                // Whole percents without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { remainingPercent }, set: { remainingPercent = $0.rounded() }), in: Model.remainingPercentRange)
                    .accessibilityLabel(text("lab.dating.remainingLabel"))
                    .accessibilityIdentifier("lab.dating.remaining")
            }
            LabStatGrid {
                LabStat(label: text("lab.dating.statAge"), value: years(age), tint: .orange)
                LabStat(label: text("lab.dating.statHalfLives"), value: number(halfLives, 2), tint: .accentColor)
            }
            Text(String(format: text("lab.dating.age"), years(age), number(halfLives, 2)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.dating.age")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.dating.challenge"),
                         solved: isotopeIndex == 0 && abs(age - 17_190) < 400, solvedText: text("lab.dating.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.dating.hint"),
                String(format: text("lab.dating.oldRock"), Int(Model.halfLivesElapsed(years: 3e9, isotope: isotope).rounded()).formatted(.number.locale(locale))),
                text("lab.dating.limit"),
            ])
        }
    }

    // The halving curve with axes in half-lives and percent, steps at 1/2, 1/4, 1/8, and a draggable point.
    private func curve(_ plot: LabPlotGeometry, halfLives: Double) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: text("lab.dating.axisX"), yLabel: "%", xTicks: Array(0...7).map(Double.init), format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -8, dy: -8)))
            var steps = Path()
            for n in 1...7 {
                steps.move(to: plot.point(Double(n), 0))
                steps.addLine(to: plot.point(Double(n), 100 * pow(0.5, Double(n))))
                steps.addLine(to: plot.point(0, 100 * pow(0.5, Double(n))))
            }
            clipped.stroke(steps, with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            var line = Path()
            for index in 0...200 {
                let x = 7 * Double(index) / 200
                let location = plot.point(x, 100 * pow(0.5, x))
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
            }
            clipped.stroke(line, with: .color(.accentColor), lineWidth: 2.5)
            let marker = plot.point(min(halfLives, 7), remainingPercent)
            clipped.fill(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.orange))
            clipped.stroke(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.white), lineWidth: 2)
        }
    }

    // A hundred atoms: the remaining share stays coloured, the decayed ones fade out.
    private var atoms: some View {
        Canvas { context, size in
            let cell = min(size.width, size.height) / 10
            let remaining = Int(remainingPercent.rounded())
            for index in 0..<100 {
                let rect = CGRect(x: CGFloat(index % 10) * cell + cell * 0.15, y: CGFloat(index / 10) * cell + cell * 0.15, width: cell * 0.7, height: cell * 0.7)
                context.fill(Path(ellipseIn: rect), with: .color(index < remaining ? .green : .secondary.opacity(0.18)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: remainingPercent)
        .accessibilityHidden(true)
    }
}

private struct FeedbackLoopLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var negative = true
    @State private var gain = 0.3
    @State private var disturbance = 2.0
    @State private var shownSteps = FeedbackLoopModel.steps
    @State private var playing = false

    private typealias Model = FeedbackLoopModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    private var settleStep: Int? {
        (0...Model.steps).first { abs(Model.deviation(after: $0, initial: disturbance, gain: gain, negative: negative)) < 0.1 }
    }

    var body: some View {
        let finalDeviation = Model.deviation(after: Model.steps, initial: disturbance, gain: gain, negative: negative)
        LabCard {
            LabHeader(title: text("lab.feedback.title"), instruction: text("lab.feedback.subtitle"))
            Picker(text("lab.feedback.type"), selection: $negative.animation()) {
                Text(text("lab.feedback.negative")).tag(true)
                Text(text("lab.feedback.positive")).tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.feedback.type")

            chart
                .frame(height: 260)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.feedback.chart"))
                .accessibilityValue(Text(verbatim: number(finalDeviation, 2)))

            HStack(spacing: 12) {
                Button {
                    shownSteps = 0
                    playing = true
                } label: { Label(text("lab.feedback.play"), systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.feedback.play")
                Text(String(format: text("lab.feedback.disturbance"), number(disturbance, 1))).monospacedDigit().frame(minWidth: 230, alignment: .leading)
                // Rounds to half a degree without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { disturbance }, set: { disturbance = ($0 * 2).rounded() / 2 }), in: Model.disturbanceRange)
                    .accessibilityLabel(text("lab.feedback.disturbanceLabel"))
                    .accessibilityIdentifier("lab.feedback.disturbance")
            }
            HStack(spacing: 12) {
                Text(String(format: text("lab.feedback.gain"), number(gain, 2))).monospacedDigit().frame(minWidth: 230, alignment: .leading)
                Slider(value: Binding(get: { gain }, set: { gain = ($0 * 20).rounded() / 20 }), in: Model.gainRange)
                    .accessibilityLabel(text("lab.feedback.gainLabel"))
                    .accessibilityIdentifier("lab.feedback.gain")
            }
            LabStatGrid {
                LabStat(label: text("lab.feedback.statFinal"), value: number(Model.setPoint + max(min(finalDeviation, 99), -99), 2) + " °C", tint: negative ? .green : .red)
                LabStat(label: text("lab.feedback.statSettle"), value: settleStep.map(String.init) ?? "—", tint: .accentColor)
            }
            Text(String(format: text("lab.feedback.result"), String(Model.steps), number(finalDeviation, 2)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.feedback.result")
            LabStatusBadge(kind: negative ? .good : .bad, text: text(negative ? "lab.feedback.negativeNote" : "lab.feedback.positiveNote"))
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.feedback.challenge"),
                         solved: negative && disturbance == 2 && (settleStep ?? 99) <= 5, solvedText: text("lab.feedback.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.feedback.hint"), text("lab.feedback.limit")])
        }
        .task(id: playing) {
            guard playing else { return }
            while shownSteps < Model.steps && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 220_000_000)
                withAnimation(.easeOut(duration: 0.2)) { shownSteps += 1 }
            }
            playing = false
        }
    }

    // Temperature after each step with the 37 °C set point and a ±0.1 °C band; values beyond the chart are clamped.
    private var chart: some View {
        Canvas { context, size in
            let plot = LabPlotGeometry(size: size, x: 0...Double(Model.steps), y: (Model.setPoint - 4)...(Model.setPoint + 4))
            plot.drawAxes(in: context, xLabel: text("lab.feedback.axisX"), yLabel: "°C", format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -6, dy: -6)))
            let bandTop = plot.point(0, Model.setPoint + 0.1), bandBottom = plot.point(Double(Model.steps), Model.setPoint - 0.1)
            clipped.fill(Path(CGRect(x: bandTop.x, y: bandTop.y, width: bandBottom.x - bandTop.x, height: max(2, bandBottom.y - bandTop.y))), with: .color(.green.opacity(0.25)))
            var setPoint = Path()
            setPoint.move(to: plot.point(0, Model.setPoint))
            setPoint.addLine(to: plot.point(Double(Model.steps), Model.setPoint))
            clipped.stroke(setPoint, with: .color(.green), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            clipped.draw(Text(text("lab.feedback.setPoint")).font(.caption.weight(.semibold)).foregroundColor(.green),
                         at: plot.point(Double(Model.steps), Model.setPoint + 0.3), anchor: .bottomTrailing)
            let values = Model.temperatures(initial: disturbance, gain: gain, negative: negative).prefix(shownSteps + 1)
            let color: Color = negative ? .accentColor : .red
            var line = Path()
            for (step, value) in values.enumerated() {
                let location = plot.point(Double(step), min(max(value, plot.y.lowerBound - 0.5), plot.y.upperBound + 0.5))
                if step == 0 { line.move(to: location) } else { line.addLine(to: location) }
                clipped.fill(Path(ellipseIn: CGRect(x: location.x - 4, y: location.y - 4, width: 8, height: 8)), with: .color(color))
            }
            clipped.stroke(line, with: .color(color), lineWidth: 2.5)
        }
    }
}

private struct EnergyCouplingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var reaction = 20.0
    @State private var atpCount = 1

    private typealias Model = EnergyCouplingModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let total = Model.total(reaction: reaction, atpCount: atpCount)
        let runs = Model.runs(reaction: reaction, atpCount: atpCount)
        LabCard {
            LabHeader(title: text("lab.coupling.title"), instruction: text("lab.coupling.subtitle"))

            staircase(total: total)
                .frame(height: 260)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.coupling.chart"))
                .accessibilityValue(Text(verbatim: number(total, 1)))

            HStack(spacing: 12) {
                Text(String(format: text("lab.coupling.reaction"), number(reaction, 0))).monospacedDigit().frame(minWidth: 290, alignment: .leading)
                // Whole kJ/mol without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { reaction }, set: { reaction = $0.rounded() }), in: Model.reactionRange)
                    .accessibilityLabel(text("lab.coupling.reactionLabel"))
                    .accessibilityIdentifier("lab.coupling.reaction")
            }
            HStack(spacing: 10) {
                Text(text("lab.coupling.atpLabel")).frame(minWidth: 290, alignment: .leading)
                Button { withAnimation(.spring(response: 0.35)) { atpCount = max(atpCount - 1, Model.atpRange.lowerBound) } } label: { Image(systemName: "minus") }
                    .accessibilityLabel(text("lab.coupling.atpLess"))
                Text(verbatim: String(atpCount)).font(.title2.weight(.bold)).monospacedDigit().frame(minWidth: 36)
                    .accessibilityIdentifier("lab.coupling.atpCount")
                Button { withAnimation(.spring(response: 0.35)) { atpCount = min(atpCount + 1, Model.atpRange.upperBound) } } label: { Image(systemName: "plus") }
                    .accessibilityLabel(text("lab.coupling.atpMore"))
                Text(verbatim: "ATP").font(.headline).foregroundStyle(.green)
            }
            LabStatGrid {
                LabStat(label: text("lab.coupling.statTotal"), value: number(total, 1), tint: runs ? .green : .red, identifier: "lab.coupling.total")
                LabStat(label: text("lab.coupling.statMinimum"), value: String(Model.minimumATP(reaction: reaction)), tint: .accentColor)
            }
            LabStatusBadge(kind: runs ? .good : .bad, text: text(runs ? "lab.coupling.runs" : "lab.coupling.stalls"), identifier: "lab.coupling.verdict")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.coupling.challenge"),
                         solved: reaction == 45 && atpCount == 2, solvedText: text("lab.coupling.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.coupling.hint"),
                String(format: text("lab.coupling.total"), number(reaction, 0), String(atpCount), number(total, 1)),
                text("lab.coupling.limit"),
            ])
        }
    }

    // An energy staircase: the reaction climbs by +ΔG, each ATP steps down by 30.5 kJ/mol, and the last step is the total.
    private func staircase(total: Double) -> some View {
        Canvas { context, size in
            let lowest = min(0, total) - 20, highest = max(reaction, 40) + 20
            let plot = LabPlotGeometry(size: size, x: 0...Double(atpCount + 2), y: lowest...highest, leading: 56)
            plot.drawAxes(in: context, xLabel: "", yLabel: text("lab.coupling.axisY"), xTicks: [], format: { number($0, 0) })
            var zero = Path()
            zero.move(to: plot.point(0, 0))
            zero.addLine(to: plot.point(Double(atpCount + 2), 0))
            context.stroke(zero, with: .color(.secondary), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            func step(_ index: Int, _ from: Double, _ to: Double, _ color: Color, _ label: String) {
                let a = plot.point(Double(index) + 0.15, from), b = plot.point(Double(index) + 0.85, to)
                var bar = Path()
                bar.move(to: CGPoint(x: a.x, y: b.y))
                bar.addLine(to: CGPoint(x: b.x, y: b.y))
                context.stroke(bar, with: .color(color), lineWidth: 4)
                var arrow = Path()
                let x = (a.x + b.x) / 2
                arrow.move(to: CGPoint(x: x, y: a.y))
                arrow.addLine(to: CGPoint(x: x, y: b.y))
                let direction: CGFloat = to > from ? 1 : -1
                arrow.move(to: CGPoint(x: x - 6, y: b.y + 9 * direction))
                arrow.addLine(to: CGPoint(x: x, y: b.y))
                arrow.addLine(to: CGPoint(x: x + 6, y: b.y + 9 * direction))
                context.stroke(arrow, with: .color(color.opacity(0.8)), lineWidth: 2)
                context.draw(Text(verbatim: label).font(.caption.weight(.bold)).foregroundColor(color), at: CGPoint(x: x + 10, y: (a.y + b.y) / 2), anchor: .leading)
            }
            step(0, 0, reaction, .red, "+" + number(reaction, 0))
            var level = reaction
            for index in 0..<atpCount {
                step(index + 1, level, level + Model.atpFreeEnergy, .green, "ATP " + number(Model.atpFreeEnergy, 1))
                level += Model.atpFreeEnergy
            }
            let final = plot.point(Double(atpCount + 1) + 0.5, total)
            context.draw(Text(verbatim: "ΔG = " + number(total, 1)).font(.headline).foregroundColor(total < 0 ? .green : .red),
                         at: CGPoint(x: final.x, y: final.y + (total < 0 ? 16 : -16)))
        }
    }
}

private struct ReactionQuotientLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var mixture = ReactionQuotientModel.lessonMixture

    private typealias Model = ReactionQuotientModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let quotient = Model.quotient(mixture)
        let direction = Model.direction(mixture)
        LabCard {
            LabHeader(title: text("lab.quotient.title"), instruction: text("lab.quotient.subtitle"))

            HStack(alignment: .center, spacing: 18) {
                beaker([("CO", mixture.carbonMonoxide, Color.gray), ("H₂O", mixture.water, Color.blue)], title: text("lab.quotient.reactants"))
                Image(systemName: direction == .forward ? "arrow.right.circle.fill" : direction == .reverse ? "arrow.left.circle.fill" : "equal.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(direction == .equilibrium ? Color.green : Color.orange)
                    .symbolRenderingMode(.hierarchical)
                beaker([("CO₂", mixture.carbonDioxide, Color.purple), ("H₂", mixture.hydrogen, Color.teal)], title: text("lab.quotient.products"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 235)
            gauge(quotient: quotient)
                .frame(height: 70)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.quotient.gauge"))
                .accessibilityValue(Text(verbatim: number(quotient, 3)))

            LabStatGrid {
                LabStat(label: "Q = [CO₂][H₂] / ([CO][H₂O])", value: number(quotient, 3), tint: .orange, identifier: "lab.quotient.value")
                LabStat(label: text("lab.quotient.statK"), value: number(Model.equilibriumConstant, 2), tint: .green)
            }
            LabStatusBadge(kind: direction == .equilibrium ? .good : .info,
                           text: text(direction == .forward ? "lab.quotient.forward" : direction == .reverse ? "lab.quotient.reverse" : "lab.quotient.equilibrium"),
                           identifier: "lab.quotient.direction")
            HStack(spacing: 10) {
                Button { withAnimation(.easeInOut(duration: 0.8)) { mixture = Model.equilibrate(mixture) } } label: { Label(text("lab.quotient.settle"), systemImage: "scalemass") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.quotient.settle")
                Button(text("lab.quotient.addWater")) { withAnimation { mixture.water = min(mixture.water + 0.01, Model.concentrationRange.upperBound) } }
                    .accessibilityIdentifier("lab.quotient.addWater")
                Button(text("lab.quotient.reset")) { withAnimation { mixture = Model.lessonMixture } }
                    .accessibilityIdentifier("lab.quotient.reset")
            }
            DisclosureGroup(text("lab.quotient.manual")) {
                VStack(alignment: .leading, spacing: 6) {
                    concentration("CO", \.carbonMonoxide, "lab.quotient.slider.co")
                    concentration("H₂O", \.water, "lab.quotient.slider.water")
                    concentration("CO₂", \.carbonDioxide, "lab.quotient.slider.co2")
                    concentration("H₂", \.hydrogen, "lab.quotient.slider.h2")
                }
                .padding(.top, 6)
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.quotient.challenge"), solved: direction == .reverse, solvedText: text("lab.quotient.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.quotient.hint"), text("lab.quotient.limit")])
        }
    }

    // Columns for two substances; heights are concentrations on a shared 0–0.05 mol/L scale.
    private func beaker(_ items: [(String, Double, Color)], title: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(items, id: \.0) { name, value, color in
                    VStack(spacing: 4) {
                        Text(verbatim: number(value, 4)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.gradient)
                            .frame(width: 56, height: max(4, 160 * CGFloat(value / Model.concentrationRange.upperBound)))
                        Text(verbatim: name).font(.headline)
                    }
                }
            }
            .frame(height: 205, alignment: .bottom)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // A logarithmic gauge from 0.001 to 1000 with K marked in green and Q as an orange pointer.
    private func gauge(quotient: Double) -> some View {
        Canvas { context, size in
            let left: CGFloat = 20, right = size.width - 20, y = size.height * 0.5
            func x(_ value: Double) -> CGFloat { left + (right - left) * CGFloat((log10(min(max(value, 0.001), 1000)) + 3) / 6) }
            context.fill(Path(roundedRect: CGRect(x: left, y: y - 5, width: right - left, height: 10), cornerRadius: 5), with: .color(.secondary.opacity(0.2)))
            for power in -3...3 {
                context.draw(Text(verbatim: power >= 0 ? number(pow(10, Double(power)), 0) : number(pow(10, Double(power)), -power)).font(.caption2).foregroundColor(.secondary),
                             at: CGPoint(x: x(pow(10, Double(power))), y: y + 20))
            }
            let k = x(Model.equilibriumConstant)
            context.fill(Path(CGRect(x: k - 2, y: y - 16, width: 4, height: 32)), with: .color(.green))
            context.draw(Text(verbatim: "K").font(.caption.weight(.bold)).foregroundColor(.green), at: CGPoint(x: k, y: y - 24))
            let q = x(quotient)
            var pointer = Path()
            pointer.move(to: CGPoint(x: q, y: y - 4))
            pointer.addLine(to: CGPoint(x: q - 8, y: y - 18))
            pointer.addLine(to: CGPoint(x: q + 8, y: y - 18))
            pointer.closeSubpath()
            context.fill(pointer, with: .color(.orange))
            context.draw(Text(verbatim: "Q").font(.caption.weight(.bold)).foregroundColor(.orange), at: CGPoint(x: q, y: y - 26))
        }
    }

    private func concentration(_ formula: String, _ path: WritableKeyPath<Model.Mixture, Double>, _ identifier: String) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: "[\(formula)] = \(number(mixture[keyPath: path], 4)) " + text("lab.quotient.unit")).monospacedDigit().frame(minWidth: 220, alignment: .leading)
            // Rounds to 0.001 mol/L without `step:`, which would draw a dense row of tick marks.
            Slider(value: Binding(get: { mixture[keyPath: path] }, set: { mixture[keyPath: path] = ($0 * 1000).rounded() / 1000 }), in: Model.concentrationRange)
                .accessibilityLabel(Text(verbatim: formula))
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct TimeDilationLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var speed = 0.6
    @State private var properTime = 10.0
    @State private var flight = 1.0
    @State private var flying = false

    private typealias Model = RelativityModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let gamma = Model.gamma(speed: speed)
        LabCard {
            LabHeader(title: text("lab.relativity.title"), instruction: text("lab.relativity.subtitle"))

            HStack(spacing: 20) {
                clock(text("lab.relativity.shipClock"), seconds: properTime * flight, color: .orange)
                clock(text("lab.relativity.earthClock"), seconds: properTime * gamma * flight, color: .accentColor)
                GeometryReader { proxy in
                    let plot = LabPlotGeometry(size: proxy.size, x: 0...1, y: 0...8)
                    curve(plot)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                            speed = min(max((plot.value(at: drag.location).x * 100).rounded() / 100, Model.speedRange.lowerBound), Model.speedRange.upperBound)
                        })
                }
            }
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.relativity.chart"))
            .accessibilityValue(Text(verbatim: number(gamma, 2)))

            HStack(spacing: 12) {
                Button {
                    flight = 0
                    flying = true
                } label: { Label(text("lab.relativity.fly"), systemImage: "airplane") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lab.relativity.fly")
                Text(String(format: text("lab.relativity.speed"), number(speed, 2))).monospacedDigit().frame(minWidth: 150, alignment: .leading)
                // Rounds to hundredths of c without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { speed }, set: { speed = ($0 * 100).rounded() / 100 }), in: Model.speedRange)
                    .accessibilityLabel(text("lab.relativity.speedLabel"))
                    .accessibilityIdentifier("lab.relativity.speed")
            }
            HStack(spacing: 12) {
                Text(String(format: text("lab.relativity.proper"), number(properTime, 0))).monospacedDigit().frame(minWidth: 310, alignment: .leading)
                Slider(value: Binding(get: { properTime }, set: { properTime = $0.rounded() }), in: Model.properTimeRange)
                    .accessibilityLabel(text("lab.relativity.properLabel"))
                    .accessibilityIdentifier("lab.relativity.proper")
            }
            LabStatGrid {
                LabStat(label: "γ = 1 / √(1 − v²/c²)", value: number(gamma, 3), tint: .purple)
                LabStat(label: text("lab.relativity.statShip"), value: number(properTime, 0) + " " + text("lab.relativity.unitS"), tint: .orange)
                LabStat(label: text("lab.relativity.statEarth"), value: number(Model.dilatedTime(properTime: properTime, speed: speed), 2) + " " + text("lab.relativity.unitS"), tint: .accentColor)
            }
            Text(String(format: text("lab.relativity.result"), number(gamma, 3), number(properTime, 0), number(Model.dilatedTime(properTime: properTime, speed: speed), 2)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.relativity.result")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.relativity.challenge"), solved: abs(gamma - 2) < 0.035, solvedText: text("lab.relativity.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.relativity.hint"),
                String(format: text("lab.relativity.muon"), number(Model.dilatedTime(properTime: Model.muonHalfLife, speed: speed), 2)),
                text("lab.relativity.limit"),
            ])
        }
        .task(id: flying) {
            guard flying else { return }
            while flight < 1 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 40_000_000)
                flight = min(flight + 0.01, 1)
            }
            flying = false
        }
    }

    // A clock face whose hand makes a turn every 10 s, with the elapsed time underneath.
    private func clock(_ title: String, seconds: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            Canvas { context, size in
                let radius = min(size.width, size.height) / 2 - 4
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(color), lineWidth: 4)
                for tick in 0..<10 {
                    let angle = Double(tick) / 10 * 2 * .pi
                    var mark = Path()
                    mark.move(to: CGPoint(x: center.x + (radius - 10) * CGFloat(sin(angle)), y: center.y - (radius - 10) * CGFloat(cos(angle))))
                    mark.addLine(to: CGPoint(x: center.x + (radius - 3) * CGFloat(sin(angle)), y: center.y - (radius - 3) * CGFloat(cos(angle))))
                    context.stroke(mark, with: .color(.secondary), lineWidth: 2)
                }
                let angle = seconds.truncatingRemainder(dividingBy: 10) / 10 * 2 * .pi
                var hand = Path()
                hand.move(to: center)
                hand.addLine(to: CGPoint(x: center.x + (radius - 14) * CGFloat(sin(angle)), y: center.y - (radius - 14) * CGFloat(cos(angle))))
                context.stroke(hand, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            .frame(width: 130, height: 130)
            Text(verbatim: number(seconds, 1) + " " + text("lab.relativity.unitS")).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func curve(_ plot: LabPlotGeometry) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: "v / c", yLabel: "γ", format: { number($0, $0 == $0.rounded() ? 0 : 1) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -6, dy: -6)))
            var line = Path()
            for index in 0...198 {
                let x = Double(index) / 200
                let location = plot.point(x, Model.gamma(speed: x))
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
            }
            clipped.stroke(line, with: .color(.purple), lineWidth: 2.5)
            let marker = plot.point(speed, Model.gamma(speed: speed))
            clipped.fill(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.orange))
            clipped.stroke(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.white), lineWidth: 2)
        }
    }
}

private struct HydrogenSpectrumLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var upper = 3
    @State private var lower = 2

    private typealias Model = HydrogenSpectrumModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    // An approximate colour for a visible wavelength, linear between rough anchors; outside the range it is grey.
    private func lineColor(_ wavelength: Double) -> Color {
        guard Model.visibleRange.contains(wavelength) else { return .gray }
        let anchors: [(Double, Double, Double, Double)] = [(380, 0.5, 0, 1), (440, 0, 0, 1), (490, 0, 1, 1), (510, 0, 1, 0), (580, 1, 1, 0), (645, 1, 0, 0), (760, 0.6, 0, 0)]
        for (left, right) in zip(anchors, anchors.dropFirst()) where wavelength <= right.0 {
            let share = (wavelength - left.0) / (right.0 - left.0)
            return Color(red: left.1 + (right.1 - left.1) * share, green: left.2 + (right.2 - left.2) * share, blue: left.3 + (right.3 - left.3) * share)
        }
        return .red
    }

    var body: some View {
        let wavelength = Model.wavelength(from: upper, to: lower)
        let region = wavelength < Model.visibleRange.lowerBound ? "lab.hydrogen.ultraviolet"
            : wavelength > Model.visibleRange.upperBound ? "lab.hydrogen.infrared" : "lab.hydrogen.visible"
        LabCard {
            LabHeader(title: text("lab.hydrogen.title"), instruction: text("lab.hydrogen.subtitle"))
            HStack(alignment: .top, spacing: 18) {
                levels
                    .frame(width: 320, height: 260)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(text("lab.hydrogen.diagram"))
                    .accessibilityValue(Text(verbatim: "\(upper) → \(lower)"))
                VStack(alignment: .leading, spacing: 12) {
                    Stepper(value: Binding(get: { upper }, set: { upper = $0; if lower >= upper { lower = upper - 1 } }), in: 2...Model.levelRange.upperBound) {
                        Text(String(format: text("lab.hydrogen.upper"), String(upper))).font(.headline).monospacedDigit()
                    }
                    .accessibilityIdentifier("lab.hydrogen.upper")
                    Stepper(value: Binding(get: { lower }, set: { lower = min($0, upper - 1) }), in: 1...(upper - 1)) {
                        Text(String(format: text("lab.hydrogen.lower"), String(lower))).font(.headline).monospacedDigit()
                    }
                    .accessibilityIdentifier("lab.hydrogen.lower")
                    LabStatGrid {
                        LabStat(label: "ΔE, " + text("lab.hydrogen.unitEV"), value: number(Model.photonEnergy(from: upper, to: lower), 2), tint: .purple)
                        LabStat(label: "λ, " + text("lab.hydrogen.unitNM"), value: number(wavelength, 0), tint: lineColor(wavelength))
                    }
                    Text(String(format: text("lab.hydrogen.photon"), number(Model.photonEnergy(from: upper, to: lower), 2), number(wavelength, 0)))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("lab.hydrogen.photon")
                    Text(text(region)).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            spectrum(wavelength: wavelength)
                .frame(height: 64)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.hydrogen.spectrum"))
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.hydrogen.challenge"), solved: upper == 4 && lower == 2, solvedText: text("lab.hydrogen.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.hydrogen.hint"),
                String(format: text("lab.hydrogen.shell"), String(upper), String(Model.shellCapacity(level: upper))),
                text("lab.hydrogen.limit"),
            ])
        }
    }

    // Levels Eₙ = −13.6/n² to scale with their energies, and the chosen transition as a coloured arrow.
    private var levels: some View {
        Canvas { context, size in
            func y(_ energy: Double) -> CGFloat { 14 + (size.height - 28) * CGFloat(-energy / 13.6) }
            for level in Model.levelRange {
                let energy = Model.energy(level: level)
                var line = Path()
                line.move(to: CGPoint(x: 56, y: y(energy)))
                line.addLine(to: CGPoint(x: size.width - 70, y: y(energy)))
                let chosen = level == upper || level == lower
                context.stroke(line, with: .color(chosen ? .primary : .secondary.opacity(0.5)), lineWidth: chosen ? 2.5 : 1)
                // Levels above n = 3 crowd near zero, so only the chosen ones among them are labelled.
                guard level <= 3 || chosen else { continue }
                context.draw(Text(verbatim: "n = \(level)").font(.caption.weight(chosen ? .bold : .regular)).foregroundColor(.secondary), at: CGPoint(x: 4, y: y(energy)), anchor: .leading)
                context.draw(Text(verbatim: number(energy, 2) + " " + text("lab.hydrogen.unitEV")).font(.caption2).foregroundColor(.secondary),
                             at: CGPoint(x: size.width - 2, y: y(energy)), anchor: .trailing)
            }
            let color = lineColor(Model.wavelength(from: upper, to: lower))
            let x = size.width * 0.5
            let from = CGPoint(x: x, y: y(Model.energy(level: upper))), to = CGPoint(x: x, y: y(Model.energy(level: lower)))
            var arrow = Path()
            arrow.move(to: from)
            arrow.addLine(to: to)
            arrow.move(to: CGPoint(x: x - 8, y: to.y - 11))
            arrow.addLine(to: to)
            arrow.addLine(to: CGPoint(x: x + 8, y: to.y - 11))
            context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            var wave = Path()
            for index in 0...60 {
                let t = CGFloat(index) / 60
                let point = CGPoint(x: x + 14 + t * 60, y: (from.y + to.y) / 2 + 7 * CGFloat(sin(Double(t) * 6 * .pi)))
                if index == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
            }
            context.stroke(wave, with: .color(color), lineWidth: 2)
        }
    }

    // The visible band as a rainbow from 380 to 760 nm with the emitted line marked; lines outside are labelled at the edge.
    private func spectrum(wavelength: Double) -> some View {
        Canvas { context, size in
            let band = CGRect(x: 40, y: 8, width: size.width - 80, height: 30)
            let steps = 120
            for index in 0..<steps {
                let lambda = Model.visibleRange.lowerBound + (Model.visibleRange.upperBound - Model.visibleRange.lowerBound) * Double(index) / Double(steps)
                context.fill(Path(CGRect(x: band.minX + band.width * CGFloat(index) / CGFloat(steps), y: band.minY, width: band.width / CGFloat(steps) + 0.5, height: band.height)),
                             with: .color(lineColor(lambda).opacity(0.55)))
            }
            for lambda in [400.0, 500, 600, 700] {
                let x = band.minX + band.width * CGFloat((lambda - Model.visibleRange.lowerBound) / (Model.visibleRange.upperBound - Model.visibleRange.lowerBound))
                context.draw(Text(verbatim: number(lambda, 0)).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: x, y: band.maxY + 10))
            }
            if Model.visibleRange.contains(wavelength) {
                let x = band.minX + band.width * CGFloat((wavelength - Model.visibleRange.lowerBound) / (Model.visibleRange.upperBound - Model.visibleRange.lowerBound))
                context.fill(Path(CGRect(x: x - 2.5, y: band.minY - 4, width: 5, height: band.height + 8)), with: .color(.white))
            } else {
                let left = wavelength < Model.visibleRange.lowerBound
                context.draw(Text(verbatim: (left ? "◀ " : "") + number(wavelength, 0) + " " + text("lab.hydrogen.unitNM") + (left ? "" : " ▶")).font(.caption.weight(.bold)).foregroundColor(.secondary),
                             at: CGPoint(x: left ? 2 : size.width - 2, y: band.midY), anchor: left ? .leading : .trailing)
            }
        }
    }
}

private struct ElectromagneticWaveLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var exponent = 8.0

    private typealias Model = ElectromagneticWaveModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    // Scientific notation such as 3,00 · 10⁸, written with superscript digits.
    private func scientific(_ value: Double) -> String {
        let power = Int(floor(log10(value)))
        let mantissa = value / pow(10, Double(power))
        let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
        return "\(number(mantissa, 2)) · 10" + String(String(power).map { superscripts[$0] ?? $0 })
    }

    var body: some View {
        let frequency = pow(10, exponent)
        let wavelength = Model.wavelength(frequency: frequency)
        LabCard {
            LabHeader(title: text("lab.emwave.title"), instruction: text("lab.emwave.subtitle"))
            wave
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.emwave.waveChart"))
            scale
                .frame(height: 70)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.emwave.scale"))
            HStack(spacing: 12) {
                Text(String(format: text("lab.emwave.frequency"), scientific(frequency))).monospacedDigit().frame(minWidth: 230, alignment: .leading)
                // Tenths of an order of magnitude without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { exponent }, set: { exponent = ($0 * 10).rounded() / 10 }), in: Model.exponentRange)
                    .accessibilityLabel(text("lab.emwave.frequencyLabel"))
                    .accessibilityValue(Text(verbatim: scientific(frequency)))
                    .accessibilityIdentifier("lab.emwave.frequency")
            }
            LabStatGrid {
                LabStat(label: text("lab.emwave.statFrequency"), value: scientific(frequency), tint: .purple)
                LabStat(label: text("lab.emwave.statWavelength"), value: scientific(wavelength), tint: .orange, identifier: "lab.emwave.wavelength")
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.emwave.challenge"),
                         solved: abs(wavelength - Model.greenWavelength) / Model.greenWavelength < 0.1, solvedText: text("lab.emwave.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.emwave.hint"),
                String(format: text("lab.emwave.compareRadio"), scientific(frequency / Model.radioFrequency)),
                String(format: text("lab.emwave.compareGreen"), scientific(wavelength / Model.greenWavelength)),
                text("lab.emwave.limit"),
            ])
        }
    }

    // A sine wave whose drawn wavelength shrinks by the same step for every tenfold rise in frequency.
    private var wave: some View {
        Canvas { context, size in
            let share = (exponent - Model.exponentRange.lowerBound) / (Model.exponentRange.upperBound - Model.exponentRange.lowerBound)
            let pixels = CGFloat(pow(10, 2.6 - 2.2 * share))
            var path = Path()
            for index in 0...Int(size.width) {
                let x = CGFloat(index)
                let point = CGPoint(x: x, y: size.height / 2 - (size.height * 0.38) * CGFloat(sin(Double(x / pixels) * 2 * .pi)))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(.purple), lineWidth: 2)
        }
    }

    // A log scale of frequency from 10⁶ to 10¹⁸ Hz with the two lesson examples and the current frequency marked.
    private var scale: some View {
        Canvas { context, size in
            let left: CGFloat = 24, right = size.width - 24, y = size.height * 0.45
            func x(_ power: Double) -> CGFloat { left + (right - left) * CGFloat((power - 6) / 12) }
            context.fill(Path(roundedRect: CGRect(x: left, y: y - 5, width: right - left, height: 10), cornerRadius: 5), with: .color(.secondary.opacity(0.2)))
            for power in stride(from: 6, through: 18, by: 2) {
                context.draw(Text(verbatim: scientific(pow(10, Double(power))).replacingOccurrences(of: number(1, 2) + " · ", with: "")).font(.caption2).foregroundColor(.secondary),
                             at: CGPoint(x: x(Double(power)), y: y + 20))
            }
            for (power, key) in [(8.0, "lab.emwave.radioMark"), (log10(Model.frequency(wavelength: Model.greenWavelength)), "lab.emwave.greenMark")] {
                context.fill(Path(CGRect(x: x(power) - 1.5, y: y - 14, width: 3, height: 28)), with: .color(.green))
                context.draw(Text(text(key)).font(.caption2.weight(.semibold)).foregroundColor(.green), at: CGPoint(x: x(power), y: y - 22))
            }
            var pointer = Path()
            pointer.move(to: CGPoint(x: x(exponent), y: y + 6))
            pointer.addLine(to: CGPoint(x: x(exponent) - 8, y: y + 20))
            pointer.addLine(to: CGPoint(x: x(exponent) + 8, y: y + 20))
            pointer.closeSubpath()
            context.fill(pointer, with: .color(.orange))
        }
    }
}

private struct CircuitLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var first = 2.0
    @State private var second = 6.0
    @State private var voltage = 12.0
    @State private var parallel = true

    private typealias Model = CircuitModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let total = Model.totalCurrent(voltage: voltage, first, second, parallel: parallel)
        LabCard {
            LabHeader(title: text("lab.circuit.title"), instruction: text("lab.circuit.subtitle"))
            Picker(text("lab.circuit.mode"), selection: $parallel.animation()) {
                Text(text("lab.circuit.series")).tag(false)
                Text(text("lab.circuit.parallel")).tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.circuit.mode")

            TimelineView(.animation) { timeline in
                schematic(time: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(height: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.circuit.diagram"))
            .accessibilityValue(Text(verbatim: number(total, 2)))

            slider(String(format: text("lab.circuit.first"), number(first, 0)), "lab.circuit.first", $first, Model.resistanceRange)
            slider(String(format: text("lab.circuit.second"), number(second, 0)), "lab.circuit.second", $second, Model.resistanceRange)
            slider(String(format: text("lab.circuit.voltage"), number(voltage, 0)), "lab.circuit.voltage", $voltage, Model.voltageRange)

            LabStatGrid {
                LabStat(label: text("lab.circuit.statResistance"), value: number(Model.totalResistance(first, second, parallel: parallel), 2), tint: .purple)
                LabStat(label: text("lab.circuit.statCurrent"), value: number(total, 2), tint: .orange)
            }
            Text(String(format: text("lab.circuit.total"), number(Model.totalResistance(first, second, parallel: parallel), 2), number(total, 2)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.circuit.total")
            LabStatusBadge(kind: .info, text: text(parallel ? "lab.circuit.parallelNote" : "lab.circuit.seriesNote"))
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.circuit.challenge"),
                         solved: parallel && voltage == 12 && abs(total - 6) < 0.01, solvedText: text("lab.circuit.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.circuit.hint"), text("lab.circuit.limit")])
        }
    }

    private func slider(_ title: String, _ identifier: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title).monospacedDigit().frame(minWidth: 230, alignment: .leading)
            // Whole units without `step:`, which would draw a dense row of tick marks.
            Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0.rounded() }), in: range)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityIdentifier(identifier)
        }
    }

    // A battery and two resistors in series or parallel. Dots move along each wire at a speed proportional to its
    // current, so a larger current visibly flows faster; each resistor shows its current and voltage.
    private func schematic(time: Double) -> some View {
        Canvas { context, size in
            let left: CGFloat = 70, right = size.width - 70, top: CGFloat = 40, bottom = size.height - 30
            let wire = GraphicsContext.Shading.color(.secondary)
            func flow(_ path: [CGPoint], current: Double) {
                var line = Path()
                line.addLines(path)
                context.stroke(line, with: wire, lineWidth: 2.5)
                let lengths = zip(path, path.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
                let total = lengths.reduce(0, +)
                guard total > 0, current > 0 else { return }
                let spacing: CGFloat = 26
                let offset = CGFloat((time * current * 14).truncatingRemainder(dividingBy: Double(spacing)))
                var distance = offset
                while distance < total {
                    var remaining = distance
                    for (index, length) in lengths.enumerated() {
                        if remaining <= length {
                            let a = path[index], b = path[index + 1], t = remaining / length
                            let point = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                            context.fill(Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)), with: .color(.yellow))
                            break
                        }
                        remaining -= length
                    }
                    distance += spacing
                }
            }
            func resistor(at center: CGPoint, name: String, resistance: Double, current: Double, voltage: Double) {
                let body = CGRect(x: center.x - 42, y: center.y - 14, width: 84, height: 28)
                context.fill(Path(roundedRect: body, cornerRadius: 6), with: .color(.orange.opacity(0.85)))
                context.draw(Text(verbatim: "\(name) = \(number(resistance, 0)) " + text("lab.circuit.unitOhm")).font(.caption.weight(.bold)).foregroundColor(.white), at: center)
                context.draw(Text(verbatim: "\(number(current, 2)) " + text("lab.circuit.unitA") + " · \(number(voltage, 2)) " + text("lab.circuit.unitV"))
                    .font(.caption2.weight(.semibold)).foregroundColor(.secondary), at: CGPoint(x: center.x, y: center.y + 26))
            }
            let battery = CGPoint(x: left, y: (top + bottom) / 2)
            let total = Model.totalCurrent(voltage: voltage, first, second, parallel: parallel)
            if parallel {
                let upperY = top, lowerY = (top + bottom) / 2 + 30
                flow([CGPoint(x: left, y: battery.y - 20), CGPoint(x: left, y: top), CGPoint(x: left + 60, y: top)], current: total)
                flow([CGPoint(x: left + 60, y: upperY), CGPoint(x: right - 60, y: upperY)], current: Model.branchCurrent(voltage: voltage, resistor: first, other: second, parallel: true))
                flow([CGPoint(x: left + 60, y: upperY), CGPoint(x: left + 60, y: lowerY), CGPoint(x: right - 60, y: lowerY), CGPoint(x: right - 60, y: upperY)],
                     current: Model.branchCurrent(voltage: voltage, resistor: second, other: first, parallel: true))
                flow([CGPoint(x: right - 60, y: upperY), CGPoint(x: right, y: upperY), CGPoint(x: right, y: bottom), CGPoint(x: left, y: bottom), CGPoint(x: left, y: battery.y + 20)], current: total)
                resistor(at: CGPoint(x: (left + right) / 2, y: upperY), name: "R₁", resistance: first,
                         current: Model.branchCurrent(voltage: voltage, resistor: first, other: second, parallel: true), voltage: voltage)
                resistor(at: CGPoint(x: (left + right) / 2, y: lowerY), name: "R₂", resistance: second,
                         current: Model.branchCurrent(voltage: voltage, resistor: second, other: first, parallel: true), voltage: voltage)
            } else {
                flow([CGPoint(x: left, y: battery.y - 20), CGPoint(x: left, y: top), CGPoint(x: right, y: top), CGPoint(x: right, y: bottom),
                      CGPoint(x: left, y: bottom), CGPoint(x: left, y: battery.y + 20)], current: total)
                resistor(at: CGPoint(x: left + (right - left) * 0.33, y: top), name: "R₁", resistance: first, current: total,
                         voltage: Model.branchVoltage(voltage: voltage, resistor: first, other: second, parallel: false))
                resistor(at: CGPoint(x: left + (right - left) * 0.67, y: top), name: "R₂", resistance: second, current: total,
                         voltage: Model.branchVoltage(voltage: voltage, resistor: second, other: first, parallel: false))
            }
            context.fill(Path(CGRect(x: battery.x - 18, y: battery.y - 20, width: 36, height: 5)), with: .color(.primary))
            context.fill(Path(CGRect(x: battery.x - 10, y: battery.y + 15, width: 20, height: 5)), with: .color(.primary))
            context.draw(Text(verbatim: "\(number(voltage, 0)) " + text("lab.circuit.unitV")).font(.headline).foregroundColor(.primary), at: CGPoint(x: battery.x - 26, y: battery.y), anchor: .trailing)
            context.draw(Text(verbatim: "I = \(number(total, 2)) " + text("lab.circuit.unitA")).font(.headline).foregroundColor(.orange), at: CGPoint(x: (left + right) / 2, y: bottom + 16))
        }
    }
}

private struct RefractionLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var firstIndex = 0
    @State private var secondIndex = 2
    @State private var incidence = 30.0

    private typealias Model = RefractionModel
    private let mediumKeys = ["lab.refraction.air", "lab.refraction.water", "lab.refraction.glass", "lab.refraction.diamond"]

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let first = Model.media[firstIndex], second = Model.media[secondIndex]
        let refracted = Model.refractionAngle(incidence: incidence, from: first, to: second)
        LabCard {
            LabHeader(title: text("lab.refraction.title"), instruction: text("lab.refraction.subtitle"))
            mediumPicker("lab.refraction.from", $firstIndex, "lab.refraction.picker.first")
            mediumPicker("lab.refraction.to", $secondIndex, "lab.refraction.picker.second")

            GeometryReader { proxy in
                rays(refracted: refracted, size: proxy.size)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        let dx = Double(center.x - drag.location.x), dy = Double(center.y - drag.location.y)
                        guard dy > 0 else { return }
                        incidence = min(max((atan2(abs(dx), dy) * 180 / .pi).rounded(), Model.angleRange.lowerBound), Model.angleRange.upperBound)
                    })
            }
            .frame(height: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.refraction.diagram"))
            .accessibilityValue(Text(verbatim: refracted.map { number($0, 1) } ?? "—"))

            HStack(spacing: 12) {
                Text(String(format: text("lab.refraction.incidence"), number(incidence, 0))).monospacedDigit().frame(minWidth: 190, alignment: .leading)
                // Whole degrees without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { incidence }, set: { incidence = $0.rounded() }), in: Model.angleRange)
                    .accessibilityLabel(text("lab.refraction.incidenceLabel"))
                    .accessibilityIdentifier("lab.refraction.incidence")
            }
            LabStatGrid {
                LabStat(label: "θ₁", value: number(incidence, 0) + "°", tint: .orange)
                LabStat(label: "θ₂", value: refracted.map { number($0, 1) + "°" } ?? "—", tint: refracted == nil ? .red : .accentColor)
                LabStat(label: text("lab.refraction.statSpeed"), value: number(Model.speed(in: second) / 1e8, 2) + " · 10⁸", tint: .purple)
            }
            Text(refracted.map { String(format: text("lab.refraction.angle"), number($0, 1)) }
                 ?? String(format: text("lab.refraction.total"), number(Model.criticalAngle(from: first, to: second) ?? 90, 1)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(refracted == nil ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.refraction.angle")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.refraction.challenge"),
                         solved: firstIndex == 2 && secondIndex == 0 && refracted == nil && incidence <= 42, solvedText: text("lab.refraction.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.refraction.hint"),
                String(format: text("lab.refraction.speed"), number(Model.speed(in: second) / 1e8, 2)),
                text("lab.refraction.limit"),
            ])
        }
    }

    private func mediumPicker(_ titleKey: String, _ selection: Binding<Int>, _ identifier: String) -> some View {
        Picker(text(titleKey), selection: selection.animation()) {
            ForEach(mediumKeys.indices, id: \.self) { index in Text(text(mediumKeys[index])).tag(index) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(identifier)
    }

    // Two media (darker means optically denser), the dashed normal, the draggable incident ray with θ₁, and the
    // refracted ray with θ₂ or the reflected ray in red when the light is totally internally reflected.
    private func rays(refracted: Double?, size: CGSize) -> some View {
        Canvas { context, _ in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let length = min(size.width * 0.45, size.height * 0.48)
            let shade = [0.04, 0.16, 0.26, 0.38]
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: center.y)), with: .color(.blue.opacity(shade[firstIndex])))
            context.fill(Path(CGRect(x: 0, y: center.y, width: size.width, height: size.height - center.y)), with: .color(.blue.opacity(shade[secondIndex])))
            context.draw(Text(text(mediumKeys[firstIndex])).font(.caption.weight(.semibold)).foregroundColor(.secondary), at: CGPoint(x: 10, y: 10), anchor: .topLeading)
            context.draw(Text(text(mediumKeys[secondIndex])).font(.caption.weight(.semibold)).foregroundColor(.secondary), at: CGPoint(x: 10, y: size.height - 10), anchor: .bottomLeading)
            var normal = Path()
            normal.move(to: CGPoint(x: center.x, y: 0))
            normal.addLine(to: CGPoint(x: center.x, y: size.height))
            context.stroke(normal, with: .color(.secondary), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            let incoming = incidence * .pi / 180
            let source = CGPoint(x: center.x - length * CGFloat(sin(incoming)), y: center.y - length * CGFloat(cos(incoming)))
            var incident = Path()
            incident.move(to: source)
            incident.addLine(to: center)
            context.stroke(incident, with: .color(.orange), lineWidth: 3.5)
            context.fill(Path(ellipseIn: CGRect(x: source.x - 9, y: source.y - 9, width: 18, height: 18)), with: .color(.orange))
            var arc1 = Path()
            arc1.addArc(center: center, radius: 46, startAngle: .degrees(-90), endAngle: .degrees(-90 - incidence), clockwise: true)
            context.stroke(arc1, with: .color(.orange), lineWidth: 1.5)
            context.draw(Text(verbatim: "θ₁ = " + number(incidence, 0) + "°").font(.caption.weight(.bold)).foregroundColor(.orange),
                         at: CGPoint(x: center.x - 60 * CGFloat(sin(incoming / 2)) - 6, y: center.y - 60 * CGFloat(cos(incoming / 2))), anchor: .trailing)
            var outgoing = Path()
            outgoing.move(to: center)
            if let refracted {
                let angle = refracted * .pi / 180
                outgoing.addLine(to: CGPoint(x: center.x + length * CGFloat(sin(angle)), y: center.y + length * CGFloat(cos(angle))))
                context.stroke(outgoing, with: .color(.accentColor), lineWidth: 3.5)
                var arc2 = Path()
                arc2.addArc(center: center, radius: 46, startAngle: .degrees(90), endAngle: .degrees(90 - refracted), clockwise: true)
                context.stroke(arc2, with: .color(.accentColor), lineWidth: 1.5)
                context.draw(Text(verbatim: "θ₂ = " + number(refracted, 1) + "°").font(.caption.weight(.bold)).foregroundColor(.accentColor),
                             at: CGPoint(x: center.x + 60 * CGFloat(sin(angle / 2)) + 6, y: center.y + 60 * CGFloat(cos(angle / 2))), anchor: .leading)
            } else {
                outgoing.addLine(to: CGPoint(x: center.x + length * CGFloat(sin(incoming)), y: center.y - length * CGFloat(cos(incoming))))
                context.stroke(outgoing, with: .color(.red), lineWidth: 3.5)
            }
        }
    }
}

private struct SeesawLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var leftMass = 30.0
    @State private var leftDistance = 2.0
    @State private var rightMass = 40.0
    @State private var rightDistance = 2.0

    private typealias Model = SeesawModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let net = Model.netTorque(leftMass: leftMass, leftDistance: leftDistance, rightMass: rightMass, rightDistance: rightDistance)
        let balanced = abs(net) < 0.5
        LabCard {
            LabHeader(title: text("lab.seesaw.title"), instruction: text("lab.seesaw.subtitle"))

            GeometryReader { proxy in
                board(net: net, size: proxy.size)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        let half = proxy.size.width * 0.45
                        let distance = Double(abs(drag.location.x - proxy.size.width / 2) / half) * Model.distanceRange.upperBound
                        let rounded = min(max((distance * 20).rounded() / 20, Model.distanceRange.lowerBound), Model.distanceRange.upperBound)
                        withAnimation(.interactiveSpring()) {
                            if drag.location.x < proxy.size.width / 2 { leftDistance = rounded } else { rightDistance = rounded }
                        }
                    })
            }
            .frame(height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.seesaw.diagram"))
            .accessibilityValue(Text(verbatim: number(net, 0)))

            HStack(spacing: 16) {
                massStepper(String(format: text("lab.seesaw.leftMass"), number(leftMass, 0)), $leftMass, "lab.seesaw.leftMass")
                massStepper(String(format: text("lab.seesaw.rightMass"), number(rightMass, 0)), $rightMass, "lab.seesaw.rightMass")
            }
            LabStatGrid {
                LabStat(label: String(format: text("lab.seesaw.statLeft"), number(leftDistance, 2)), value: number(Model.torque(mass: leftMass, distance: leftDistance), 0) + " " + text("lab.seesaw.unitNm"), tint: .orange)
                LabStat(label: String(format: text("lab.seesaw.statRight"), number(rightDistance, 2)), value: number(Model.torque(mass: rightMass, distance: rightDistance), 0) + " " + text("lab.seesaw.unitNm"), tint: .accentColor)
            }
            LabStatusBadge(kind: balanced ? .good : .warning, text: text(balanced ? "lab.seesaw.balanced" : (net > 0 ? "lab.seesaw.rightDown" : "lab.seesaw.leftDown")))
            Text(String(format: text("lab.seesaw.balance"), number(Model.balancingDistance(mass: leftMass, distance: leftDistance, otherMass: rightMass), 2)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.seesaw.balance")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.seesaw.challenge"), solved: balanced, solvedText: text("lab.seesaw.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.seesaw.hint"), text("lab.seesaw.limit")])
        }
    }

    private func massStepper(_ title: String, _ value: Binding<Double>, _ identifier: String) -> some View {
        Stepper(value: value.animation(.spring(response: 0.4, dampingFraction: 0.6)), in: Model.massRange, step: 5) { Text(title).monospacedDigit() }
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityIdentifier(identifier)
    }

    // The board tilts toward the larger torque (capped at 12°); each child is a block sized by mass that can be
    // dragged along the board, with distance marks every half metre.
    private func board(net: Double, size: CGSize) -> some View {
        Canvas { context, _ in
            let pivot = CGPoint(x: size.width / 2, y: size.height * 0.68)
            let tilt = CGFloat(max(-12, min(12, net / 20))) * .pi / 180
            let half = size.width * 0.45
            let scale = half / CGFloat(Model.distanceRange.upperBound)
            func point(_ offset: CGFloat, lift: CGFloat = 0) -> CGPoint {
                CGPoint(x: pivot.x + offset * cos(tilt) + lift * sin(tilt), y: pivot.y + offset * sin(tilt) - lift * cos(tilt))
            }
            var plank = Path()
            plank.move(to: point(-half))
            plank.addLine(to: point(half))
            context.stroke(plank, with: .color(.brown), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            for mark in stride(from: 0.5, through: 3.0, by: 0.5) {
                for side in [-1.0, 1.0] {
                    let location = point(CGFloat(side * mark) * scale, lift: -14)
                    context.draw(Text(verbatim: number(mark, 1)).font(.caption2).foregroundColor(.secondary), at: location)
                }
            }
            var triangle = Path()
            triangle.move(to: CGPoint(x: pivot.x, y: pivot.y + 4))
            triangle.addLine(to: CGPoint(x: pivot.x - 18, y: pivot.y + 40))
            triangle.addLine(to: CGPoint(x: pivot.x + 18, y: pivot.y + 40))
            triangle.closeSubpath()
            context.fill(triangle, with: .color(.secondary))
            for (offset, mass, color) in [(-CGFloat(leftDistance) * scale, leftMass, Color.orange), (CGFloat(rightDistance) * scale, rightMass, Color.accentColor)] {
                let side = CGFloat(22 + mass * 0.7)
                let base = point(offset, lift: side / 2 + 4)
                let rect = CGRect(x: base.x - side / 2, y: base.y - side / 2, width: side, height: side)
                context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(color))
                context.draw(Text(verbatim: number(mass, 0) + " " + text("lab.seesaw.unitKg")).font(.caption.weight(.bold)).foregroundColor(.white), at: base)
            }
        }
    }
}

private struct LogisticGrowthLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var rate = 0.1
    @State private var capacity = 1000.0
    @State private var population = 500.0

    private typealias Model = LogisticGrowthModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let growth = Model.growth(population: population, rate: rate, capacity: capacity)
        LabCard {
            LabHeader(title: text("lab.logistic.title"), instruction: text("lab.logistic.subtitle"))
            HStack(spacing: 16) {
                GeometryReader { proxy in
                    let peak = Model.growth(population: capacity / 2, rate: rate, capacity: capacity)
                    let plot = LabPlotGeometry(size: proxy.size, x: 0...capacity, y: 0...max(peak, 1) * 1.2)
                    hump(plot)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                            population = min(max((plot.value(at: drag.location).x / 10).rounded() * 10, 0), capacity)
                        })
                }
                sCurve
                    .frame(width: 300)
            }
            .frame(height: 250)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.logistic.chart"))
            .accessibilityValue(Text(verbatim: number(growth, 1)))

            slider(String(format: text("lab.logistic.rate"), number(rate, 2)), "lab.logistic.rate",
                   Binding(get: { rate }, set: { rate = ($0 * 100).rounded() / 100 }), Model.rateRange)
            slider(String(format: text("lab.logistic.capacity"), number(capacity, 0)), "lab.logistic.capacity",
                   Binding(get: { capacity }, set: { capacity = ($0 / 50).rounded() * 50; population = min(population, capacity) }), Model.capacityRange)
            LabStatGrid {
                LabStat(label: text("lab.logistic.statPopulation"), value: number(population, 0), tint: .accentColor)
                LabStat(label: text("lab.logistic.statGrowth"), value: number(growth, 1), tint: .orange, identifier: "lab.logistic.growth")
                LabStat(label: text("lab.logistic.statExponential"), value: number(Model.exponentialGrowth(population: population, rate: rate), 1), tint: .secondary)
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.logistic.challenge"),
                         solved: abs(population - capacity / 2) <= capacity * 0.01, solvedText: text("lab.logistic.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.logistic.hint"), text("lab.logistic.limit")])
        }
    }

    private func slider(_ title: String, _ identifier: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title).monospacedDigit().frame(minWidth: 260, alignment: .leading)
            // Rounded values without `step:`, which would draw a dense row of tick marks.
            Slider(value: value, in: range)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityIdentifier(identifier)
        }
    }

    // The growth rate against N: a hump peaking at K/2, with the draggable current population.
    private func hump(_ plot: LabPlotGeometry) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: "N", yLabel: "dN/dt", format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -8, dy: -8)))
            var line = Path()
            for index in 0...100 {
                let n = capacity * Double(index) / 100
                let location = plot.point(n, Model.growth(population: n, rate: rate, capacity: capacity))
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
            }
            clipped.stroke(line, with: .color(.accentColor), lineWidth: 2.5)
            var half = Path()
            half.move(to: plot.point(capacity / 2, 0))
            half.addLine(to: plot.point(capacity / 2, Model.growth(population: capacity / 2, rate: rate, capacity: capacity)))
            clipped.stroke(half, with: .color(.secondary), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            clipped.draw(Text(verbatim: "K/2").font(.caption.weight(.semibold)).foregroundColor(.secondary), at: plot.point(capacity / 2, 0), anchor: .bottomLeading)
            let marker = plot.point(population, Model.growth(population: population, rate: rate, capacity: capacity))
            clipped.fill(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.orange))
            clipped.stroke(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.white), lineWidth: 2)
        }
    }

    // The S-shaped curve N(t) from 1% of K, stepped with a small time step, levelling off at K.
    private var sCurve: some View {
        Canvas { context, size in
            var values: [Double] = [capacity * 0.01]
            let dt = 0.5, span = 12 / rate
            while Double(values.count) * dt < span { values.append(values.last! + dt * Model.growth(population: values.last!, rate: rate, capacity: capacity)) }
            let plot = LabPlotGeometry(size: size, x: 0...span, y: 0...capacity * 1.1, leading: 50)
            plot.drawAxes(in: context, xLabel: "t", yLabel: "N", format: { number($0, 0) })
            var clipped = context
            clipped.clip(to: Path(plot.rect))
            var k = Path()
            k.move(to: plot.point(0, capacity))
            k.addLine(to: plot.point(span, capacity))
            clipped.stroke(k, with: .color(.green), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            clipped.draw(Text(verbatim: "K").font(.caption.weight(.bold)).foregroundColor(.green), at: plot.point(span * 0.04, capacity), anchor: .bottomLeading)
            var line = Path()
            for (index, value) in values.enumerated() {
                let location = plot.point(Double(index) * dt, value)
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
            }
            clipped.stroke(line, with: .color(.purple), lineWidth: 2.5)
        }
    }
}

private struct MarkRecaptureLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var marked = 50
    @State private var caught = 60
    @State private var recaptured = 15

    private typealias Model = MarkRecaptureModel

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let estimate = Model.estimate(marked: marked, caught: caught, recaptured: recaptured)
        LabCard {
            LabHeader(title: text("lab.recapture.title"), instruction: text("lab.recapture.subtitle"))
            pond
                .frame(height: 200)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("lab.recapture.chart"))
                .accessibilityValue(Text(verbatim: "\(recaptured) / \(caught)"))
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    stepper(String(format: text("lab.recapture.marked"), String(marked)), "lab.recapture.marked",
                            Binding(get: { marked }, set: { marked = $0; recaptured = min(recaptured, marked) }), 1...300)
                    stepper(String(format: text("lab.recapture.caught"), String(caught)), "lab.recapture.caught",
                            Binding(get: { caught }, set: { caught = $0; recaptured = min(recaptured, caught) }), 1...300)
                }
                GridRow {
                    stepper(String(format: text("lab.recapture.recaptured"), String(recaptured)), "lab.recapture.recaptured",
                            $recaptured, 1...max(1, min(marked, caught)))
                }
            }
            LabStatGrid {
                LabStat(label: text("lab.recapture.statShare"), value: L10n.number(Double(recaptured) / Double(max(caught, 1)) * 100, fractionDigits: 0, store.language) + " %", tint: .orange)
                LabStat(label: text("lab.recapture.statEstimate"), value: estimate.map { L10n.number($0, fractionDigits: 0, store.language) } ?? "—", tint: .green)
            }
            Text(estimate.map {
                    String(format: text("lab.recapture.estimate"), String(marked), String(caught), String(recaptured), L10n.number($0, fractionDigits: 0, store.language))
                } ?? text("lab.recapture.none"))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lab.recapture.estimate")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.recapture.challenge"),
                         solved: marked == 50 && caught == 60 && recaptured == 10, solvedText: text("lab.recapture.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.recapture.hint"), text("lab.recapture.limit")])
        }
    }

    private func stepper(_ title: String, _ identifier: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        Stepper(value: value.animation(.easeInOut(duration: 0.2)), in: range) { Text(title).monospacedDigit() }
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityIdentifier(identifier)
    }

    // The second catch as animals in a pond: the marked ones are orange with a tag, the rest grey.
    private var pond: some View {
        Canvas { context, size in
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18), with: .color(.teal.opacity(0.15)))
            // Typed steps keep older Swift compilers from timing out on one long expression.
            let aspect: Double = Double(size.width / size.height)
            let columns: Int = max(1, Int((Double(caught) * aspect).squareRoot().rounded(.up)))
            let rows: Int = max(1, Int((Double(caught) / Double(columns)).rounded(.up)))
            let cell: CGFloat = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let marginX: CGFloat = (size.width - cell * CGFloat(columns)) / 2
            let marginY: CGFloat = (size.height - cell * CGFloat(rows)) / 2
            for index in 0..<caught {
                let column: CGFloat = CGFloat(index % columns)
                let row: CGFloat = CGFloat(index / columns)
                let center = CGPoint(x: (column + 0.5) * cell + marginX, y: (row + 0.5) * cell + marginY)
                let radius: CGFloat = cell * 0.32
                let isMarked = index < recaptured
                context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.7, width: radius * 2, height: radius * 1.4)),
                             with: .color(isMarked ? .orange : .secondary.opacity(0.55)))
                if isMarked {
                    context.fill(Path(ellipseIn: CGRect(x: center.x + radius * 0.4, y: center.y - radius, width: radius * 0.6, height: radius * 0.6)), with: .color(.white))
                }
            }
        }
    }
}

private struct SurfaceVolumeLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var size = 1.0
    @State private var isSphere = true

    private typealias Model = SurfaceVolumeModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let shape = isSphere ? Model.sphere(radius: size) : Model.cube(side: size)
        let ratio = shape.surface / shape.volume
        LabCard {
            LabHeader(title: text("lab.surface.title"), instruction: text("lab.surface.subtitle"))
            Picker(text("lab.surface.shape"), selection: $isSphere.animation()) {
                Text(text("lab.surface.sphere")).tag(true)
                Text(text("lab.surface.cube")).tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lab.surface.shape")
            HStack(spacing: 16) {
                figure
                    .frame(width: 220)
                GeometryReader { proxy in
                    let plot = LabPlotGeometry(size: proxy.size, x: Model.sizeRange, y: 0...Model.ratio(size: 1, sphere: isSphere) * 1.1)
                    curve(plot)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                            size = min(max((plot.value(at: drag.location).x * 10).rounded() / 10, Model.sizeRange.lowerBound), Model.sizeRange.upperBound)
                        })
                }
            }
            .frame(height: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.surface.chart"))
            .accessibilityValue(Text(verbatim: number(ratio, 2)))

            HStack(spacing: 12) {
                Text(String(format: text(isSphere ? "lab.surface.radius" : "lab.surface.side"), number(size, 1))).monospacedDigit().frame(minWidth: 190, alignment: .leading)
                // Tenths without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { size }, set: { size = ($0 * 10).rounded() / 10 }), in: Model.sizeRange)
                    .accessibilityLabel(text("lab.surface.sizeLabel"))
                    .accessibilityIdentifier("lab.surface.size")
            }
            LabStatGrid {
                LabStat(label: text("lab.surface.statSurface"), value: number(shape.surface, 1), tint: .orange)
                LabStat(label: text("lab.surface.statVolume"), value: number(shape.volume, 1), tint: .purple)
                LabStat(label: "S / V", value: number(ratio, 2), tint: .green, identifier: "lab.surface.ratio")
            }
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.surface.challenge"),
                         solved: abs(ratio - Model.ratio(size: 1, sphere: isSphere) / 4) < 0.01, solvedText: text("lab.surface.challengeSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.surface.hint"), text("lab.surface.limit")])
        }
    }

    // The shape drawn to scale (size 1 to 10 fills the panel at 10), so growth is visible next to the falling ratio.
    private var figure: some View {
        Canvas { canvas, panel in
            let side = min(panel.width, panel.height) * CGFloat(size / Model.sizeRange.upperBound) * 0.9
            let rect = CGRect(x: (panel.width - side) / 2, y: (panel.height - side) / 2, width: side, height: side)
            let path = isSphere ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 3)
            canvas.fill(path, with: .color(.teal.opacity(0.6)))
            canvas.stroke(path, with: .color(.orange), lineWidth: 3)
        }
        .animation(.easeInOut(duration: 0.2), value: size)
    }

    private func curve(_ plot: LabPlotGeometry) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: text(isSphere ? "lab.surface.axisRadius" : "lab.surface.axisSide"), yLabel: "S / V", format: { number($0, $0 == $0.rounded() ? 0 : 1) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -8, dy: -8)))
            var line = Path()
            for index in 0...90 {
                let x = 1 + Double(index) / 10
                let location = plot.point(x, Model.ratio(size: x, sphere: isSphere))
                if index == 0 { line.move(to: location) } else { line.addLine(to: location) }
            }
            clipped.stroke(line, with: .color(.green), lineWidth: 2.5)
            let marker = plot.point(size, Model.ratio(size: size, sphere: isSphere))
            clipped.fill(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.orange))
            clipped.stroke(Path(ellipseIn: CGRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16)), with: .color(.white), lineWidth: 2)
        }
    }
}

private struct PendulumLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var length = 1.0
    @State private var mass = 0.5
    @State private var isSwinging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Model = PendulumModel

    private func number(_ value: Double, _ digits: Int) -> String { L10n.number(value, fractionDigits: digits, store.language) }
    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        let period = Model.period(length: length)
        LabCard {
            LabHeader(title: text("lab.pendulum.title"), instruction: text("lab.pendulum.subtitle"))
            HStack(spacing: 16) {
                // With Reduce Motion the pendulum does not swing; it shows both extreme positions instead.
                TimelineView(.animation(paused: !isSwinging || reduceMotion)) { timeline in
                    pendulum(time: isSwinging && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0)
                }
                .frame(width: 260)
                .accessibilityLabel(text("lab.pendulum.diagram"))
                GeometryReader { proxy in
                    let plot = LabPlotGeometry(size: proxy.size, x: Model.lengthRange, y: 0...3)
                    periodCurve(plot)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                            length = min(max((plot.value(at: drag.location).x * 100).rounded() / 100, Model.lengthRange.lowerBound), Model.lengthRange.upperBound)
                        })
                }
            }
            .frame(height: 260)

            HStack(spacing: 12) {
                Button { isSwinging.toggle() } label: {
                    Label(text(isSwinging ? "lab.descent2d.pause" : "lab.pendulum.swing"), systemImage: isSwinging ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("lab.pendulum.swingButton")
                Text(String(format: text("lab.pendulum.length"), L10n.measurement(length, fractionDigits: 2, unit: "m", store.language))).monospacedDigit().frame(minWidth: 180, alignment: .leading)
                // Rounds to centimetres without `step:`, which would draw a dense row of tick marks.
                Slider(value: Binding(get: { length }, set: { length = ($0 * 100).rounded() / 100 }), in: Model.lengthRange)
                    .accessibilityLabel(text("lab.pendulum.lengthLabel"))
            }
            HStack(spacing: 12) {
                Text(String(format: text("lab.pendulum.mass"), L10n.measurement(mass, fractionDigits: 1, unit: "kg", store.language))).monospacedDigit().frame(minWidth: 180, alignment: .leading)
                Slider(value: Binding(get: { mass }, set: { mass = ($0 * 10).rounded() / 10 }), in: Model.massRange)
                    .accessibilityLabel(text("lab.pendulum.massLabel"))
            }
            LabStatGrid {
                LabStat(label: text("lab.pendulum.statPeriod"), value: L10n.measurement(period, fractionDigits: 2, unit: "s", store.language), tint: .orange)
                LabStat(label: text("lab.pendulum.statFrequency"), value: L10n.measurement(Model.frequency(length: length), fractionDigits: 2, unit: "Hz", store.language), tint: .purple)
            }
            Text(String(format: text("lab.pendulum.reading"), L10n.measurement(period, fractionDigits: 2, unit: "s", store.language),
                        L10n.measurement(Model.frequency(length: length), fractionDigits: 2, unit: "Hz", store.language)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.pendulum.reading")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.pendulum.goal"), solved: abs(period - 2) < 0.01, solvedText: text("lab.pendulum.goalSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [text("lab.pendulum.hint"), text("lab.pendulum.challenge"), text("lab.pendulum.limit")])
        }
    }

    // The pendulum drawn to scale with the bob sized by mass; it swings with the true period when started.
    private func pendulum(time: Double) -> some View {
        Canvas { context, size in
            let pivot = CGPoint(x: size.width / 2, y: 14)
            let scale = (size.height - 50) / CGFloat(Model.lengthRange.upperBound)
            let angle = isSwinging && !reduceMotion ? Model.angle(atSeconds: time, length: length) : Model.amplitudeDegrees * .pi / 180
            if isSwinging && reduceMotion {
                let ghost = CGPoint(x: pivot.x - CGFloat(sin(angle)) * CGFloat(length) * scale, y: pivot.y + CGFloat(cos(angle)) * CGFloat(length) * scale)
                var ghostString = Path()
                ghostString.move(to: pivot)
                ghostString.addLine(to: ghost)
                context.stroke(ghostString, with: .color(.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                let ghostRadius = CGFloat(8 + mass * 9)
                context.fill(Path(ellipseIn: CGRect(x: ghost.x - ghostRadius, y: ghost.y - ghostRadius, width: 2 * ghostRadius, height: 2 * ghostRadius)), with: .color(.orange.opacity(0.35)))
            }
            let bob = CGPoint(x: pivot.x + CGFloat(sin(angle)) * CGFloat(length) * scale, y: pivot.y + CGFloat(cos(angle)) * CGFloat(length) * scale)
            context.fill(Path(CGRect(x: pivot.x - 40, y: pivot.y - 6, width: 80, height: 6)), with: .color(.secondary))
            var string = Path()
            string.move(to: pivot)
            string.addLine(to: bob)
            context.stroke(string, with: .color(.primary), lineWidth: 2)
            let radius = CGFloat(8 + mass * 9)
            context.fill(Path(ellipseIn: CGRect(x: bob.x - radius, y: bob.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(.orange))
        }
    }

    // T = 2π√(L/g) against L with the chosen length marked; the L = 0.25 m and 1.00 m pair shows the doubling.
    private func periodCurve(_ plot: LabPlotGeometry) -> some View {
        Canvas { context, _ in
            plot.drawAxes(in: context, xLabel: text("lab.pendulum.axisLength"), yLabel: text("lab.pendulum.axisPeriod"), format: { number($0, $0 == $0.rounded() ? 0 : 1) })
            var clipped = context
            clipped.clip(to: Path(plot.rect.insetBy(dx: -8, dy: -8)))
            var curve = Path()
            for index in 0...100 {
                let l = plot.x.lowerBound + (plot.x.upperBound - plot.x.lowerBound) * Double(index) / 100
                let location = plot.point(l, Model.period(length: l))
                if index == 0 { curve.move(to: location) } else { curve.addLine(to: location) }
            }
            clipped.stroke(curve, with: .color(.accentColor), lineWidth: 2.5)
            for l in [0.25, 1.0] {
                let location = plot.point(l, Model.period(length: l))
                clipped.fill(Path(ellipseIn: CGRect(x: location.x - 4, y: location.y - 4, width: 8, height: 8)), with: .color(.green))
            }
            let current = plot.point(length, Model.period(length: length))
            clipped.fill(Path(ellipseIn: CGRect(x: current.x - 8, y: current.y - 8, width: 16, height: 16)), with: .color(.orange))
            clipped.stroke(Path(ellipseIn: CGRect(x: current.x - 8, y: current.y - 8, width: 16, height: 16)), with: .color(.white), lineWidth: 2)
        }
    }
}

private struct PendulumDrawing: View {
    let lengthFraction: Double
    let massFraction: Double
    let angle: Double

    var body: some View {
        Canvas { context, size in
            let pivot = CGPoint(x: size.width / 2, y: 8)
            let stringLength = (size.height - 30) * CGFloat(lengthFraction)
            let bob = CGPoint(
                x: pivot.x + stringLength * CGFloat(sin(angle)),
                y: pivot.y + stringLength * CGFloat(cos(angle))
            )
            var support = Path()
            support.move(to: CGPoint(x: pivot.x - 30, y: pivot.y))
            support.addLine(to: CGPoint(x: pivot.x + 30, y: pivot.y))
            context.stroke(support, with: .color(.secondary), lineWidth: 2)
            var string = Path()
            string.move(to: pivot)
            string.addLine(to: bob)
            context.stroke(string, with: .color(.secondary), lineWidth: 1.5)
            let radius = 6 + 8 * CGFloat(massFraction)
            context.fill(Path(ellipseIn: CGRect(x: bob.x - radius, y: bob.y - radius, width: radius * 2, height: radius * 2)), with: .color(.accentColor))
        }
    }
}

private struct HeatMixingLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var coldMass = 1.0
    @State private var coldTemperature = 20.0
    @State private var hotMass = 1.0
    @State private var hotTemperature = 80.0

    private typealias Model = HeatMixingModel

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func celsius(_ value: Double, _ digits: Int = 1) -> String { L10n.measurement(value, fractionDigits: digits, unit: "°C", store.language) }

    // Blue for cold water through purple to red for hot, by temperature from 0 to 100 °C.
    private func waterColor(_ temperature: Double) -> Color {
        let t = min(max(temperature / 100, 0), 1)
        return Color(red: 0.15 + 0.8 * t, green: 0.35 - 0.2 * t, blue: 0.9 - 0.75 * t)
    }

    var body: some View {
        let finalTemperature = Model.finalTemperature(coldMass: coldMass, coldTemperature: coldTemperature, hotMass: hotMass, hotTemperature: hotTemperature)
        let transferredHeat = abs(Model.heat(mass: coldMass, from: coldTemperature, to: finalTemperature))
        LabCard {
            LabHeader(title: text("lab.heat.title"), instruction: text("lab.heat.subtitle"))
            HStack(alignment: .bottom, spacing: 22) {
                beaker(text("lab.heat.first"), mass: coldMass, temperature: coldTemperature)
                Image(systemName: "plus").font(.title2.weight(.bold)).foregroundStyle(.secondary)
                beaker(text("lab.heat.second"), mass: hotMass, temperature: hotTemperature)
                Image(systemName: "arrow.right").font(.title2.weight(.bold)).foregroundStyle(.secondary)
                beaker(text("lab.heat.mixture"), mass: coldMass + hotMass, temperature: finalTemperature)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("lab.heat.scale"))
            .accessibilityValue(Text(verbatim: celsius(finalTemperature)))

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                portion(text("lab.heat.first"), mass: $coldMass, temperature: $coldTemperature)
                portion(text("lab.heat.second"), mass: $hotMass, temperature: $hotTemperature)
            }
            LabStatGrid {
                LabStat(label: text("lab.heat.statFinal"), value: celsius(finalTemperature), tint: .purple)
                LabStat(label: text("lab.heat.statHeat"), value: L10n.measurement(transferredHeat / 1000, fractionDigits: 1, unit: "kJ", store.language), tint: .orange)
            }
            Text(String(format: text("lab.heat.result"), celsius(finalTemperature)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("lab.heat.result")
            LabChallenge(caption: text("lab.kit.task"), task: text("lab.heat.goal"),
                         solved: coldTemperature == 20 && hotTemperature == 80 && abs(finalTemperature - 40) < 0.05, solvedText: text("lab.heat.goalSolved"))
            LabExplainer(title: text("lab.kit.how"), paragraphs: [
                text("lab.heat.hint"),
                String(format: text("lab.heat.transfer"), L10n.measurement(transferredHeat / 1000, fractionDigits: 1, unit: "kJ", store.language)),
                text("lab.heat.challenge"),
                text("lab.heat.limit"),
            ])
        }
    }

    private func portion(_ title: String, mass: Binding<Double>, temperature: Binding<Double>) -> some View {
        GridRow {
            Text(title).font(.callout.weight(.semibold))
            Text(String(format: text("lab.heat.mass"), L10n.measurement(mass.wrappedValue, fractionDigits: 1, unit: "kg", store.language))).monospacedDigit().frame(minWidth: 90, alignment: .leading)
            // Rounded values without `step:`, which would draw a dense row of tick marks.
            Slider(value: Binding(get: { mass.wrappedValue }, set: { mass.wrappedValue = ($0 * 10).rounded() / 10 }), in: Model.massRange)
                .accessibilityLabel(Text(title + " · " + text("lab.heat.massLabel")))
            Text(String(format: text("lab.heat.temperature"), temperature.wrappedValue)).monospacedDigit().frame(minWidth: 80, alignment: .leading)
            Slider(value: Binding(get: { temperature.wrappedValue }, set: { temperature.wrappedValue = $0.rounded() }), in: Model.temperatureRange)
                .accessibilityLabel(Text(title + " · " + text("lab.heat.temperatureLabel")))
        }
    }

    // A beaker filled in proportion to the mass and coloured by temperature, with a thermometer reading.
    private func beaker(_ title: String, mass: Double, temperature: Double) -> some View {
        VStack(spacing: 6) {
            Text(verbatim: celsius(temperature)).font(.headline.monospacedDigit()).foregroundStyle(waterColor(temperature))
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10).stroke(Color.secondary, lineWidth: 2).frame(width: 90, height: 150)
                RoundedRectangle(cornerRadius: 8).fill(waterColor(temperature).gradient)
                    .frame(width: 84, height: max(6, 146 * CGFloat(mass / (2 * Model.massRange.upperBound))))
                    .padding(.bottom, 2)
            }
            Text(verbatim: "\(title) · " + L10n.measurement(mass, fractionDigits: 1, unit: "kg", store.language)).font(.caption).foregroundStyle(.secondary)
        }
        .animation(.easeInOut(duration: 0.25), value: temperature)
        .animation(.easeInOut(duration: 0.25), value: mass)
    }
}

private struct ShortMessageLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var stepIndex = 0
    @State private var selectedDisplayIndex: Int?
    @State private var feedbackCorrect: Bool?
    @State private var choiceOrder = AnswerChoiceOrder(optionCount: 3)

    private var currentStep: ShortMessageStep? {
        ShortMessagePractice.steps.indices.contains(stepIndex) ? ShortMessagePractice.steps[stepIndex] : nil
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.message.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.message.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let step = currentStep {
                Text(String(format: L10n.text("lab.message.progress", store.language), stepIndex + 1, ShortMessagePractice.steps.count))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(L10n.text(step.promptKey, store.language))
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Picker(L10n.text("lab.message.choose", store.language), selection: $selectedDisplayIndex) {
                    ForEach(Array(choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                        Text(L10n.text(step.optionKeys[originalIndex], store.language)).tag(displayIndex as Int?)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(feedbackCorrect == true)
                .accessibilityIdentifier("lab.message.options")

                if feedbackCorrect == true {
                    Button(L10n.text("lab.message.next", store.language)) { advance() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(L10n.text("lab.message.check", store.language)) { check(step) }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedDisplayIndex == nil)
                }

                if let feedbackCorrect {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            L10n.text(feedbackCorrect ? "lab.message.correct" : "lab.message.review", store.language),
                            systemImage: feedbackCorrect ? "checkmark.circle.fill" : "arrow.uturn.backward.circle"
                        )
                        .font(.callout.weight(.medium))
                        .foregroundStyle(feedbackCorrect ? .green : .orange)
                        if feedbackCorrect {
                            Text(L10n.text(step.explanationKey, store.language))
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("lab.message.feedback")
                }
            } else {
                Text(L10n.text("lab.message.result", store.language))
                    .font(.callout.weight(.medium))
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ShortMessagePractice.assembledMessageKeys, id: \.self) { key in
                        Text(L10n.text(key, store.language))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)
                .accessibilityIdentifier("lab.message.assembled")
                Button(L10n.text("lab.message.restart", store.language)) { restart() }
            }

            Text(L10n.text("lab.message.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func check(_ step: ShortMessageStep) {
        guard let selectedDisplayIndex, let original = choiceOrder.originalIndex(forDisplayedIndex: selectedDisplayIndex) else { return }
        let correct = ShortMessagePractice.isCorrect(original, stepID: step.id)
        feedbackCorrect = correct
        if !correct {
            // After a wrong answer the options are reshuffled so the retry is a fresh choice.
            choiceOrder.reshuffle()
            self.selectedDisplayIndex = nil
        }
    }

    private func advance() {
        stepIndex += 1
        selectedDisplayIndex = nil
        feedbackCorrect = nil
        choiceOrder = AnswerChoiceOrder(optionCount: 3)
    }

    private func restart() {
        stepIndex = 0
        selectedDisplayIndex = nil
        feedbackCorrect = nil
        choiceOrder = AnswerChoiceOrder(optionCount: 3)
    }
}

private struct DataStructureChoiceLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var stepIndex = 0
    @State private var selectedDisplayIndex = -1
    @State private var feedbackCorrect: Bool?
    @State private var optionOrders = Self.makeOptionOrders()

    private var optionOrder: QuizAnswerOrder { optionOrders[stepIndex] }
    @State private var assessmentTracker = InteractiveChoiceAssessmentTracker(
        itemIDs: DataStructureChoicePractice.scenarios.map(\.id)
    )

    private var currentScenario: DataStructureChoiceScenario? {
        guard DataStructureChoicePractice.scenarios.indices.contains(stepIndex) else { return nil }
        return DataStructureChoicePractice.scenarios[stepIndex]
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.dataStructures.title", store.language))
                .font(.headline)
            Text(L10n.text("lab.dataStructures.hint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let scenario = currentScenario {
                Text(String(format: L10n.text("lab.dataStructures.progress", store.language), stepIndex + 1, DataStructureChoicePractice.scenarios.count))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(L10n.text(scenario.promptKey, store.language))
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Picker(L10n.text("lab.dataStructures.choicePicker", store.language), selection: $selectedDisplayIndex) {
                    Text(L10n.text("lab.dataStructures.choose", store.language)).tag(-1)
                    ForEach(Array(optionOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                        Text(L10n.text(scenario.optionKeys[originalIndex], store.language))
                            .tag(displayIndex)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(feedbackCorrect == true)
                .onChange(of: selectedDisplayIndex) { _ in
                    if feedbackCorrect == false { feedbackCorrect = nil }
                }

                if let feedbackCorrect {
                    Label(
                        L10n.text(feedbackCorrect ? "lab.dataStructures.correct" : "lab.dataStructures.incorrect", store.language),
                        systemImage: feedbackCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(feedbackCorrect ? Color.green : Color.orange)
                    Text(L10n.text(scenario.explanationKey, store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        check(scenario: scenario)
                    } label: {
                        Label(L10n.text("lab.dataStructures.check", store.language), systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedDisplayIndex < 0 || feedbackCorrect == true)

                    if feedbackCorrect == true {
                        Button(action: advance) {
                            Label(L10n.text("lab.dataStructures.next", store.language), systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Label(L10n.text("lab.dataStructures.complete", store.language), systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                Button(action: restart) {
                    Label(L10n.text("lab.dataStructures.restart", store.language), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            Text(L10n.text("lab.dataStructures.limit", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func check(scenario: DataStructureChoiceScenario) {
        guard let answerIndex = optionOrder.originalIndex(forDisplayedIndex: selectedDisplayIndex) else { return }
        let isAnswerCorrect = DataStructureChoicePractice.isCorrect(answerIndex, for: scenario.id)
        feedbackCorrect = isAnswerCorrect
        guard let evidence = assessmentTracker.recordSubmission(
            selectedAnswerIndex: answerIndex,
            correctAnswerIndex: scenario.correctOptionIndex,
            optionCount: scenario.optionKeys.count,
            itemID: scenario.id
        ) else { return }
        store.recordStudyAssessment(lessonID: "programming.search_and_complexity", evidence: evidence)
    }

    private func advance() {
        stepIndex += 1
        selectedDisplayIndex = -1
        feedbackCorrect = nil
        guard currentScenario != nil else { return }
    }

    private func restart() {
        stepIndex = 0
        selectedDisplayIndex = -1
        feedbackCorrect = nil
        optionOrders = Self.makeOptionOrders()
        assessmentTracker.reset()
    }

    private static func makeOptionOrders() -> [QuizAnswerOrder] {
        QuizAnswerOrder.balancedSequence(
            optionCount: DataStructureChoicePractice.scenarios[0].optionKeys.count,
            answerOriginalIndices: DataStructureChoicePractice.scenarios.map(\.correctOptionIndex)
        )
    }
}

private struct LoopTraceLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var scenarioID: String
    @State private var question: LoopTraceQuestion
    @State private var prediction: InteractivePredictionAttempt
    @State private var selectedDisplayIndex = -1
    @State private var revealedStepCount = 0

    init() {
        let initialScenario = LoopTracePractice.scenarios[0]
        let initialQuestion = LoopTraceQuestion(scenario: initialScenario)
        _scenarioID = State(initialValue: initialScenario.id)
        _question = State(initialValue: initialQuestion)
        _prediction = State(initialValue: Self.makePrediction(for: initialQuestion))
    }

    private var scenario: LoopTraceScenario {
        LoopTracePractice.scenario(id: scenarioID) ?? LoopTracePractice.scenarios[0]
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.loopTraceHint", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("count_even(\(scenario.displayedValues))")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
                .accessibilityLabel(Text(L10n.text("lab.loopTraceInput", store.language)))

            Picker(
                L10n.text("lab.loopTraceScenario", store.language),
                selection: Binding(
                    get: { scenarioID },
                    set: selectScenario
                )
            ) {
                ForEach(LoopTracePractice.scenarios) { item in
                    Text(L10n.text("lab.loopTraceScenario.\(item.id)", store.language)).tag(item.id)
                }
            }
            .pickerStyle(.menu)

            Text("""
            count = 0
            for number in numbers:
                if number % 2 == 0:
                    count += 1
            return count
            """)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(Text(L10n.text("lab.loopTraceCode", store.language)))

            HStack {
                Text(L10n.text("lab.loopTracePrediction", store.language))
                Spacer()
                Picker(L10n.text("lab.loopTracePrediction", store.language), selection: $selectedDisplayIndex) {
                    Text(L10n.text("lab.loopTraceChoose", store.language)).tag(-1)
                    ForEach(Array(prediction.choiceOrder.displayedOriginalIndices.enumerated()), id: \.offset) { displayIndex, originalIndex in
                        Text(String(question.options[originalIndex])).tag(displayIndex)
                    }
                }
                .pickerStyle(.menu)
                .disabled(prediction.hasAnswered)
            }

            if prediction.hasAnswered {
                if prediction.isCorrect {
                    Label(
                        String(format: L10n.text("lab.loopTraceFeedback", store.language), scenario.expectedCount),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(scenario.steps.prefix(revealedStepCount))) { step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(step.index + 1)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(format: L10n.text("lab.loopTraceStep", store.language), step.value))
                                    .font(.system(.callout, design: .monospaced).weight(.medium))
                                Text(L10n.text(step.isEven ? "lab.loopTraceEven" : "lab.loopTraceOdd", store.language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(step.countAfter))
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                                .accessibilityLabel(Text(L10n.text("lab.loopTraceCount", store.language)))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityElement(children: .combine)
                    }

                    if revealedStepCount == scenario.steps.count {
                        Label(
                            String(format: L10n.text("lab.loopTraceReturn", store.language), scenario.expectedCount),
                            systemImage: "arrow.uturn.backward.circle"
                        )
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.tint)
                    }
                } else {
                    Label(L10n.text("lab.loopTraceWrong", store.language), systemImage: "arrow.counterclockwise.circle")
                        .foregroundStyle(.orange)
                    Text(L10n.text("lab.loopTraceWrongHint", store.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("lab.loopTraceRetry", store.language)) {
                        prediction.retry()
                        selectedDisplayIndex = -1
                        revealedStepCount = 0
                    }
                    .buttonStyle(.link)
                }
            }

            if prediction.hasAnswered, prediction.isCorrect {
                Button {
                    revealedStepCount = min(revealedStepCount + 1, scenario.steps.count)
                } label: {
                    Label(L10n.text("lab.loopTraceNextStep", store.language), systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(revealedStepCount >= scenario.steps.count)
            } else if !prediction.hasAnswered {
                Button {
                    prediction.select(displayedIndex: selectedDisplayIndex)
                    guard let evidence = prediction.currentAnswerEventEvidence() else { return }
                    store.recordStudyAssessment(lessonID: "programming.conditions_loops_functions", evidence: evidence)
                    if prediction.isCorrect {
                        revealedStepCount = scenario.steps.isEmpty ? 0 : 1
                    }
                } label: {
                    Label(L10n.text("lab.loopTraceCheck", store.language), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedDisplayIndex < 0)
            }
        }
    }

    private static func makePrediction(for question: LoopTraceQuestion) -> InteractivePredictionAttempt {
        guard let attempt = InteractivePredictionAttempt(
            optionCount: question.options.count,
            answerOriginalIndex: question.correctOptionIndex,
            itemID: question.itemID
        ) else {
            preconditionFailure("A loop-trace prediction must have one valid answer.")
        }
        return attempt
    }

    private func selectScenario(_ id: String) {
        guard let nextScenario = LoopTracePractice.scenario(id: id) else { return }
        scenarioID = nextScenario.id
        let nextQuestion = LoopTraceQuestion(scenario: nextScenario)
        question = nextQuestion
        prediction = Self.makePrediction(for: nextQuestion)
        selectedDisplayIndex = -1
        revealedStepCount = 0
    }
}

private struct CollectionsLoopsLab: View {
    @EnvironmentObject private var store: LearningStore
    @State private var tasks = ["docs", "tests", "app"]
    @State private var nextTask = 0
    @State private var includesIndexes = true
    @State private var whileInitialValue = 5
    @State private var whileDecrement = 2
    @State private var whileTrace = WhileLoopTrace(initialValue: 5, decrement: 2)

    private let additions = ["build", "review", "ship", "notes", "measure"]

    private var outputLines: [String] {
        if includesIndexes {
            return tasks.enumerated().map { "\($0.offset)  \($0.element)" }
        }
        return tasks.map { $0 }
    }

    private var loopCode: String {
        includesIndexes
            ? "for index, task in enumerate(tasks):\n    print(index, task)"
            : "for task in tasks:\n    print(task)"
    }

    var body: some View {
        LabCard {
            Text(L10n.text("lab.collectionsHelp", store.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("tasks = [\(tasks.map { "\"\($0)\"" }.joined(separator: ", "))]")
                .font(.system(.body, design: .monospaced).weight(.medium))
                .textSelection(.enabled)
                .accessibilityLabel(Text(L10n.text("lab.collectionsState", store.language)))

            if tasks.isEmpty {
                Label(L10n.text("lab.collectionsEmpty", store.language), systemImage: "list.bullet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(tasks.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 7) {
                                if includesIndexes {
                                    Text("[\(index)]")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text(tasks[index])
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .accessibilityLabel(Text(L10n.text("lab.collectionsState", store.language)))
            }

            Picker(L10n.text("lab.collectionsLoop", store.language), selection: $includesIndexes) {
                Text(L10n.text("lab.collectionsValuesOnly", store.language)).tag(false)
                Text(L10n.text("lab.collectionsWithIndex", store.language)).tag(true)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text(loopCode)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Divider()
                ForEach(outputLines.indices, id: \.self) { index in
                    Text(outputLines[index])
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                Button {
                    guard tasks.count < 8 else { return }
                    tasks.append(additions[nextTask % additions.count])
                    nextTask += 1
                } label: {
                    Label(L10n.text("lab.collectionsAdd", store.language), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(tasks.count >= 8)

                Button {
                    guard !tasks.isEmpty else { return }
                    tasks.removeLast()
                } label: {
                    Label(L10n.text("lab.collectionsRemove", store.language), systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(tasks.isEmpty)
            }

            Text(L10n.text("lab.collectionsCount", store.language) + ": \(tasks.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("lab.collectionsWhileTitle", store.language))
                    .font(.headline)
                Text(L10n.text("lab.collectionsWhileHint", store.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("remaining = \(whileTrace.initialValue)\nwhile remaining > 0:\n    print(remaining)\n    remaining -= \(whileTrace.decrement)")
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))

                Stepper(value: $whileInitialValue, in: WhileLoopTrace.initialValueRange) {
                    Text(String(format: L10n.text("lab.collectionsWhileInitial", store.language), whileInitialValue))
                        .font(.callout.monospacedDigit())
                }
                .onChange(of: whileInitialValue) { _ in resetWhileTrace() }

                Stepper(value: $whileDecrement, in: WhileLoopTrace.decrementRange) {
                    Text(String(format: L10n.text("lab.collectionsWhileDecrement", store.language), whileDecrement))
                        .font(.callout.monospacedDigit())
                }
                .onChange(of: whileDecrement) { _ in resetWhileTrace() }

                Label(
                    String(format: L10n.text("lab.collectionsWhileCurrent", store.language), whileTrace.currentValue),
                    systemImage: whileTrace.isComplete ? "checkmark.circle.fill" : "repeat"
                )
                .font(.callout.weight(.medium).monospacedDigit())
                .foregroundStyle(whileTrace.isComplete ? Color.green : Color.primary)

                Text(L10n.text("lab.collectionsWhileOutput", store.language) + ": [\(whileTrace.printedValues.map(String.init).joined(separator: ", "))]")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)

                ForEach(whileTrace.steps) { step in
                    VStack(alignment: .leading, spacing: 4) {
                        let feedbackKey = step.conditionTrue
                            ? "lab.collectionsWhileConditionTrue"
                            : "lab.collectionsWhileConditionFalse"
                        Label(
                            String(format: L10n.text(feedbackKey, store.language), step.checkNumber, step.valueBeforeCheck),
                            systemImage: step.conditionTrue ? "checkmark.circle" : "stop.circle.fill"
                        )
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(step.conditionTrue ? Color.secondary : Color.green)

                        if let valueAfterBody = step.valueAfterBody {
                            Text(String(format: L10n.text("lab.collectionsWhileBody", store.language), valueAfterBody))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.text("lab.collectionsWhileExit", store.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 10) {
                    Button {
                        whileTrace.checkNextStep()
                    } label: {
                        Label(L10n.text("lab.collectionsWhileCheck", store.language), systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(whileTrace.isComplete)

                    Button {
                        resetWhileTrace()
                    } label: {
                        Label(L10n.text("lab.collectionsWhileRestart", store.language), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Text(L10n.text("lab.collectionsWhileLimit", store.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func resetWhileTrace() {
        whileTrace = WhileLoopTrace(initialValue: whileInitialValue, decrement: whileDecrement)
    }
}


private struct PendingCustomTopicOutlineReview: Identifiable {
    let messageID: UUID
    let proposal: CustomTopicOutlineProposal

    var id: UUID { messageID }
}

struct TutorChatView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backendSupervisor: LocalBackendSupervisor
    @StateObject private var chat: TutorChatModel
    @State private var draft = ""
    @State private var useWebSearch = false
    @State private var includeLocalSourcesInWebSearch = false
    @State private var hasConfirmedGoogleSearchAge = false
    @State private var showGoogleSearchAgeConfirmation = false
    @State private var outlinePromptPrepared = false
    @State private var outlineResponseMessageID: UUID?
    @State private var pendingOutlineReview: PendingCustomTopicOutlineReview?
    @State private var importedOutlineMessageIDs = Set<UUID>()
    @State private var outlineErrorMessageID: UUID?
    @State private var outlineImportError: String?
    @State private var outlineImportSuccess: String?
    let language: AppLanguage
    private let tutorSubjectID: String
    private let outlineDraftPrompt: String?
    private let outlineDestination: CustomTopicOutlineDestination?
    private let outlineParentTopicID: UUID?

    init(subject: Subject, lesson: LessonContent, language: AppLanguage, mode: AIRoutingMode) {
        self.language = language
        tutorSubjectID = subject.rawValue
        outlineDraftPrompt = nil
        outlineDestination = nil
        outlineParentTopicID = nil
        _chat = StateObject(wrappedValue: TutorChatModel(subject: subject, lesson: lesson, language: language, mode: mode))
    }

    init(
        customSubject: CustomLearningSubject,
        topic: CustomLearningTopic,
        language: AppLanguage,
        mode: AIRoutingMode,
        routeSubjectID: String? = nil,
        outlineDestination: CustomTopicOutlineDestination? = nil,
        outlineParentTopicID: UUID? = nil
    ) {
        self.language = language
        let resolvedSubjectID = routeSubjectID ?? "custom-\(customSubject.id.uuidString.lowercased())"
        tutorSubjectID = resolvedSubjectID
        self.outlineDestination = outlineDestination
        self.outlineParentTopicID = outlineParentTopicID
        outlineDraftPrompt = outlineDestination != nil && outlineParentTopicID != nil
            ? CustomTopicStudyPrompt.outlineDraft(languageCode: language.rawValue)
            : nil
        let topicName = topic.name.value(in: language.rawValue)
        let subjectName = customSubject.name.value(in: language.rawValue)
        let notes = topic.notes.value(in: language.rawValue)
        let goal = topic.learningOutcome.value(in: language.rawValue)
        let lesson = LessonContent(
            title: topicName,
            objective: goal.isEmpty ? topicName : goal,
            explanation: notes,
            mechanism: L10n.text("custom.learnPrompt", language),
            example: notes,
            limitations: language == .ru
                ? "Это пользовательский материал. Не выдавай его за подтверждённый источник; отмечай, что требует проверки."
                : "This is learner-provided material. Do not present it as a verified source; flag claims that need checking.",
            question: "",
            options: [],
            answerIndex: 0,
            feedback: ""
        )
        _chat = StateObject(wrappedValue: TutorChatModel(
            subjectID: resolvedSubjectID,
            subjectName: subjectName,
            lesson: lesson,
            language: language,
            mode: mode
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("tutor.title", language)).font(.title2.weight(.semibold))
                    Text(L10n.text("tutor.subtitle", language)).font(.subheadline).foregroundStyle(.secondary)
                    if let preference = store.studyFormatPreferenceProfile.tutorPreference(forSubjectID: tutorSubjectID) {
                        let preferenceKey = store.studyFormatPreferenceProfile.mostFrequentlyHelpful(forSubjectID: tutorSubjectID) == nil
                            ? "studyFormat.tutorFallback"
                            : "studyFormat.tutorPreference"
                        Label(
                            String(
                                format: L10n.text(preferenceKey, language),
                                L10n.text(preference.titleKey, language)
                            ),
                            systemImage: "sparkles"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if chat.isSending {
                    Label(L10n.text("settings.tutorProbe.checking", language), systemImage: "hourglass")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let completionLabel = chat.completionLabel {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(L10n.text("tutor.responseVerified", language), systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                        if !completionLabel.isEmpty {
                            Text(completionLabel)
                                .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } else if store.isCheckingAI && store.aiHealth == nil {
                    ProgressView().controlSize(.small)
                } else if let health = store.aiHealth {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(L10n.text("settings.aiBackendResponding", language), systemImage: "server.rack")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(L10n.text("tutor.responseNotVerified", language))
                            .font(.caption2).foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                        Text(routeDescription(for: health))
                            .font(.caption2).foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    Label(L10n.text("settings.aiOffline", language), systemImage: "wifi.slash")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if chat.messages.isEmpty {
                            VStack(spacing: 12) {
                                Text(L10n.text("tutor.empty", language))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: outlineDraftPrompt == nil ? 220 : 140)
                                if outlineDraftPrompt != nil {
                                    Button {
                                        if let outlineDraftPrompt {
                                            draft = outlineDraftPrompt
                                            outlinePromptPrepared = true
                                            outlineImportSuccess = nil
                                        }
                                    } label: {
                                        Label(L10n.text("custom.outlineDraftAction", language), systemImage: "list.bullet.rectangle")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(chat.isSending || !canSend)
                                    Text(L10n.text("custom.outlineDraftHint", language))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 520)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        ForEach(chat.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                        if let error = chat.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout).foregroundStyle(.orange)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: chat.messages.count) { _ in
                    if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onChange(of: chat.messages.last?.text) { _ in
                    if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text(chat.mode == .localOnly ? "tutor.localPrivacy" : "tutor.privacy", language))
                    .font(.caption).foregroundStyle(.secondary)
                if let outlineImportSuccess {
                    Label(outlineImportSuccess, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if chat.mode == .automatic {
                    if let policy = store.autoCostPolicy, !policy.allowPaidRoutes {
                        Label(L10n.text("tutor.webSearchCostBlocked", language), systemImage: "lock.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else if store.autoCostPolicy == nil {
                        Label(L10n.text("tutor.webSearchCostChecking", language), systemImage: "lock.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Toggle(isOn: Binding(
                        get: { useWebSearch },
                        set: { enabled in
                            guard enabled else {
                                useWebSearch = false
                                includeLocalSourcesInWebSearch = false
                                return
                            }
                            if hasConfirmedGoogleSearchAge {
                                useWebSearch = true
                            } else {
                                showGoogleSearchAgeConfirmation = true
                            }
                        }
                    )) {
                        Label(L10n.text("tutor.webSearchToggle", language), systemImage: "globe")
                    }
                    .toggleStyle(.checkbox)
                    .disabled(chat.isSending || store.autoCostPolicy?.allowPaidRoutes != true)
                    .alert(L10n.text("tutor.webSearchAgeTitle", language), isPresented: $showGoogleSearchAgeConfirmation) {
                        Button(L10n.text("tutor.webSearchCancel", language), role: .cancel) {}
                        Button(L10n.text("tutor.webSearchAgeConfirm", language)) {
                            hasConfirmedGoogleSearchAge = true
                            useWebSearch = true
                        }
                    } message: {
                        Text(L10n.text("tutor.webSearchAgeMessage", language))
                    }
                    if useWebSearch {
                        Toggle(isOn: $includeLocalSourcesInWebSearch) {
                            Label(L10n.text("tutor.webSearchIncludeLocalSources", language), systemImage: "folder")
                        }
                        .toggleStyle(.checkbox)
                        .disabled(chat.isSending)
                        Text(L10n.text(
                            includeLocalSourcesInWebSearch
                                ? "tutor.webSearchPrivacyWithLocalSources"
                                : "tutor.webSearchPrivacy",
                            language
                        ))
                            .font(.caption2).foregroundStyle(.secondary)
                        if store.aiHealth?.geminiKeyConfigured != true {
                            Label(L10n.text("tutor.webSearchNeedsGeminiKey", language), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                        } else if store.aiHealth?.hasGroundedSearch != true {
                            Label(L10n.text("tutor.webSearchUnavailable", language), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                } else {
                    Label(L10n.text("tutor.webSearchAutoOnly", language), systemImage: "wifi.slash")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if !composerReadiness.isReady, let messageKey = composerReadiness.messageKey {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(L10n.text(messageKey, language), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                        if composerReadiness == .backendNotReady {
                            Text(L10n.text(backendSupervisor.status.localizationKey, language))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField(L10n.text("tutor.placeholder", language), text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .onSubmit(send)
                        .disabled(chat.isSending || !canSend)
                    if chat.isSending {
                        Button(action: chat.cancel) {
                            Label(L10n.text("tutor.stop", language), systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: send) {
                            Label(L10n.text("tutor.send", language), systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canSend)
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(item: $pendingOutlineReview) { pending in
            if let outlineDestination, let outlineParentTopicID {
                CustomTopicOutlineReviewView(
                    proposal: pending.proposal,
                    destination: outlineDestination,
                    parentTopicID: outlineParentTopicID
                ) { count in
                    importedOutlineMessageIDs.insert(pending.messageID)
                    outlineImportSuccess = String(
                        format: L10n.text("custom.outlineSaved", language),
                        "\(count)"
                    )
                    outlineErrorMessageID = nil
                    outlineImportError = nil
                }
            }
        }
        .task {
            guard await backendSupervisor.ensureRunning() else { return }
            await store.refreshAIStatus()
            await store.refreshAutoCostPolicy()
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: TutorMessage) -> some View {
        HStack {
            if message.role == .learner { Spacer(minLength: 50) }
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text(message.role == .learner ? "tutor.learner" : "tutor.assistant", language))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                if message.role == .tutor, message.id == outlineResponseMessageID {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.text("custom.outlineDraftReady", language), systemImage: "list.bullet.rectangle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        DisclosureGroup(L10n.text("custom.outlineShowRaw", language)) {
                            Text(message.text.isEmpty && chat.isSending ? "…" : message.text)
                                .textSelection(.enabled)
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption)
                    }
                } else if message.isGoogleGrounded {
                    Text((try? AttributedString(markdown: message.text)) ?? AttributedString(message.text))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(message.text.isEmpty && chat.isSending ? "…" : message.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if message.role == .tutor, message.id == outlineResponseMessageID, !message.text.isEmpty {
                    if importedOutlineMessageIDs.contains(message.id) {
                        Label(L10n.text("custom.outlineImported", language), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if !chat.isSending {
                        Button {
                            reviewOutline(message)
                        } label: {
                            Label(L10n.text("custom.outlineReviewAction", language), systemImage: "list.bullet.rectangle")
                        }
                        .buttonStyle(.bordered)
                    }
                    if outlineErrorMessageID == message.id, let outlineImportError {
                        Text(outlineImportError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if message.role == .tutor, !message.isGoogleGrounded,
                   let label = chat.completionLabel, message.id == chat.messages.last?.id {
                    Text(label).font(.caption2).foregroundStyle(.tertiary)
                }
                if message.role == .tutor, !message.citationWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        if message.citationWarnings.contains("NO_VALID_CITATIONS") {
                            Label(L10n.text("tutor.noValidCitations", language), systemImage: "quote.bubble")
                        }
                        let missingIDs = message.citationWarnings.filter { $0 != "NO_VALID_CITATIONS" }
                        if !missingIDs.isEmpty {
                            Label(
                                String(
                                    format: L10n.text("tutor.missingCitation", language),
                                    missingIDs.joined(separator: ", ")
                                ),
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                        Text(L10n.text("tutor.citationValidationLimit", language))
                    }
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
                if message.role == .tutor,
                   message.isGoogleGrounded,
                   let suggestions = message.googleSearchSuggestions {
                    GoogleSearchSuggestionsView(html: suggestions)
                        .frame(height: 54)
                        .accessibilityLabel(L10n.text("tutor.googleSearchSuggestions", language))
                }
                if message.role == .tutor, let source = message.sources.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.text("tutor.sources", language), systemImage: "books.vertical")
                            .font(.caption.weight(.semibold))
                        Text("\(L10n.text("tutor.retrievedAt", language)): \(source.displayRetrievedAt)")
                            .font(.caption2).foregroundStyle(.secondary)
                        ForEach(message.sources) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                if ["google_grounding", "official_web"].contains(item.sourceType ?? ""),
                                   let path = item.path,
                                   let url = URL(string: path),
                                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                                    Link("[\(item.id)] \(item.title)", destination: url)
                                        .font(.caption.weight(.medium))
                                } else {
                                    Text("[\(item.id)] \(item.title)")
                                        .font(.caption.weight(.medium))
                                        .textSelection(.enabled)
                                }
                                if let path = item.path,
                                   path != item.title,
                                   !["google_grounding", "official_web"].contains(item.sourceType ?? "") {
                                    Text(path)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                        .textSelection(.enabled)
                                }
                                if let location = item.location {
                                    Text("\(L10n.text("tutor.location", language)): \(location)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                if let modifiedAt = item.displayModifiedAt {
                                    Text("\(L10n.text("tutor.fileModifiedAt", language)): \(modifiedAt)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                } else if item.sourceType == "obsidian" {
                                    Text(L10n.text("tutor.modifiedDateUnavailable", language))
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                if let sourceCheckedAt = item.sourceCheckedAt {
                                    Text("\(L10n.text(item.sourceType == "official_web" ? "tutor.sourceCheckedAt" : "tutor.sourceReviewDate", language)): \(sourceCheckedAt)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                    if item.sourceType != "official_web" {
                                        Text(L10n.text("tutor.sourceCheckCaveat", language))
                                        .font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                                if let snapshotFetchedAt = item.sourceSnapshotFetchedAt {
                                    Text("\(L10n.text("tutor.sourceSnapshotFetchedAt", language)): \(snapshotFetchedAt)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                if item.sourceType == "official_web",
                                   item.pagePublishedAt != nil || item.pageUpdatedAt != nil {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let publishedAt = item.pagePublishedAt {
                                            Text("\(L10n.text("tutor.publisherPublishedAt", language)): \(publishedAt)")
                                        }
                                        if let updatedAt = item.pageUpdatedAt {
                                            Text("\(L10n.text("tutor.publisherUpdatedAt", language)): \(updatedAt)")
                                        }
                                        Text(L10n.text("tutor.publisherDateCaveat", language))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                if let license = item.license {
                                    HStack(spacing: 4) {
                                        Text("\(L10n.text("tutor.sourceLicense", language)): \(license)")
                                        if let licenseURL = item.licenseURL,
                                           let url = URL(string: licenseURL) {
                                            Link(L10n.text("tutor.sourceLicenseTerms", language), destination: url)
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                if let attribution = item.attribution {
                                    Text(attribution)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .textSelection(.enabled)
                                }
                                if let officialReferences = item.officialReferences,
                                   !officialReferences.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L10n.text("tutor.officialReferences", language))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        ForEach(officialReferences) { reference in
                                            if let url = officialSourceURL(reference) {
                                                Link(reference.title, destination: url)
                                                    .font(.caption2)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Text(L10n.text("tutor.officialReferencesCaveat", language))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                if let intervalDays = item.sourceReviewIntervalDays {
                                    Text("\(L10n.text("tutor.sourceReviewInterval", language)): \(intervalDays)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                if let dueOn = item.sourceReviewDueOn {
                                    let isDue = item.sourceReviewStatus == "due"
                                    Text("\(L10n.text(isDue ? "tutor.sourceReviewDue" : "tutor.sourceReviewNext", language)): \(dueOn)")
                                        .font(.caption2)
                                        .foregroundStyle(isDue ? Color.orange : Color.secondary)
                                    Text(L10n.text("tutor.sourceReviewScheduleCaveat", language))
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                if !item.excerpt.isEmpty {
                                    Text(item.excerpt)
                                        .font(.caption2).foregroundStyle(.secondary)
                                        .lineLimit(4)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    .padding(9)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .padding(12)
            .background(message.role == .learner ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            if message.role == .tutor { Spacer(minLength: 50) }
        }
    }

    private var composerReadiness: TutorComposerReadiness {
        TutorComposerReadiness.resolve(
            backendReady: backendSupervisor.isReady,
            routeStatusAvailable: store.aiHealth != nil,
            isLocalOnly: chat.mode == .localOnly,
            hasAutomaticRoute: store.aiHealth?.hasAutomaticRoute == true,
            hasLocalModel: store.aiHealth?.hasLocalModel == true,
            isLocalEndpointConfirmed: store.aiHealth?.isOllamaEndpointLocal == true
        )
    }

    private var canSend: Bool {
        guard composerReadiness.isReady, let health = store.aiHealth else { return false }
        if useWebSearch {
            return chat.mode == .automatic
                && store.autoCostPolicy?.allowPaidRoutes == true
                && health.hasGroundedSearch
        }
        return true
    }

    private func officialSourceURL(_ reference: TutorSourceReference) -> URL? {
        reference.safeURL
    }

    private func routeDescription(for health: OrchestratorHealth) -> String {
        if store.aiMode == .localOnly {
            return L10n.text(health.hasLocalModel ? "settings.aiLocalRoute" : "settings.aiNoLocal", language)
        }
        if health.hasCloudRoute { return L10n.text("settings.aiOnlineRoute", language) }
        if health.hasLocalModel { return L10n.text("settings.aiLocalRoute", language) }
        return L10n.text("settings.aiNoRoute", language)
    }

    private func send() {
        guard canSend, !chat.isSending else { return }
        let message = draft
        let isOutlineDraft = outlinePromptPrepared
        Task {
            guard await backendSupervisor.ensureRunning() else { return }
            await store.refreshAIStatus()
            await store.refreshAutoCostPolicy()
            guard canSend, !chat.isSending else { return }
            draft = ""
            chat.send(
                message,
                useWebSearch: useWebSearch,
                groundingAgeConfirmed: hasConfirmedGoogleSearchAge,
                includeLocalSourcesInWebSearch: includeLocalSourcesInWebSearch,
                preferredLearningFormat: store.studyFormatPreferenceProfile.tutorPreference(forSubjectID: tutorSubjectID)
            )
            if isOutlineDraft {
                outlineResponseMessageID = chat.messages.last?.id
                outlineImportError = nil
                outlineImportSuccess = nil
            }
            outlinePromptPrepared = false
        }
    }

    private func reviewOutline(_ message: TutorMessage) {
        guard outlineDestination != nil, outlineParentTopicID != nil else { return }
        do {
            let proposal = try CustomTopicOutlineProposal.parse(message.text)
            pendingOutlineReview = PendingCustomTopicOutlineReview(
                messageID: message.id,
                proposal: proposal
            )
            outlineImportError = nil
            outlineErrorMessageID = nil
        } catch let error as CustomTopicOutlineError {
            outlineImportError = outlineErrorText(error)
            outlineErrorMessageID = message.id
        } catch {
            outlineImportError = L10n.text("custom.outlineParseMalformed", language)
            outlineErrorMessageID = message.id
        }
    }

    private func outlineErrorText(_ error: CustomTopicOutlineError) -> String {
        let key: String
        switch error {
        case .malformedJSON:
            key = "custom.outlineParseMalformed"
        case .unsupportedSchema, .unsupportedVersion:
            key = "custom.outlineParseUnsupported"
        case .invalidBilingualContent:
            key = "custom.outlineParseIncomplete"
        case .invalidLevel:
            key = "custom.outlineParseLevel"
        case .duplicateSiblingName:
            key = "custom.outlineParseDuplicates"
        case .emptyTopics:
            key = "custom.outlineParseEmpty"
        case .tooManyTopics:
            key = "custom.outlineParseTooMany"
        case .tooDeep:
            key = "custom.outlineParseTooDeep"
        case .oversizedResponse:
            key = "custom.outlineParseTooLarge"
        }
        return L10n.text(key, language)
    }
}

private struct GoogleSearchSuggestionsView: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.underPageBackgroundColor = .clear
        view.navigationDelegate = context.coordinator
        context.coordinator.load(html, into: view)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.load(html, into: view)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var loadedHTML: String?

        func load(_ html: String, into view: WKWebView) {
            guard loadedHTML != html else { return }
            loadedHTML = html
            view.loadHTMLString(html, baseURL: nil)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated else {
                decisionHandler(.allow)
                return
            }
            guard let url = navigationAction.request.url,
                  ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                decisionHandler(.cancel)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }
}

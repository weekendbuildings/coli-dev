import SwiftUI

struct CustomSubjectCard: View {
    let subject: CustomLearningSubject
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: "books.vertical.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 44, height: 44)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                Text(subject.name.value(in: language.rawValue))
                    .font(.headline)
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 4) {
                    if !subject.description.value(in: language.rawValue).isEmpty {
                        Text(subject.description.value(in: language.rawValue))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text(L10n.text("custom.topicCount", language).replacingOccurrences(of: "%@", with: "\(subject.totalTopicCount)"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 134, alignment: .leading)
            .background(AppPalette.inset.color, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

struct CustomSubjectEditor: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @State private var russianName = ""
    @State private var englishName = ""
    @State private var russianDescription = ""
    @State private var englishDescription = ""
    @State private var errorMessage: String?

    let onCreated: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("custom.createSubject", store.language))
                .font(.title2.weight(.semibold))
            TextField(L10n.text("custom.subjectNameRu", store.language), text: $russianName)
            TextField(L10n.text("custom.subjectNameEn", store.language), text: $englishName)
            TextField(L10n.text("custom.subjectDescriptionRu", store.language), text: $russianDescription, axis: .vertical)
                .lineLimit(2...4)
            TextField(L10n.text("custom.subjectDescriptionEn", store.language), text: $englishDescription, axis: .vertical)
                .lineLimit(2...4)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }
            HStack {
                Spacer()
                Button(L10n.text("common.cancel", store.language), role: .cancel) { dismiss() }
                Button(L10n.text("custom.saveSubject", store.language), action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasBothNames)
            }
        }
        .padding(24)
        .frame(minWidth: 440, idealWidth: 520, minHeight: 340)
    }

    private var hasBothNames: Bool {
        !russianName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !englishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        do {
            let id = try store.addCustomSubject(
                name: CustomCurriculumText(russian: russianName, english: englishName),
                description: CustomCurriculumText(russian: russianDescription, english: englishDescription)
            )
            onCreated(id)
            dismiss()
        } catch CustomCurriculumError.duplicateSubjectName {
            errorMessage = L10n.text("custom.duplicateSubject", store.language)
        } catch {
            errorMessage = L10n.text("custom.requiredNames", store.language)
        }
    }
}

struct CustomTopicEditor: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @State private var russianName = ""
    @State private var englishName = ""
    @State private var russianOutcome = ""
    @State private var englishOutcome = ""
    @State private var russianNotes = ""
    @State private var englishNotes = ""
    @State private var level = 1
    @State private var errorMessage: String?

    let subjectID: UUID?
    let builtInSubject: Subject?
    let parentTopicID: UUID?
    let onCreated: () -> Void

    init(subjectID: UUID? = nil, builtInSubject: Subject? = nil, parentTopicID: UUID?, onCreated: @escaping () -> Void) {
        self.subjectID = subjectID
        self.builtInSubject = builtInSubject
        self.parentTopicID = parentTopicID
        self.onCreated = onCreated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text(parentTopicID == nil ? "custom.addTopic" : "custom.addSubtopic", store.language))
                .font(.title2.weight(.semibold))
            TextField(L10n.text("custom.topicNameRu", store.language), text: $russianName)
            TextField(L10n.text("custom.topicNameEn", store.language), text: $englishName)
            TextField(L10n.text("custom.outcomeRu", store.language), text: $russianOutcome, axis: .vertical)
                .lineLimit(2...3)
            TextField(L10n.text("custom.outcomeEn", store.language), text: $englishOutcome, axis: .vertical)
                .lineLimit(2...3)
            TextField(L10n.text("custom.notesRu", store.language), text: $russianNotes, axis: .vertical)
                .lineLimit(2...4)
            TextField(L10n.text("custom.notesEn", store.language), text: $englishNotes, axis: .vertical)
                .lineLimit(2...4)
            Stepper(
                L10n.text("custom.level", store.language).replacingOccurrences(of: "%@", with: "\(level)"),
                value: $level,
                in: 1...7
            )
            Text(L10n.text("custom.depth.\(level)", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }
            HStack {
                Spacer()
                Button(L10n.text("common.cancel", store.language), role: .cancel) { dismiss() }
                Button(L10n.text(parentTopicID == nil ? "custom.addTopic" : "custom.addSubtopic", store.language), action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasBothNames)
            }
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 480)
    }

    private var hasBothNames: Bool {
        !russianName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !englishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        do {
            let name = CustomCurriculumText(russian: russianName, english: englishName)
            let outcome = CustomCurriculumText(russian: russianOutcome, english: englishOutcome)
            let notes = CustomCurriculumText(russian: russianNotes, english: englishNotes)
            if let subjectID {
                try store.addCustomTopic(
                    subjectID: subjectID,
                    parentTopicID: parentTopicID,
                    name: name,
                    learningOutcome: outcome,
                    notes: notes,
                    level: level
                )
            } else if let builtInSubject {
                try store.addCustomTopic(
                    builtInSubject: builtInSubject,
                    parentTopicID: parentTopicID,
                    name: name,
                    learningOutcome: outcome,
                    notes: notes,
                    level: level
                )
            } else {
                errorMessage = L10n.text("custom.subjectMissing", store.language)
                return
            }
            onCreated()
            dismiss()
        } catch CustomCurriculumError.duplicateTopicName {
            errorMessage = L10n.text("custom.duplicateTopic", store.language)
        } catch CustomCurriculumError.parentTopicNotFound {
            errorMessage = L10n.text("custom.parentMissing", store.language)
        } catch {
            errorMessage = L10n.text("custom.requiredNames", store.language)
        }
    }
}

struct CustomSubjectDetailView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var showingTopicEditor = false
    @State private var topicParentID: UUID?
    @State private var topicToDelete: UUID?
    @State private var showingSubjectDelete = false
    @State private var showingTopicDelete = false

    let subjectID: UUID
    let openTopic: (UUID) -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            if let subject = store.customCurriculum.subject(id: subjectID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text("custom.customLabel", store.language))
                                .font(.caption.weight(.semibold)).tracking(1.3).foregroundStyle(.secondary)
                            Text(subject.name.value(in: store.language.rawValue))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text(subject.description.value(in: store.language.rawValue))
                                .font(.title3).foregroundStyle(.secondary)
                            Text(L10n.text("custom.topicCount", store.language)
                                .replacingOccurrences(of: "%@", with: "\(subject.totalTopicCount)"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if subject.topics.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "text.badge.plus").font(.largeTitle).foregroundStyle(.secondary)
                                Text(L10n.text("custom.emptyTitle", store.language)).font(.headline)
                                Text(L10n.text("custom.emptyTopics", store.language))
                                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 240)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(subject.topics) { topic in
                                    CustomTopicBranch(
                                        topic: topic,
                                        language: store.language,
                                        lessonID: { CustomTopicStudyRoute.userTopic(subjectID: subjectID, topicID: $0).lessonID },
                                        open: { openTopic($0) },
                                        addChild: { topicParentID = $0; showingTopicEditor = true },
                                        delete: { topicToDelete = $0; showingTopicDelete = true }
                                    )
                                }
                            }
                        }
                        Button {
                            topicParentID = nil
                            showingTopicEditor = true
                        } label: {
                            Label(L10n.text("custom.addTopic", store.language), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(30)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .navigationTitle(subject.name.value(in: store.language.rawValue))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) { showingSubjectDelete = true } label: {
                            Label(L10n.text("custom.deleteSubject", store.language), systemImage: "trash")
                        }
                    }
                }
                .sheet(isPresented: $showingTopicEditor) {
                    CustomTopicEditor(subjectID: subjectID, parentTopicID: topicParentID) {}
                        .environmentObject(store)
                }
                .confirmationDialog(
                    L10n.text("custom.deleteSubject", store.language),
                    isPresented: $showingSubjectDelete,
                    titleVisibility: .visible
                ) {
                    Button(L10n.text("custom.deleteSubject", store.language), role: .destructive) {
                        store.removeCustomSubject(id: subjectID)
                        onDelete()
                    }
                    Button(L10n.text("common.cancel", store.language), role: .cancel) {}
                } message: {
                    Text(L10n.text("custom.confirmDeleteSubject", store.language))
                }
                .confirmationDialog(
                    L10n.text("custom.deleteTopic", store.language),
                    isPresented: $showingTopicDelete,
                    titleVisibility: .visible
                ) {
                    Button(L10n.text("custom.deleteTopic", store.language), role: .destructive) {
                        if let topicToDelete { store.removeCustomTopic(subjectID: subjectID, topicID: topicToDelete) }
                        topicToDelete = nil
                    }
                    Button(L10n.text("common.cancel", store.language), role: .cancel) { topicToDelete = nil }
                } message: {
                    Text(L10n.text("custom.confirmDeleteTopic", store.language))
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical").font(.largeTitle).foregroundStyle(.secondary)
                    Text(L10n.text("custom.subjectMissingTitle", store.language)).font(.headline)
                    Text(L10n.text("custom.subjectMissing", store.language)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CustomTopicBranch: View {
    @EnvironmentObject private var store: LearningStore
    let topic: CustomLearningTopic
    let language: AppLanguage
    let lessonID: (UUID) -> String
    let open: (UUID) -> Void
    let addChild: (UUID) -> Void
    let delete: (UUID) -> Void

    var body: some View {
        if topic.subtopics.isEmpty {
            AnyView(topicRow)
        } else {
            AnyView(DisclosureGroup {
                ForEach(topic.subtopics) { child in
                    AnyView(CustomTopicBranch(
                        topic: child,
                        language: language,
                        lessonID: lessonID,
                        open: open,
                        addChild: addChild,
                        delete: delete
                    )
                        .padding(.leading, 18))
                }
            } label: {
                topicRow
            })
        }
    }

    private var topicRow: some View {
        HStack(spacing: 12) {
            Button { open(topic.id) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "text.book.closed").foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(topic.name.value(in: language.rawValue)).font(.headline).foregroundStyle(.primary)
                        Text(L10n.text("custom.depth.\(topic.level)", language))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if store.isComplete(lessonID: lessonID(topic.id)) {
                        Image(systemName: store.isReviewDue(lessonID: lessonID(topic.id))
                            ? "clock.arrow.circlepath"
                            : "checkmark.circle.fill")
                            .foregroundStyle(store.isReviewDue(lessonID: lessonID(topic.id)) ? .orange : .green)
                            .accessibilityLabel(L10n.text(
                                store.isReviewDue(lessonID: lessonID(topic.id))
                                    ? "custom.topicReviewDue"
                                    : "custom.topicCompleted",
                                language
                            ))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Menu {
                Button { addChild(topic.id) } label: {
                    Label(L10n.text("custom.addSubtopic", language), systemImage: "plus")
                }
                Button(role: .destructive) { delete(topic.id) } label: {
                    Label(L10n.text("custom.deleteTopic", language), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
                .padding(12)
        .background(AppPalette.inset.color, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }

}

private struct CustomTopicProgressSection: View {
    @EnvironmentObject private var store: LearningStore
    @State private var learnerConfirmed = false
    @State private var recallQuality = 4

    let lessonID: String

    private var isComplete: Bool { store.isComplete(lessonID: lessonID) }
    private var isReviewDue: Bool { store.isReviewDue(lessonID: lessonID) }
    private var hasPendingReview: Bool { store.hasPendingReview(lessonID: lessonID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("custom.topicProgressTitle", store.language))
                .font(.headline)
            Text(L10n.text("custom.topicProgressHint", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if isComplete {
                Label(
                    L10n.text(isReviewDue ? "custom.topicReviewDue" : "custom.topicCompleted", store.language),
                    systemImage: isReviewDue ? "clock.arrow.circlepath" : "checkmark.circle.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isReviewDue ? .orange : .green)
            }
            Picker(L10n.text("session.recallQuality", store.language), selection: $recallQuality) {
                Text(L10n.text("session.recallHard", store.language)).tag(2)
                Text(L10n.text("session.recallGood", store.language)).tag(4)
                Text(L10n.text("session.recallEasy", store.language)).tag(5)
            }
            .pickerStyle(.segmented)
            Toggle(L10n.text("custom.topicConfirmStudied", store.language), isOn: $learnerConfirmed)
                .toggleStyle(.checkbox)
            Button {
                if isComplete {
                    store.recordReview(lessonID: lessonID, quality: recallQuality)
                } else {
                    store.markComplete(lessonID: lessonID, quality: recallQuality)
                }
                learnerConfirmed = false
            } label: {
                let titleKey = hasPendingReview
                    ? "session.reviewSaved"
                    : (isComplete
                        ? (isReviewDue ? "session.recordReview" : "custom.topicCompleted")
                        : "custom.topicMarkComplete")
                Label(L10n.text(titleKey, store.language), systemImage: isComplete ? "checkmark.circle.fill" : "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                !learnerConfirmed
                    || hasPendingReview
                    || (isComplete && !isReviewDue)
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .onAppear {
            recallQuality = store.studyProgress[lessonID]?.lastQuality ?? 4
        }
    }
}

struct CustomTopicStudyView: View {
    @EnvironmentObject private var store: LearningStore
    let subjectID: UUID
    let topicID: UUID
    let goBack: () -> Void

    var body: some View {
        Group {
            if let subject = store.customCurriculum.subject(id: subjectID),
               let topic = store.customCurriculum.topic(subjectID: subjectID, topicID: topicID) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button(action: goBack) {
                            Label(L10n.text("common.back", store.language), systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(L10n.text("custom.depth.\(topic.level)", store.language))
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Text(topic.name.value(in: store.language.rawValue))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    if !topic.learningOutcome.value(in: store.language.rawValue).isEmpty {
                        LabeledContent(L10n.text("custom.learningGoal", store.language)) {
                            Text(topic.learningOutcome.value(in: store.language.rawValue))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if !topic.notes.value(in: store.language.rawValue).isEmpty {
                        Text(topic.notes.value(in: store.language.rawValue))
                            .textSelection(.enabled)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                    CustomTopicProgressSection(
                        lessonID: CustomTopicStudyRoute.userTopic(subjectID: subjectID, topicID: topicID).lessonID
                    )
                    Divider()
                    TutorChatView(
                        customSubject: subject,
                        topic: topic,
                        language: store.language,
                        mode: store.aiMode,
                        outlineDestination: .learnerSubject(subjectID: subjectID),
                        outlineParentTopicID: topicID
                    )
                }
                .padding(24)
                .navigationTitle(topic.name.value(in: store.language.rawValue))
                .onAppear {
                    store.rememberStudyRoute(CustomTopicStudyRoute.userTopic(subjectID: subjectID, topicID: topicID))
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "text.book.closed").font(.largeTitle).foregroundStyle(.secondary)
                    Text(L10n.text("custom.topicMissingTitle", store.language)).font(.headline)
                    Text(L10n.text("custom.parentMissing", store.language)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct BuiltInCustomTopicStudyView: View {
    @EnvironmentObject private var store: LearningStore
    let subject: Subject
    let topicID: UUID
    let goBack: () -> Void

    var body: some View {
        Group {
            if let topic = store.customCurriculum.topic(builtInSubjectID: subject.rawValue, topicID: topicID) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button(action: goBack) {
                            Label(L10n.text("common.back", store.language), systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(L10n.text("custom.depth.\(topic.level)", store.language))
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Text(topic.name.value(in: store.language.rawValue))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    if !topic.learningOutcome.value(in: store.language.rawValue).isEmpty {
                        LabeledContent(L10n.text("custom.learningGoal", store.language)) {
                            Text(topic.learningOutcome.value(in: store.language.rawValue))
                                .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        }
                    }
                    if !topic.notes.value(in: store.language.rawValue).isEmpty {
                        Text(topic.notes.value(in: store.language.rawValue))
                            .textSelection(.enabled)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                    CustomTopicProgressSection(
                        lessonID: CustomTopicStudyRoute.builtInTopic(subjectID: subject.rawValue, topicID: topicID).lessonID
                    )
                    Divider()
                    TutorChatView(
                        customSubject: CustomLearningSubject(
                            name: CustomCurriculumText(
                                russian: subject.title(in: .ru),
                                english: subject.title(in: .en)
                            ),
                            description: CustomCurriculumText(russian: "", english: "")
                        ),
                        topic: topic,
                        language: store.language,
                        mode: store.aiMode,
                        routeSubjectID: subject.rawValue,
                        outlineDestination: .builtInSubject(subjectID: subject.rawValue),
                        outlineParentTopicID: topicID
                    )
                }
                .padding(24)
                .navigationTitle(topic.name.value(in: store.language.rawValue))
                .onAppear {
                    store.rememberStudyRoute(CustomTopicStudyRoute.builtInTopic(subjectID: subject.rawValue, topicID: topicID))
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "text.book.closed").font(.largeTitle).foregroundStyle(.secondary)
                    Text(L10n.text("custom.topicMissingTitle", store.language)).font(.headline)
                    Text(L10n.text("custom.parentMissing", store.language)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CustomTopicOutlineReviewView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @State private var proposal: CustomTopicOutlineProposal
    @State private var errorMessage: String?

    let destination: CustomTopicOutlineDestination
    let parentTopicID: UUID
    let onSaved: (Int) -> Void

    init(
        proposal: CustomTopicOutlineProposal,
        destination: CustomTopicOutlineDestination,
        parentTopicID: UUID,
        onSaved: @escaping (Int) -> Void
    ) {
        _proposal = State(initialValue: proposal)
        self.destination = destination
        self.parentTopicID = parentTopicID
        self.onSaved = onSaved
    }

    private var topicCount: Int {
        proposal.topics.reduce(0) { $0 + $1.totalTopicCount }
    }

    private var isValid: Bool {
        (try? proposal.validate()) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("custom.outlineReviewTitle", store.language))
                .font(.title2.weight(.semibold))

            Label(
                L10n.text("custom.outlineReviewWarning", store.language),
                systemImage: "exclamationmark.triangle"
            )
            .font(.callout)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)

            Text(L10n.text("custom.outlineReviewInstructions", store.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($proposal.topics) { topic in
                        CustomTopicOutlineItemEditor(
                            item: topic,
                            depth: 0,
                            language: store.language
                        ) {
                            let id = topic.wrappedValue.id
                            proposal.topics.removeAll { $0.id == id }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !isValid {
                Label(
                    L10n.text("custom.outlineReviewInvalid", store.language),
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(L10n.text("common.cancel", store.language), role: .cancel) {
                    dismiss()
                }
                Button(
                    String(
                        format: L10n.text("custom.outlineSaveCount", store.language),
                        topicCount
                    ),
                    action: save
                )
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 620, idealWidth: 760, minHeight: 600)
    }

    private func save() {
        do {
            let ids = try store.addCustomTopicOutline(
                proposal,
                to: destination,
                parentTopicID: parentTopicID
            )
            onSaved(ids.count)
            dismiss()
        } catch CustomCurriculumError.duplicateTopicName {
            errorMessage = L10n.text("custom.duplicateTopic", store.language)
        } catch CustomCurriculumError.parentTopicNotFound {
            errorMessage = L10n.text("custom.parentMissing", store.language)
        } catch {
            errorMessage = L10n.text("custom.outlineSaveFailed", store.language)
        }
    }
}

private struct CustomTopicOutlineItemEditor: View {
    @Binding var item: CustomTopicOutlineItem
    let depth: Int
    let language: AppLanguage
    let onRemove: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.text("custom.outlineItemTitle", language))
                        .font(.headline)
                    Spacer()
                    Button(role: .destructive, action: onRemove) {
                        Label(L10n.text("custom.outlineRemoveItem", language), systemImage: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }

                TextField(L10n.text("custom.topicNameRu", language), text: $item.name.russian)
                TextField(L10n.text("custom.topicNameEn", language), text: $item.name.english)
                TextField(L10n.text("custom.outcomeRu", language), text: $item.learningOutcome.russian, axis: .vertical)
                    .lineLimit(2...3)
                TextField(L10n.text("custom.outcomeEn", language), text: $item.learningOutcome.english, axis: .vertical)
                    .lineLimit(2...3)
                TextField(L10n.text("custom.notesRu", language), text: $item.notes.russian, axis: .vertical)
                    .lineLimit(3...6)
                TextField(L10n.text("custom.notesEn", language), text: $item.notes.english, axis: .vertical)
                    .lineLimit(3...6)

                Stepper(
                    L10n.text("custom.level", language).replacingOccurrences(of: "%@", with: "\(item.level)"),
                    value: $item.level,
                    in: 1...7
                )

                if !item.subtopics.isEmpty {
                    Divider()
                    ForEach($item.subtopics) { subtopic in
                        CustomTopicOutlineItemEditor(
                            item: subtopic,
                            depth: depth + 1,
                            language: language
                        ) {
                            let id = subtopic.wrappedValue.id
                            item.subtopics.removeAll { $0.id == id }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, CGFloat(min(depth, 3) * 12))
        }
    }
}

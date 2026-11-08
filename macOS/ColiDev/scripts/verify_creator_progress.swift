import Foundation

// Проверяет логику экрана «Прогресс Творца»: итоги «Собери и проверь сам», столбики, ленту дней, оценку времени и Skillbox.
// Verifies the Creator progress logic: lab results, bars, the day strip, the time estimate and Skillbox.

func require(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

@main
struct VerifyCreatorProgress {
    static func main() {
        labs()
        bars()
        days()
        time()
        skillbox()
        print("OK: Creator progress / Прогресс Творца")
    }

    static func labs() {
        let home = URL(fileURLWithPath: "/Users/learner", isDirectory: true)
        require(CreatorLabResults.fileURL(environment: [:], home: home).path == "/Users/learner/ai-path/creator_labs/.results.json",
                "results live next to the copied checks")
        require(CreatorLabResults.fileURL(environment: ["COLIDEV_CREATOR_LABS_DIR": "/tmp/labs"], home: home).path == "/tmp/labs/.results.json",
                "the folder can be overridden for checks of the app")

        let file = """
        {"format": "creator-labs-results", "version": 1, "runs": [
          {"check": "check_tokenizer_bpe.py", "lesson": "tokenizer_bpe", "passed": 0, "total": 7, "at": "2026-11-08T10:00:00Z"},
          {"check": "check_tokenizer_bpe.py", "lesson": "tokenizer_bpe", "passed": 7, "total": 7, "at": "2026-11-08T11:00:00Z"},
          {"check": "check_tokenizer_bpe.py", "lesson": "tokenizer_bpe", "passed": 5, "total": 7, "at": "2026-11-08T12:00:00Z"},
          {"broken": true},
          {"check": "check_autograd_engine.py", "lesson": "autograd_engine", "passed": 2, "total": 6, "at": "2026-11-07T09:00:00Z"}
        ]}
        """
        let runs = CreatorLabResults.parse(Data(file.utf8))
        require(runs.count == 4, "a broken entry is skipped, the rest is read")
        require(runs[0].date != nil, "lab timestamps parse")
        let summaries = CreatorLabResults.summaries(runs)
        require(summaries["tokenizer_bpe"]?.latest.passed == 5, "the latest run is shown")
        require(summaries["tokenizer_bpe"]?.everPassed == true, "a lab passed once stays done")
        require(summaries["tokenizer_bpe"]?.runs == 3, "runs are counted")
        require(summaries["autograd_engine"]?.everPassed == false, "a lab with failing checks is not done")
        require(CreatorLabResults.parse(Data("{\"format\": \"other\", \"runs\": []}".utf8)).isEmpty, "a foreign file gives nothing")
        require(CreatorLabResults.parse(Data("not json".utf8)).isEmpty, "a broken file gives nothing")
        require(CreatorLabResults.lessons.count == 7 && Set(CreatorLabResults.lessons).count == 7, "seven labs")
        require(CreatorDates.parse("2026-11-08T10:00:00.123Z") != nil, "fractions of a second parse")

        let backup = """
        {"format": "colidev-learning-progress", "version": 2, "records": [], "assessment_events": [
          {"event_id": "1", "lesson_id": "programming.variables_and_types", "created_at": "2026-11-02T13:01:59Z",
           "assessment": {"task_type": "knowledge_check", "passed": false, "error_categories": ["concept"]}},
          {"event_id": "2", "lesson_id": "intro.physics", "created_at": "2026-10-28T12:16:02Z",
           "assessment": {"task_type": "interactive_prediction", "attempts": 2, "first_try_correct": false, "hints_used": 0}}
        ]}
        """
        let events = CreatorBackendEvents.parse(Data(backup.utf8))
        require(events?.count == 2 && events?[0].isCheck == true && events?[0].passed == false, "a knowledge check event is read")
        require(events?[1].isCheck == false && events?[1].passed == nil, "a trainer task is a step, not a check")
        require(CreatorBackendEvents.parse(Data("{}".utf8)) == nil, "an answer that is not a backup is refused")
    }

    static func facts(_ resource: String, completed: Bool, passed: Int = 0, total: Int = 0, lab: CreatorLabSummary? = nil) -> CreatorLessonFacts {
        CreatorLessonFacts(resource: resource, written: true, completed: completed, checksPassed: passed, checksTotal: total,
                           hasLab: lab != nil, lab: lab)
    }

    static func bars() {
        let passedLab = CreatorLabSummary(
            latest: CreatorLabRun(check: "c", lesson: "a", passed: 3, total: 3, at: "2026-11-08T10:00:00Z"), everPassed: true, runs: 1)
        let failedLab = CreatorLabSummary(
            latest: CreatorLabRun(check: "c", lesson: "b", passed: 1, total: 3, at: "2026-11-08T10:00:00Z"), everPassed: false, runs: 2)
        let bar = CreatorProgressMath.bar(id: "module1", lessons: [
            facts("a", completed: true, passed: 1, total: 2, lab: passedLab),
            facts("b", completed: false, passed: 2, total: 3, lab: failedLab),
            facts("c", completed: false),
            facts("d", completed: true)
        ])
        require(bar.done == 2 && bar.total == 4 && bar.fraction == 0.5, "height is the share of completed lessons")
        require(bar.good == 4 && bar.graded == 7, "quality counts correct checks and finished labs among tried ones")
        require(abs((bar.quality ?? 0) - 4.0 / 7.0) < 1e-9, "quality is good / graded")
        let empty = CreatorProgressMath.bar(id: "module10", lessons: [])
        require(empty.fraction == 0 && empty.quality == nil, "an empty module has no height and no colour")
        let skillbox = CreatorProgressMath.bar(id: "main", done: 9, total: 34, gradedBy: [facts("x", completed: false, passed: 1, total: 4)])
        require(skillbox.done == 9 && abs((skillbox.quality ?? 0) - 0.25) < 1e-9, "a Skillbox bar takes its colour from linked lessons")
        require(CreatorProgressMath.hue(forQuality: 0) == 0 && abs(CreatorProgressMath.hue(forQuality: 1) - 1.0 / 3.0) < 1e-9,
                "red for 0, green for 1")
    }

    static func days() {
        let calendar = CreatorActivity.mondayCalendar(timeZone: TimeZone(identifier: "Asia/Tashkent")!)
        func day(_ d: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
        }
        let today = day(8, 23) // Sunday / воскресенье
        let counts = CreatorActivity.dayCounts([day(8, 1), day(8, 22), day(7), day(6), day(4)], calendar: calendar)
        require(counts[calendar.startOfDay(for: today)] == 2, "two steps today")
        require(CreatorActivity.streak(counts, today: today, calendar: calendar) == 3, "8, 7 and 6 November in a row")
        let noStepYet = CreatorActivity.dayCounts([day(7), day(6)], calendar: calendar)
        require(CreatorActivity.streak(noStepYet, today: today, calendar: calendar) == 2, "no step yet today keeps the streak")
        require(CreatorActivity.streak([:], today: today, calendar: calendar) == 0, "no steps, no streak")

        let grid = CreatorActivity.weeks(3, today: day(4), calendar: calendar) // Wednesday / среда
        require(grid.count == 3 && grid.allSatisfy { $0.count == 7 }, "columns of seven days")
        require(calendar.component(.weekday, from: grid[0][0]!) == 2, "a column starts on Monday")
        require(grid[2][2].map { calendar.isDate($0, inSameDayAs: day(4)) } == true, "today is in the last column")
        require(grid[2][3] == nil && grid[2][6] == nil, "days after today are empty")
        require(calendar.isDate(grid[0][0]!, inSameDayAs: calendar.date(from: DateComponents(year: 2026, month: 10, day: 19))!),
                "three weeks back from the week of 4 November start on 19 October")
        require([0, 1, 2, 3, 4, 6, 7, 30].map(CreatorActivity.level) == [0, 1, 2, 2, 3, 3, 4, 4], "GitHub-like levels")
    }

    static func time() {
        let lesson = """
        ---
        subject: programming
        ---

        # Title

        ## Русский

        Один два три **четыре** — пять.

        ```python
        print(1)
        ```

        ## English

        One two three.

        ## Sources

        - link one two
        """
        require(CreatorTimeEstimate.words(inLesson: lesson, russian: true) == 6, "Russian words up to English, code counts, dashes do not")
        require(CreatorTimeEstimate.words(inLesson: lesson, russian: false) == 3, "English words up to the sources")
        require(CreatorTimeEstimate.words(inLesson: "no sections", russian: true) == 0, "a file without sections has no words")
        require(CreatorTimeEstimate.minutes(words: 2_000, hasLab: false) == 35, "2000 words: 20 min reading + 15 practice")
        require(CreatorTimeEstimate.minutes(words: 2_001, hasLab: true) == 96, "reading rounds up, a lab adds an hour")
        require(CreatorTimeEstimate.hours(minutes: 0) == 0 && CreatorTimeEstimate.hours(minutes: 20) == 1, "at least an hour while anything is left")
        require(CreatorTimeEstimate.hours(minutes: 150) == 3 && CreatorTimeEstimate.hours(minutes: 140) == 2, "rounded to whole hours")
    }

    static func skillbox() {
        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let json = here.appendingPathComponent("../../../02_Areas/Programming/resources/skillbox_python_program.json").standardizedFileURL
        guard let data = try? Data(contentsOf: json), let program = SkillboxProgress.load(data) else {
            require(false, "the Skillbox program decodes: \(json.path)")
            return
        }
        require(program.readOn == "2026-11-08", "read date")
        let main = SkillboxProgress.courses(of: program, track: .main).map(\.id)
        require(main == ["python-basic-plus", "python-basic"], "main track: Python parts 1 and 2, got \(main)")
        let engineering = SkillboxProgress.courses(of: program, track: .engineering).map(\.id)
        require(engineering == ["python-advanced", "sql-basics", "django", "practice-python"], "engineering order, got \(engineering)")
        require(SkillboxProgress.courses(of: program, track: .stage1).map(\.id) == ["neural-networks-practical"], "next to stage 1")
        require(program.courses.allSatisfy { SkillboxTrack(rawValue: $0.role) != nil }, "every course is on a track")

        let mainItems = SkillboxProgress.items(of: program, track: .main)
        require(mainItems.filter { SkillboxProgress.isDone($0, ticks: [:]) }.count == 9, "nine topics done when read")
        require(mainItems.filter(\.isCurrent).map(\.key) == ["python-basic-plus#10"], "the owner stopped at topic 10")
        require(Set(program.courses.flatMap(SkillboxProgress.items(of:)).map(\.key)).count
                    == program.courses.flatMap(SkillboxProgress.items(of:)).count, "keys are unique")
        let django = SkillboxProgress.items(of: program, track: .engineering).first { $0.courseID == "django" }
        require(django?.key == "django" && django?.number == nil, "a course without listed topics is one row")
        let network = SkillboxProgress.items(of: program, track: .stage1).first
        require(network?.lessons.contains("live_model_tokens_temperature") == true, "the course links take the course path")

        let defaults = UserDefaults(suiteName: "verify.creator.progress.\(ProcessInfo.processInfo.processIdentifier)")!
        defaults.removePersistentDomain(forName: "verify.creator.progress.\(ProcessInfo.processInfo.processIdentifier)")
        let current = mainItems.first { $0.isCurrent }!
        let first = mainItems[0]
        _ = SkillboxProgress.saveTick(true, for: current, in: defaults)
        let ticks = SkillboxProgress.saveTick(false, for: first, in: defaults)
        require(SkillboxProgress.loadTicks(defaults) == ticks, "ticks are read back")
        require(SkillboxProgress.isDone(current, ticks: ticks) && !SkillboxProgress.isDone(first, ticks: ticks),
                "the learner's ticks win over the read state, both ways")
        defaults.removePersistentDomain(forName: "verify.creator.progress.\(ProcessInfo.processInfo.processIdentifier)")

        let keys = Set(program.courses.flatMap(SkillboxProgress.items(of:)).map(\.key))
        for (key, note) in SkillboxModernNotes.notes {
            require(keys.contains(key), "a modern note sits on an existing topic: \(key)")
            require(note.url.hasPrefix("https://") && URL(string: note.url) != nil, "a modern note links to documentation: \(key)")
        }
    }
}

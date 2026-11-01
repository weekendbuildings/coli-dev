import XCTest

final class ManagementUITests: XCTestCase {
    @MainActor
    func testSettingsShowsReleaseCatalogAndSafeUpdateStatus() async throws {
        let app = XCUIApplication()
        app.launch()

        let settingsItem = app.staticTexts["sidebar.settings"]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 15))
        settingsItem.click()

        let updatesTitle = app.staticTexts["settings.updates.title"]
        XCTAssertTrue(
            updatesTitle.waitForExistence(timeout: 15),
            "Settings must include the in-app release catalogue. / В настройках должен быть каталог версий.")
        let refreshButton = app.buttons["settings.updates.refresh"]
        let settingsScrollView = app.windows.firstMatch.scrollViews.element(boundBy: 1)
        XCTAssertTrue(settingsScrollView.waitForExistence(timeout: 5))
        let scrollPoint = settingsScrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.92, dy: 0.9))
        for _ in 0..<10 where !refreshButton.isHittable {
            scrollPoint.scroll(byDeltaX: 0, deltaY: -120)
        }
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
        let automaticToggle = app.descendants(matching: .any)["settings.updates.auto-toggle"]
        let unavailableStatus = app.descendants(matching: .any)["settings.updates.auto-unavailable"]
        XCTAssertTrue(
            automaticToggle.exists || unavailableStatus.exists,
            "Settings must either expose configured Sparkle controls or explain why secure auto-updates are disabled. / Настройки должны показать готовый Sparkle или объяснить, почему автообновление закрыто.")
    }

    @MainActor
    func testReleaseCatalogOffersBetaArchiveForCurrentMacArchitecture() async throws {
        let app = XCUIApplication()
        // A fixed catalog keeps the test off the rate-limited GitHub API. / Фиксированный каталог не зависит от лимитов GitHub API.
        app.launchEnvironment["COLIDEV_UI_TEST_RELEASES_JSON"] = """
        [{"id": 12, "name": "ColiDev 0.1.0 Beta 12 / Бета 12", "tag_name": "v0.1.0-beta.12", "body": "",
          "published_at": "2026-10-25T15:33:03Z",
          "html_url": "https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.12",
          "draft": false, "prerelease": true,
          "assets": [
            {"id": 121, "name": "ColiDev-beta-AppleSilicon.zip",
             "browser_download_url": "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.12/ColiDev-beta-AppleSilicon.zip"},
            {"id": 122, "name": "ColiDev-beta-Intel.zip",
             "browser_download_url": "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.12/ColiDev-beta-Intel.zip"}
          ]},
         {"id": 11, "name": "ColiDev 0.1.0 Beta 11 / Бета 11", "tag_name": "v0.1.0-beta.11", "body": "",
          "published_at": "2026-10-24T12:47:15Z",
          "html_url": "https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.11",
          "draft": false, "prerelease": true,
          "assets": [
            {"id": 111, "name": "ColiDev-beta-AppleSilicon.zip",
             "browser_download_url": "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.11/ColiDev-beta-AppleSilicon.zip"},
            {"id": 112, "name": "ColiDev-beta-Intel.zip",
             "browser_download_url": "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.11/ColiDev-beta-Intel.zip"}
          ]}]
        """
        app.launch()

        let settingsItem = app.staticTexts["sidebar.settings"]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 15))
        settingsItem.click()

        let release = app.descendants(matching: .any)["settings.updates.release.v0.1.0-beta.12"]
        XCTAssertTrue(
            release.waitForExistence(timeout: 30),
            "The published Beta 12 release must appear in the catalog. / Опубликованная Beta 12 должна отображаться в каталоге.")

        let settingsScrollView = app.windows.firstMatch.scrollViews.element(boundBy: 1)
        XCTAssertTrue(settingsScrollView.waitForExistence(timeout: 5))
        scrollUntilHittable(release, in: settingsScrollView)

        // Each release title is a button that expands its row.
        release.click()

        let download = app.links["settings.updates.download.v0.1.0-beta.12"]
        XCTAssertTrue(
            download.waitForExistence(timeout: 10),
            "The catalog must expose the archive for the running Mac architecture. / Каталог должен показывать архив для архитектуры этого Mac.\n\(app.debugDescription)")

        // Beta 9–11 crash at launch: the row warns instead of offering the archive.
        let brokenRelease = app.descendants(matching: .any)["settings.updates.release.v0.1.0-beta.11"]
        XCTAssertTrue(brokenRelease.waitForExistence(timeout: 10))
        scrollUntilHittable(brokenRelease, in: settingsScrollView)
        brokenRelease.click()

        let warning = app.descendants(matching: .any)["settings.updates.issue.v0.1.0-beta.11"]
        XCTAssertTrue(
            warning.waitForExistence(timeout: 10),
            "A build that crashes at launch must carry a warning. / Сборка, которая падает при запуске, должна быть помечена.\n\(app.debugDescription)")
        XCTAssertFalse(
            app.links["settings.updates.download.v0.1.0-beta.11"].exists,
            "A build that crashes at launch must not be offered for download. / Сборку, которая падает при запуске, нельзя предлагать для скачивания.")
    }

    @MainActor
    func testSettingsExplainsOrchestratorIsNotTheSelectedModel() async throws {
        let app = XCUIApplication()
        app.launch()

        let settingsItem = app.staticTexts["sidebar.settings"]
        XCTAssertTrue(
            settingsItem.waitForExistence(timeout: 15),
            "Settings navigation item did not appear. / Не появился пункт настроек.\n\(app.debugDescription)"
        )
        settingsItem.click()

        let routeExplanation = app.staticTexts["settings.ai.orchestrator-status"]
        XCTAssertTrue(
            routeExplanation.waitForExistence(timeout: 30),
            "Settings must identify the orchestrator separately from the per-request model route. / Настройки должны отделять оркестратор от маршрута модели для отдельного запроса.\n\(app.debugDescription)"
        )
        let orchestratorStatus = routeExplanation.value as? String ?? ""
        XCTAssertTrue(
            orchestratorStatus.localizedCaseInsensitiveContains("consilium"),
            "The health payload's orchestrator identity was not rendered. / Идентификатор оркестратора из health не показан.\n\(routeExplanation.debugDescription)"
        )
        XCTAssertTrue(
            orchestratorStatus.localizedCaseInsensitiveContains("orchestrator")
                || orchestratorStatus.localizedCaseInsensitiveContains("оркестратор"),
            "Settings must label 'consilium' as the orchestration layer, not as the selected AI provider. / Настройки должны обозначать consilium как слой оркестрации, а не выбранного ИИ-провайдера.\n\(routeExplanation.debugDescription)"
        )
        XCTAssertTrue(
            orchestratorStatus.localizedCaseInsensitiveContains("model")
                || orchestratorStatus.localizedCaseInsensitiveContains("модел"),
            "Settings must make clear that the orchestrator is not the model route. / Настройки должны пояснять, что оркестратор — не маршрут модели.\n\(routeExplanation.debugDescription)"
        )
        let routePolicy = app.staticTexts["settings.ai.route-resolution"]
        XCTAssertTrue(
            routePolicy.waitForExistence(timeout: 10),
            "Settings must explain that Auto resolves a route per request. / Настройки должны объяснять, что Auto выбирает маршрут для каждого запроса.\n\(app.debugDescription)"
        )
        XCTAssertTrue((routePolicy.value as? String)?.contains("Auto") == true)

        let paidRoutePolicy = app.descendants(matching: .any)["settings.ai.paid-routes"]
        XCTAssertTrue(
            paidRoutePolicy.waitForExistence(timeout: 10),
            "Settings must expose the live paid-route policy. / Настройки должны показывать текущую политику платных маршрутов.\n\(app.debugDescription)"
        )
        let paidRoutePolicyValue = paidRoutePolicy.value as? String ?? ""
        XCTAssertTrue(
            paidRoutePolicyValue.localizedCaseInsensitiveContains("blocked")
                || paidRoutePolicyValue.localizedCaseInsensitiveContains("заблокированы"),
            "The fresh test backend must show its default free-only policy. / Новый тестовый backend должен показывать политику без платных маршрутов.\n\(paidRoutePolicy.debugDescription)"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Settings with per-request AI routing explanation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSettingsShowsEffectiveAIRoutesBeforeSendingAnyRequest() async throws {
        let app = XCUIApplication()
        app.launch()

        let settingsItem = app.staticTexts["sidebar.settings"]
        XCTAssertTrue(
            settingsItem.waitForExistence(timeout: 15),
            "Settings navigation item did not appear. / Не появился пункт настроек.\n\(app.debugDescription)"
        )
        settingsItem.click()

        let routePreviewToggle = app.buttons["settings.ai.route-preview.toggle"]
        XCTAssertTrue(
            routePreviewToggle.waitForExistence(timeout: 30),
            "Settings must offer a read-only effective-route preview before a tutor request. / Настройки должны показывать эффективные маршруты до запроса тьютору.\n\(app.debugDescription)"
        )
        guard routePreviewToggle.exists else { return }
        routePreviewToggle.click()

        let routeIdentifiers = [
            "settings.ai.route-preview.role.local_draft",
            "settings.ai.route-preview.role.gemini_draft",
            "settings.ai.route-preview.role.critic",
            "settings.ai.route-preview.role.verifier",
            "settings.ai.route-preview.final",
            "settings.ai.route-preview.subject.mathematics",
            "settings.ai.route-preview.subject.english",
            "settings.ai.route-preview.subject.physics",
            "settings.ai.route-preview.subject.biology",
            "settings.ai.route-preview.subject.zoology",
            "settings.ai.route-preview.subject.programming"
        ]

        for identifier in routeIdentifiers {
            let route = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(
                route.waitForExistence(timeout: 20),
                "Effective route preview is missing \(identifier). / В предпросмотре нет маршрута \(identifier).\n\(app.debugDescription)"
            )
            if route.exists {
                XCTAssertTrue(
                    route.label.contains("→"),
                    "The route preview must show configured and effective providers for \(identifier). / Для \(identifier) нужно показать настроенный и эффективный провайдер.\n\(route.debugDescription)"
                )
            }
        }
    }

    @MainActor
    func testHomeDashboardShowsNextActionAndExportsScreenshot() async throws {
        let app = XCUIApplication()
        app.launch()

        let homeTitle = app.staticTexts["home.title"]
        XCTAssertTrue(
            homeTitle.waitForExistence(timeout: 15),
            "The Today dashboard did not appear after launch. / После запуска не открылся экран «Сегодня».\n\(app.debugDescription)"
        )

        let progressTitle = app.staticTexts["home.progress-title"]
        XCTAssertTrue(
            progressTitle.waitForExistence(timeout: 10),
            "The learning progress and next action card is missing. / Не найдена карточка прогресса и следующего шага.\n\(app.debugDescription)"
        )

        let primaryAction = app.buttons["home.primary-action"]
        XCTAssertTrue(
            primaryAction.waitForExistence(timeout: 10),
            "The dashboard does not expose its next learning action. / На главном экране нет следующего учебного действия.\n\(app.debugDescription)"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "ColiDev Today dashboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStudyGoalSelectionSurvivesAppRelaunch() async throws {
        let app = XCUIApplication()
        app.launch()

        let goalPickerButton = app.buttons["study-goal-picker-button"]
        XCTAssertTrue(
            goalPickerButton.waitForExistence(timeout: 15),
            "Today must let the learner choose a long-term study goal. / На экране «Сегодня» ученик должен иметь возможность выбрать учебную цель.\n\(app.debugDescription)"
        )
        goalPickerButton.click()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 10),
            "The goal picker must let the learner search the route. / В выборе цели должен работать поиск маршрута.\n\(app.debugDescription)"
        )
        searchField.click()
        searchField.typeText("Числа, дроби")

        let mathematicsGoal = app.buttons["study-goal-option.mathematics.numbers_fractions_and_percentages"]
        XCTAssertTrue(
            mathematicsGoal.waitForExistence(timeout: 15),
            "The goal picker must offer the first mathematics milestone. / В выборе цели должен быть доступен первый этап математики.\n\(app.debugDescription)"
        )
        mathematicsGoal.click()

        let selectedGoal = app.staticTexts["study-goal-selected-title"]
        let goalProgress = app.staticTexts["study-goal-progress"]
        XCTAssertTrue(selectedGoal.waitForExistence(timeout: 10))
        XCTAssertTrue(goalProgress.exists)
        XCTAssertTrue(app.staticTexts["study-goal-next-step"].exists)

        app.terminate()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["study-goal-selected-title"].waitForExistence(timeout: 15),
            "The selected study goal must be restored after relaunch. / После перезапуска выбранная учебная цель должна восстановиться.\n\(app.debugDescription)"
        )
        XCTAssertTrue(app.staticTexts["study-goal-progress"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["study-goal-next-step"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testTodayShowsSequentialLearningJourneyAndCheckedSources() async throws {
        let app = XCUIApplication()
        app.launch()

        let journeyTitle = app.staticTexts["journey.title"]
        XCTAssertTrue(
            journeyTitle.waitForExistence(timeout: 15),
            "Today must show the long-term learning journey, not leave it only in project documents. / На экране «Сегодня» должен быть учебный маршрут, а не только в документах проекта.\n\(app.debugDescription)"
        )

        let expandButton = app.buttons["journey.expand"]
        XCTAssertTrue(expandButton.exists)
        expandButton.click()

        let steps = [
            "mathematics", "scientific_method", "python", "cs50x", "physics",
            "biology", "machine_learning", "brain_science", "own_projects"
        ]
        var previousStepY: CGFloat?
        for (index, step) in steps.enumerated() {
            XCTAssertTrue(
                app.staticTexts["journey.step.\(step).title"].waitForExistence(timeout: 5),
                "The in-app journey is missing the ordered \(step) stage. / Встроенный маршрут пропускает этап \(step).\n\(app.debugDescription)"
            )
            let number = app.staticTexts["journey.step.\(step).number"]
            XCTAssertEqual(
                number.value as? String,
                "\(index + 1)",
                "The journey stage number must match its place in the learning sequence. / Номер этапа должен соответствовать его месту в маршруте."
            )

            let currentStepY = app.staticTexts["journey.step.\(step).title"].frame.midY
            if let previousStepY {
                XCTAssertGreaterThan(currentStepY, previousStepY, "Journey stages must appear from foundations to later specializations. / Этапы должны идти от основ к последующим специализациям.")
            }
            previousStepY = currentStepY

            XCTAssertTrue(
                app.descendants(matching: .any)["journey.step.\(step).project-result"].exists,
                "Every journey stage needs a locally saved mini-project result. / У каждого этапа должно быть поле для локально сохраняемого результата мини-проекта."
            )
        }

        for source in [
            "math.stepik", "science.stepik", "python.stepik", "cs50x.official", "physics.phet",
            "physics.geogebra", "biology.stepik", "machine_learning.stepik", "brain.hse"
        ] {
            XCTAssertTrue(
                app.links["journey.source.\(source)"].exists,
                "The checked external source \(source) is missing from the in-app route. / В маршруте нет проверенного внешнего источника \(source).\n\(app.debugDescription)"
            )
        }

        let brainCourseSource = app.links["journey.source.brain.hse"]
        XCTAssertTrue(brainCourseSource.label.contains("13"))
        let brainCourseAccessNote = app.staticTexts["journey.hse-access-note"]
        XCTAssertTrue(brainCourseAccessNote.exists)

        XCTAssertTrue(app.buttons["journey.primary-action"].exists)
        let primaryActionLabel = app.buttons["journey.primary-action"].label.lowercased()
        XCTAssertTrue(primaryActionLabel.contains("математ") || primaryActionLabel.contains("math"))
        XCTAssertTrue(primaryActionLabel.contains("python"))
    }

    @MainActor
    func testJourneyPrimaryActionOpensFirstMathematicsLesson() async throws {
        let app = XCUIApplication()
        app.launch()

        let primaryAction = app.buttons["journey.primary-action"]
        XCTAssertTrue(
            primaryAction.waitForExistence(timeout: 15),
            "The learning journey must offer a direct first step. / Маршрут должен предлагать прямой первый шаг.\n\(app.debugDescription)"
        )
        primaryAction.click()

        let firstMathematicsLessonWindow = app.windows.matching(
            NSPredicate(
                format: "title CONTAINS[c] %@ OR title CONTAINS[c] %@",
                "Часть целого",
                "Parts of a whole"
            )
        ).firstMatch
        XCTAssertTrue(
            firstMathematicsLessonWindow.waitForExistence(timeout: 20),
            "The journey action must open the first mathematics lesson, not only the subject overview. / Кнопка маршрута должна открыть первый урок математики, а не только обзор предмета.\n\(app.debugDescription)"
        )
    }

    @MainActor
    func testJourneyMiniProjectResultSurvivesAppRelaunch() async throws {
        let app = XCUIApplication()
        app.launch()

        let expandButton = app.buttons["journey.expand"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 15))
        expandButton.click()

        let projectResult = app.descendants(matching: .any)["journey.step.mathematics.project-result"]
        XCTAssertTrue(projectResult.waitForExistence(timeout: 10))
        if !projectResult.isHittable {
            projectResult.click()
        }
        XCTAssertTrue(projectResult.isHittable)
        projectResult.click()

        let draft = "Saved math mini-project \(UUID().uuidString)"
        projectResult.typeText(draft)
        XCTAssertEqual(projectResult.value as? String, draft)

        app.terminate()
        app.launch()

        let relaunchedExpandButton = app.buttons["journey.expand"]
        XCTAssertTrue(relaunchedExpandButton.waitForExistence(timeout: 15))
        relaunchedExpandButton.click()

        let restoredResult = app.descendants(matching: .any)["journey.step.mathematics.project-result"]
        XCTAssertTrue(restoredResult.waitForExistence(timeout: 10))
        XCTAssertEqual(
            restoredResult.value as? String,
            draft,
            "A learner's saved mini-project result must be restored after reopening ColiDev. / Результат мини-проекта должен восстановиться после повторного запуска ColiDev."
        )
    }

    @MainActor
    func testPythonJourneyProjectMatchesTheFirstProgrammingCourse() async throws {
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        let expandButton = app.buttons["journey.expand"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 15))
        expandButton.click()

        let projectOutput = app.staticTexts["journey.step.python.project-output"]
        XCTAssertTrue(
            projectOutput.waitForExistence(timeout: 10),
            "The Python route must expose its own mini-project outcome. / У Python-этапа должен быть доступный результат мини-проекта.\n\(app.debugDescription)"
        )
        let output = accessibleText(of: projectOutput).lowercased()
        XCTAssertTrue(
            output.contains("минут") || output.contains("minute"),
            "The first Python project must match the practice-minute program in the variables lesson. / Первый проект Python должен совпадать с программой учёта минут из урока о переменных. Actual accessibility label: '\(projectOutput.label)'."
        )
        XCTAssertFalse(
            output.contains("трени") || output.contains("friction"),
            "The Python project must not depend on friction before the physics stage. / Проект Python не должен зависеть от трения до этапа физики."
        )
    }

    @MainActor
    func testPreviewOpensLockedGradientDescentLessonWithItsLab() async throws {
        let app = XCUIApplication()
        app.launchEnvironment["COLIDEV_UI_TEST_PREVIEW_LOCKED"] = "1"
        app.launch()
        defer { app.terminate() }

        let programmingItem = app.staticTexts["Программирование"]
        XCTAssertTrue(
            programmingItem.waitForExistence(timeout: 15),
            "The programming subject must be available from the sidebar. / Предмет «Программирование» должен быть доступен в боковой панели.\n\(app.debugDescription)"
        )
        programmingItem.click()

        let lessonIdentifier = "roadmap.lesson.programming.gradient_descent_and_learning_rate"
        let lessonButton = app.buttons[lessonIdentifier]
        XCTAssertTrue(
            lessonButton.waitForExistence(timeout: 10),
            "The gradient descent lesson must be listed in the programming roadmap. / Урок о градиентном спуске должен быть в маршруте программирования.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            lessonButton.isEnabled,
            "Preview mode must open an intermediate lesson before its foundations are complete. / Режим просмотра должен открывать урок среднего уровня до прохождения базовых."
        )
        let roadmapScrollView = app.scrollViews.containing(.button, identifier: lessonIdentifier).firstMatch
        scrollUntilHittable(lessonButton, in: roadmapScrollView)
        lessonButton.click()

        let state = app.staticTexts["lab.gd.state"]
        XCTAssertTrue(
            state.waitForExistence(timeout: 15),
            "The gradient descent lesson must show its own lab. / Урок о градиентном спуске должен показывать свой тренажёр.\n\(app.debugDescription)"
        )
        let stateText = accessibleText(of: state)
        XCTAssertTrue(
            stateText.contains("1.988") || stateText.contains("1,988"),
            "Five iterations at η = 0.05 must reach w ≈ 1.988. / Пять итераций при η = 0,05 должны дать w ≈ 1,988.\n\(state.debugDescription)"
        )
    }

    @MainActor
    func testVariablesLessonRunsPracticeMinutesProjectInLocalTrainer() async throws {
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        let programmingItem = app.staticTexts["Программирование"]
        XCTAssertTrue(
            programmingItem.waitForExistence(timeout: 15),
            "The programming subject must be available from the sidebar. / Предмет «Программирование» должен быть доступен в боковой панели.\n\(app.debugDescription)"
        )
        programmingItem.click()

        let variablesLesson = app.buttons["roadmap.lesson.programming.variables_and_types"]
        XCTAssertTrue(
            variablesLesson.waitForExistence(timeout: 10),
            "The variables lesson must be reachable from the programming roadmap. / Урок о переменных должен открываться из маршрута программирования.\n\(app.debugDescription)"
        )
        variablesLesson.click()

        let runButton = app.buttons["python.minutes.run"]
        XCTAssertTrue(
            runButton.waitForExistence(timeout: 15),
            "The variables lesson must include a runnable practice-minutes project. / В уроке о переменных должен быть запускаемый мини-проект учёта минут практики.\n\(app.debugDescription)"
        )
        runButton.click()

        let result = app.staticTexts["python.minutes.result"]
        XCTAssertTrue(
            result.waitForExistence(timeout: 20),
            "The local Python practice runner must display its output. / Локальный тренажёр Python должен показать результат выполнения.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            accessibleText(of: result).contains("20"),
            "Adding the default inputs 12 and 8 must display 20. / Для входных значений 12 и 8 результат должен быть равен 20.\n\(result.debugDescription)"
        )

        app.terminate()
        app.launch()
        let programmingAfterRelaunch = app.staticTexts["Программирование"]
        XCTAssertTrue(programmingAfterRelaunch.waitForExistence(timeout: 15))
        programmingAfterRelaunch.click()
        let lessonAfterRelaunch = app.buttons["roadmap.lesson.programming.variables_and_types"]
        XCTAssertTrue(lessonAfterRelaunch.waitForExistence(timeout: 10))
        lessonAfterRelaunch.click()
        let savedResult = app.staticTexts["python.minutes.result"]
        XCTAssertTrue(
            savedResult.waitForExistence(timeout: 15),
            "The mini-project result must survive relaunch. / Результат мини-проекта должен сохраниться после перезапуска.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            accessibleText(of: savedResult).contains("20"),
            "The saved mini-project result should still be 20. / После перезапуска сохранённый результат должен оставаться равным 20.\n\(savedResult.debugDescription)"
        )

        let today = app.staticTexts["Сегодня"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        today.click()
        let expandJourney = app.buttons["journey.expand"]
        XCTAssertTrue(expandJourney.waitForExistence(timeout: 10))
        expandJourney.click()
        let savedJourneyProject = app.descendants(matching: .any)["journey.step.python.project-result"]
        XCTAssertTrue(savedJourneyProject.waitForExistence(timeout: 10))
        XCTAssertEqual(savedJourneyProject.value as? String, "12 + 8 = 20")
        let completedJourneyProject = app.buttons["journey.step.python.complete"]
        XCTAssertTrue(completedJourneyProject.exists)
        let completionStatus = (completedJourneyProject.value as? String ?? "").lowercased()
        XCTAssertTrue(completionStatus.contains("completed") || completionStatus.contains("выполнен"))
    }

    @MainActor
    func testJourneyProjectCompletionUpdatesProgressAndSurvivesRelaunch() async throws {
        let app = XCUIApplication()
        defer { if app.state != .notRunning { app.terminate() } }
        app.launch()

        let expandButton = app.buttons["journey.expand"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 15))
        expandButton.click()

        let progress = app.staticTexts["journey.project-progress"]
        XCTAssertTrue(
            progress.waitForExistence(timeout: 10),
            "The learning journey must show how many mini-project milestones are complete. / Маршрут должен показывать число завершённых мини-проектов.\n\(app.debugDescription)"
        )

        let completion = app.buttons["journey.step.mathematics.complete"]
        if completion.exists {
            let currentStatus = (completion.value as? String ?? "").lowercased()
            if currentStatus.contains("completed") || currentStatus.contains("выполнен") {
                completion.click()
            }
        }
        let startingProgress = accessibleText(of: progress)
        XCTAssertFalse(
            startingProgress.isEmpty,
            "The progress summary must expose its visible count to accessibility. / Сводка должна отдавать видимый счётчик через accessibility.\n\(progress.debugDescription)"
        )

        let projectResult = app.descendants(matching: .any)["journey.step.mathematics.project-result"]
        XCTAssertTrue(projectResult.waitForExistence(timeout: 10))
        if !projectResult.isHittable {
            projectResult.click()
        }
        XCTAssertTrue(projectResult.isHittable)
        projectResult.click()
        projectResult.typeKey("a", modifierFlags: .command)
        let result = "Verified prototype \(UUID().uuidString)"
        projectResult.typeText(result)

        XCTAssertTrue(
            completion.waitForExistence(timeout: 10),
            "A saved project result must be markable as complete. / Сохранённый результат мини-проекта должен отмечаться выполненным.\n\(app.debugDescription)"
        )
        completion.click()
        let completedProgress = accessibleText(of: progress)
        XCTAssertFalse(completedProgress.isEmpty)
        XCTAssertNotEqual(completedProgress, startingProgress)

        app.terminate()
        app.launch()

        let relaunchedExpandButton = app.buttons["journey.expand"]
        XCTAssertTrue(relaunchedExpandButton.waitForExistence(timeout: 15))
        relaunchedExpandButton.click()

        let restoredProgress = app.staticTexts["journey.project-progress"]
        XCTAssertTrue(restoredProgress.waitForExistence(timeout: 10))
        XCTAssertEqual(accessibleText(of: restoredProgress), completedProgress)
        let restoredResult = app.descendants(matching: .any)["journey.step.mathematics.project-result"]
        XCTAssertTrue(restoredResult.waitForExistence(timeout: 10))
        XCTAssertEqual(restoredResult.value as? String, result)
        let restoredCompletion = app.buttons["journey.step.mathematics.complete"]
        XCTAssertTrue(restoredCompletion.exists)
        let restoredStatus = (restoredCompletion.value as? String ?? "").lowercased()
        XCTAssertTrue(restoredStatus.contains("completed") || restoredStatus.contains("выполнен"))
    }

    @MainActor
    func testSynapticPlasticityLabStrengthensOnlyOnCoincidence() async throws {
        let app = XCUIApplication()
        app.launchEnvironment["COLIDEV_UI_TEST_LESSON"] = "biology/synaptic_plasticity_and_learning"
        app.launchEnvironment["COLIDEV_UI_TEST_NEW_LEARNER"] = "1"
        app.launch()
        app.activate()
        let lessonScrollView = app.scrollViews["lesson.scrollView"]
        XCTAssertTrue(lessonScrollView.waitForExistence(timeout: 5))

        let stimulate = app.buttons["lab.plasticity.stimulate"]
        XCTAssertTrue(
            stimulate.waitForExistence(timeout: 10),
            "The synaptic plasticity lesson must show its lab. / В уроке о пластичности синапса должен быть тренажёр.\n\(app.debugDescription)"
        )
        let strength = app.staticTexts["lab.plasticity.strength"]
        func text(_ element: XCUIElement) -> String { (element.value as? String ?? "") + " " + element.label }
        XCTAssertTrue(text(strength).contains(": 3 "), text(strength))

        // Glutamate alone: magnesium blocks NMDA, so the synapse stays the same.
        scrollUntilHittable(stimulate, in: lessonScrollView)
        stimulate.click()
        if !text(app.staticTexts["lab.plasticity.outcome"]).contains("NMDA"), stimulate.isHittable { stimulate.click() }
        XCTAssertTrue(text(strength).contains(": 3 "), text(strength))

        let depolarization = app.descendants(matching: .any)["lab.plasticity.depolarization"]
        XCTAssertTrue(depolarization.exists)
        scrollUntilHittable(depolarization, in: lessonScrollView)
        depolarization.click()
        stimulate.click()
        XCTAssertTrue(
            text(strength).contains(": 4 "),
            "Glutamate plus strong depolarisation must insert one more AMPA receptor. / Совпадение должно добавить рецептор AMPA.\n\(text(strength))"
        )
    }

    @MainActor
    func testMichaelisMentenLabStartsAtTheLessonQuiz() async throws {
        let app = XCUIApplication()
        app.launchEnvironment["COLIDEV_UI_TEST_LESSON"] = "chemistry/enzyme_kinetics_michaelis_menten"
        app.launchEnvironment["COLIDEV_UI_TEST_NEW_LEARNER"] = "1"
        app.launch()
        app.activate()
        let rate = app.staticTexts["lab.enzyme.rate"]
        XCTAssertTrue(
            rate.waitForExistence(timeout: 10),
            "The enzyme kinetics lesson must show its lab. / В уроке о кинетике ферментов должен быть тренажёр.\n\(app.debugDescription)"
        )
        let shown = (rate.value as? String ?? "") + " " + rate.label
        XCTAssertTrue(shown.contains("75"), "Vmax 100, Km 2 mM, [S] 6 mM must give 75. / Должно получиться 75.\n\(shown)")
    }

    @MainActor
    func testLeastSquaresLabFitsTheLineToPendulumData() async throws {
        let app = XCUIApplication()
        app.launchEnvironment["COLIDEV_UI_TEST_LESSON"] = "physics/fitting_pendulum_data_least_squares"
        app.launchEnvironment["COLIDEV_UI_TEST_NEW_LEARNER"] = "1"
        app.launch()
        app.activate()
        let lessonScrollView = app.scrollViews["lesson.scrollView"]
        XCTAssertTrue(lessonScrollView.waitForExistence(timeout: 5))

        let fit = app.buttons["lab.lsq.fit"]
        XCTAssertTrue(
            fit.waitForExistence(timeout: 10),
            "The pendulum fitting lesson must show its least-squares lab. / В уроке о подгонке данных маятника должен быть тренажёр.\n\(app.debugDescription)"
        )
        let gravity = app.staticTexts["lab.lsq.gravity"]
        func text(_ element: XCUIElement) -> String { (element.value as? String ?? "") + " " + element.label }
        XCTAssertTrue(text(gravity).contains("13,16") || text(gravity).contains("13.16"), text(gravity))

        scrollUntilHittable(fit, in: lessonScrollView)
        fit.click()
        // On macOS, the first click on an off-screen SwiftUI control may only scroll it into view.
        if !(text(gravity).contains("9,74") || text(gravity).contains("9.74")), fit.isHittable {
            fit.click()
        }
        XCTAssertTrue(
            text(gravity).contains("9,74") || text(gravity).contains("9.74"),
            "Fitting by least squares must give g = 9.74 m/s² from the lesson data. / Подгонка должна дать g = 9,74 м/с².\n\(text(gravity))"
        )
    }

    @MainActor
    func testFrictionLessonOffersSourceBackedVideoStudyCard() async throws {
        let app = XCUIApplication()
        app.launchEnvironment["COLIDEV_UI_TEST_FRICTION_LESSON"] = "1"
        // testFrictionLessonLearningCycle… runs earlier and saves an answer; this test covers a first visit.
        app.launchEnvironment["COLIDEV_UI_TEST_NEW_LEARNER"] = "1"
        app.launch()
        app.activate()
        let lessonScrollView = app.scrollViews["lesson.scrollView"]
        XCTAssertTrue(lessonScrollView.waitForExistence(timeout: 5))

        let videoTitle = app.staticTexts["lesson.video.title"]
        XCTAssertTrue(
            videoTitle.waitForExistence(timeout: 10),
            "The lesson did not render its source-backed video activity. / В уроке не появилась видеоактивность с указанным источником.\n\(app.debugDescription)"
        )
        XCTAssertTrue(app.staticTexts["lesson.video.before"].exists)
        XCTAssertFalse(app.staticTexts["lesson.video.after"].exists)

        let response = app.descendants(matching: .any)["lesson.video.response"]
        XCTAssertFalse(response.exists, "The response must stay hidden until the learner confirms watching. / Ответ должен быть скрыт, пока ученик не подтвердит просмотр.\n\(app.debugDescription)")

        XCTAssertTrue(
            app.staticTexts["lesson.video.privacyNotice"].exists,
            "The app must disclose YouTube data sharing before playback is loaded. / До загрузки плеера приложение должно предупредить о передаче данных YouTube.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["lesson.video.player"].exists,
            "The player must not load before the learner grants consent. / Плеер не должен загружаться до согласия ученика.\n\(app.debugDescription)"
        )
        XCTAssertFalse(app.buttons["lesson.video.markWatched"].exists)

        let enablePlayback = app.buttons["lesson.video.enablePlayback"]
        XCTAssertTrue(
            enablePlayback.waitForExistence(timeout: 10),
            "Playback must require a deliberate user action after the privacy notice. / Воспроизведение должно начинаться только после явного действия пользователя и предупреждения о приватности.\n\(app.debugDescription)"
        )
        scrollUntilHittable(enablePlayback, in: lessonScrollView)
        enablePlayback.click()

        // On macOS, the first click on an off-screen SwiftUI control may only scroll it into view.
        // If the consent action is still present and now hittable, click again to activate it.
        if enablePlayback.exists && enablePlayback.isHittable {
            enablePlayback.click()
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["lesson.video.player"].waitForExistence(timeout: 10),
            "The lesson must reveal an embedded player after consent. / После согласия в уроке должен появиться встроенный плеер.\n\(app.debugDescription)"
        )

        let markWatched = app.buttons["lesson.video.markWatched"]
        XCTAssertTrue(markWatched.waitForExistence(timeout: 10))
        scrollUntilHittable(markWatched, in: lessonScrollView)
        markWatched.click()
        if markWatched.exists && markWatched.isHittable {
            markWatched.click()
        }
        XCTAssertFalse(app.staticTexts["lesson.video.after"].exists)
        XCTAssertFalse(response.exists)

        let videoLink = app.links["lesson.video.open"]
        XCTAssertTrue(
            videoLink.waitForExistence(timeout: 10),
            "The video activity must retain a direct source link as a fallback. / Видеоактивность должна сохранять прямую ссылку на источник как запасной вариант.\n\(app.debugDescription)"
        )
        XCTAssertTrue(videoLink.label.localizedCaseInsensitiveContains("Khan Academy"))
    }

    @MainActor
    func testNotebookLMCanReceiveTheLessonAsCopiedMarkdown() async throws {
        let app = XCUIApplication()
        defer { if app.state != .notRunning { app.terminate() } }
        app.launchEnvironment["COLIDEV_UI_TEST_FRICTION_LESSON"] = "1"
        // The test walks through the video steps, which a saved answer from an earlier test would skip.
        app.launchEnvironment["COLIDEV_UI_TEST_NEW_LEARNER"] = "1"
        app.launch()
        app.activate()

        let scrollView = app.scrollViews["lesson.scrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        let copyButton = app.buttons["lesson.notebook.copy"]
        XCTAssertTrue(
            copyButton.waitForExistence(timeout: 10),
            "The lesson must offer a local Markdown copy path for manual NotebookLM import. / Урок должен позволять скопировать Markdown для ручного импорта в NotebookLM.\n\(app.debugDescription)"
        )
        scrollUntilHittable(copyButton, in: scrollView)
        copyButton.click()

        let copyStatus = app.staticTexts["lesson.notebook.status"]
        XCTAssertTrue(
            copyStatus.waitForExistence(timeout: 5),
            "Copying the NotebookLM lesson source must show a result. / После копирования источника для NotebookLM должен появиться результат.\n\(app.debugDescription)"
        )
        XCTAssertFalse((copyStatus.value as? String ?? "").isEmpty)

        let consentButton = app.buttons["lesson.video.enablePlayback"]
        scrollUntilHittable(consentButton, in: scrollView)
        consentButton.click()
        if consentButton.exists && consentButton.isHittable {
            consentButton.click()
        }
        let markWatched = app.buttons["lesson.video.markWatched"]
        scrollUntilHittable(markWatched, in: scrollView)
        markWatched.click()
        if markWatched.exists && markWatched.isHittable {
            markWatched.click()
        }

        let knowledgeAnswer = app.buttons["lesson.check.option.0"]
        scrollUntilHittable(knowledgeAnswer, in: scrollView)
        knowledgeAnswer.click()

        let response = app.descendants(matching: .any)["lesson.video.response"]
        XCTAssertTrue(response.waitForExistence(timeout: 10))
        scrollUntilHittable(response, in: scrollView)
        response.click()
        response.typeKey("a", modifierFlags: .command)
        response.typeKey("v", modifierFlags: .command)
        XCTAssertTrue(
            (response.value as? String)?.hasPrefix("# ") == true
                && (response.value as? String)?.contains("ColiDev") == true,
            "The clipboard must contain the lesson Markdown, ready to paste into NotebookLM. / В буфере должен быть Markdown урока, готовый к вставке в NotebookLM.\n\(response.debugDescription)"
        )
    }

    @MainActor
    func testFrictionLessonLearningCycleAndProgressSurviveAppRelaunch() async throws {
        let app = XCUIApplication()
        app.launchEnvironment["COLIDEV_UI_TEST_FRICTION_LESSON"] = "1"
        app.launch()
        app.activate()
        let lessonScrollView = app.scrollViews["lesson.scrollView"]
        XCTAssertTrue(lessonScrollView.waitForExistence(timeout: 5))

        let theory = app.staticTexts["lesson.theory"].firstMatch
        let videoTitle = app.staticTexts["lesson.video.title"]
        let modelHint = app.staticTexts["lesson.friction.model"]
        XCTAssertTrue(theory.waitForExistence(timeout: 10))
        XCTAssertTrue(videoTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(modelHint.waitForExistence(timeout: 10))
        XCTAssertLessThan(theory.frame.midY, videoTitle.frame.midY)
        XCTAssertLessThan(videoTitle.frame.midY, modelHint.frame.midY)
        XCTAssertTrue(app.staticTexts["lesson.video.captionHelp"].exists)
        XCTAssertTrue(app.staticTexts["lesson.video.before"].exists)
        XCTAssertFalse(app.staticTexts["lesson.video.after"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["lesson.video.response"].exists)
        XCTAssertTrue(app.staticTexts["lesson.video.privacyNotice"].exists)
        XCTAssertFalse(app.buttons["lesson.video.markWatched"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["lesson.video.player"].exists)
        XCTAssertTrue(app.links["lesson.video.open"].label.localizedCaseInsensitiveContains("Khan Academy"))

        let consentButton = app.buttons["lesson.video.enablePlayback"]
        XCTAssertTrue(consentButton.waitForExistence(timeout: 10))
        scrollUntilHittable(consentButton, in: lessonScrollView)
        consentButton.click()
        if consentButton.exists && consentButton.isHittable {
            consentButton.click()
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["lesson.video.player"].waitForExistence(timeout: 10),
            "The embedded video must load only after explicit consent. / Встроенное видео должно загрузиться только после явного согласия.\n\(app.debugDescription)"
        )

        let markWatched = app.buttons["lesson.video.markWatched"]
        XCTAssertTrue(markWatched.waitForExistence(timeout: 10))
        scrollUntilHittable(markWatched, in: lessonScrollView)
        markWatched.click()
        if markWatched.exists && markWatched.isHittable {
            markWatched.click()
        }
        XCTAssertFalse(app.staticTexts["lesson.video.after"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["lesson.video.response"].exists)

        let pushSlider = app.sliders["lesson.friction.slider.push"]
        scrollUntilHittable(pushSlider, in: lessonScrollView)
        let sliderThumb = pushSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
        let sliderTarget = pushSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        sliderThumb.press(forDuration: 0.2, thenDragTo: sliderTarget)
        let motionState = app.staticTexts["lesson.friction.motion-state"]
        XCTAssertTrue(motionState.waitForExistence(timeout: 5))
        let motionStateText = accessibleText(of: motionState)
        XCTAssertTrue(
            motionStateText.localizedCaseInsensitiveContains("скольжение")
                || motionStateText.localizedCaseInsensitiveContains("sliding"),
            "Changing the applied-force slider must change the visual model's motion state. / Изменение силы должно менять состояние наглядной модели.\n\(motionStateText)\n\(app.debugDescription)"
        )

        let firstPrediction = app.buttons["lesson.friction.prediction.option.friction.at-15n.0"]
        scrollUntilHittable(firstPrediction, in: lessonScrollView)
        firstPrediction.click()
        let predictionAction = app.buttons["lesson.friction.prediction.action"]
        scrollUntilHittable(predictionAction, in: lessonScrollView)
        predictionAction.click()
        let predictionFeedback = app.staticTexts["lesson.friction.prediction.feedback"]
        XCTAssertTrue(predictionFeedback.waitForExistence(timeout: 5))
        let firstPredictionFeedback = accessibleText(of: predictionFeedback)
        XCTAssertTrue(firstPredictionFeedback.localizedCaseInsensitiveContains("верно")
            || firstPredictionFeedback.localizedCaseInsensitiveContains("correct"),
            "The first prediction must receive correct feedback. / Первый прогноз должен получить отметку о правильном ответе.\n\(app.debugDescription)")
        scrollUntilHittable(predictionAction, in: lessonScrollView)
        predictionAction.click()

        let secondPrediction = app.buttons["lesson.friction.prediction.option.friction.at-25n.1"]
        scrollUntilHittable(secondPrediction, in: lessonScrollView)
        secondPrediction.click()
        scrollUntilHittable(predictionAction, in: lessonScrollView)
        predictionAction.click()
        XCTAssertTrue(predictionFeedback.waitForExistence(timeout: 5))
        let secondPredictionFeedback = accessibleText(of: predictionFeedback)
        XCTAssertTrue(secondPredictionFeedback.localizedCaseInsensitiveContains("верно")
            || secondPredictionFeedback.localizedCaseInsensitiveContains("correct"),
            "The second prediction must receive correct feedback. / Второй прогноз должен получить отметку о правильном ответе.\n\(app.debugDescription)")
        scrollUntilHittable(predictionAction, in: lessonScrollView)
        predictionAction.click()
        XCTAssertTrue(app.staticTexts["lesson.friction.prediction.complete"].waitForExistence(timeout: 5))

        let knowledgeAnswer = app.buttons["lesson.check.option.0"]
        scrollUntilHittable(knowledgeAnswer, in: lessonScrollView)
        knowledgeAnswer.click()
        let knowledgeFeedback = app.staticTexts["lesson.check.feedback"]
        XCTAssertTrue(knowledgeFeedback.waitForExistence(timeout: 5))
        let knowledgeFeedbackText = accessibleText(of: knowledgeFeedback)
        XCTAssertTrue(knowledgeFeedbackText.localizedCaseInsensitiveContains("верно")
            || knowledgeFeedbackText.localizedCaseInsensitiveContains("correct"),
            "The lesson check must accept the correct answer. / Проверочный вопрос урока должен принять правильный ответ.\n\(app.debugDescription)")

        let response = app.descendants(matching: .any)["lesson.video.response"]
        XCTAssertTrue(app.staticTexts["lesson.video.after"].waitForExistence(timeout: 5))
        XCTAssertTrue(response.waitForExistence(timeout: 10))
        XCTAssertLessThan(knowledgeAnswer.frame.midY, response.frame.midY)
        scrollUntilHittable(response, in: lessonScrollView)
        let draft = "I predict 15 N is below the static-friction threshold."
        response.click()
        response.typeKey("a", modifierFlags: .command)
        response.typeText(draft)
        XCTAssertEqual(response.value as? String, draft)

        let learnerConfirmation = app.descendants(matching: .any)["lesson.completion.confirmed"]
        scrollUntilHittable(learnerConfirmation, in: lessonScrollView)
        learnerConfirmation.click()
        let completionAction = app.buttons["lesson.completion.action"]
        scrollUntilHittable(completionAction, in: lessonScrollView)
        completionAction.click()

        let savedCompletion = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                "сохранён",
                "сохранить",
                "saved",
                "save practice result"
            ),
            object: completionAction
        )
        let completionResult = await XCTWaiter.fulfillment(of: [savedCompletion], timeout: 10)
        XCTAssertEqual(completionResult, .completed, "The completed lesson must be saved before relaunch. / Завершение урока должно сохраниться до перезапуска.\n\(app.debugDescription)")

        app.terminate()
        app.launch()
        app.activate()

        // The saved answer after the video is shown straight away: the learner does not consent to YouTube,
        // confirm watching or answer the check again. / Сохранённый ответ виден сразу, без повторного согласия и проверки.
        let restoredConsent = app.buttons["lesson.video.enablePlayback"]
        XCTAssertTrue(restoredConsent.waitForExistence(timeout: 10))
        let restoredLessonScrollView = app.scrollViews["lesson.scrollView"]
        XCTAssertTrue(restoredLessonScrollView.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["lesson.video.player"].exists)
        XCTAssertFalse(app.buttons["lesson.video.markWatched"].exists)

        let restoredResponse = app.descendants(matching: .any)["lesson.video.response"]
        XCTAssertTrue(
            restoredResponse.waitForExistence(timeout: 10),
            "A saved answer after the video must be visible as soon as the lesson opens. / Сохранённый ответ после видео должен быть виден сразу при открытии урока.\n\(app.debugDescription)")
        XCTAssertTrue(app.staticTexts["lesson.video.after"].exists)
        XCTAssertEqual(
            restoredResponse.value as? String,
            draft,
            "An unfinished lesson reflection must survive quitting and reopening ColiDev. / Незавершённый ответ к уроку должен сохраняться после закрытия и повторного запуска ColiDev."
        )
        let restoredCompletionAction = app.buttons["lesson.completion.action"]
        XCTAssertTrue(restoredCompletionAction.waitForExistence(timeout: 10))
        let restoredCompletionText = accessibleText(of: restoredCompletionAction)
        XCTAssertTrue(
            restoredCompletionText.localizedCaseInsensitiveContains("сохранён как завершённый")
                || restoredCompletionText.localizedCaseInsensitiveContains("сохранить результат тренировки")
                || restoredCompletionText.localizedCaseInsensitiveContains("saved as completed")
                || restoredCompletionText.localizedCaseInsensitiveContains("save practice result"),
            "Lesson progress must survive quitting and reopening ColiDev. / Прогресс урока должен сохраняться после закрытия и повторного запуска ColiDev.\n\(app.debugDescription)"
        )
        let restoredLearnerConfirmation = app.descendants(matching: .any)["lesson.completion.confirmed"]
        XCTAssertTrue(restoredLearnerConfirmation.waitForExistence(timeout: 5))
        let confirmationValue = restoredLearnerConfirmation.value
        let confirmationIsSet = (confirmationValue as? NSNumber)?.boolValue == true
            || ["1", "true", "on"].contains((confirmationValue as? String ?? "").lowercased())
        XCTAssertTrue(
            confirmationIsSet,
            "The learner's completion confirmation must survive relaunch. / Подтверждение прохождения должно пережить перезапуск.\n\(restoredLearnerConfirmation.debugDescription)"
        )
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in scrollView: XCUIElement
    ) {
        // The left inset is outside the full-width WKWebView player, so the lesson scroll view receives the wheel.
        let lessonScrollPoint = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.9))
        for _ in 0..<64 {
            if element.isHittable { return }

            // Scroll toward the element. A fixed negative wheel delta pushed content above the
            // viewport farther away when the lesson opens focused on a lower practice section.
            let elementFrame = element.frame
            let scrollFrame = scrollView.frame
            let elementIsAboveViewport = elementFrame.maxY < scrollFrame.minY
            let direction: CGFloat = elementIsAboveViewport ? 140 : -140
            lessonScrollPoint.scroll(byDeltaX: 0, deltaY: direction)
        }
        XCTAssertTrue(element.isHittable, "Expected control to become visible after scrolling. / Элемент должен появиться после прокрутки.\n\(element.debugDescription)")
    }

    @MainActor
    private func accessibleText(of element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    @MainActor
    func testMissingIntroMarkdownShowsUnavailableStateInsteadOfLegacyLesson() async throws {
        let app = XCUIApplication()
        defer { if app.state != .notRunning { app.terminate() } }
        app.launchEnvironment["COLIDEV_UI_TEST_MISSING_INTRO_ROUTE"] = "1"
        app.launch()

        let mathematicsItem = app.staticTexts["Математика"]
        XCTAssertTrue(
            mathematicsItem.waitForExistence(timeout: 15),
            "The Mathematics navigation item did not appear. / Не появился пункт навигации «Математика».\n\(app.debugDescription)"
        )
        mathematicsItem.click()

        let openIntroLessonButton = app.buttons["Открыть вводный урок"]
        XCTAssertTrue(
            openIntroLessonButton.waitForExistence(timeout: 10),
            "The subject overview must expose its intro-lesson action. / На странице предмета должна быть кнопка вводного урока.\n\(app.debugDescription)"
        )
        openIntroLessonButton.click()

        let unavailableTitle = app.staticTexts["lesson.intro.unavailable.title"]
        XCTAssertTrue(
            unavailableTitle.waitForExistence(timeout: 10),
            "A missing source-backed intro route must be visible instead of silently showing the legacy localized lesson. / При отсутствии основного маршрута должен отображаться явный статус, а не старая локализованная копия без источников.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            app.buttons["lesson.intro.unavailable.back"].exists,
            "The unavailable state must let the learner return to the subject. / Из состояния ошибки ученик должен иметь возможность вернуться к предмету."
        )
    }

    @MainActor
    func testClickingCellOrganelleUpdatesSelectionAndDescription() async throws {
        let app = XCUIApplication()
        app.launchArguments = ["-colidev.uiTestCell3D", "YES"]
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 10) else {
            XCTFail("ColiDev did not present its main window. / ColiDev не показал главное окно.\n\(app.debugDescription)")
            return
        }

        let scene = app.descendants(matching: .any)["biology.cell3d.scene"]
        guard scene.waitForExistence(timeout: 15) else {
            XCTFail("3D cell scene was not opened by the UI-test route. / UI-тест не открыл 3D-сцену клетки.\n\(app.debugDescription)")
            return
        }

        let description = app.staticTexts["biology.cell3d.description"]
        guard description.waitForExistence(timeout: 10) else {
            XCTFail("The selected organelle description is missing. / Не найдено описание выбранной органеллы.\n\(app.debugDescription)")
            return
        }
        let organelleMenu = app.popUpButtons["biology.cell3d.organelles"]
        guard organelleMenu.waitForExistence(timeout: 5) else {
            XCTFail("The organelle menu is missing. / Не найдено меню органелл.\n\(app.debugDescription)")
            return
        }
        let tapState = app.staticTexts["biology.cell3d.tapState"]
        guard tapState.waitForExistence(timeout: 5) else {
            XCTFail("The test-only scene tap diagnostic is missing. / Не найден тестовый счётчик щелчков сцены.\n\(app.debugDescription)")
            return
        }
        XCTAssertEqual(
            description.value as? String,
            "Хранит большую часть ДНК клетки; оболочка ядра отделяет её от цитоплазмы.",
            "The nucleus must be selected initially. / При открытии должно быть выбрано ядро."
        )
        let initialTapState = tapState.value as? String
        XCTAssertTrue(initialTapState?.hasPrefix("tap=0, part=nucleus") == true)
        XCTAssertEqual(organelleMenu.value as? String, "Ядро", "The menu must start on the nucleus. / В меню должно быть выбрано ядро.")
        XCTAssertEqual(
            scene.label,
            "Упрощённая вращаемая 3D-модель животной клетки; органеллу можно выбрать нажатием или в меню.",
            "The 3D scene must expose its accessible label. / У 3D-сцены должна быть доступная подпись."
        )

        let lessonScrollView = window.scrollViews.element(boundBy: 1)
        guard lessonScrollView.waitForExistence(timeout: 5) else {
            XCTFail("The lesson scroll area is missing. / Не найдена область прокрутки урока.\n\(app.debugDescription)")
            return
        }
        let viewport = lessonScrollView.frame.insetBy(dx: 0, dy: 12)
        let sceneBecameHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: scene
        )
        let visibilityResult = await XCTWaiter.fulfillment(of: [sceneBecameHittable], timeout: 10)
        guard visibilityResult == .completed else {
            XCTFail("The test route must open the 3D cell scene inside the lesson viewport. / Тестовый маршрут должен открыть 3D-сцену клетки в видимой области урока.\nScene: \(scene.frame), viewport: \(viewport)\n\(scene.debugDescription)")
            return
        }
        let visibleSceneFrame = viewport.intersection(scene.frame)
        let sceneArea = scene.frame.width * scene.frame.height
        let visibleFraction = sceneArea > 0
            ? (visibleSceneFrame.width * visibleSceneFrame.height) / sceneArea
            : 0
        let sceneCenter = CGPoint(x: scene.frame.midX, y: scene.frame.midY)
        guard visibleFraction >= 0.9, viewport.contains(sceneCenter) else {
            XCTFail("The 3D cell scene must be mostly visible and centered in the lesson viewport. / 3D-сцена клетки должна в основном помещаться в видимой области урока.\nVisible: \(Int(visibleFraction * 100))%, scene: \(scene.frame), viewport: \(viewport)\n\(scene.debugDescription)")
            return
        }

        // A seed click lets the live SceneKit renderer report its current target projection.
        // Первый щелчок активирует SceneKit; рендерер сообщит актуальную проекцию цели.
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.38)).click()
        let seedTapRecognized = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", initialTapState ?? "tap=0, part=nucleus"),
            object: tapState
        )
        let seedTapResult = await XCTWaiter.fulfillment(of: [seedTapRecognized], timeout: 5)
        guard seedTapResult == .completed,
              let seedDiagnostic = tapState.value as? String,
              let targetField = seedDiagnostic.split(separator: " ").first(where: { $0.hasPrefix("mitochondriaTarget=") }) else {
            XCTFail("The live SceneKit click did not provide a mitochondrion target point. / Активный рендерер SceneKit не сообщил координаты митохондрии.\n\(tapState.value ?? tapState.label)")
            return
        }
        let targetValue = targetField.dropFirst("mitochondriaTarget=".count)
        let targetComponents = targetValue.split(separator: ",")
        guard targetComponents.count == 2,
              let targetX = Double(targetComponents[0]),
              let targetY = Double(targetComponents[1]),
              (0...1).contains(targetX),
              (0...1).contains(targetY) else {
            XCTFail("The projected mitochondrion point is invalid. / Неверные координаты проекции митохондрии: \(targetValue)")
            return
        }
        let tapStateBeforeProjectedClick = tapState.value as? String
        scene.coordinate(withNormalizedOffset: CGVector(dx: CGFloat(targetX), dy: CGFloat(targetY))).click()

        let tapWasRecognized = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", tapStateBeforeProjectedClick ?? ""),
            object: tapState
        )
        let tapResult = await XCTWaiter.fulfillment(of: [tapWasRecognized], timeout: 5)
        guard tapResult == .completed else {
            XCTFail("The click did not reach the native SceneKit click recognizer. / Щелчок не дошёл до нативного обработчика SceneKit. Tap state / Состояние щелчка: \(tapState.value ?? tapState.label); scene frame after click / рамка сцены после щелчка: \(scene.frame); lesson viewport / область урока: \(viewport).\n\(app.debugDescription)")
            return
        }

        let mitochondriaDescription = "Участвуют в клеточном дыхании и производстве ATP для многих процессов клетки."
        let descriptionChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", mitochondriaDescription),
            object: description
        )
        let selectionResult = await XCTWaiter.fulfillment(of: [descriptionChanged], timeout: 5)
        XCTAssertEqual(
            selectionResult,
            .completed,
            "Clicking the mitochondrion did not synchronize its selection and description. / Нажатие на митохондрию не синхронизировало выбор и описание. Tap state / Состояние щелчка: \(tapState.value ?? tapState.label); scene frame / рамка сцены: \(scene.frame); lesson viewport / область урока: \(viewport).\n\(app.debugDescription)"
        )

        XCTAssertEqual(
            organelleMenu.value as? String,
            "Митохондрии",
            "The menu must follow the organelle selected in the scene. / Меню должно показывать органеллу, выбранную в сцене."
        )
    }

    @MainActor
    func testSelectingManagementRendersOverviewContent() async throws {
        let app = XCUIApplication()
        app.launch()

        let managementItem = app.staticTexts["sidebar.management"]
        XCTAssertTrue(managementItem.waitForExistence(timeout: 15))
        managementItem.click()

        let systemStatus = app.staticTexts["control-center.overview.system-status"]
        XCTAssertTrue(
            systemStatus.waitForExistence(timeout: 10),
            "Control Center overview did not show its system status heading after navigation."
        )

        let reloadButton = app.buttons["Обновить данные панели"]
        XCTAssertTrue(
            reloadButton.waitForExistence(timeout: 10),
            "Control Center overview did not expose its refresh button.\n\(app.debugDescription)"
        )
        let overviewTab = app.buttons["control-center.pane.overview"]
        XCTAssertTrue(
            overviewTab.waitForExistence(timeout: 10),
            "Control Center overview tab was missing.\n\(app.debugDescription)"
        )

        let backendReady = app.staticTexts.matching(
            NSPredicate(
                format: "value IN %@ OR label IN %@",
                ["Работает", "Running"],
                ["Работает", "Running"]
            )
        ).firstMatch
        XCTAssertTrue(
            backendReady.waitForExistence(timeout: 30),
            "The app did not start its bundled local backend.\n\(app.debugDescription)"
        )

        let dashboardStatusMessage = app.descendants(matching: .any)["control-center.status-message"]
        let dashboardLoaded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: dashboardStatusMessage
        )
        let dashboardLoadResult = await XCTWaiter.fulfillment(of: [dashboardLoaded], timeout: 10)
        XCTAssertEqual(
            dashboardLoadResult,
            .completed,
            "The Control Center remained in a load-error state after the backend became ready.\n\(app.debugDescription)"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Control Center after backend readiness"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Control Center accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        let visibleRefreshButton = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: reloadButton
        )
        let visibleOverviewTab = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: overviewTab
        )
        let visibilityResult = await XCTWaiter.fulfillment(
            of: [visibleRefreshButton, visibleOverviewTab],
            timeout: 10
        )
        XCTAssertEqual(
            visibilityResult,
            .completed,
            "Control Center refresh button exists in accessibility but is not interactable.\n\(reloadButton.debugDescription)\n\(app.debugDescription)"
        )

        let additionalPanes: [(title: String, id: String, anchorID: String)] = [
            ("Курсы", "courses", "control-center.courses.description"),
            ("Локальные модели", "models", "control-center.models.description"),
            ("RAG", "rag", "control-center.rag.description"),
            ("Источники", "sources", "control-center.sources.description"),
            ("Сервисы", "integrations", "control-center.integrations.providers-heading"),
        ]

        for pane in additionalPanes {
            let tab = app.buttons["control-center.pane.\(pane.id)"]
            XCTAssertTrue(
                tab.waitForExistence(timeout: 10),
                "Control Center tab '\(pane.title)' was missing.\n\(app.debugDescription)"
            )
            XCTAssertTrue(
                tab.isEnabled,
                "Control Center tab '\(pane.title)' is disabled.\n\(tab.debugDescription)\n\(app.debugDescription)"
            )
            XCTAssertTrue(
                tab.isHittable,
                "Control Center tab '\(pane.title)' is not hittable.\n\(tab.debugDescription)\n\(app.debugDescription)"
            )
            app.activate()
            XCTAssertEqual(
                app.state,
                .runningForeground,
                "ColiDev lost foreground focus before selecting Control Center tab '\(pane.title)'.\n\(app.debugDescription)"
            )
            tab.click()

            let paneContent = app.descendants(matching: .any)
                .matching(identifier: pane.anchorID)
                .firstMatch
            XCTAssertTrue(
                paneContent.waitForExistence(timeout: 10),
                "Control Center tab '\(pane.title)' opened without its expected content.\n\(app.debugDescription)"
            )

            let paneScreenshot = XCTAttachment(screenshot: app.screenshot())
            paneScreenshot.name = "Control Center pane: \(pane.title)"
            paneScreenshot.lifetime = .keepAlways
            add(paneScreenshot)
        }

        overviewTab.click()
        XCTAssertTrue(
            systemStatus.waitForExistence(timeout: 10),
            "Control Center could not return to its overview after visiting every pane.\n\(app.debugDescription)"
        )
    }

    @MainActor
    func testSourceRegistryPagesKeepManagementNavigationResponsive() async throws {
        let app = XCUIApplication()
        app.launch()

        let managementItem = app.staticTexts["sidebar.management"]
        XCTAssertTrue(managementItem.waitForExistence(timeout: 15))
        managementItem.click()

        let sourcesTab = app.buttons["control-center.pane.sources"]
        XCTAssertTrue(sourcesTab.waitForExistence(timeout: 15))
        sourcesTab.click()

        let pageStatus = app.staticTexts["control-center.sources.page-status"]
        let nextPage = app.buttons["control-center.sources.next-page"]
        XCTAssertTrue(
            pageStatus.waitForExistence(timeout: 15),
            "The source registry must report its current page. / Реестр источников должен показывать текущую страницу.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            nextPage.waitForExistence(timeout: 15),
            "The bundled source registry must paginate when it has more than one page. / Большой реестр источников должен переключать страницы.\n\(app.debugDescription)"
        )

        let firstPage = try XCTUnwrap(pageStatus.value as? String)
        nextPage.click()
        let pageAdvanced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", firstPage),
            object: pageStatus
        )
        let pageAdvanceResult = await XCTWaiter.fulfillment(of: [pageAdvanced], timeout: 5)
        XCTAssertEqual(
            pageAdvanceResult,
            .completed,
            "Next page must advance the source registry. / Кнопка должна переключить страницу источников."
        )

        XCTAssertTrue(
            app.buttons["control-center.pane.integrations"].exists,
            "The Services tab must remain queryable while browsing sources. / Вкладка «Сервисы» должна оставаться доступной при просмотре источников.\n\(app.debugDescription)"
        )
    }

    @MainActor
    func testRAGPaneExposesLocalEmbeddingModelControls() async throws {
        let app = XCUIApplication()
        app.launch()

        let managementItem = app.staticTexts["sidebar.management"]
        XCTAssertTrue(managementItem.waitForExistence(timeout: 15))
        managementItem.click()

        let ragTab = app.buttons["control-center.pane.rag"]
        XCTAssertTrue(ragTab.waitForExistence(timeout: 10))
        ragTab.click()

        let modelField = app.textFields["control-center.rag.embedding-model"]
        XCTAssertTrue(
            modelField.waitForExistence(timeout: 10),
            "RAG pane must expose a local Ollama embedding model field.\n\(app.debugDescription)"
        )
        XCTAssertTrue(app.buttons["control-center.rag.save-embedding-model"].exists)

        let disableButton = app.buttons["control-center.rag.disable-embedding-model"]
        XCTAssertTrue(disableButton.waitForExistence(timeout: 10))
        let disableButtonReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: disableButton
        )
        let disableButtonResult = await XCTWaiter.fulfillment(of: [disableButtonReady], timeout: 10)
        XCTAssertEqual(disableButtonResult, .completed)

        disableButton.click()
        let statusMessage = app.descendants(matching: .any)["control-center.status-message"]
        let disabledSuccessfully = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@ OR value CONTAINS %@", "отключена", "disabled"),
            object: statusMessage
        )
        let disableResult = await XCTWaiter.fulfillment(of: [disabledSuccessfully], timeout: 15)
        guard disableResult == .completed else {
            XCTFail(
                "Disabling semantic search should show a success message. / При отключении должен появиться статус успеха. "
                    + "Message value: \(statusMessage.value ?? "<missing>")\n\(app.debugDescription)"
            )
            return
        }
    }
}

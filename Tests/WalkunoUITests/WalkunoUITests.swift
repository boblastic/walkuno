import XCTest

@MainActor
final class WalkunoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(demo: Bool = true, languages: [String] = ["fr"], locale: String = "fr_FR", pro: Bool? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let preferredLanguages = "(" + languages.map { "\"\($0)\"" }.joined(separator: ",") + ")"
        app.launchArguments = (demo ? ["--demo"] : []) + ["-AppleLanguages", preferredLanguages, "-AppleLocale", locale]
        if let pro { app.launchArguments += ["-development.proEnabled", pro ? "YES" : "NO"] }
        app.launch()
        return app
    }

    func testSevenLanguagesWithRegionalVariants() {
        let cases: [(String, String, [String], String, String)] = [
            ("en-GB", "en_GB", ["Today", "Statistics", "Explore", "Achievements", "Settings"], "Steps", "Done"),
            ("fr-FR", "fr_FR", ["Aujourd’hui", "Statistiques", "Explorer", "Succès", "Réglages"], "Pas", "Terminé"),
            ("de-DE", "de_DE", ["Heute", "Statistiken", "Entdecken", "Erfolge", "Einstellungen"], "Schritte", "Fertig"),
            ("es-MX", "es_MX", ["Hoy", "Estadísticas", "Explorar", "Logros", "Ajustes"], "Pasos", "Listo"),
            ("it-IT", "it_IT", ["Oggi", "Statistiche", "Esplora", "Traguardi", "Impostazioni"], "Passi", "Fine"),
            ("pt-BR", "pt_BR", ["Hoje", "Estatísticas", "Explorar", "Conquistas", "Definições"], "Passos", "Concluir"),
            ("ja-JP", "ja_JP", ["今日", "統計", "探索", "実績", "設定"], "歩数", "完了")
        ]
        for (language, locale, tabs, steps, done) in cases {
            XCTContext.runActivity(named: language) { _ in
                let app = launch(languages: [language], locale: locale)
                XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))
                for title in tabs { XCTAssertTrue(app.tabBars.buttons[title].exists, "\(language): \(title)") }
                XCTAssertFalse(app.buttons["today.counter"].label.contains("today.counter.accessibility"))
                assertHeader(in: app)
                capture("Langue-\(language)-Accueil")

                app.tabBars.buttons[tabs[1]].tap()
                let metric = app.buttons["statistics.metric.steps"]
                XCTAssertTrue(metric.waitForExistence(timeout: 5))
                XCTAssertTrue(metric.label.contains(steps), "\(language): \(metric.label)")
                capture("Langue-\(language)-Statistiques")
                app.tabBars.buttons[tabs[2]].tap()
                assertHeader(in: app)
                app.tabBars.buttons[tabs[3]].tap()
                assertHeader(in: app)
                app.tabBars.buttons[tabs[4]].tap()
                app.buttons["settings.subscription"].tap()
                XCTAssertTrue(app.navigationBars["Walkuno Premium"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.buttons[done].exists)
                capture("Langue-\(language)-Premium")
                app.buttons[done].firstMatch.tap()
                app.terminate()
            }
        }
    }

    func testUnsupportedLanguagesFallBackToEnglishAndRespectPreferenceOrder() {
        for languages in [["nl-NL"], ["zh-Hans-CN"], ["ko-KR", "sv-SE"]] {
            let app = launch(languages: languages, locale: "nl_NL")
            XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))
            for title in ["Today", "Statistics", "Explore", "Achievements", "Settings"] {
                XCTAssertTrue(app.tabBars.buttons[title].exists, languages.joined(separator: ","))
            }
            capture("Repli-anglais-\(languages[0])")
            app.terminate()
        }
        let app = launch(languages: ["nl-NL", "de-DE", "fr-FR"], locale: "nl_NL")
        XCTAssertTrue(app.tabBars.buttons["Heute"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.tabBars.buttons["Einstellungen"].exists)
        app.terminate()
    }

    func testLocalizedOnboardingAndEnglishFallback() {
        for (language, title, next) in [
            ("ja-JP", "一歩一歩が、\n力になる。", "続ける"),
            ("nl-NL", "Every step\ncounts.", "Continue")
        ] {
            let app = launch(demo: false, languages: [language], locale: language.replacingOccurrences(of: "-", with: "_"))
            XCTAssertTrue(app.buttons[next].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts[title].exists)
            capture("Langue-\(language)-Bienvenue")
            app.terminate()
        }
    }

    func testDashboardNavigationAndPremiumRemainOptional() {
        let app = launch()
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))
        capture("01-Tableau-de-bord")
        app.tabBars.buttons["Statistiques"].tap()
        XCTAssertTrue(app.buttons["statistics.metric.steps"].waitForExistence(timeout: 5))
        capture("02-Statistiques")
        trendPeriod(app).buttons["Année"].tap()
        XCTAssertTrue(app.navigationBars["Walkuno Premium"].waitForExistence(timeout: 5))
        app.buttons["Terminé"].firstMatch.tap()
        app.tabBars.buttons["Succès"].tap()
        XCTAssertTrue(app.staticTexts["Les belles étapes"].waitForExistence(timeout: 5))
        capture("03-Succes")
        app.tabBars.buttons["Aujourd’hui"].tap()
        XCTAssertTrue(app.buttons["today.counter"].exists)
    }

    func testGoalEditingAndReadOnlyPrivacy() {
        let app = launch()
        app.tabBars.buttons["Réglages"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Objectif quotidien")).firstMatch.tap()
        XCTAssertTrue(app.textFields["goal.input"].waitForExistence(timeout: 5))
        app.buttons["5 000"].firstMatch.tap()
        app.buttons["Enregistrer"].tap()
        app.swipeUp()
        app.buttons["Confidentialité"].tap()
        XCTAssertTrue(app.staticTexts["Vos pas vous appartiennent."].waitForExistence(timeout: 5))
        capture("04-Confidentialite")
    }

    func testHeaderStaysFixedAcrossTabsAndPresentedScreens() {
        let app = launch()
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))

        for tab in ["Aujourd’hui", "Statistiques", "Explorer", "Succès", "Réglages"] {
            app.tabBars.buttons[tab].tap()
            assertHeader(in: app)
            let initialY = app.buttons["app.account"].frame.minY
            app.swipeUp()
            app.swipeUp()
            assertHeader(in: app)
            XCTAssertEqual(app.buttons["app.account"].frame.minY, initialY, accuracy: 1)
            capture("Bandeau-\(tab)")
        }

        app.buttons["app.account"].tap()
        XCTAssertTrue(app.navigationBars["Mon compte"].waitForExistence(timeout: 5))
        assertHeader(in: app)
        capture("Bandeau-Compte")
        app.buttons["account.subscription"].tap()
        XCTAssertTrue(app.navigationBars["Walkuno Premium"].waitForExistence(timeout: 5))
        assertHeader(in: app)
        app.swipeUp()
        assertHeader(in: app)
        capture("Bandeau-Premium")
        app.navigationBars["Walkuno Premium"].buttons["Terminé"].tap()
        app.navigationBars["Mon compte"].buttons["Terminé"].tap()

        app.tabBars.buttons["Aujourd’hui"].tap()
        let counter = app.buttons["today.counter"]
        for _ in 0..<6 {
            if counter.isHittable { break }
            app.swipeDown()
        }
        counter.tap()
        assertHeader(in: app)
        capture("Bandeau-Detail")
    }

    func testScreenContentStartsBelowHeader() {
        let app = launch()
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))

        for (tab, firstContent) in [
            ("Aujourd’hui", app.staticTexts["Aperçu · données de démonstration"]),
            ("Statistiques", app.staticTexts["Mon jour"]),
            ("Explorer", app.segmentedControls["statistics.explorer.period"]),
            ("Succès", app.staticTexts["Records personnels"]),
            ("Réglages", app.buttons["settings.subscription"])
        ] {
            app.tabBars.buttons[tab].tap()
            assertBelowHeader(firstContent, in: app)
            capture("Contenu-sous-bandeau-\(tab)")
        }

        app.buttons["app.account"].tap()
        XCTAssertTrue(app.navigationBars["Mon compte"].waitForExistence(timeout: 5))
        assertBelowHeader(app.staticTexts["Votre espace Walkuno"], in: app)

        app.buttons["account.subscription"].tap()
        XCTAssertTrue(app.navigationBars["Walkuno Premium"].waitForExistence(timeout: 5))
        assertBelowHeader(app.staticTexts["Un peu plus loin.\nUn peu plus vous."], in: app)
        capture("Contenu-sous-bandeau-Premium")
        app.navigationBars["Walkuno Premium"].buttons["Terminé"].tap()
        app.navigationBars["Mon compte"].buttons["Terminé"].tap()

        let goal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Objectif quotidien")).firstMatch
        goal.tap()
        assertBelowHeader(app.textFields["goal.input"], in: app)
        capture("Contenu-sous-bandeau-Objectif")
        app.buttons["Annuler"].tap()
    }

    private func assertBelowHeader(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        let headers = app.descendants(matching: .any).matching(identifier: "app.header")
        let header = headers.allElementsBoundByIndex.first { $0.isHittable } ?? headers.firstMatch
        XCTAssertTrue(header.exists, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.minY, header.frame.maxY,
                                    "Content is covered by the fixed header: \(element.label)", file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    func testHeaderAccountOpensFromScrolledSettings() {
        let app = launch()
        app.tabBars.buttons["Réglages"].tap()
        let slider = app.sliders["settings.glass.transparency"]
        reveal(slider, in: app)
        slider.adjust(toNormalizedSliderPosition: 0.6)
        capture("Bandeau-Reglages-Avant-compte")
        app.buttons["app.account"].tap()
        XCTAssertTrue(app.navigationBars["Mon compte"].waitForExistence(timeout: 5))
    }

    func testGlassTransparencyUpdatesWhileHeaderRemainsAccessible() {
        let app = launch()
        app.tabBars.buttons["Réglages"].tap()
        let slider = app.sliders["settings.glass.transparency"]
        reveal(slider, in: app)
        for _ in 0..<3 {
            slider.adjust(toNormalizedSliderPosition: 0)
            if (slider.value as? String)?.filter(\.isNumber) == "0" { break }
        }
        XCTAssertEqual((slider.value as? String)?.filter(\.isNumber), "0")
        assertHeader(in: app)
        capture("Verre-Opaque")
        for _ in 0..<3 {
            slider.adjust(toNormalizedSliderPosition: 1)
            if (slider.value as? String)?.filter(\.isNumber) == "100" { break }
        }
        XCTAssertEqual((slider.value as? String)?.filter(\.isNumber), "100")
        assertHeader(in: app)
        capture("Verre-Transparent")
        app.buttons["app.account"].tap()
        XCTAssertTrue(app.navigationBars["Mon compte"].waitForExistence(timeout: 5))
        assertHeader(in: app)
        app.buttons["Terminé"].firstMatch.tap()
        XCTAssertEqual((slider.value as? String)?.filter(\.isNumber), "100")
        slider.adjust(toNormalizedSliderPosition: 0.6)
    }

    private func assertHeader(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        func visible(_ identifier: String) -> XCUIElement {
            let matches = app.descendants(matching: .any).matching(identifier: identifier)
            XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 5), file: file, line: line)
            return matches.allElementsBoundByIndex.first { $0.isHittable } ?? matches.firstMatch
        }
        let brand = visible("app.brand")
        let badge = visible("app.subscription")
        let account = visible("app.account")
        // SwiftUI Form insets can report no hit point; opening the account is verified by an actual tap.
        XCTAssertTrue(app.frame.contains(account.frame), file: file, line: line)
        XCTAssertGreaterThanOrEqual(badge.frame.minX, brand.frame.maxX, file: file, line: line)
        XCTAssertLessThan(badge.frame.maxX, account.frame.minX, file: file, line: line)
        XCTAssertEqual(badge.frame.midY, account.frame.midY, accuracy: 1, file: file, line: line)
        let headerFrame = brand.frame.union(badge.frame).union(account.frame)
        for button in app.navigationBars.buttons.allElementsBoundByIndex where button.isHittable {
            XCTAssertFalse(button.frame.intersects(headerFrame), "Navigation control overlaps the app header: \(button.label)", file: file, line: line)
        }
    }

    func testDevelopmentProPersistsAndUpdatesSubscriptionAccess() {
        let app = launch()

        func openDevelopmentSwitch() -> XCUIElement {
            app.tabBars.buttons["Réglages"].tap()
            app.buttons["settings.subscription"].tap()
            let toggle = app.switches["premium.development.pro"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            if !toggle.isHittable { app.swipeUp() }
            return toggle
        }

        let initialToggle = openDevelopmentSwitch()
        if initialToggle.value as? String == "1" { initialToggle.tap() }
        app.buttons["Terminé"].firstMatch.tap()
        app.tabBars.buttons["Aujourd’hui"].tap()
        XCTAssertEqual(app.staticTexts["app.subscription"].label, "Gratuit")
        XCTAssertTrue(app.descendants(matching: .any)["app.brand"].exists)
        capture("09-Accueil-Gratuit")

        openDevelopmentSwitch().tap()
        app.buttons["Terminé"].firstMatch.tap()
        app.tabBars.buttons["Aujourd’hui"].tap()
        XCTAssertEqual(app.staticTexts["app.subscription"].label, "Pro")
        capture("10-Accueil-Pro")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["app.subscription"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["app.subscription"].label, "Pro")
        app.tabBars.buttons["Statistiques"].tap()
        trendPeriod(app).buttons["Année"].tap()
        XCTAssertFalse(app.navigationBars["Walkuno Premium"].exists)
        trendPeriod(app).buttons["Semaine"].tap()

        let enabledToggle = openDevelopmentSwitch()
        XCTAssertEqual(enabledToggle.value as? String, "1")
        enabledToggle.tap()
        app.buttons["Terminé"].firstMatch.tap()
        app.tabBars.buttons["Aujourd’hui"].tap()
        XCTAssertEqual(app.staticTexts["app.subscription"].label, "Gratuit")
        app.tabBars.buttons["Statistiques"].tap()
        trendPeriod(app).buttons["Année"].tap()
        XCTAssertTrue(app.navigationBars["Walkuno Premium"].waitForExistence(timeout: 5))
        app.buttons["Terminé"].firstMatch.tap()
    }

    func testShareCardContainsOnlyChosenMetrics() {
        let app = launch()
        app.swipeUp()
        app.swipeUp()
        app.buttons["Partager"].firstMatch.tap()
        XCTAssertTrue(app.switches["Inclure la distance"].waitForExistence(timeout: 5))
        app.switches["Inclure la distance"].tap()
        capture("05-Carte-de-partage")
        app.buttons["Terminé"].firstMatch.tap()
        XCTAssertTrue(app.buttons["today.counter"].exists)
    }

    func testStatisticsInsightsMetricsRecordsAndYearHistory() {
        let app = launch()
        app.tabBars.buttons["Réglages"].tap()
        app.buttons["settings.subscription"].tap()
        let toggle = app.switches["premium.development.pro"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if !toggle.isHittable { app.swipeUp() }
        if toggle.value as? String != "1" { toggle.tap() }
        app.buttons["Terminé"].firstMatch.tap()
        app.tabBars.buttons["Statistiques"].tap()

        let steps = app.buttons["statistics.metric.steps"]
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        let metricY = steps.frame.minY
        assertBelowHeader(steps, in: app)
        capture("11-Statistiques-Mon-jour")
        for (id, title) in [("distance", "Distance"), ("exerciseTime", "Temps d’exercice"), ("floors", "Étages"), ("energy", "Énergie active")] {
            let button = app.buttons["statistics.metric." + id]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(button.isSelected)
            for card in ["day", "trends", "weekday", "record.year", "all.years"] {
                XCTAssertEqual(app.staticTexts["insights.header.insights." + card].value as? String, title)
            }
        }
        app.buttons["statistics.metric.distance"].tap()
        capture("12-Statistiques-Distance")

        trendPeriod(app).buttons["7 jours"].tap()
        capture("13-Statistiques-Tendances")
        let recordPeriod = app.segmentedControls["insights.record.period"]
        reveal(recordPeriod, in: app)
        recordPeriod.buttons["Année"].tap()
        capture("14-Statistiques-Record")
        let details = app.buttons["insights.record.details"]
        reveal(details, in: app)
        details.tap()
        capture("14b-Statistiques-Record-Details")
        let historyMode = app.segmentedControls["insights.history.mode"]
        reveal(historyMode, in: app)
        historyMode.buttons["Totaux"].tap()
        capture("15-Statistiques-Historique-Totaux")
        historyMode.buttons["Moyennes"].tap()
        capture("16-Statistiques-Historique-Moyennes")

        XCTAssertTrue(steps.isHittable)
        XCTAssertEqual(steps.frame.minY, metricY, accuracy: 1)
        assertHeader(in: app)
        steps.tap()
        XCTAssertEqual(app.staticTexts["insights.header.insights.all.years"].value as? String, "Pas")
        XCTAssertFalse(app.segmentedControls["statistics.explorer.period"].exists)
        capture("16b-Statistiques-Menu-fixe")
        app.buttons["app.account"].tap()
        XCTAssertTrue(app.navigationBars["Mon compte"].waitForExistence(timeout: 5))
        app.buttons["Terminé"].firstMatch.tap()

        app.tabBars.buttons["Explorer"].tap()
        let explorer = app.segmentedControls["statistics.explorer.period"]
        XCTAssertTrue(explorer.waitForExistence(timeout: 5))
        explorer.buttons["Année"].tap()
        XCTAssertFalse(app.navigationBars["Walkuno Premium"].exists)

        app.tabBars.buttons["Réglages"].tap()
        app.buttons["settings.subscription"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if !toggle.isHittable { app.swipeUp() }
        if toggle.value as? String == "1" { toggle.tap() }
        app.buttons["Terminé"].firstMatch.tap()
    }

    func testExplorerPeriodsAndMonthCapitalization() {
        let app = launch(pro: true)
        app.tabBars.buttons["Statistiques"].tap()
        XCTAssertFalse(app.segmentedControls["statistics.explorer.period"].exists)
        app.tabBars.buttons["Explorer"].tap()
        let picker = app.segmentedControls["statistics.explorer.period"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        assertBelowHeader(picker, in: app)
        let title = app.staticTexts["explorer.period.title"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")

        picker.buttons["Mois"].tap()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        let month = formatter.string(from: .now)
        XCTAssertEqual(title.label, month.prefix(1).uppercased() + month.dropFirst())
        capture("Explorer-Mois")

        picker.buttons["Jour"].tap()
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        XCTAssertEqual(title.label, formatter.string(from: .now))

        picker.buttons["Année"].tap()
        let bestMonth = app.staticTexts["explorer.best.month"]
        reveal(bestMonth, in: app)
        let monthName = bestMonth.label.replacingOccurrences(of: "Meilleur mois, ", with: "")
        XCTAssertNotEqual(monthName, "—")
        XCTAssertEqual(String(monthName.prefix(1)), monthName.prefix(1).uppercased())
        XCTAssertEqual(String(monthName.dropFirst()), monthName.dropFirst().lowercased())
        capture("Explorer-Annee-Meilleur-mois")
        picker.buttons["Mois"].tap()
        let calendarDay = app.buttons["explorer.calendar.day.\(Calendar.current.component(.day, from: .now))"]
        app.swipeUp()
        reveal(calendarDay, in: app)
        calendarDay.tap()
        XCTAssertTrue(app.navigationBars[formatter.string(from: .now)].waitForExistence(timeout: 5))
        app.buttons["Terminé"].firstMatch.tap()
    }

    func testExplorerHourlyTotalsPeriodHighlightsAndAdaptiveCalendars() {
        let app = launch(pro: true)
        app.tabBars.buttons["Explorer"].tap()
        let picker = app.segmentedControls["statistics.explorer.period"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        picker.buttons["Jour"].tap()
        XCTAssertTrue(app.staticTexts["explorer.day.total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["explorer.day.total"].label.filter(\.isNumber), "6432")
        XCTAssertTrue(app.descendants(matching: .any)["explorer.day.hourly"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Objectif quotidien"].exists)
        capture("Explorer-Jour-Total-Echelle")

        for period in ["Semaine", "Mois", "Année"] {
            picker.buttons[period].tap()
            let floors = app.descendants(matching: .any)["explorer.total.floors"].firstMatch
            reveal(floors, in: app)
            XCTAssertTrue(floors.exists)
            XCTAssertTrue(app.descendants(matching: .any)["explorer.total.energy"].firstMatch.exists)
            XCTAssertTrue(app.descendants(matching: .any)["explorer.total.exercise"].firstMatch.exists)
            let best = app.descendants(matching: .any)["explorer.best.day"].firstMatch
            XCTAssertTrue(best.exists)
            capture("Explorer-\(period)-Cumuls")
            if period == "Semaine" {
                let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explorer.calendar.day.")).firstMatch
                reveal(first, in: app)
                let cells = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explorer.calendar.day."))
                XCTAssertEqual(cells.count, 7)
                XCTAssertTrue(cells.element(boundBy: 0).label.hasPrefix("lundi"))
                XCTAssertTrue(cells.element(boundBy: 6).label.hasPrefix("dimanche"))
                XCTAssertEqual(cells.element(boundBy: 0).frame.minY, cells.element(boundBy: 6).frame.minY, accuracy: 1)
                capture("Explorer-Semaine-Lundi-Dimanche")
            } else if period == "Année" {
                let january = app.buttons["explorer.calendar.month.1"]
                reveal(january, in: app)
                XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explorer.calendar.month.")).count, 12)
                XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explorer.calendar.day.")).count, 0)
                capture("Explorer-Annee-Douze-Mois")
                january.tap()
                XCTAssertTrue(picker.buttons["Mois"].isSelected)
                XCTAssertTrue(app.staticTexts["explorer.period.title"].label.hasPrefix("Janvier"))
            }
        }
    }

    func testExplorerPinsGlassControlsAndSwipesEveryPeriod() {
        let app = launch(pro: true)
        app.tabBars.buttons["Explorer"].tap()
        let picker = app.segmentedControls["statistics.explorer.period"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Explorer une période"].exists)
        let title = app.staticTexts["explorer.period.title"]
        let scroll = app.scrollViews["explorer.scroll"]
        let pickerY = picker.frame.minY
        let titleY = title.frame.minY

        for period in ["Jour", "Semaine", "Mois", "Année"] {
            picker.buttons[period].tap()
            let original = title.label
            XCTAssertFalse(app.buttons["explorer.next"].isEnabled)
            // Begin over the widgets, including the chart, rather than the pinned controls.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
                .press(forDuration: 0.01, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.3)))
            waitForExplorerTitle(title, predicate: NSPredicate(format: "label != %@", original))
            XCTAssertTrue(app.buttons["explorer.next"].isEnabled)
            let previous = title.label
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.3))
                .press(forDuration: 0.01, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)))
            waitForExplorerTitle(title, predicate: NSPredicate(format: "label == %@", original))
            XCTAssertNotEqual(title.label, previous)
            XCTAssertFalse(app.buttons["explorer.next"].isEnabled)
            scroll.swipeUp()
            XCTAssertEqual(picker.frame.minY, pickerY, accuracy: 1)
            XCTAssertEqual(title.frame.minY, titleY, accuracy: 1)
            XCTAssertTrue(picker.isHittable)
            app.buttons["explorer.previous"].tap()
            waitForExplorerTitle(title, predicate: NSPredicate(format: "label != %@", original))
            app.buttons["explorer.next"].tap()
            waitForExplorerTitle(title, predicate: NSPredicate(format: "label == %@", original))
            capture("Explorer-Fixe-\(period)")
            // Swipe again with the widgets already scrolled beneath the glass.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
                .press(forDuration: 0.01, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
            waitForExplorerTitle(title, predicate: NSPredicate(format: "label != %@", original))
            app.buttons["explorer.next"].tap()
            waitForExplorerTitle(title, predicate: NSPredicate(format: "label == %@", original))
        }
    }

    private func waitForExplorerTitle(_ title: XCUIElement, predicate: NSPredicate, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: title)], timeout: 3),
                       .completed, file: file, line: line)
    }

    func testExplorerCancelledSwipeAndFutureBoundary() {
        let app = launch(pro: true)
        app.tabBars.buttons["Explorer"].tap()
        let title = app.staticTexts["explorer.period.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let original = title.label
        let scroll = app.scrollViews["explorer.scroll"]
        let middle = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        middle.press(forDuration: 0.01, thenDragTo: middle.withOffset(CGVector(dx: 25, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertEqual(title.label, original)
        scroll.swipeLeft()
        XCTAssertEqual(title.label, original)
        XCTAssertFalse(app.buttons["explorer.next"].isEnabled)
        XCTAssertFalse(app.navigationBars["Walkuno Premium"].exists)
    }

    func testExplorerKeepsFreeHistoryAndYearGates() {
        let app = launch(pro: false)
        app.tabBars.buttons["Explorer"].tap()
        let picker = app.segmentedControls["statistics.explorer.period"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Année"].tap()
        XCTAssertTrue(app.navigationBars["Walkuno Premium"].waitForExistence(timeout: 5))
        app.buttons["Terminé"].firstMatch.tap()
        XCTAssertTrue(picker.buttons["Semaine"].isSelected)
        picker.buttons["Mois"].tap()
        for _ in 0..<2 {
            if app.navigationBars["Walkuno Premium"].exists { break }
            let title = app.staticTexts["explorer.period.title"]
            let before = title.label
            app.buttons["Période précédente"].tap()
            let landedOrLocked = NSPredicate { _, _ in
                title.label != before || app.navigationBars["Walkuno Premium"].exists
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: landedOrLocked, object: nil)], timeout: 3), .completed)
        }
        XCTAssertTrue(app.navigationBars["Walkuno Premium"].waitForExistence(timeout: 5))
        app.buttons["Terminé"].firstMatch.tap()
    }

    func testTrophiesRecordsGoalsStreaksAndJourneyCollection() {
        let app = launch(pro: false)
        app.tabBars.buttons["Succès"].tap()
        XCTAssertTrue(app.staticTexts["Records personnels"].waitForExistence(timeout: 10))
        for metric in ["steps", "energy", "distance", "exerciseTime", "floors"] {
            XCTAssertTrue(app.descendants(matching: .any)["trophies.record.\(metric)"].firstMatch.exists)
        }
        capture("Trophees-Records")
        let goal = app.descendants(matching: .any)["trophies.goal.1"].firstMatch
        reveal(goal, in: app)
        XCTAssertTrue(goal.label.contains("fois"))
        XCTAssertTrue(goal.label.contains("8"))
        capture("Trophees-Objectifs")
        let perfect = app.descendants(matching: .any)["trophies.perfect.year"].firstMatch
        reveal(perfect, in: app)
        XCTAssertTrue(perfect.label.contains("Année parfaite"))
        capture("Trophees-Periodes-parfaites")
        let goalHeight = goal.frame.height
        for id in ["goal.1", "goal.2", "goal.3", "perfect.week", "perfect.month", "perfect.year"] {
            let card = app.descendants(matching: .any)["trophies.\(id)"].firstMatch
            reveal(card, in: app)
            XCTAssertEqual(card.frame.height, goalHeight, accuracy: 1, "Hauteur de \(id)")
        }
        let streak = app.descendants(matching: .any)["trophies.streak.30"].firstMatch
        reveal(streak, in: app)
        XCTAssertTrue(streak.label.contains("30 jours d’affilée"))
        XCTAssertFalse(app.descendants(matching: .any)["trophies.streak.60"].exists)
        capture("Trophees-Series")
        let track = app.descendants(matching: .any)["trophies.journey.track"].firstMatch
        reveal(track, in: app)
        XCTAssertTrue(track.label.contains("fois"))
        capture("Trophees-Traversees")
        let collection = app.buttons["trophies.collection"]
        reveal(collection, in: app)
        XCTAssertTrue(collection.label.contains("18"))
        collection.tap()
        let earth = app.descendants(matching: .any)["trophies.journey.earth"].firstMatch
        reveal(earth, in: app)
        XCTAssertTrue(earth.label.contains("Terre"))
        capture("Trophees-Terre")
        let sun = app.descendants(matching: .any)["trophies.journey.sun"].firstMatch
        reveal(sun, in: app)
        XCTAssertTrue(sun.label.contains("Soleil"))
        capture("Trophees-Espace")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<32 {
            let navigationBar = app.navigationBars.firstMatch
            let top = navigationBar.exists ? navigationBar.frame.maxY + 8 : app.frame.height * 0.2
            let tabBar = app.tabBars.firstMatch
            let bottom = tabBar.exists ? tabBar.frame.minY - 8 : app.frame.height * 0.9
            if element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            // Drag in the margin so chart selection does not capture the scroll gesture.
            let scrollDown = element.exists && element.frame.minY < top
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: scrollDown ? 0.48 : 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: scrollDown ? 0.72 : 0.48))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(element.isHittable)
    }

    private func trendPeriod(_ app: XCUIApplication) -> XCUIElement {
        let picker = app.segmentedControls["insights.trend.period"]
        reveal(picker, in: app)
        return picker
    }

    private func assertHomePeriodPickerIsVisible(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let header = app.descendants(matching: .any)["app.header"]
        let picker = app.segmentedControls["today.period"]
        XCTAssertTrue(header.exists, file: file, line: line)
        XCTAssertTrue(picker.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertGreaterThanOrEqual(picker.frame.minY, header.frame.maxY, file: file, line: line)
        for period in ["Jour", "Semaine", "Mois", "Année"] {
            XCTAssertTrue(picker.buttons[period].isHittable, file: file, line: line)
        }
    }

    func testTabTitlesAndHomePeriodPickerLayout() {
        let app = launch()
        assertHomePeriodPickerIsVisible(in: app)
        let picker = app.segmentedControls["today.period"]
        for period in ["Semaine", "Mois", "Jour"] {
            let segment = picker.buttons[period]
            segment.tap()
            XCTAssertTrue(segment.isSelected)
        }
        for tab in ["Statistiques", "Explorer", "Succès", "Réglages"] {
            let button = app.tabBars.buttons[tab]
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertFalse(app.navigationBars[tab].exists)
        }
        app.tabBars.buttons["Aujourd’hui"].tap()
        assertHomePeriodPickerIsVisible(in: app)
    }

    func testOnboardingWorksWithoutHealthOrPayment() {
        let app = launch(demo: false)
        XCTAssertTrue(app.buttons["Continuer"].waitForExistence(timeout: 10))
        assertHeader(in: app)
        assertBelowHeader(app.staticTexts["1 / 4"], in: app)
        capture("06-Accueil")
        reveal(app.buttons["Continuer"], in: app)
        app.buttons["Continuer"].tap()
        app.swipeUp()
        app.buttons["Continuer sans connecter Santé"].tap()
        app.swipeUp()
        app.buttons["Continuer"].tap()
        app.swipeUp()
        app.buttons["C’est parti"].tap()
        assertHomePeriodPickerIsVisible(in: app)
        assertBelowHeader(app.segmentedControls["today.period"], in: app)
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Votre activité, bientôt ici"].exists)
        capture("07-Sans-donnees")
        app.tabBars.buttons["Statistiques"].tap()
        XCTAssertTrue(app.staticTexts["La comparaison apparaîtra lorsque des mesures horaires seront disponibles à la même heure sur les journées récentes."].waitForExistence(timeout: 5))
        capture("08-Statistiques-Sans-donnees")
        app.tabBars.buttons["Réglages"].tap()
        let periodAnimations = app.switches["settings.period.animations"]
        reveal(periodAnimations, in: app)
        XCTAssertEqual(periodAnimations.value as? String, "0")
        periodAnimations.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(periodAnimations.value as? String, "1")
        let transparency = app.sliders["settings.glass.transparency"]
        reveal(transparency, in: app)
        transparency.adjust(toNormalizedSliderPosition: 0.35)
        let savedTransparency = transparency.value as? String
        XCTAssertNotNil(savedTransparency)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 10))
        assertBelowHeader(app.segmentedControls["today.period"], in: app)
        app.tabBars.buttons["Réglages"].tap()
        reveal(periodAnimations, in: app)
        XCTAssertEqual(periodAnimations.value as? String, "1")
        reveal(transparency, in: app)
        XCTAssertEqual(transparency.value as? String, savedTransparency)
        capture("Verre-Preference-Conservee")
        // Restore a fresh install state for a later test run.
        app.swipeUp(); app.swipeUp()
        app.buttons["Effacer les données locales"].tap()
        app.buttons["Effacer et recommencer"].tap()
        XCTAssertTrue(app.buttons["Continuer"].waitForExistence(timeout: 5))
    }

    func testHomeNavigationWithPeriodAnimationsEnabledAndDisabled() {
        let app = launch(pro: true)
        let counter = app.buttons["today.counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        for enabled in [true, false] {
            app.tabBars.buttons["Réglages"].tap()
            let toggle = app.switches["settings.period.animations"]
            reveal(toggle, in: app)
            if (toggle.value as? String) != (enabled ? "1" : "0") {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
            capture(enabled ? "Animation-periodes-Activee" : "Animation-periodes-Desactivee")
            app.tabBars.buttons["Aujourd’hui"].tap()
            let picker = app.segmentedControls["today.period"]
            for period in ["Jour", "Semaine", "Mois", "Année"] {
                picker.buttons[period].tap()
                let currentDate = app.staticTexts["today.date"].label
                counter.swipeRight()
                XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 4))
                XCTAssertNotEqual(app.staticTexts["today.date"].label, currentDate)
                XCTAssertTrue(app.buttons["today.next"].isEnabled)
                XCTAssertFalse(app.sheets.firstMatch.exists)
                capture("Cercle-\(period)-Animation-\(enabled)")
                counter.swipeLeft()
                XCTAssertTrue(app.buttons["today.current"].waitForNonExistence(timeout: 4))
                XCTAssertEqual(app.staticTexts["today.date"].label, currentDate)
                XCTAssertFalse(app.buttons["today.next"].isEnabled)
            }
        }
    }

    func testHomeSwipesAndChangesPeriod() {
        let app = launch()
        let counter = app.buttons["today.counter"]
        let next = app.buttons["today.next"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        let todayValue = counter.label
        XCTAssertFalse(todayValue.isEmpty)
        capture("15-Accueil-Compact")
        XCTAssertFalse(next.isEnabled)
        counter.swipeLeft()
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertFalse(app.buttons["today.current"].exists)
        XCTAssertFalse(next.isEnabled)
        XCTAssertEqual(counter.label, todayValue)
        counter.swipeRight()
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 3))
        XCTAssertTrue(counter.isHittable)
        XCTAssertTrue(next.isEnabled)
        XCTAssertNotEqual(counter.label, todayValue)
        capture("11-Accueil-Hier")
        counter.swipeLeft()
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertTrue(app.buttons["today.current"].waitForNonExistence(timeout: 4))
        XCTAssertFalse(next.isEnabled)
        XCTAssertEqual(counter.label, todayValue)

        let picker = app.segmentedControls["today.period"]
        picker.buttons["Semaine"].tap()
        XCTAssertNotEqual(counter.label, todayValue)
        XCTAssertTrue(app.staticTexts["Moyenne par jour"].exists)
        // Capture the settled total rather than a frame in the two-second count-up animation.
        Thread.sleep(forTimeInterval: 2.2)
        capture("12-Accueil-Semaine")
        counter.swipeRight()
        XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 4))
        XCTAssertTrue(next.isEnabled)
        app.buttons["today.current"].tap()
        XCTAssertFalse(next.isEnabled)
        picker.buttons["Mois"].tap()
        Thread.sleep(forTimeInterval: 2.2)
        capture("13-Accueil-Mois")
        counter.swipeRight()
        XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 4))
        XCTAssertTrue(next.isEnabled)
        counter.swipeLeft()
        XCTAssertTrue(app.buttons["today.current"].waitForNonExistence(timeout: 4))
        XCTAssertFalse(next.isEnabled)
        picker.buttons["Jour"].tap()
        XCTAssertEqual(counter.label, todayValue)
    }

    func testHomeSevenDayChartSelectsEveryDayAndKeepsItsWindow() {
        let app = launch()
        let counter = app.buttons["today.counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 15))
        let todayValue = counter.label
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        let expectedSteps = [12_773, 10_006, 7_239, 4_472, 11_905, 9_138, 6_432]
        let average = app.staticTexts["today.trend.average"]
        reveal(average, in: app)
        XCTAssertEqual(average.label, "Moyenne : " + formatter.string(from: 8_852)!)
        XCTAssertTrue(app.staticTexts["today.trend.goal"].label.hasPrefix("Objectif : "))
        capture("Accueil-Sept-jours-Moyenne")

        let today = Calendar.current.startOfDay(for: .now)
        for index in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: index - 6, to: today)!
            let button = app.buttons["today.trend.day.\(index)"]
            XCTAssertTrue(button.exists)
            let expectedDate = day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
            XCTAssertEqual(button.label, expectedDate)
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertTrue(counter.label.contains(formatter.string(from: NSNumber(value: expectedSteps[index]))!))
            XCTAssertEqual(average.label, "Moyenne : " + formatter.string(from: 8_852)!)
            XCTAssertEqual(app.buttons["today.next"].isEnabled, index < 6)
            XCTAssertFalse(app.sheets.firstMatch.exists)
        }
        XCTAssertEqual(counter.label, todayValue)
        capture("Accueil-Sept-jours-Aujourd-hui")
    }

    func testHomeDailyRhythmShowsFullDayAndPreviousDayComparison() {
        let app = launch()
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))
        let chart = app.descendants(matching: .any)["today.rhythm.chart"].firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.exists)
        XCTAssertEqual(chart.label, "Activité de 0 à 24 heures, avec la veille en barres grises côte à côte")
        for hour in 0..<24 {
            XCTAssertTrue(app.staticTexts["today.rhythm.hour.\(hour)"].exists)
        }
        XCTAssertTrue(app.staticTexts["today.rhythm.previous"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["today.rhythm.now"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Données de la veille indisponibles"].exists)
        capture("Accueil-Rythme-24-heures")

        for _ in 0..<6 {
            if app.buttons["today.previous"].isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(app.buttons["today.previous"].isHittable)
        app.buttons["today.previous"].tap()
        XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 4))
        reveal(chart, in: app)
        XCTAssertTrue(chart.exists)
        XCTAssertTrue(app.staticTexts["today.rhythm.previous"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["today.rhythm.now"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Données de la veille indisponibles"].exists)
        capture("Accueil-Rythme-Jour-selectionne")
    }

    func testHomeTrendKeepsCompactHeaderAcrossCalendarPeriods() {
        let app = launch(pro: true)
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))
        let picker = app.segmentedControls["today.period"]
        var initialChartHeight: CGFloat?
        for period in ["Jour", "Semaine", "Mois", "Année"] {
            picker.buttons[period].tap()
            let title = app.staticTexts["today.trend.title"]
            reveal(title, in: app)
            let goal = app.staticTexts["today.trend.goal"]
            let average = app.staticTexts["today.trend.average"]
            XCTAssertTrue(title.exists)
            XCTAssertTrue(goal.exists)
            XCTAssertTrue(average.exists)
            XCTAssertEqual(title.frame.maxY, goal.frame.maxY, accuracy: 3)
            XCTAssertEqual(goal.frame.maxY, average.frame.maxY, accuracy: 3)
            XCTAssertLessThanOrEqual(title.frame.maxX, goal.frame.minX)
            XCTAssertLessThanOrEqual(goal.frame.maxX, average.frame.minX)
            let chart = app.descendants(matching: .any)["today.trend.chart"].firstMatch
            XCTAssertTrue(chart.exists)
            if let initialChartHeight {
                XCTAssertEqual(chart.frame.height, initialChartHeight, accuracy: 1)
            } else { initialChartHeight = chart.frame.height }
            capture("Tendance-" + period)
        }
        app.terminate()

        let german = launch(languages: ["de"], locale: "de_DE", pro: true)
        XCTAssertTrue(german.buttons["today.counter"].waitForExistence(timeout: 15))
        for period in ["Tag", "Jahr"] {
            let picker = german.segmentedControls["today.period"]
            picker.buttons[period].tap()
            let title = german.staticTexts["today.trend.title"]
            reveal(title, in: german)
            let average = german.staticTexts["today.trend.average"]
            XCTAssertEqual(title.frame.maxY, average.frame.maxY, accuracy: 3)
            capture("Tendance-DE-" + period)
        }
    }

    func testHomeAnnualPeriodAndSharing() {
        let app = launch()
        app.tabBars.buttons["Réglages"].tap()
        app.buttons["settings.subscription"].tap()
        let toggle = app.switches["premium.development.pro"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        reveal(toggle, in: app)
        if toggle.value as? String == "1" { toggle.tap() }
        app.buttons["Terminé"].firstMatch.tap()
        app.tabBars.buttons["Aujourd’hui"].tap()

        let picker = app.segmentedControls["today.period"]
        picker.buttons["Année"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        reveal(toggle, in: app)
        toggle.tap()
        app.buttons["Terminé"].firstMatch.tap()
        XCTAssertTrue(picker.buttons["Jour"].isSelected)
        picker.buttons["Année"].tap()
        XCTAssertTrue(picker.buttons["Année"].isSelected)

        let counter = app.buttons["today.counter"]
        let currentYear = Date.now.formatted(.dateTime.year())
        XCTAssertEqual(app.staticTexts["today.date"].label, currentYear)
        XCTAssertFalse(app.buttons["today.next"].isEnabled)
        counter.swipeRight()
        let previousYear = Calendar.current.date(byAdding: .year, value: -1, to: .now)!.formatted(.dateTime.year())
        XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["today.date"].label, previousYear)
        XCTAssertTrue(app.buttons["today.next"].isEnabled)
        let selectedYearCounter = counter.label
        capture("16-Accueil-Annee")
        let comparison = app.staticTexts["Par rapport à l’année précédente"]
        reveal(comparison, in: app)
        XCTAssertTrue(comparison.exists)
        let share = app.buttons["Partager"].firstMatch
        reveal(share, in: app)
        share.tap()
        XCTAssertTrue(app.switches["Inclure la distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mon année"].exists)
        XCTAssertEqual(app.staticTexts["share.date"].label, previousYear)
        let sharedSteps = app.staticTexts["share.steps"].label
        XCTAssertNotEqual(sharedSteps, "—")
        XCTAssertTrue(selectedYearCounter.contains("\(sharedSteps) pas sur"))
        capture("17-Partage-Annee")
        app.buttons["Terminé"].firstMatch.tap()

        reveal(picker, in: app)
        counter.swipeLeft()
        XCTAssertTrue(app.buttons["today.current"].waitForNonExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["today.date"].label, currentYear)
        XCTAssertFalse(app.buttons["today.next"].isEnabled)
        app.tabBars.buttons["Réglages"].tap()
        app.buttons["settings.subscription"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        reveal(toggle, in: app)
        toggle.tap()
        app.buttons["Terminé"].firstMatch.tap()
        app.tabBars.buttons["Aujourd’hui"].tap()
        XCTAssertTrue(picker.buttons["Jour"].isSelected)
    }

    func testHomeShortDragsDoNotOpenDetail() {
        let app = launch()
        let counter = app.buttons["today.counter"]
        let next = app.buttons["today.next"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        let todayValue = counter.label

        for velocity in [XCUIGestureVelocity.slow, .fast] {
            let right = counter.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
            let left = counter.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
            left.press(forDuration: 0.05, thenDragTo: right, withVelocity: velocity, thenHoldForDuration: 0)
            XCTAssertFalse(app.sheets.firstMatch.exists)
            XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 3))
            XCTAssertTrue(next.isEnabled)
            XCTAssertNotEqual(counter.label, todayValue)

            right.press(forDuration: 0.05, thenDragTo: left, withVelocity: velocity, thenHoldForDuration: 0)
            XCTAssertFalse(app.sheets.firstMatch.exists)
            XCTAssertTrue(app.buttons["today.current"].waitForNonExistence(timeout: 3))
            XCTAssertFalse(next.isEnabled)
            XCTAssertEqual(counter.label, todayValue)
        }
    }

    func testHomeCounterKeepsVerticalScrollingAndTapToDetail() {
        let app = launch()
        let counter = app.buttons["today.counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        let todayValue = counter.label
        let initialY = counter.frame.minY
        let top = counter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let bottom = counter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        bottom.press(forDuration: 0.05, thenDragTo: top, withVelocity: .slow, thenHoldForDuration: 0)

        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertEqual(counter.label, todayValue)
        XCTAssertFalse(app.buttons["today.current"].exists)
        XCTAssertLessThan(counter.frame.minY, initialY - 40)

        app.scrollViews.firstMatch.swipeDown()
        XCTAssertTrue(counter.isHittable)
        counter.tap()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        XCTAssertTrue(app.navigationBars[formatter.string(from: .now)].waitForExistence(timeout: 5))
    }

    func testHomeOpensAndSharesSelectedDay() {
        let app = launch()
        let counter = app.buttons["today.counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        counter.swipeRight()
        XCTAssertTrue(app.buttons["today.current"].waitForExistence(timeout: 4))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        counter.tap()
        XCTAssertTrue(app.navigationBars[formatter.string(from: yesterday)].waitForExistence(timeout: 5))
        app.buttons["Terminé"].firstMatch.tap()
        app.swipeUp(); app.swipeUp()
        app.buttons["Partager"].firstMatch.tap()
        XCTAssertTrue(app.switches["Inclure la distance"].waitForExistence(timeout: 5))
        formatter.dateStyle = .long
        XCTAssertTrue(app.staticTexts[formatter.string(from: yesterday)].exists)
        capture("14-Partage-Jour-selectionne")
    }

    func testThemeUpdatesBrandAndHomeIcon() {
        let app = XCUIApplication()
        app.launchArguments = ["-development.proEnabled", "YES",
                               "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func dismissIconConfirmation() {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 3) {
                alert.buttons.firstMatch.tap()
            }
        }
        if app.buttons["Continuer"].waitForExistence(timeout: 5) {
            reveal(app.buttons["Continuer"], in: app)
            app.buttons["Continuer"].tap()
            app.swipeUp()
            app.buttons["Continuer sans connecter Santé"].tap()
            app.swipeUp()
            app.buttons["Continuer"].tap()
            app.swipeUp()
            app.buttons["C’est parti"].tap()
        }
        XCTAssertTrue(app.buttons["today.counter"].waitForExistence(timeout: 15))
        dismissIconConfirmation()
        app.tabBars.buttons["Réglages"].tap()
        app.buttons["settings.palette"].tap()
        for theme in ["coral", "violet"] {
            app.buttons["theme." + theme].tap()
            dismissIconConfirmation()
            XCTAssertTrue(app.buttons["theme." + theme].isSelected)
            XCTAssertFalse(app.alerts["Icône de l’application"].exists)
            capture("Palette-" + theme)
        }
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["app.account"].waitForExistence(timeout: 10))
        dismissIconConfirmation()
        app.tabBars.buttons["Réglages"].tap()
        app.buttons["settings.palette"].tap()
        XCTAssertTrue(app.buttons["theme.violet"].isSelected)
        app.buttons["theme.mint"].tap()
        dismissIconConfirmation()
        XCTAssertTrue(app.buttons["theme.mint"].isSelected)
        XCTAssertFalse(app.alerts["Icône de l’application"].exists)
        capture("Palette-retour-Grande-foulee")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

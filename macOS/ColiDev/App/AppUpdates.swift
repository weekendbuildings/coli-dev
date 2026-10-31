import Foundation
import Combine
import SwiftUI
import Sparkle

struct GitHubRelease: Decodable, Identifiable {
    struct Asset: Decodable, Identifiable {
        let id: Int
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case browserDownloadURL = "browser_download_url"
        }

        var isTrustedColiDevArchive: Bool {
            guard let host = browserDownloadURL.host?.lowercased() else { return false }
            return browserDownloadURL.scheme == "https"
                && host == "github.com"
                && browserDownloadURL.path.hasPrefix("/weekendbuildings/coli-dev/releases/download/")
        }
    }

    let id: Int
    let name: String?
    let tagName: String
    let body: String?
    let publishedAt: Date?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tagName = "tag_name"
        case body
        case publishedAt = "published_at"
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }

    var currentArchitectureAsset: Asset? {
        let suffix: String
        #if arch(arm64)
        suffix = "AppleSilicon.zip"
        #elseif arch(x86_64)
        suffix = "Intel.zip"
        #else
        return nil
        #endif

        return assets.first { $0.name.hasSuffix(suffix) && $0.isTrustedColiDevArchive }
    }

    var trustedReleasePageURL: URL? {
        guard htmlURL.scheme == "https",
              htmlURL.host?.lowercased() == "github.com",
              htmlURL.path.hasPrefix("/weekendbuildings/coli-dev/releases/") else { return nil }
        return htmlURL
    }
}

@MainActor
final class ReleaseCatalog: ObservableObject {
    @Published private(set) var releases: [GitHubRelease] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var lastUpdated: Date?

    private let endpoint = URL(string: "https://api.github.com/repos/weekendbuildings/coli-dev/releases")!

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // UI tests supply a fixed release list: CI runners share IPs and hit the unauthenticated GitHub API rate limit.
            if let fixture = ProcessInfo.processInfo.environment["COLIDEV_UI_TEST_RELEASES_JSON"] {
                releases = try decoder.decode([GitHubRelease].self, from: Data(fixture.utf8)).filter { !$0.draft }
                lastUpdated = Date()
                return
            }

            var allReleases: [GitHubRelease] = []
            var page = 1

            repeat {
                var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(name: "per_page", value: "100"),
                    URLQueryItem(name: "page", value: String(page))
                ]
                var request = URLRequest(url: components.url!)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("ColiDev macOS app updater", forHTTPHeaderField: "User-Agent")
                request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                allReleases.append(contentsOf: try decoder.decode([GitHubRelease].self, from: data))

                let hasNextPage = response.value(forHTTPHeaderField: "Link")?
                    .contains("rel=\"next\"") == true
                guard hasNextPage, page < 50 else { break }
                page += 1
            } while true

            releases = allReleases.filter { !$0.draft }
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }
}

@MainActor
final class AppUpdateController: ObservableObject {
    @Published private(set) var isConfigured: Bool
    @Published private(set) var canCheckForUpdates = false
    @Published var automaticChecksEnabled: Bool {
        didSet {
            guard isConfigured else { return }
            controller?.updater.automaticallyChecksForUpdates = automaticChecksEnabled
        }
    }

    private let controller: SPUStandardUpdaterController?

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let key = info["SUPublicEDKey"] as? String ?? ""
        let feed = info["SUFeedURL"] as? String ?? ""
        let hasValidPublicKey = Data(base64Encoded: key)?.count == 32
        let hasHTTPSFeed = URL(string: feed)?.scheme == "https"
        let updaterIsConfigured = hasValidPublicKey && hasHTTPSFeed
        isConfigured = updaterIsConfigured

        guard updaterIsConfigured else {
            controller = nil
            automaticChecksEnabled = false
            return
        }

        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller = updaterController
        automaticChecksEnabled = updaterController.updater.automaticallyChecksForUpdates
        updaterController.updater.automaticallyDownloadsUpdates = false
        updaterController.updater.sendsSystemProfile = false
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        guard isConfigured, canCheckForUpdates else { return }
        controller?.checkForUpdates(nil)
    }
}

struct UpdatesSettingsSection: View {
    let language: AppLanguage
    @EnvironmentObject private var updater: AppUpdateController
    @StateObject private var catalog = ReleaseCatalog()
    @State private var expandedReleaseIDs: Set<Int> = []

    private var locale: Locale {
        Locale(identifier: language == .ru ? "ru_RU" : "en_US")
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent(title, value: installedVersion)

                if updater.isConfigured {
                    Toggle(autoUpdateTitle, isOn: $updater.automaticChecksEnabled)
                        .accessibilityIdentifier("settings.updates.auto-toggle")
                    Button(checkUpdatesTitle, action: updater.checkForUpdates)
                        .disabled(!updater.canCheckForUpdates)
                        .accessibilityIdentifier("settings.updates.check")
                } else {
                    Label(autoUpdateUnavailable, systemImage: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.updates.auto-unavailable")
                    Text(autoUpdateSetup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(historyTitle).font(.headline)
                    Spacer()
                    Button(action: { Task { await catalog.refresh() } }) {
                        if catalog.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(refreshTitle, systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(catalog.isLoading)
                    .accessibilityIdentifier("settings.updates.refresh")
                }

                if let error = catalog.error, catalog.releases.isEmpty {
                    Label(unavailableTitle, systemImage: "network.slash")
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(retryTitle) { Task { await catalog.refresh() } }
                } else if catalog.releases.isEmpty && catalog.isLoading {
                    ProgressView(loadingTitle)
                } else if catalog.releases.isEmpty {
                    Text(emptyHistory).font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(catalog.releases) { release in
                        releaseRow(release)
                    }
                }

                Text(manualInstallHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(sectionTitle).accessibilityIdentifier("settings.updates.title")
        }
        .task {
            if catalog.releases.isEmpty { await catalog.refresh() }
        }
    }

    // A grouped Form merges a DisclosureGroup row into one accessibility element that ignores clicks on its title
    // and drops the title from VoiceOver, so each release row is an explicit button with its own expanded state.
    @ViewBuilder
    private func releaseRow(_ release: GitHubRelease) -> some View {
        let isExpanded = expandedReleaseIDs.contains(release.id)
        let knownIssue = KnownReleaseIssue.issue(forTag: release.tagName)
        VStack(alignment: .leading, spacing: 6) {
            Button { toggleRelease(release.id) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(release.name.flatMap { $0.isEmpty ? nil : $0 } ?? release.tagName)
                                .font(.body.weight(.semibold))
                            Spacer()
                            if let knownIssue {
                                Label(L10n.text(knownIssue.badgeKey, language), systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                            } else if release.prerelease {
                                Text(betaLabel).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            Text(release.tagName).font(.caption.monospaced()).foregroundStyle(.secondary)
                            if let publishedAt = release.publishedAt {
                                Text(publishedAt.formatted(.dateTime.locale(locale).month(.abbreviated).day()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.updates.release.\(release.tagName)")
            .accessibilityValue(Text(isExpanded ? expandedState : collapsedState))

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let body = release.body, !body.isEmpty {
                        Text(markdown(body))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let knownIssue, !knownIssue.allowsDownload {
                        Label(L10n.text(knownIssue.messageKey, language), systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.updates.issue.\(release.tagName)")
                    } else if let asset = release.currentArchitectureAsset {
                        Link(destination: asset.browserDownloadURL) {
                            Label(downloadTitle, systemImage: "arrow.down.circle")
                        }
                        .accessibilityIdentifier("settings.updates.download.\(release.tagName)")
                    } else {
                        Label(noArchitectureBuild, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let releaseURL = release.trustedReleasePageURL {
                        Link(githubReleaseTitle, destination: releaseURL).font(.caption)
                    }
                }
                .padding(.leading, 20)
                .padding(.vertical, 6)
            }
        }
    }

    private func toggleRelease(_ id: Int) {
        if expandedReleaseIDs.contains(id) {
            expandedReleaseIDs.remove(id)
        } else {
            expandedReleaseIDs.insert(id)
        }
    }

    private func markdown(_ source: String) -> AttributedString {
        (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .full)))
            ?? AttributedString(source)
    }

    private var installedVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String
        switch (short, build) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (build \(build))"
        case let (short?, _) where !short.isEmpty:
            return short
        case let (_, build?) where !build.isEmpty:
            return build
        default:
            return unknownVersion
        }
    }

    private var title: String { L10n.text("updates.installed", language) }
    private var sectionTitle: String { L10n.text("updates.title", language) }
    private var autoUpdateTitle: String { L10n.text("updates.auto", language) }
    private var checkUpdatesTitle: String { L10n.text("updates.check", language) }
    private var autoUpdateUnavailable: String { L10n.text("updates.autoUnavailable", language) }
    private var autoUpdateSetup: String { L10n.text("updates.autoSetup", language) }
    private var historyTitle: String { L10n.text("updates.history", language) }
    private var refreshTitle: String { L10n.text("updates.refresh", language) }
    private var unavailableTitle: String { L10n.text("updates.unavailable", language) }
    private var retryTitle: String { L10n.text("updates.retry", language) }
    private var loadingTitle: String { L10n.text("updates.loading", language) }
    private var emptyHistory: String { L10n.text("updates.empty", language) }
    private var manualInstallHelp: String { L10n.text("updates.manualHelp", language) }
    private var downloadTitle: String { L10n.text("updates.download", language) }
    private var noArchitectureBuild: String { L10n.text("updates.noBuild", language) }
    private var githubReleaseTitle: String { L10n.text("updates.github", language) }
    private var betaLabel: String { L10n.text("updates.beta", language) }
    private var expandedState: String { L10n.text("updates.expanded", language) }
    private var collapsedState: String { L10n.text("updates.collapsed", language) }
    private var unknownVersion: String { L10n.text("updates.unknownVersion", language) }
}

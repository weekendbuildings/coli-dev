import AppKit
import WebKit

// NotebookLM inside the app: its own window with a WKWebView on notebooklm.google.com. The default (persistent) website
// data store keeps the owner's Google sign-in between launches; videos and audio overviews play inside. The app never
// reads, scrapes or drives the page — it is the owner's own browser window.
// NotebookLM внутри приложения: отдельное окно с WKWebView на notebooklm.google.com. Постоянное хранилище данных сайта
// помнит вход владельца в Google между запусками; видео и аудиообзоры играют внутри. Приложение не читает страницу и
// ничего не делает за владельца — это его собственное окно браузера.

@MainActor
final class NotebookWindow: NSObject, WKUIDelegate, WKNavigationDelegate {
    static let shared = NotebookWindow()
    static let home = URL(string: "https://notebooklm.google.com/")!
    /// Google refuses sign-in in web views that do not look like a browser, so the page sees Safari.
    /// Google не пускает войти во встроенный браузер, который не похож на браузер, поэтому страница видит Safari.
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    private var window: NSWindow?
    private var webView: WKWebView?

    /// The same web view for the glass panel inside the HUD (one parent at a time; the sign-in is shared).
    /// Тот же веб-вид для стеклянной панели внутри HUD (одна панель за раз, вход общий).
    func paneView() -> WKWebView {
        if let webView { return webView }
        let webView = makeWebView()
        self.webView = webView
        webView.load(URLRequest(url: Self.home))
        return webView
    }

    /// A second web view for videos in the same glass panel (NotebookLM keeps its page). / Второй веб-вид для видео.
    private var media: WKWebView?
    func mediaView(_ url: URL?) -> WKWebView {
        let view = media ?? makeWebView()
        media = view
        guard let url else { return view }
        var request = URLRequest(url: url)
        // YouTube embeds want a referring page. / Встраивание YouTube требует страницу-источник.
        request.setValue("https://github.com/weekendbuildings/coli-dev", forHTTPHeaderField: "Referer")
        view.load(request)
        return view
    }

    func stopMedia() { media?.loadHTMLString("", baseURL: nil) }

    func show(title: String) {
        if window == nil { makeWindow(title: title) }
        NSApp.activate(ignoringOtherApps: true)
        window?.collectionBehavior.insert(.moveToActiveSpace)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.isElementFullscreenEnabled = true
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1240, height: 820), configuration: configuration)
        webView.customUserAgent = Self.userAgent
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = .black
        webView.wantsLayer = true
        webView.layer?.cornerRadius = 16
        webView.layer?.masksToBounds = true
        return webView
    }

    private func makeWindow(title: String) {
        let webView = self.webView ?? makeWebView()
        webView.removeFromSuperview()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.minSize = NSSize(width: 720, height: 520)
        window.contentView = webView
        window.setFrameAutosaveName("ColiDev.NotebookLM")
        if !window.setFrameUsingName("ColiDev.NotebookLM") { window.center() }
        self.window = window
        if self.webView == nil { webView.load(URLRequest(url: Self.home)) }
        self.webView = webView
    }

    /// Sign-in and share pop-ups open in the same window. / Окна входа и общего доступа открываются в этом же окне.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    /// Web pages stay here; other links (mailto:, apps) go to macOS. / Веб-страницы остаются здесь, прочие ссылки — в macOS.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { return .cancel }
        if ["https", "http", "about", "blob", "data"].contains(scheme) { return .allow }
        NSWorkspace.shared.open(url)
        return .cancel
    }
}

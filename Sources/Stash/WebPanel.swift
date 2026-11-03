import SwiftUI
import WebKit

/// A Space running as a mini app, attached to the left of the Space list.
struct WebPanel: View {
    let link: SpaceLink
    @EnvironmentObject private var store: SpacesStore

    var body: some View {
        let web = store.webModel(for: link)
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(link.title).font(Theme.font(14, .medium)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(link.url.host() ?? "").font(Theme.mono(11)).foregroundStyle(Theme.faint).lineLimit(1)
                }
                Spacer()
                RoundButton(symbol: "arrow.clockwise", help: "Reload") { web.view.reload() }
                RoundButton(symbol: "link", help: "Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString((web.view.url ?? link.url).absoluteString, forType: .string)
                }
                RoundButton(symbol: "safari", help: "Open in browser") { store.openExternally(web.view.url ?? link.url) }
                RoundButton(symbol: "xmark", help: "Close") { store.closeSpace() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            Rectangle().fill(Theme.hairline).frame(height: 1)
            if Demo.isRendering {
                // A web view doesn't draw offscreen; show the page's screenshot.
                Color.clear
                    .overlay(alignment: .topLeading) {
                        Demo.pageImage(for: link.id).map { Image(nsImage: $0).resizable().scaledToFill() }
                    }
                    .clipped()
            } else {
                WebView(webView: web.view)
            }
        }
    }
}

/// One per opened Space, kept for the session so switching Spaces keeps each
/// one's page and scroll.
@MainActor
final class WebModel: NSObject, WKUIDelegate {
    let view = WKWebView()

    init(url: URL) {
        super.init()
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
    }

    /// Links that ask for a new window go to the browser.
    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }
}

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

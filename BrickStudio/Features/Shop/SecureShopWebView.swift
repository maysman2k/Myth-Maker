import SwiftUI
import WebKit

@MainActor
final class ShopWebViewStore {
    static let shared = ShopWebViewStore()

    let url = URL(string: "https://bricksinabag.com")!
    let webView: WKWebView
    private var hasStartedLoading = false

    private init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()

        let lockScript = """
        (function() {
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.setAttribute('content', 'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover');
            document.documentElement.style.overflowX = 'hidden';
            document.body.style.overflowX = 'hidden';
            document.body.style.width = '100vw';
            document.body.style.minWidth = '100vw';
            document.body.style.maxWidth = '100vw';
            document.body.style.touchAction = 'pan-y';
        })();
        """
        configuration.userContentController.addUserScript(WKUserScript(source: lockScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        webView = WKWebView(frame: .zero, configuration: configuration)
        configureScrollView()
    }

    func preload() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
    }

    func reload() {
        hasStartedLoading = true
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    func configureScrollView() {
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.zoomScale = 1
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.backgroundColor = UIColor(BrickColor.background)
    }
}

struct SecureShopWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    private let allowedHosts: Set<String> = [
        "bricksinabag.com",
        "www.bricksinabag.com"
    ]

    func makeCoordinator() -> Coordinator {
        Coordinator(
            allowedHosts: allowedHosts,
            isLoading: $isLoading,
            errorMessage: $errorMessage
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let store = ShopWebViewStore.shared
        let webView = store.webView
        store.configureScrollView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        isLoading = webView.isLoading || webView.url == nil
        errorMessage = nil
        store.preload()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        ShopWebViewStore.shared.configureScrollView()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
        private let allowedHosts: Set<String>
        private var isLoading: Binding<Bool>
        private var errorMessage: Binding<String?>

        init(allowedHosts: Set<String>, isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            self.allowedHosts = allowedHosts
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
            errorMessage.wrappedValue = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
            lockViewport(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            guard ["http", "https"].contains(url.scheme?.lowercased()) else {
                openExternally(url)
                decisionHandler(.cancel)
                return
            }

            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            guard isMainFrame else {
                decisionHandler(.allow)
                return
            }

            if isAllowed(url) {
                decisionHandler(.allow)
            } else {
                openExternally(url)
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                openExternally(url)
            }
            return nil
        }

        private func isAllowed(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return false }
            return allowedHosts.contains(host)
        }

        private func openExternally(_ url: URL) {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            nil
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            scrollView.zoomScale = 1
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if scrollView.zoomScale != 1 {
                scrollView.zoomScale = 1
            }
            if scrollView.contentOffset.x != 0 {
                scrollView.contentOffset.x = 0
            }
        }

        private func lockViewport(in webView: WKWebView) {
            let script = """
            (function() {
                var meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    document.head.appendChild(meta);
                }
                meta.setAttribute('content', 'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover');
                document.documentElement.style.overflowX = 'hidden';
                document.body.style.overflowX = 'hidden';
                document.body.style.width = '100vw';
                document.body.style.minWidth = '100vw';
                document.body.style.maxWidth = '100vw';
                document.body.style.touchAction = 'pan-y';
            })();
            """
            webView.evaluateJavaScript(script)
        }

        private func handle(_ error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            isLoading.wrappedValue = false
            errorMessage.wrappedValue = "Couldn't load the Bricks in a Bag shop. Check your connection and try again."
        }
    }
}

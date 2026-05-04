import WebKit
import UIKit
import Combine

// The iPhone IS the browser. BrowserEngine manages an offscreen WKWebView,
// captures JPEG frames, and streams them to the Apple TV via TVClient.

class BrowserEngine: NSObject, ObservableObject {
    let client = TVClient()
    private(set) var webView: WKWebView!
    private var clientCancellable: AnyCancellable?

    @Published var previewImage: UIImage?
    @Published var currentURL = ""
    @Published var pageTitle = ""

    // Cursor in WKWebView points (view is 960×540)
    private(set) var cursorX: CGFloat = 480
    private(set) var cursorY: CGFloat = 270
    private let vw: CGFloat = 960
    private let vh: CGFloat = 540

    private var isCapturing = false
    private var wantCapture = false

    var isConnected: Bool { client.isConnected }

    override init() {
        super.init()
        // Forward TVClient changes so SwiftUI views update on connect/disconnect
        clientCancellable = client.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        buildWebView()
    }

    private func buildWebView() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: vw, height: vh), configuration: cfg)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func start() {
        client.startDiscovery()
        navigate(to: "https://www.google.com")
    }

    // Call from SwiftUI .onAppear — adds the WKWebView to the live UIKit hierarchy
    // so that takeSnapshot() works reliably.
    func attachWebView(to window: UIWindow) {
        guard webView.superview == nil else { return }
        webView.alpha = 0.01
        webView.frame = CGRect(x: 0, y: -(vh + 100), width: vw, height: vh)
        window.addSubview(webView)
    }

    // MARK: Cursor

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        cursorX = max(0, min(vw, cursorX + dx))
        cursorY = max(0, min(vh, cursorY + dy))
        client.sendCommand(RemoteCommand("cursor",
                                        nx: Double(cursorX / vw),
                                        ny: Double(cursorY / vh)))
    }

    // MARK: Actions

    func tap() {
        client.sendCommand(RemoteCommand("tap"))  // TV shows cursor pulse
        let x = cursorX, y = cursorY
        let js = """
        (function(){
            var el = document.elementFromPoint(\(x), \(y));
            if (!el) return;
            ['mouseover','mousedown','mouseup','click'].forEach(function(t){
                el.dispatchEvent(new MouseEvent(t,{bubbles:true,cancelable:true,
                    clientX:\(x),clientY:\(y)}));
            });
            if (el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.tagName==='SELECT')
                el.focus();
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.captureAndSend() }
        }
    }

    func scroll(dx: CGFloat, dy: CGFloat) {
        webView.evaluateJavaScript("window.scrollBy(\(dx * 2.5), \(dy * 2.5));") { [weak self] _, _ in
            self?.captureAndSend()
        }
    }

    func navigate(to raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            if s.contains(".") && !s.contains(" ") { s = "https://" + s }
            else {
                let q = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
                s = "https://www.google.com/search?q=\(q)"
            }
        }
        if let url = URL(string: s) { webView.load(URLRequest(url: url)) }
    }

    func goBack()    { webView.goBack();    captureAndSend() }
    func goForward() { webView.goForward(); captureAndSend() }
    func reload()    { webView.reload() }

    func injectText(_ text: String) {
        let safe = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = """
        (function(){
            var el=document.activeElement;
            if(!el||(el.tagName!=='INPUT'&&el.tagName!=='TEXTAREA')) return;
            var s=el.selectionStart??el.value.length, e=el.selectionEnd??s;
            el.value=el.value.slice(0,s)+'\(safe)'+el.value.slice(e);
            el.selectionStart=el.selectionEnd=s+'\(safe)'.length;
            el.dispatchEvent(new Event('input',{bubbles:true}));
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] _, _ in self?.captureAndSend() }
    }

    func deleteChar() {
        let js = """
        (function(){
            var el=document.activeElement;
            if(!el||(el.tagName!=='INPUT'&&el.tagName!=='TEXTAREA')) return;
            var s=el.selectionStart, e=el.selectionEnd;
            if(s>0){
                el.value=el.value.slice(0,s-1)+el.value.slice(e);
                el.selectionStart=el.selectionEnd=s-1;
                el.dispatchEvent(new Event('input',{bubbles:true}));
            }
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] _, _ in self?.captureAndSend() }
    }

    // MARK: Frame capture

    func captureAndSend() {
        guard !isCapturing else { wantCapture = true; return }
        isCapturing = true

        webView.takeSnapshot(with: nil) { [weak self] image, _ in
            guard let self else { return }
            defer {
                self.isCapturing = false
                if self.wantCapture {
                    self.wantCapture = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.captureAndSend() }
                }
            }
            guard let image else { return }

            // Resize to 720p for efficient streaming (≈120-250 KB per JPEG)
            let target = CGSize(width: 1280, height: 720)
            let renderer = UIGraphicsImageRenderer(size: target)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }

            guard let jpeg = resized.jpegData(compressionQuality: 0.72) else { return }
            self.client.sendFrame(jpeg)
            DispatchQueue.main.async { self.previewImage = resized }
        }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentURL = webView.url?.absoluteString ?? ""
        pageTitle = webView.title ?? ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.captureAndSend() }
    }
}

// MARK: - WKUIDelegate (handle target="_blank")

extension BrowserEngine: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith cfg: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { webView.load(URLRequest(url: url)) }
        return nil
    }
}

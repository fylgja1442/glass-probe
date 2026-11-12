import UIKit
import WebKit

// Launch args: -state bar|native|menu|realmenu|sheet|toolbar|live  -url <http url>  -edge 1  -insets 1  -freeze 1  -light 1
// live: -url <page> -driver <script url> -demo 1 (see README)
// Deployment target is iOS 26.0, so every iOS 26 symbol is used directly. A toolchain without the iOS 26 SDK fails the build loudly.
// "native" = same pills over a native striped UIView with no WKWebView: it separates "VM cannot render glass" from "glass does not sample WKWebView".

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

final class Stripes: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .redraw
        backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    override func draw(_ rect: CGRect) {
        let w = bounds.width, h = bounds.height
        UIColor.systemYellow.setFill()
        var x = -h
        while x < w {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: x, y: h)); p.addLine(to: CGPoint(x: x + 22, y: h))
            p.addLine(to: CGPoint(x: x + 22 + h, y: 0)); p.addLine(to: CGPoint(x: x + h, y: 0))
            p.close(); p.fill()
            x += 44
        }
        UIColor.systemPink.setFill(); UIRectFill(CGRect(x: 0, y: h - 96, width: w, height: 20))
        UIColor.systemCyan.setFill(); UIRectFill(CGRect(x: 0, y: h - 64, width: w, height: 20))
        UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 62, width: w, height: 24))
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { fatalError("expected a UIWindowScene") }
        let w = UIWindow(windowScene: ws)
        w.overrideUserInterfaceStyle = arg("-light") == "1" ? .light : .dark // same appearance for every shot
        w.rootViewController = ProbeViewController()
        w.makeKeyAndVisible()
        window = w
    }
}

final class ProbeViewController: UIViewController {
    let state = arg("-state") ?? "bar"
    let webView: WKWebView = {
        let c = WKWebViewConfiguration()
        if arg("-freeze") == "1" { // page.html skips its scroll loop when window.FREEZE is set
            c.userContentController.addUserScript(WKUserScript(source: "window.FREEZE = true;", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        return WKWebView(frame: .zero, configuration: c)
    }()
    var plusButton: UIButton?
    // live state
    var pageLoaded = false, driverRan = false, readyWritten = false
    var driverText: String?
    let pollStart = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let backdrop: UIView = state == "native" ? Stripes() : webView
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backdrop)
        if state != "native" {
            if arg("-insets") == "1" {
                webView.obscuredContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
            }
            if state == "live" {
                webView.navigationDelegate = self
                fetchDriver()
            }
            loadPage()
        }
        if state == "live" {
            addComposer()
        } else if state == "toolbar" {
            addToolbar()
        } else {
            let bars = addBars()
            addGlassButton()
            if state == "menu" { addPanel(above: bars) }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if state == "sheet" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.showSheet() }
        }
        if state == "realmenu" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.plusButton?.performPrimaryAction() }
        }
        if state == "live" { poll() }
    }

    func loadPage() {
        if let s = arg("-url") {
            guard let u = URL(string: s) else { fatalError("bad -url") }
            webView.load(URLRequest(url: u))
        } else {
            guard let u = Bundle.main.url(forResource: "page", withExtension: "html") else {
                fatalError("page.html missing from bundle")
            }
            webView.loadFileURL(u, allowingReadAccessTo: u.deletingLastPathComponent())
        }
    }

    // Two pills, same size, side by side at the same y so both see the same backdrop: plain blur left, glass right.
    func addBars() -> UIStackView {
        let menu = UIMenu(children: [
            UIAction(title: "New chat", image: UIImage(systemName: "square.and.pencil")) { _ in },
            UIAction(title: "Photos", image: UIImage(systemName: "photo")) { _ in },
            UIAction(title: "Files", image: UIImage(systemName: "doc")) { _ in },
        ])
        let blur = pill(UIBlurEffect(style: .systemThinMaterial), title: "Blur bar", menu: nil)
        let glass = pill(UIGlassEffect(style: .regular), title: "Glass bar", menu: menu)
        let bars = UIStackView(arrangedSubviews: [blur, glass])
        bars.axis = .horizontal
        bars.distribution = .fillEqually
        bars.spacing = 12
        bars.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bars)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bars.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            bars.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            bars.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -8),
        ])
        if arg("-edge") == "1", state != "native" {
            let i = UIScrollEdgeElementContainerInteraction()
            i.scrollView = webView.scrollView
            i.edge = .bottom
            bars.addInteraction(i)
        }
        return bars
    }

    func pill(_ effect: UIVisualEffect, title: String, menu: UIMenu?) -> UIVisualEffectView {
        let v = UIVisualEffectView(effect: effect)
        v.cornerConfiguration = .capsule(maximumRadius: nil)
        if !(effect is UIGlassEffect) { // fallback in case cornerConfiguration does not clip a blur view; never on glass
            v.layer.cornerRadius = 28
            v.clipsToBounds = true
        }
        let plus = UIButton(type: .system)
        plus.setImage(UIImage(systemName: "plus"), for: .normal)
        plus.tintColor = .label
        if let menu {
            plus.menu = menu
            plus.showsMenuAsPrimaryAction = true
            plusButton = plus
        }
        plus.widthAnchor.constraint(equalToConstant: 32).isActive = true
        let label = UILabel()
        label.text = title
        label.textColor = .secondaryLabel
        let row = UIStackView(arrangedSubviews: [plus, label])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        v.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: v.contentView.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(lessThanOrEqualTo: v.contentView.trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: v.contentView.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: 56),
        ])
        return v
    }

    // Round button with the system glass button style.
    func addGlassButton() {
        var cfg = UIButton.Configuration.glass()
        cfg.image = UIImage(systemName: "plus")
        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(b)
        NSLayoutConstraint.activate([
            b.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            b.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            b.widthAnchor.constraint(equalToConstant: 48),
            b.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    // Home-made menu look: a glass panel with three rows, above the glass pill. The real UIMenu is state "realmenu".
    func addPanel(above bars: UIView) {
        let panel = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        panel.cornerConfiguration = .corners(radius: 22.0)
        let rows = UIStackView(arrangedSubviews: [row("New chat", "square.and.pencil"), row("Photos", "photo"), row("Files", "doc")])
        rows.axis = .vertical
        rows.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(rows)
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 8),
            rows.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -8),
            rows.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 12),
            rows.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -12),
            panel.trailingAnchor.constraint(equalTo: bars.trailingAnchor),
            panel.widthAnchor.constraint(equalToConstant: 240),
            panel.bottomAnchor.constraint(equalTo: bars.topAnchor, constant: -12),
        ])
    }

    func row(_ title: String, _ icon: String) -> UIButton {
        var c = UIButton.Configuration.plain()
        c.title = title
        c.image = UIImage(systemName: icon)
        c.imagePadding = 12
        c.baseForegroundColor = .label
        let b = UIButton(configuration: c)
        b.contentHorizontalAlignment = .leading
        return b
    }

    // Reference: a stock UIToolbar; with the iOS 26+ SDK the system draws it as glass without any custom code.
    func addToolbar() {
        let tb = UIToolbar()
        tb.translatesAutoresizingMaskIntoConstraints = false
        tb.items = [
            UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Message", style: .plain, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil),
        ]
        view.addSubview(tb)
        NSLayoutConstraint.activate([
            tb.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tb.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tb.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // No custom background on the sheet view: the system draws the sheet material (glass on iOS 26+).
    func showSheet(title: String = "Sheet, medium detent") {
        let vc = UIViewController()
        let l = UILabel()
        l.text = title
        l.font = .preferredFont(forTextStyle: .title2)
        l.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(l)
        NSLayoutConstraint.activate([
            l.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            l.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 48),
        ])
        vc.modalPresentationStyle = .pageSheet
        if let s = vc.sheetPresentationController {
            s.detents = [.medium(), .large()]
            s.prefersGrabberVisible = true
            s.largestUndimmedDetentIdentifier = .medium
        }
        present(vc, animated: true)
    }

    // MARK: live state

    // Composer row like the iOS 26 Messages composer: round glass +, glass capsule, round glass send, 12 pt above the bottom safe area.
    func addComposer() {
        let menu = UIMenu(children: [
            UIAction(title: "Photos", image: UIImage(systemName: "photo")) { _ in },
            UIAction(title: "Camera", image: UIImage(systemName: "camera")) { _ in },
            UIAction(title: "Files", image: UIImage(systemName: "doc")) { _ in },
            UIAction(title: "GIF", image: UIImage(systemName: "face.smiling")) { _ in },
            UIAction(title: "Background", image: UIImage(systemName: "paintbrush")) { _ in },
        ])
        let plus = roundGlassButton("plus")
        plus.menu = menu
        plus.showsMenuAsPrimaryAction = true
        plusButton = plus
        let send = roundGlassButton("arrow.up")
        let capsule = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        capsule.cornerConfiguration = .capsule(maximumRadius: nil)
        let label = UILabel()
        label.text = "Message"
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        capsule.contentView.addSubview(label)
        capsule.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(capsule)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: capsule.contentView.leadingAnchor, constant: 18),
            label.centerYAnchor.constraint(equalTo: capsule.contentView.centerYAnchor),
            plus.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            plus.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
            send.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            send.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
            capsule.leadingAnchor.constraint(equalTo: plus.trailingAnchor, constant: 8),
            capsule.trailingAnchor.constraint(equalTo: send.leadingAnchor, constant: -8),
            capsule.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
            capsule.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    func roundGlassButton(_ icon: String) -> UIButton {
        var cfg = UIButton.Configuration.glass()
        cfg.image = UIImage(systemName: icon)
        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(b)
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 52),
            b.heightAnchor.constraint(equalToConstant: 52),
        ])
        return b
    }

    // The driver script text comes from -driver; it runs once, after both it and the first didFinish have arrived.
    func fetchDriver() {
        guard let s = arg("-driver"), let u = URL(string: s) else { finishLive("KIT_FAIL: no driver url"); return }
        URLSession.shared.dataTask(with: u) { data, response, _ in
            DispatchQueue.main.async {
                // a non-200 answer is an error page, not a script: never evaluate it
                guard (response as? HTTPURLResponse)?.statusCode == 200, let data, let text = String(data: data, encoding: .utf8) else { self.finishLive("KIT_FAIL: driver fetch"); return }
                self.driverText = text
                self.runDriverIfReady()
            }
        }.resume()
    }

    func runDriverIfReady() {
        guard pageLoaded, !driverRan, let text = driverText else { return }
        driverRan = true
        webView.evaluateJavaScript(text, completionHandler: nil)
    }

    // 4 times a second: stop on a KIT_READY or KIT_FAIL title, or after 180 s (the driver may wait up to 100 s for the account alone).
    func poll() {
        guard !readyWritten else { return }
        webView.evaluateJavaScript("document.title") { result, _ in
            let t = (result as? String) ?? ""
            if t.hasPrefix("KIT_READY") || t.hasPrefix("KIT_FAIL") {
                self.finishLive(t)
            } else if Date().timeIntervalSince(self.pollStart) > 180 {
                self.finishLive("TIMEOUT")
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.poll() }
            }
        }
    }

    // ready.txt in Documents is what the CI script waits for (simctl get_app_container <udid> <bundle id> data).
    func finishLive(_ text: String) {
        guard !readyWritten else { return }
        readyWritten = true
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? text.write(to: dir.appendingPathComponent("ready.txt"), atomically: true, encoding: .utf8)
        }
        if arg("-demo") == "1" { runDemo() }
    }

    // Fixed sequence, seconds after the ready file: 5 open the real UIMenu, 9 close it, 10 sheet, 14 dismiss.
    func runDemo() {
        let q = DispatchQueue.main
        q.asyncAfter(deadline: .now() + 5) { self.plusButton?.performPrimaryAction() }
        q.asyncAfter(deadline: .now() + 9) { self.plusButton?.contextMenuInteraction?.dismissMenu() }
        q.asyncAfter(deadline: .now() + 10) { self.showSheet(title: "Chat background") }
        q.asyncAfter(deadline: .now() + 14) { self.dismiss(animated: true) }
    }
}

extension ProbeViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoaded = true
        runDriverIfReady()
    }
}

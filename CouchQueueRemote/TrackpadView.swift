import UIKit
import SwiftUI

struct TrackpadView: UIViewRepresentable {
    let engine: BrowserEngine

    func makeUIView(context: Context) -> TrackpadUIView {
        let v = TrackpadUIView()
        v.engine = engine
        return v
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {}
}

class TrackpadUIView: UIView {
    weak var engine: BrowserEngine?
    private var lastPanPt: CGPoint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.08, alpha: 1)
        layer.cornerRadius = 16
        addHint()
        setupGestures()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func addHint() {
        let lbl = UILabel()
        lbl.text = "Swipe · move     Tap · click     2-finger · scroll"
        lbl.font = .systemFont(ofSize: 13, weight: .light)
        lbl.textColor = UIColor(white: 0.3, alpha: 1)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: centerXAnchor),
            lbl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        tap.require(toFail: pan)
        addGestureRecognizer(tap)

        let scroll = UIPanGestureRecognizer(target: self, action: #selector(onScroll))
        scroll.minimumNumberOfTouches = 2
        scroll.maximumNumberOfTouches = 2
        addGestureRecognizer(scroll)

        pan.require(toFail: scroll)
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let pt = g.location(in: self)
        switch g.state {
        case .began:
            lastPanPt = pt
        case .changed:
            guard let last = lastPanPt else { return }
            let scale: CGFloat = 3.0
            engine?.moveCursor(dx: (pt.x - last.x) * scale, dy: (pt.y - last.y) * scale)
            lastPanPt = pt
        case .ended, .cancelled:
            lastPanPt = nil
        default: break
        }
    }

    @objc private func onTap(_ g: UITapGestureRecognizer) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        engine?.tap()
    }

    @objc private func onScroll(_ g: UIPanGestureRecognizer) {
        guard g.state == .changed else { return }
        let t = g.translation(in: self)
        engine?.scroll(dx: t.x, dy: t.y)
        g.setTranslation(.zero, in: self)
    }
}

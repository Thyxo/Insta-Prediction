// Låseskærmens ur tegnet med CoreText.
//
// Målt på en rigtig iOS 26-låseskærm (iPhone 1179×2556, "13.24"): SFAdaptiveNumeric med
// wght 600, wdth 100, HGHT ≈ 230. Cifrene fylder 86 % af bredden og 28,4 % af skærmhøjden,
// toppen sidder 55 pt under safe area (114 pt på en skærm med 59 pt top).
// Bredden afhænger ikke af HGHT, så størrelsen findes først (bredde), derefter HGHT (højde).
import CoreText
import SwiftUI
import UIKit

struct ClockView: UIViewRepresentable {
    let text: String
    let fontFile: String?
    let weight: Double
    let heightRatio: Double      // cifrenes højde / skærmhøjde
    let widthRatio: Double       // tekstens bredde / skærmbredde
    let screenHeight: CGFloat
    let glass: Bool

    func makeUIView(context: Context) -> ClockUIView {
        let v = ClockUIView()
        v.isOpaque = false
        v.backgroundColor = .clear
        v.contentMode = .redraw
        return v
    }

    func updateUIView(_ v: ClockUIView, context: Context) {
        let cfg = ClockUIView.Config(text: text, fontFile: fontFile, weight: weight, heightRatio: heightRatio,
                                     widthRatio: widthRatio, screenHeight: screenHeight, glass: glass)
        if v.cfg != cfg { v.cfg = cfg; v.setNeedsDisplay() }
    }
}

final class ClockUIView: UIView {
    struct Config: Equatable {
        var text = ""
        var fontFile: String?
        var weight = 600.0
        var heightRatio = 0.284
        var widthRatio = 0.86
        var screenHeight: CGFloat = 852
        var glass = true
    }

    var cfg = Config()

    /// Husk sidste tilpasning, så HGHT ikke søges hvert sekund
    private var fitKey = ""
    private var fitSize: CGFloat = 100
    private var fitHeight: Double = 230

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), !cfg.text.isEmpty else { return }
        let targetW = bounds.width * cfg.widthRatio
        let targetH = cfg.screenHeight * cfg.heightRatio

        let font: CTFont
        if let file = cfg.fontFile {
            // Bredden på "00.00" bruges, så størrelsen ikke hopper, når cifrene skifter
            let probe = cfg.text.replacingOccurrences(of: "[0-9]", with: "0", options: .regularExpression)
            let key = "\(file)|\(probe)|\(cfg.weight)|\(targetW)|\(targetH)"
            if key != fitKey {
                fit(file: file, probe: probe, targetW: targetW, targetH: targetH)
                fitKey = key
            }
            font = ClockFonts.font(file: file, size: fitSize, axes: ["HGHT": fitHeight, "wght": cfg.weight, "wdth": 100])
                ?? CTFontCreateUIFontForLanguage(.system, fitSize, nil)!
        } else {
            // Uden Apples skrift: systemskrift, smal og strakt
            let base = UIFont.systemFont(ofSize: 100, weight: .bold, width: .condensed)
            let w = Self.inkBounds(cfg.text, base as CTFont).width
            font = UIFont.systemFont(ofSize: 100 * targetW / max(1, w), weight: .bold, width: .condensed) as CTFont
        }

        let line = Self.line(cfg.text, font)
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        var sy: CGFloat = 1
        if cfg.fontFile == nil { sy = targetH / max(1, ink.height) }   // stræk systemskriften

        ctx.saveGState()
        // CoreText tegner med y opad: vend, og læg cifrenes top i bounds' top
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        let x = (bounds.width - ink.width) / 2 - ink.minX
        let topY = bounds.height                     // toppen i vendt koordinat
        ctx.translateBy(x: 0, y: topY - ink.maxY * sy)
        ctx.scaleBy(x: 1, y: sy)
        ctx.textPosition = CGPoint(x: x, y: 0)

        if cfg.glass {
            ctx.setTextDrawingMode(.clip)
            CTLineDraw(line, ctx)
            // Lys top, lidt mere gennemsigtig bund (iOS 26 "liquid glass")
            let colors = [UIColor(white: 1, alpha: 1).cgColor,
                          UIColor(white: 1, alpha: 0.94).cgColor,
                          UIColor(white: 0.97, alpha: 0.84).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: ink.maxY), end: CGPoint(x: 0, y: ink.minY), options: [])
            }
        } else {
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setTextDrawingMode(.fill)
            CTLineDraw(line, ctx)
        }
        ctx.restoreGState()
    }

    private func fit(file: String, probe: String, targetW: CGFloat, targetH: CGFloat) {
        // 1. Størrelse ud fra bredden (HGHT påvirker ikke bredden)
        guard let f100 = ClockFonts.font(file: file, size: 100, axes: ["HGHT": 100, "wght": cfg.weight, "wdth": 100]) else { return }
        let w100 = Self.inkBounds(probe, f100).width
        fitSize = max(10, 100 * targetW / max(1, w100))
        // 2. HGHT ud fra højden (binær søgning 100…500)
        var lo = 100.0, hi = 500.0
        if ClockFonts.axes(for: file).contains("HGHT") {
            for _ in 0..<14 {
                let mid = (lo + hi) / 2
                guard let f = ClockFonts.font(file: file, size: fitSize, axes: ["HGHT": mid, "wght": cfg.weight, "wdth": 100]) else { break }
                if Self.inkBounds("0123456789", f).height < targetH { lo = mid } else { hi = mid }
            }
            fitHeight = (lo + hi) / 2
        } else {
            fitHeight = 100
        }
    }

    static func line(_ s: String, _ f: CTFont) -> CTLine {
        let attr = NSAttributedString(string: s, attributes: [.font: f as UIFont])
        return CTLineCreateWithAttributedString(attr)
    }

    static func inkBounds(_ s: String, _ f: CTFont) -> CGRect {
        CTLineGetBoundsWithOptions(line(s, f), .useGlyphPathBounds)
    }
}

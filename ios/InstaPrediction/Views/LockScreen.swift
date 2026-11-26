// Falsk iPhone-låseskærm (iOS 26, dansk) som input – inspireret af ClockPlus.
//
// Genveje (som i ClockPlus):
//   Stryg op               → kode-skærm. Tilskueren "taster koden", den ryster som forkert kode.
//   Langt tryk på uret     → usynligt tastatur (3×4) i 8 sek.: 1 2 3 / 4 5 6 / 7 8 9 / ✕ 0 ✓
//   Dobbelttryk            → sort skærm (tryk vækker)
//   5 tryk øverst til højre → tilbage til Bio
//   Hold øverst til venstre 1 sek. → panik (annullér ventende afsløring)
import SwiftUI
import UIKit

struct LockScreen: View {
    @Environment(AppState.self) private var app

    @State private var showCode = false
    @State private var black = false
    @State private var drag: CGFloat = 0
    @State private var secretOn = false
    @State private var secretDigits = ""
    @State private var secretTask: Task<Void, Never>?
    @State private var exitTaps: [Date] = []
    @State private var blink = false

    var body: some View {
        GeometryReader { geo in
            let ins = geo.safeAreaInsets
            ZStack {
                Background(image: app.wallpaper, dim: app.s.lockDim, blur: showCode)

                lockContent(ins: ins, size: CGSize(width: geo.size.width + ins.leading + ins.trailing, height: geo.size.height + ins.top + ins.bottom))
                    .offset(y: showCode ? -60 : min(0, drag) * 0.35)
                    .opacity(showCode ? 0 : 1 - Double(min(1, -min(0, drag) / 300)))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { if !secretOn { black = true } }
                    .gesture(
                        DragGesture(minimumDistance: 15)
                            .onChanged { v in if !secretOn { drag = v.translation.height } }
                            .onEnded { v in
                                let up = v.translation.height < -70 || v.predictedEndTranslation.height < -180
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                    if up && !secretOn { showCode = true }
                                    drag = 0
                                }
                            }
                    )

                if showCode {
                    PasscodeView(length: app.s.lockCodeLength, topInset: ins.top, bottomInset: ins.bottom) { code in
                        app.lockCaptured(code, via: "kode")
                    } onCancel: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { showCode = false }
                    }
                    .transition(.opacity.combined(with: .offset(y: 40)))
                }

                if secretOn { secretPad(ins: ins) }

                zones(ins: ins)

                if black {
                    Color.black
                        .contentShape(Rectangle())
                        .onTapGesture { black = false }
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)   // vi tegner selv hjemmebjælken
        .onChange(of: app.lockPulse) { _, _ in
            guard app.s.lockBlink else { return }
            withAnimation(.easeInOut(duration: 0.18)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.25)) { blink = false }
            }
        }
        .onDisappear { secretTask?.cancel() }
    }

    // MARK: Låseskærmen
    // Placeringer målt på en rigtig iOS 26-låseskærm (393×852 pt, top 59 pt, bund 34 pt).

    private func lockContent(ins: EdgeInsets, size: CGSize) -> some View {
        let W = size.width, H = size.height, T = max(ins.top, 20), B = ins.bottom
        let s = app.s
        let clockH = H * s.lockHeight
        let showLock = s.lockPadlock || blink
        return ZStack(alignment: .topLeading) {
            Color.clear.frame(width: W, height: H)

            if s.lockStatus == "lock" {
                StatusBar(carrier: s.lockCarrier, silent: s.lockSilent, signal: s.lockSignal,
                          batteryPct: s.lockBatteryPct)
                    .padding(.leading, 27).padding(.trailing, 33)
                    .frame(width: W, height: 22)
                    .position(x: W / 2, y: T * 0.497)
                if s.lockGrabber {
                    Capsule().fill(.white.opacity(0.9))
                        .frame(width: 55, height: 2.3)
                        .position(x: W - 46 - 27.5, y: T * 0.75)
                }
            }

            Image(systemName: blink ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .opacity(showLock ? 1 : 0)
                .position(x: W / 2, y: T + 10)

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                ZStack(alignment: .topLeading) {
                    Text(Self.dateText(ctx.date, short: s.lockDateShort))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(s.lockGlass ? 0.93 : 1))
                        .fixedSize()
                        .position(x: W / 2, y: T + 33)
                    clock(Self.timeText(ctx.date, sep: s.lockTimeSep), W: W, H: H, h: clockH)
                        .frame(width: W, height: clockH)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.5) { startSecret() }
                        .position(x: W / 2, y: T + 55 + clockH / 2)
                }
                .frame(width: W, height: H)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 2)

            QuickButton(symbol: "flashlight.off.fill").position(x: 75, y: H - B - 45)
            QuickButton(symbol: "camera.fill").position(x: W - 75, y: H - B - 45)

            if !s.lockFocus.isEmpty {
                Label(s.lockFocus, systemImage: "moon.fill")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .position(x: W / 2, y: H - B - 45)
            }
            if !s.lockFooter.isEmpty {
                Text(s.lockFooter)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize()
                    .position(x: W / 2, y: H - max(B, 34) + 2)
            }
            Capsule().fill(.white)
                .frame(width: 140, height: 5)
                .position(x: W / 2, y: H - 10.5)
        }
        .frame(width: W, height: H)
    }

    private func clock(_ text: String, W: CGFloat, H: CGFloat, h: CGFloat) -> some View {
        // Apples skrift hvis importeret (Indstil låseskærm → Urskrift), ellers strakt systemskrift
        ClockView(text: text, fontFile: ClockFonts.resolve(app.s.lockFont), weight: app.s.lockWeight,
                  heightRatio: app.s.lockHeight, widthRatio: 0.86, screenHeight: H, glass: app.s.lockGlass)
    }

    // MARK: Usynligt tastatur

    private func startSecret() {
        secretDigits = ""
        withAnimation(.easeOut(duration: 0.15)) { secretOn = true }
        extendSecret()
    }

    private func extendSecret() {
        secretTask?.cancel()
        let sec = app.s.lockSecretSec
        secretTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(sec * 1_000_000_000))
            guard !Task.isCancelled else { return }
            finishSecret(commit: !secretDigits.isEmpty)
        }
    }

    private func finishSecret(commit: Bool) {
        secretTask?.cancel()
        if commit && !secretDigits.isEmpty { app.lockCaptured(secretDigits, via: "usynligt tastatur") }
        secretDigits = ""
        secretOn = false
    }

    private func secretPad(ins: EdgeInsets) -> some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "✕", "0", "✓"]
        return VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let k = keys[r * 3 + c]
                        ZStack {
                            if app.s.lockShowZones {
                                Rectangle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                                Text(k).font(.title).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { tapSecret(k) }
                    }
                }
            }
            if app.s.lockShowZones {
                Text(secretDigits.isEmpty ? "Usynligt tastatur" : secretDigits)
                    .font(.headline).foregroundStyle(.yellow)
                    .padding(.bottom, ins.bottom + 8)
            }
        }
        .padding(.top, ins.top)
    }

    private func tapSecret(_ k: String) {
        switch k {
        case "✕": secretDigits = ""; extendSecret()
        case "✓": finishSecret(commit: true)
        default:
            secretDigits += k
            if secretDigits.count >= 8 { finishSecret(commit: true) } else { extendSecret() }
        }
    }

    // MARK: Hemmelige zoner

    private func zones(ins: EdgeInsets) -> some View {
        let size: CGFloat = 90 + ins.top * 0.4
        return VStack {
            HStack {
                // Panik: hold 1 sek.
                zone(size: size)
                    .onLongPressGesture(minimumDuration: 1) {
                        app.lockPanic()
                        finishSecret(commit: false)
                        withAnimation { showCode = false }
                    }
                Spacer()
                // Ud: 5 hurtige tryk
                zone(size: size)
                    .onTapGesture {
                        let now = Date()
                        exitTaps = exitTaps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
                        if exitTaps.count >= 5 {
                            exitTaps = []
                            app.lockOpen = false
                        }
                    }
            }
            Spacer()
        }
    }

    private func zone(size: CGFloat) -> some View {
        Rectangle()
            .fill(app.s.lockShowZones ? Color.yellow.opacity(0.18) : Color.clear)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }

    // MARK: Tekst

    static func timeText(_ d: Date, sep: String) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%d%@%02d", c.hour ?? 0, sep, c.minute ?? 0)
    }

    static func dateText(_ d: Date, short: Bool) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "da_DK")
        f.dateFormat = short ? "EEE d. MMM" : "EEEE d. MMMM"
        let s = f.string(from: d)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: Dele

private struct Background: View {
    let image: UIImage?
    let dim: Double
    let blur: Bool

    var body: some View {
        GeometryReader { g in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: g.size.width, height: g.size.height)
                        .clipped()
                } else {
                    LinearGradient(colors: [Color(red: 0.10, green: 0.16, blue: 0.36),
                                            Color(red: 0.36, green: 0.18, blue: 0.48),
                                            Color(red: 0.86, green: 0.42, blue: 0.40)],
                                   startPoint: .top, endPoint: .bottom)
                }
                Color.black.opacity(dim)
                if blur {
                    Rectangle().fill(.ultraThinMaterial)
                    Color.black.opacity(0.22)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: blur)
    }
}

private struct StatusBar: View {
    let carrier: String
    let silent: Bool
    let signal: Int
    let batteryPct: Bool
    @State private var level: Float = UIDevice.current.batteryLevel

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(carrier).font(.system(size: 17, weight: .regular))
                if silent { Image(systemName: "bell.slash.fill").font(.system(size: 14, weight: .semibold)) }
            }
            Spacer()
            HStack(spacing: 7) {
                SignalBars(active: signal)
                Image(systemName: "wifi").font(.system(size: 15, weight: .semibold))
                Battery(level: level < 0 ? 1 : Double(level), showPct: batteryPct)
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            level = UIDevice.current.batteryLevel
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            level = UIDevice.current.batteryLevel
        }
    }
}

/// Fire signalstreger som i iOS: aktive hvide, resten dæmpede
private struct SignalBars: View {
    let active: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.7) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(i < active ? 1 : 0.35))
                    .frame(width: 3, height: 4.2 + CGFloat(i) * 2.5)
            }
        }
        .frame(height: 12, alignment: .bottom)
    }
}

/// iOS 26-batteri med procent i: tallet er skåret ud af fyldet
private struct Battery: View {
    let level: Double
    let showPct: Bool
    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.38))
                RoundedRectangle(cornerRadius: 4).fill(.white)
                    .frame(width: 25 * max(0.08, min(1, level)))
                if showPct {
                    Text("\(Int((level * 100).rounded()))")
                        .font(.system(size: 11.5, weight: .bold))
                        .frame(width: 25)
                        .blendMode(.destinationOut)
                }
            }
            .frame(width: 25, height: 12.5)
            .compositingGroup()
            RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.4)).frame(width: 1.4, height: 4)
        }
    }
}

/// Lommelygte/kamera: 57 pt "liquid glass"
private struct QuickButton: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 57, height: 57)
            .modifier(GlassCircle())
    }
}

private struct GlassCircle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Circle())
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ c: Content) -> some View {
        c.background(
            Circle().fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.08), .white.opacity(0.14)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .light).opacity(0.35))
        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.8))
    }
}

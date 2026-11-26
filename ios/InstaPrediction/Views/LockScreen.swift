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

                lockContent(ins: ins)
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
        .persistentSystemOverlays(.visible)
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

    private func lockContent(ins: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            if app.s.lockStatus == "lock" {
                StatusBar(carrier: app.s.lockCarrier)
                    .frame(height: max(20, ins.top * 0.9))
                    .padding(.horizontal, ins.top > 50 ? 34 : 22)
            } else {
                Color.clear.frame(height: max(20, ins.top * 0.9))
            }

            Image(systemName: blink ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(height: 26)
                .padding(.top, 6)
                .contentTransition(.symbolEffect(.replace))

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                VStack(spacing: app.s.lockClockTall ? -2 : 0) {
                    Text(Self.dateText(ctx.date))
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    ClockText(text: Self.timeText(ctx.date, sep: app.s.lockTimeSep), tall: app.s.lockClockTall)
                        .onLongPressGesture(minimumDuration: 0.5) { startSecret() }
                }
            }
            .padding(.top, 8)
            .shadow(color: .black.opacity(0.18), radius: 8, y: 2)

            Spacer()

            HStack {
                QuickButton(symbol: "flashlight.off.fill")
                Spacer()
                QuickButton(symbol: "camera.fill")
            }
            .padding(.horizontal, 46)
            .padding(.bottom, max(14, ins.bottom + 6))
        }
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

    static func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "da_DK")
        f.dateFormat = "EEEE d. MMMM"
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

private struct ClockText: View {
    let text: String
    let tall: Bool

    var body: some View {
        Text(text)
            .font(.system(size: tall ? 104 : 92, weight: tall ? .bold : .semibold))
            .fontWidth(tall ? .condensed : .standard)
            .monospacedDigit()
            .kerning(tall ? -1 : -2)
            .foregroundStyle(
                LinearGradient(colors: [.white, .white.opacity(tall ? 0.78 : 0.95)], startPoint: .top, endPoint: .bottom)
            )
            .scaleEffect(x: 1, y: tall ? 1.42 : 1, anchor: .top)
            .frame(height: tall ? 150 : 110, alignment: .top)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 20)
    }
}

private struct StatusBar: View {
    let carrier: String
    @State private var level: Float = UIDevice.current.batteryLevel

    var body: some View {
        HStack(spacing: 6) {
            Text(carrier).font(.system(size: 16, weight: .semibold))
            Spacer()
            Image(systemName: "cellularbars")
            Image(systemName: "wifi")
            Image(systemName: batterySymbol)
                .symbolRenderingMode(.hierarchical)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            level = UIDevice.current.batteryLevel
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            level = UIDevice.current.batteryLevel
        }
    }

    private var batterySymbol: String {
        guard level >= 0 else { return "battery.100percent" }
        switch level {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

private struct QuickButton: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 54, height: 54)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
            .environment(\.colorScheme, .dark)
    }
}

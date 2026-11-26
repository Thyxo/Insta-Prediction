// iOS-kode-skærm. Når alle cifre er tastet: koden sendes, prikkerne ryster som "forkert kode",
// telefonen vibrerer som en rigtig iPhone, og feltet tømmes.
import SwiftUI
import UIKit

struct PasscodeView: View {
    let length: Int
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onCode: (String) -> Void
    let onCancel: () -> Void

    @State private var code = ""
    @State private var shakes: CGFloat = 0
    @State private var locked = false

    private static let letters = ["", "ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: topInset + 44)
            Image(systemName: "lock.fill")
                .font(.system(size: 19, weight: .semibold))
                .padding(.bottom, 14)
            Text("Indtast kode")
                .font(.system(size: 20, weight: .regular))
                .padding(.bottom, 20)

            HStack(spacing: 22) {
                ForEach(0..<length, id: \.self) { i in
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.3)
                        .background(Circle().fill(i < code.count ? Color.white : .clear))
                        .frame(width: 13, height: 13)
                }
            }
            .modifier(Shake(animatableData: shakes))

            Spacer(minLength: 30)

            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 26) {
                        ForEach(1...3, id: \.self) { c in
                            let n = r * 3 + c
                            key(String(n), Self.letters[n - 1])
                        }
                    }
                }
                HStack(spacing: 26) {
                    Color.clear.frame(width: 80, height: 80)
                    key("0", "")
                    Color.clear.frame(width: 80, height: 80)
                }
            }

            Spacer(minLength: 24)

            HStack {
                Button("Nødopkald") {}
                Spacer()
                Button(code.isEmpty ? "Annuller" : "Slet") {
                    if code.isEmpty { onCancel() } else { code.removeLast() }
                }
            }
            .font(.system(size: 17))
            .padding(.horizontal, 44)
            .padding(.bottom, bottomInset + 18)
        }
        .foregroundStyle(.white)
        .tint(.white)
    }

    private func key(_ n: String, _ sub: String) -> some View {
        Button {
            press(n)
        } label: {
            VStack(spacing: -1) {
                Text(n).font(.system(size: 37, weight: .regular))
                if !sub.isEmpty {
                    Text(sub).font(.system(size: 10, weight: .bold)).kerning(2)
                }
            }
            .frame(width: 80, height: 80)
        }
        .buttonStyle(KeyStyle())
    }

    private func press(_ n: String) {
        guard !locked, code.count < length else { return }
        code += n
        guard code.count == length else { return }
        locked = true
        let entered = code
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onCode(entered)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.linear(duration: 0.5)) { shakes += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                code = ""
                locked = false
            }
        }
    }
}

private struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle().fill(.white.opacity(configuration.isPressed ? 0.55 : 0.16))
            )
            .animation(.easeOut(duration: configuration.isPressed ? 0.02 : 0.35), value: configuration.isPressed)
    }
}

/// "Forkert kode"-rystelse
private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = sin(animatableData * .pi * 8) * 14 * (1 - (animatableData - floor(animatableData)))
        return ProjectionTransform(CGAffineTransform(translationX: animatableData == floor(animatableData) ? 0 : x, y: 0))
    }
}

// Liquid glass (iOS 26) med pæn reserve på ældre iOS / ældre Xcode.
import SwiftUI

extension View {
    /// Glas-kort med afrundede hjørner
    @ViewBuilder
    func glassCard(_ radius: CGFloat = 26) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 0.7))
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 0.7))
        #endif
    }

    /// Glas-kapsel (knapper, chips). tint farver glasset.
    @ViewBuilder
    func glassCapsule(tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? Glass.regular.interactive(), in: Capsule())
        } else {
            self.background(Capsule().fill(tint?.opacity(0.85) ?? Color.white.opacity(0.10)))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.7))
        }
        #else
        self.background(Capsule().fill(tint?.opacity(0.85) ?? Color.white.opacity(0.10)))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.7))
        #endif
    }

    /// Rund glas-knap
    @ViewBuilder
    func glassCircle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.7))
        }
        #else
        self.background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.7))
        #endif
    }
}

/// Rolig baggrund med bløde farver, så glasset har noget at bryde
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.08)
            Circle().fill(Color(red: 0.42, green: 0.25, blue: 0.95).opacity(0.45))
                .frame(width: 420).blur(radius: 120).offset(x: -140, y: -300)
            Circle().fill(Color(red: 0.95, green: 0.35, blue: 0.55).opacity(0.30))
                .frame(width: 380).blur(radius: 130).offset(x: 170, y: 120)
            Circle().fill(Color(red: 1.0, green: 0.62, blue: 0.30).opacity(0.18))
                .frame(width: 300).blur(radius: 120).offset(x: -120, y: 420)
        }
        .ignoresSafeArea()
    }
}

/// Farvet ikon som i iOS' Indstillinger
struct SettingsIcon: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
    }
}

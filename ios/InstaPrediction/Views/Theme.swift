// Fælles udseende: iOS' egne grupperede lister, mørk, teal accent (som Mindtrace).
import SwiftUI

enum Theme {
    /// Teal accent
    static let accent = Color(red: 0.24, green: 0.77, blue: 0.80)
}

/// Farvet ikon som i iOS' Indstillinger
struct SettingsIcon: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
    }
}

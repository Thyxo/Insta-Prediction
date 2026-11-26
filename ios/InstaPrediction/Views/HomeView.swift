// Hovedskærmen: kun det vigtigste. Status, bio-kortet med felter, Afslør/Nulstil og Låseskærm.
import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    chips
                    bioCard
                    actions
                    lockTile
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $app.loginOpen) { LoginSheet() }
        .sheet(isPresented: $app.settingsOpen) { SettingsView() }
        .fullScreenCover(isPresented: $app.lockOpen) { LockScreen().environment(app) }
    }

    // MARK: Dele

    private var header: some View {
        HStack {
            Text("Bio").font(.system(size: 34, weight: .bold, design: .rounded))
            Spacer()
            Button { app.settingsOpen = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .glassCircle()
            }
            .buttonStyle(.plain)
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            Button {
                if !app.loggedIn { app.loginOpen = true }
            } label: {
                chip(app.loggedIn ? (app.username.isEmpty ? "Logget ind" : "@\(app.username)") : "Log ind",
                     dot: app.loggedIn ? .green : .gray)
            }
            .buttonStyle(.plain)
            if app.s.practice {
                Button { app.s.practice = false } label: { chip("Øve", dot: .orange) }
                    .buttonStyle(.plain)
            }
            if app.s.useRelay && RelayClient.clean(app.s.room).count >= 3 {
                chip("Relæ", dot: app.relayStatus == "online" ? .green : .yellow)
            }
            Spacer()
        }
    }

    private func chip(_ text: String, dot: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(text).font(.footnote.weight(.semibold)).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassCapsule()
    }

    private var bioCard: some View {
        @Bindable var app = app
        let r = app.rendered
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Menu {
                    Picker("Skabelon", selection: $app.s.activeTemplate) {
                        ForEach(app.s.templates) { t in Text(t.name).tag(t.id.uuidString) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(app.template.name)
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .glassCapsule()
                }
                Spacer()
                Text("\(r.length)/\(TemplateEngine.bioLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(r.tooLong ? .red : .secondary)
            }

            Text(r.text.isEmpty ? " " : r.text)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.snappy, value: r.text)

            if !app.fields.isEmpty {
                VStack(spacing: 8) {
                    ForEach(app.fields, id: \.self) { key in
                        HStack(spacing: 10) {
                            Text(key)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            TextField(placeholder(key), text: Binding(
                                get: { app.values[key]?.text ?? "" },
                                set: { app.setManual(key, $0) }
                            ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            if let v = app.values[key], v.source != "manuelt" {
                                Image(systemName: v.source == "låseskærm" ? "lock.fill" : "antenna.radiowaves.left.and.right")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    Task { await app.reveal() }
                } label: {
                    HStack(spacing: 8) {
                        if app.busy { ProgressView().tint(.white) } else { Image(systemName: "sparkles") }
                        Text("Afslør").font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .glassCapsule(tint: Color(red: 0.55, green: 0.35, blue: 1.0))
                }
                .buttonStyle(.plain)
                .disabled(app.busy)

                Button {
                    Task { await app.resetBio() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(width: 72, height: 56)
                        .glassCapsule()
                }
                .buttonStyle(.plain)
                .disabled(app.busy)
                .accessibilityLabel("Nulstil bio")
            }
            if let last = app.log.first {
                Text(last.text)
                    .font(.footnote)
                    .foregroundStyle(color(last.kind))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.log.first?.id)
    }

    private var lockTile: some View {
        Button { app.lockOpen = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.iphone")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(
                        LinearGradient(colors: [Color(red: 0.36, green: 0.33, blue: 0.95), Color(red: 0.85, green: 0.30, blue: 0.60)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Låseskærm").font(.headline)
                    Text(lockSubtitle).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .glassCard(22)
        }
        .buttonStyle(.plain)
    }

    private var lockSubtitle: String {
        let mode = LockInput.modes.first { $0.id == app.s.lockMode }?.label ?? app.s.lockMode
        return "\(mode) → {\(app.s.lockField)}"
    }

    private func placeholder(_ key: String) -> String {
        switch key {
        case "kort": "fx kh"
        case "tal": "fx 42"
        case "dato": "fx 24. december"
        default: "Skriv \(key)"
        }
    }

    private func color(_ k: LogLine.Kind) -> Color {
        switch k {
        case .info: .secondary
        case .ok: .green
        case .warn: .orange
        case .error: .red
        }
    }
}

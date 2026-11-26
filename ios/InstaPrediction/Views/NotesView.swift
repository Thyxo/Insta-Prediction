// Falsk Noter-app (iOS 26, mørk). Tilskueren skriver sin tanke; ved "Færdig" (✓) eller tilbage
// tager Bio teksten (NoteInput) og afslører i bioen. Ud til Bio: 5 hurtige tryk øverst til højre.
import SwiftUI
import UIKit

private let notesYellow = UIColor.systemYellow

struct NotesView: View {
    @Environment(AppState.self) private var app
    @State private var text = ""
    @State private var editing = false
    @State private var showList = false
    @State private var opened = Date()
    @State private var exitTaps: [Date] = []

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if showList {
                NotesList(title: firstLine, preview: secondLine, date: opened,
                          open: { withAnimation(.snappy) { showList = false } },
                          compose: {
                              text = ""; opened = Date()
                              withAnimation(.snappy) { showList = false }
                              DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { editing = true }
                          })
                .transition(.move(edge: .leading))
            } else {
                editor.transition(.move(edge: .trailing))
            }
            exitZone
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .onAppear {
            text = app.s.noteStart.isEmpty ? "" : app.s.noteStart + "\n"
            opened = Date()
        }
    }

    // MARK: Editor

    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { editing = false; withAnimation(.snappy) { showList = true } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .notesGlass(Circle())
                }
                Spacer()
                HStack(spacing: 2) {
                    if editing {
                        icon("arrow.uturn.backward")
                    }
                    icon("square.and.arrow.up")
                    icon("ellipsis")
                }
                .padding(.horizontal, 6)
                .frame(height: 44)
                .notesGlass(Capsule())
                if editing {
                    Button { editing = false } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color(notesYellow)))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(Color(notesYellow))
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .animation(.snappy, value: editing)

            NoteTextView(text: $text, editing: $editing, date: opened) { final in
                app.noteCaptured(final)
                if app.s.noteClear, NoteInput.extract(final, mode: app.s.noteMode) != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { text = "" }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !editing { bottomBar }
        }
    }

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 4) {
                icon("checklist")
                icon("paperclip")
                icon("pencil.tip.crop.circle")
            }
            .padding(.horizontal, 6)
            .frame(height: 48)
            .notesGlass(Capsule())
            Spacer()
            Button {
                text = ""; opened = Date(); editing = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 48, height: 48)
                    .notesGlass(Circle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color(notesYellow))
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .frame(width: 40, height: 40)
    }

    // MARK: Ud til Bio

    private var exitZone: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(app.s.lockShowZones ? Color.yellow.opacity(0.18) : Color.clear)
                .frame(width: 90, height: 54)
                .contentShape(Rectangle())
                .onTapGesture {
                    let now = Date()
                    exitTaps = exitTaps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
                    if exitTaps.count >= 5 {
                        exitTaps = []
                        editing = false
                        app.notesOpen = false
                    }
                }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var lines: [String] {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var firstLine: String { lines.first ?? "Ny note" }
    private var secondLine: String { lines.dropFirst().first ?? "Ingen yderligere tekst" }
}

// MARK: Noteliste ("‹ Mapper · Noter")

private struct NotesList: View {
    let title: String
    let preview: String
    let date: Date
    let open: () -> Void
    let compose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .notesGlass(Circle())
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .notesGlass(Circle())
            }
            .foregroundStyle(Color(notesYellow))
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Text("Noter")
                .font(.system(size: 34, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Text("I dag")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 8)

            Button(action: open) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(date, format: .dateTime.hour().minute()).foregroundStyle(.secondary)
                        Text(preview).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .font(.system(size: 15))
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Noter")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.11)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            Spacer()

            HStack {
                Spacer()
                Text("1 note").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button(action: compose) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(notesYellow))
                        .frame(width: 48, height: 48)
                        .notesGlass(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
    }
}

// MARK: Tekstfelt som i Noter: første linje er overskrift

private struct NoteTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var editing: Bool
    let date: Date
    let onEnd: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> NoteUITextView {
        let tv = NoteUITextView()
        tv.backgroundColor = .clear
        tv.textColor = .white
        tv.tintColor = notesYellow
        tv.keyboardAppearance = .dark
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
        tv.textContainerInset = UIEdgeInsets(top: 34, left: 16, bottom: 140, right: 16)
        tv.delegate = context.coordinator
        tv.text = text
        Self.style(tv)
        return tv
    }

    func updateUIView(_ tv: NoteUITextView, context: Context) {
        context.coordinator.parent = self
        tv.dateLabel.text = Self.dateText(date)
        if tv.text != text {
            tv.text = text
            Self.style(tv)
        }
        if editing, !tv.isFirstResponder {
            DispatchQueue.main.async { tv.becomeFirstResponder() }
        } else if !editing, tv.isFirstResponder {
            DispatchQueue.main.async { tv.resignFirstResponder() }
        }
    }

    static func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "da_DK")
        f.dateFormat = "d. MMMM y 'kl.' HH.mm"
        return f.string(from: d)
    }

    /// Overskrift (første linje) 28 pt fed, resten 17 pt
    static func style(_ tv: UITextView) {
        guard tv.markedTextRange == nil else { return }
        let title = UIFont.systemFont(ofSize: 28, weight: .bold)
        let body = UIFont.systemFont(ofSize: 17)
        let ns = tv.text as NSString
        let firstEnd = ns.range(of: "\n").location
        let titleLen = firstEnd == NSNotFound ? ns.length : firstEnd
        let sel = tv.selectedRange
        let st = tv.textStorage
        st.beginEditing()
        st.setAttributes([.font: body, .foregroundColor: UIColor.white], range: NSRange(location: 0, length: ns.length))
        if titleLen > 0 {
            st.addAttributes([.font: title], range: NSRange(location: 0, length: titleLen))
        }
        st.endEditing()
        if tv.selectedRange != sel { tv.selectedRange = sel }
        typing(tv)
    }

    /// Skriv med overskrift-skrift på første linje, ellers brødtekst
    static func typing(_ tv: UITextView) {
        let ns = tv.text as NSString
        let firstEnd = ns.range(of: "\n").location
        let inTitle = firstEnd == NSNotFound || tv.selectedRange.location <= firstEnd
        tv.typingAttributes = [.font: UIFont.systemFont(ofSize: inTitle ? 28 : 17, weight: inTitle ? .bold : .regular),
                               .foregroundColor: UIColor.white]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteTextView
        init(_ p: NoteTextView) { parent = p }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            NoteTextView.style(tv)
        }
        func textViewDidChangeSelection(_ tv: UITextView) {
            NoteTextView.typing(tv)
        }
        func textViewDidBeginEditing(_ tv: UITextView) {
            if !parent.editing { parent.editing = true }
        }
        func textViewDidEndEditing(_ tv: UITextView) {
            if parent.editing { parent.editing = false }
            parent.onEnd(tv.text)
        }
    }
}

/// UITextView med datoen centreret øverst (ruller med teksten, som i Noter)
final class NoteUITextView: UITextView {
    let dateLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .center
        addSubview(dateLabel)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        dateLabel.frame = CGRect(x: 0, y: 6, width: bounds.width, height: 18)
    }
}

// MARK: Glas

private extension View {
    @ViewBuilder
    func notesGlass<S: Shape>(_ shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.7))
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.7))
        #endif
    }
}

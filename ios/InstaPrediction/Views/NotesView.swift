// Falsk Noter-app (iOS 26, mørk). Tilskueren skriver sin tanke; ved "Færdig" (✓) eller tilbage
// tager Bio teksten (NoteInput) og afslører i bioen. Ud til Bio: 5 hurtige tryk øverst til højre.
import SwiftUI
import UIKit

/// Markør og Færdig-knap (målt på iOS 26 Noter)
private let notesGold = UIColor(red: 0.89, green: 0.70, blue: 0.24, alpha: 1)
private let checkFill = Color(red: 0.85, green: 0.70, blue: 0.22)
private let checkMark = Color(red: 1.0, green: 0.90, blue: 0.32)
private let dimmed = Color(white: 0.42)

/// Mål i punkter, aflæst fra skærmbilleder af ægte Noter (iPhone 393 pt bred)
private enum M {
    static let side: CGFloat = 16          // knapper øverst fra kant
    static let button: CGFloat = 44        // runde knapper og kapsel-højde
    static let capItem: CGFloat = 46       // del-knap / … i kapslen
    static let checkGap: CGFloat = 13      // kapsel → Færdig
    static let barSide: CGFloat = 28       // bundlinje fra kant
    static let bar: CGFloat = 47           // bundlinje højde
    static let barItem: CGFloat = 55       // afstand mellem ikoner i bundlinjen
    static let kbSide: CGFloat = 13        // værktøjslinje over tastatur fra kant
    static let kbItem: CGFloat = 56.5
    static let kbGap: CGFloat = 13         // værktøjslinje → tastatur
}

struct NotesView: View {
    @Environment(AppState.self) private var app
    @State private var text = ""
    @State private var editing = false
    @State private var showList = false
    @State private var showDate = true
    @State private var opened = Date()
    @State private var exitTaps: [Date] = []

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if showList {
                NotesList(title: firstLine, preview: secondLine, date: opened,
                          open: { withAnimation(.snappy) { showList = false } },
                          compose: {
                              newNote()
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
            showDate = true
        }
    }

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func newNote() {
        text = ""
        opened = Date()
        showDate = false   // ny note: ingen dato før den er gemt (som i Noter)
    }

    // MARK: Editor

    private var editor: some View {
        VStack(spacing: 0) {
            topBar
            NoteTextView(text: $text, editing: $editing, date: opened, showDate: showDate) { final in
                app.noteCaptured(final)
                if app.s.noteClear, NoteInput.extract(final, mode: app.s.noteMode) != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { text = "" }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if editing { keyboardBar } else { bottomBar.offset(y: 5) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button { editing = false; withAnimation(.snappy) { showList = true } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: M.button, height: M.button)
                    .notesGlass(Circle())
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(isEmpty ? dimmed : .white)
                    .frame(width: M.capItem, height: M.button)
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: M.capItem, height: M.button)
            }
            .notesGlass(Capsule())
            if editing {
                Button { editing = false } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(checkMark)
                        .frame(width: M.button, height: M.button)
                        .notesGlass(Circle(), tint: checkFill)
                }
                .padding(.leading, M.checkGap)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal, M.side)
        .animation(.snappy(duration: 0.25), value: editing)
    }

    /// Uden tastatur: kapsel med 4 værktøjer + ny note
    private var bottomBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                tool("checklist")
                tool("paperclip")
                tool("pencil.tip.crop.circle")
                tool("apple.writing.tools", fallback: "wand.and.stars")
            }
            .frame(height: M.bar)
            .notesGlass(Capsule())
            Spacer()
            Button {
                newNote()
                editing = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isEmpty ? dimmed : .white)
                    .frame(width: M.bar, height: M.bar)
                    .notesGlass(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isEmpty)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, M.barSide)
    }

    /// Over tastaturet: lang kapsel, sidste knap skåret af i kanten (den kan rulles i Noter)
    private var keyboardBar: some View {
        HStack(spacing: 0) {
            tool("textformat", width: M.kbItem, size: 24)
            tool("checklist", width: M.kbItem)
            tool("tablecells", width: M.kbItem)
            tool("paperclip", width: M.kbItem)
            tool("pencil.tip.crop.circle", width: M.kbItem)
            tool("apple.writing.tools", fallback: "wand.and.stars", width: M.kbItem)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: M.bar, maxHeight: M.bar)
        .overlay(alignment: .trailing) {
            Circle().fill(checkFill)
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: "rectangle.split.3x1").font(.system(size: 13, weight: .bold)).foregroundStyle(checkMark).offset(x: -8))
                .offset(x: 15)
        }
        .clipShape(Capsule())
        .notesGlass(Capsule())
        .foregroundStyle(.white)
        .padding(.horizontal, M.kbSide)
        .padding(.bottom, M.kbGap)
    }

    private func tool(_ name: String, fallback: String? = nil, width: CGFloat = M.barItem, size: CGFloat = 22) -> some View {
        let sym = UIImage(systemName: name) != nil ? name : (fallback ?? name)
        return Image(systemName: sym)
            .font(.system(size: size, weight: .regular))
            .frame(width: width, height: M.bar)
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
            .foregroundStyle(.white)
            .padding(.horizontal, 16)

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
                        .foregroundStyle(.white)
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
    let showDate: Bool
    let onEnd: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> NoteUITextView {
        let tv = NoteUITextView()
        tv.backgroundColor = .clear
        tv.textColor = .white
        tv.tintColor = notesGold
        tv.keyboardAppearance = .dark
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
        tv.textContainerInset = Self.insets(showDate)
        tv.delegate = context.coordinator
        tv.text = text
        Self.style(tv)
        return tv
    }

    func updateUIView(_ tv: NoteUITextView, context: Context) {
        context.coordinator.parent = self
        tv.dateLabel.text = Self.dateText(date)
        tv.dateLabel.isHidden = !showDate
        if tv.textContainerInset != Self.insets(showDate) { tv.textContainerInset = Self.insets(showDate) }
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

    /// Markøren står 27 pt fra kanten; 35 pt under knapperne med dato, 16 pt uden
    static func insets(_ date: Bool) -> UIEdgeInsets {
        UIEdgeInsets(top: date ? 34 : 15, left: 22, bottom: 140, right: 22)
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
        dateLabel.font = .systemFont(ofSize: 15)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .center
        addSubview(dateLabel)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        dateLabel.frame = CGRect(x: 0, y: 9, width: bounds.width, height: 20)
    }
}

// MARK: Glas

private extension View {
    @ViewBuilder
    func notesGlass<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? Glass.regular.interactive(), in: shape)
        } else {
            self.background(shape.fill(tint ?? Color(white: 0.11)))
                .overlay(shape.stroke(.white.opacity(0.10), lineWidth: 0.7))
        }
        #else
        self.background(shape.fill(tint ?? Color(white: 0.11)))
            .overlay(shape.stroke(.white.opacity(0.10), lineWidth: 0.7))
        #endif
    }
}

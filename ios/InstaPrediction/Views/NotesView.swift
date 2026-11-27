// Falsk Noter-app, klonet fra ejerens skærmoptagelse af iOS 26 Noter.
// Bygget på iOS' egen navigation (NavigationStack, værktøjslinjer, søgefelt, swipe-handlinger),
// så glas, animationer, stryg-tilbage og menuer er de ægte. Kun værktøjslinjen over tastaturet er tegnet.
//
// Tilskueren skriver i en ny note. Ved ✓ eller tilbage tager Bio teksten (NoteInput) og afslører.
// Kun noter oprettet i denne omgang tæller, så du kan rette dine egne noter uden at afsløre noget.
// Ud til Bio: 5 hurtige tryk øverst til højre (over batteriet) eller hold øverst til venstre i 1 sek.
import SwiftUI
import UIKit

private let notesGold = UIColor(red: 0.89, green: 0.70, blue: 0.24, alpha: 1)
private let gold = Color(notesGold)

@available(iOS 26.0, *)
struct NotesView: View {
    @Environment(AppState.self) private var app
    @State private var path: [UUID] = []
    @State private var search = ""
    @State private var session: Set<UUID> = []
    @State private var dated: Set<UUID> = []
    @State private var pinnedOpen = true
    @State private var exitTaps: [Date] = []
    @State private var started = false

    var body: some View {
        NavigationStack(path: $path) {
            list
                .navigationDestination(for: UUID.self) { id in
                    NoteEditor(id: id,
                               counts: session.contains(id),
                               showDate: dated.contains(id),
                               compose: { compose(replacing: true) },
                               delete: { delete(id); if !path.isEmpty { path.removeLast() } })
                }
        }
        .tint(gold)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) { exitZones }
        .onAppear(perform: start)
        .onAppear { app.notesShown(true) }
        .onDisappear { app.notesShown(false) }
    }

    // MARK: Start og ud

    private func start() {
        guard !started else { return }
        started = true
        guard app.s.noteOpen == "ny" else { return }
        let n = FakeNote(text: app.s.noteStart.isEmpty ? "" : app.s.noteStart + "\n", date: Date())
        app.fakeNotes.append(n)
        session.insert(n.id)
        dated.insert(n.id)   // åbnes som en note, der allerede findes (med dato øverst)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { path = [n.id] }
    }

    private func leave() {
        exitTaps = []
        app.fakeNotes.removeAll { $0.isEmpty }
        app.notesOpen = false
    }

    private var exitZones: some View {
        HStack {
            Rectangle().fill(app.s.lockShowZones ? Color.yellow.opacity(0.2) : Color.clear)
                .frame(width: 90, height: 56)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 1) { leave() }
            Spacer()
            Rectangle().fill(app.s.lockShowZones ? Color.yellow.opacity(0.2) : Color.clear)
                .frame(width: 90, height: 56)
                .contentShape(Rectangle())
                .onTapGesture {
                    let now = Date()
                    exitTaps = exitTaps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
                    if exitTaps.count >= 5 { leave() }
                }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Noter

    private func compose(replacing: Bool) {
        let n = FakeNote(text: "", date: Date())
        app.fakeNotes.append(n)
        session.insert(n.id)
        if replacing, !path.isEmpty {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { path.removeLast() }
            DispatchQueue.main.async { path.append(n.id) }
        } else {
            path.append(n.id)
        }
    }

    private func delete(_ id: UUID) {
        withAnimation { app.fakeNotes.removeAll { $0.id == id } }
    }

    private func togglePin(_ id: UUID) {
        guard let i = app.fakeNotes.firstIndex(where: { $0.id == id }) else { return }
        withAnimation { app.fakeNotes[i].pinned.toggle() }
    }

    // MARK: Liste

    private var list: some View {
        let now = Date()
        let notes = FakeNotes.filter(app.fakeNotes.filter { !$0.isEmpty }, search)
        let sections = FakeNotes.sections(notes, now: now)
        return List {
            ForEach(sections) { sec in
                Section {
                    if sec.title != "Fastgjort" || pinnedOpen {
                        ForEach(sec.notes) { n in row(n, now: now) }
                    }
                } header: {
                    HStack {
                        Text(sec.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        if sec.title == "Fastgjort" {
                            Button {
                                withAnimation(.snappy) { pinnedOpen.toggle() }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(gold)
                                    .rotationEffect(.degrees(pinnedOpen ? 0 : -90))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .textCase(nil)
                    .padding(.leading, -4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(18)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Noter")
        .navigationBarTitleDisplayMode(.large)
        .toolbarRole(.editor)
        .searchable(text: $search, prompt: "Søg")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { } label: { Image(systemName: "chevron.left") }
                    .tint(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section {
                        Button { } label: { Label("Vis som galleri", systemImage: "square.grid.2x2") }
                        Button { } label: { Label("Vælg noter", systemImage: "checkmark.circle") }
                    }
                    Section {
                        Button { } label: { Label("Sortér efter", systemImage: "arrow.up.arrow.down") }
                        Button { } label: { Label("Gruppér efter dato", systemImage: "calendar") }
                        Button { } label: { Label("Vis vedhæftede filer", systemImage: "paperclip") }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .tint(.white)
            }
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button { compose(replacing: false) } label: { Image(systemName: "square.and.pencil") }
                    .tint(.white)
            }
        }
    }

    private func row(_ n: FakeNote, now: Date) -> some View {
        Button {
            path.append(n.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(n.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 7) {
                    Text(FakeNotes.dateLabel(n.date, now: now))
                    Text(n.preview).lineLimit(1)
                }
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.56))
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .listRowBackground(Color(white: 0.11))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(n.id) } label: { Label("Slet", systemImage: "trash") }
            Button { } label: { Label("Flyt", systemImage: "folder") }
                .tint(.indigo)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { togglePin(n.id) } label: {
                Label(n.pinned ? "Frigør" : "Fastgør", systemImage: n.pinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(.orange)
        }
    }
}

// MARK: Note

@available(iOS 26.0, *)
private struct NoteEditor: View {
    @Environment(AppState.self) private var app
    let id: UUID
    let counts: Bool          // tæller som tilskuerens note
    let showDate: Bool
    let compose: () -> Void
    let delete: () -> Void

    @State private var text = ""
    @State private var editing = false
    @State private var formatBar = false
    @State private var loaded = false
    @State private var ref = TextViewRef()

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var note: FakeNote? { app.fakeNotes.first { $0.id == id } }

    var body: some View {
        NoteTextView(text: $text, editing: $editing, date: note?.date ?? Date(), showDate: showDate, ref: ref) { final in
            capture(final)
        }
        .background(Color.black)
        .overlay(alignment: .bottom) {
            if editing { keyboardBar.transition(.opacity) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar(editing ? .hidden : .visible, for: .bottomBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: text) { Image(systemName: "square.and.arrow.up") }
                    .disabled(isEmpty)
                    .tint(.white)
                Menu {
                    Section {
                        Button { ref.find() } label: { Label("Find i note", systemImage: "magnifyingglass") }
                        Button { } label: { Label("Flyt note", systemImage: "folder") }
                        Button { } label: { Label("Linjer og gitre", systemImage: "rectangle.split.3x3") }
                    }
                    Section {
                        Button {
                            if let i = app.fakeNotes.firstIndex(where: { $0.id == id }) { app.fakeNotes[i].pinned.toggle() }
                        } label: {
                            Label(note?.pinned == true ? "Frigør" : "Fastgør", systemImage: note?.pinned == true ? "pin.slash" : "pin")
                        }
                        Button { } label: { Label("Lås", systemImage: "lock") }
                    }
                    Section {
                        Button(role: .destructive) { delete() } label: { Label("Slet", systemImage: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .tint(.white)
            }
            if editing {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = false } label: { Image(systemName: "checkmark") }
                        .buttonStyle(.glassProminent)
                        .tint(gold)
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button { } label: { Image(systemName: "checklist") }
                attachMenu
                Button { } label: { Image(systemName: "pencil.tip.crop.circle") }
                Button { ref.writingTools() } label: { Image(systemName: "apple.writing.tools") }
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button { compose() } label: { Image(systemName: "square.and.pencil") }
                    .disabled(isEmpty)
            }
        }
        .tint(.white)
        .animation(.snappy(duration: 0.25), value: editing)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = note?.text ?? ""
            if counts { app.activeNoteID = id }
            if counts && !showDate {   // ny note: tastaturet kommer med det samme (som i Noter)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if isEmpty { editing = true } }
            }
        }
        .onChange(of: text) { _, t in
            formatBar = false
            if counts { app.noteTyped(t) }
            if let i = app.fakeNotes.firstIndex(where: { $0.id == id }), app.fakeNotes[i].text != t {
                app.fakeNotes[i].text = t
                app.fakeNotes[i].date = Date()
            }
        }
        .onDisappear {
            if app.activeNoteID == id { app.activeNoteID = nil }
            capture(text)
            if isEmpty { app.fakeNotes.removeAll { $0.id == id } }
        }
    }

    private func capture(_ final: String) {
        guard counts else { return }
        app.noteCaptured(final)
        if app.s.noteClear, NoteInput.extract(final, mode: app.s.noteMode) != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { text = "" }
        }
    }

    private var attachMenu: some View {
        Menu {
            Button { } label: { Label("Vælg foto eller video", systemImage: "photo.on.rectangle") }
            Button { } label: { Label("Tag foto eller video", systemImage: "camera") }
            Button { } label: { Label("Scan dokumenter", systemImage: "doc.viewfinder") }
            Button { } label: { Label("Scan tekst", systemImage: "text.viewfinder") }
            Button { } label: { Label("Vedhæft fil", systemImage: "doc") }
        } label: {
            Image(systemName: "paperclip")
        }
    }

    // MARK: Værktøjslinje over tastaturet (som i Noter: kan rulles, sidste knap skåret af)

    private var keyboardBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                if formatBar {
                    key("bold") { ref.send("toggleBoldface:") }
                    key("italic") { ref.send("toggleItalics:") }
                    key("underline") { ref.send("toggleUnderline:") }
                    key("strikethrough") { }
                    key("highlighter") { }
                    key("link") { }
                    key("list.bullet") { }
                    key("list.number") { }
                    key("increase.indent") { }
                    key("decrease.indent") { }
                    key("text.quote") { }
                } else {
                    Button { formatBar = true } label: {
                        Text("Aa").font(.system(size: 22, weight: .regular)).frame(width: 56.5, height: 47)
                    }
                    key("checklist") { }
                    key("tablecells") { }
                    Menu {
                        Button { } label: { Label("Vælg foto eller video", systemImage: "photo.on.rectangle") }
                        Button { } label: { Label("Tag foto eller video", systemImage: "camera") }
                        Button { } label: { Label("Scan dokumenter", systemImage: "doc.viewfinder") }
                        Button { } label: { Label("Vedhæft fil", systemImage: "doc") }
                    } label: {
                        Image(systemName: "paperclip").font(.system(size: 21)).frame(width: 56.5, height: 47)
                    }
                    key("pencil.tip.crop.circle") { }
                    key("apple.writing.tools") { ref.writingTools() }
                    if isEmpty {
                        Circle().fill(gold).frame(width: 38, height: 38)
                            .overlay(Image(systemName: "rectangle.split.3x1").font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.32)))
                            .padding(.leading, 6)
                    } else {
                        key("text.justify.left") { }
                    }
                    key("list.bullet.indent") { }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 47)
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .clipShape(Capsule())
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.horizontal, 13)
        .padding(.bottom, 13)
    }

    private func key(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .regular))
                .frame(width: 56.5, height: 47)
                .contentShape(Rectangle())
        }
    }
}

// MARK: Tekstfeltet

/// Giver knapperne adgang til tekstfeltet (fed, find, skriveværktøjer)
final class TextViewRef {
    weak var tv: UITextView?

    func send(_ action: String) {
        let sel = NSSelectorFromString(action)
        guard let tv, tv.responds(to: sel) else { return }
        tv.perform(sel, with: nil)
    }

    func writingTools() {
        guard let tv else { return }
        if !tv.isFirstResponder { tv.becomeFirstResponder() }
        send("showWritingTools:")
    }

    func find() {
        tv?.findInteraction?.presentFindNavigator(showingReplace: false)
    }
}

/// Som i Noter: første linje er overskrift. Dato øverst kun på en note, der "fandtes" i forvejen.
private struct NoteTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var editing: Bool
    let date: Date
    let showDate: Bool
    let ref: TextViewRef
    let onEnd: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> NoteUITextView {
        let tv = NoteUITextView()
        tv.backgroundColor = .black
        tv.textColor = .white
        tv.tintColor = notesGold
        tv.keyboardAppearance = .dark
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
        tv.isFindInteractionEnabled = true
        tv.allowsEditingTextAttributes = true
        tv.textContainerInset = Self.insets(showDate)
        tv.delegate = context.coordinator
        tv.text = text
        Self.style(tv)
        ref.tv = tv
        return tv
    }

    func updateUIView(_ tv: NoteUITextView, context: Context) {
        context.coordinator.parent = self
        ref.tv = tv
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

    static func insets(_ date: Bool) -> UIEdgeInsets {
        UIEdgeInsets(top: date ? 34 : 15, left: 22, bottom: 160, right: 22)
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
        let ns = tv.text as NSString
        let firstEnd = ns.range(of: "\n").location
        let titleLen = firstEnd == NSNotFound ? ns.length : firstEnd
        let sel = tv.selectedRange
        let st = tv.textStorage
        st.beginEditing()
        st.setAttributes([.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.white],
                         range: NSRange(location: 0, length: ns.length))
        if titleLen > 0 {
            st.addAttributes([.font: UIFont.systemFont(ofSize: 28, weight: .bold)], range: NSRange(location: 0, length: titleLen))
        }
        st.endEditing()
        if tv.selectedRange != sel { tv.selectedRange = sel }
        typing(tv)
    }

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
        func textViewDidChangeSelection(_ tv: UITextView) { NoteTextView.typing(tv) }
        func textViewDidBeginEditing(_ tv: UITextView) { if !parent.editing { parent.editing = true } }
        func textViewDidEndEditing(_ tv: UITextView) {
            if parent.editing { parent.editing = false }
            parent.onEnd(tv.text)
        }

        /// Ingen "Autoudfyld"-boble (den har Noter ikke)
        func textView(_ tv: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            UIMenu(children: suggestedActions.filter { el in
                if let m = el as? UIMenu, m.identifier.rawValue.lowercased().contains("autofill") { return false }
                let t = (el as? UIAction)?.title ?? (el as? UIMenu)?.title ?? ""
                return !t.localizedCaseInsensitiveContains("autoudfyld") && !t.localizedCaseInsensitiveContains("autofill")
            })
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

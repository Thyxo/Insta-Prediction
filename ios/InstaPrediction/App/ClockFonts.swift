// Apples urskrifter (fx SFAdaptiveNumeric-VF.otf fra iOS 26.3) gemmes kun på telefonen
// (Application Support/Fonts). De må ikke ligge i det offentlige repo eller IPA'en.
// Kilder: iOS selv (findOnDevice), zip/otf fra Filer, Bio-mappen i Filer (scanDocuments) eller et link.
// Variable akser (HGHT, wght, wdth) sættes via CoreText.
import CoreText
import Foundation
import UIKit

enum ClockFonts {
    /// Den skrift iOS 26's høje låseskærm-ur bruger
    static let preferred = "SFAdaptiveNumeric-VF.otf"

    static var dir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func list() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.filter { f in [".otf", ".ttf", ".ttc"].contains { f.lowercased().hasSuffix($0) } }.sorted()
    }

    /// Kopiér valgte filer ind (fra Filer/AirDrop). Zip-filer pakkes ud. Returnerer navnene på skrifterne.
    @discardableResult
    static func importFiles(_ urls: [URL]) -> [String] {
        var out: [String] = []
        for u in urls {
            let scoped = u.startAccessingSecurityScopedResource()
            defer { if scoped { u.stopAccessingSecurityScopedResource() } }
            var data: Data?
            NSFileCoordinator().coordinate(readingItemAt: u, options: [.withoutChanges], error: nil) { url in
                data = try? Data(contentsOf: url)
            }
            if let data { out += importData(name: u.lastPathComponent, data: data) }
        }
        return out
    }

    /// En skrift- eller zip-fil som data
    static func importData(name: String, data: Data) -> [String] {
        let isZip = data.prefix(4) == Data([0x50, 0x4b, 0x03, 0x04]) || name.lowercased().hasSuffix(".zip")
        var out: [String] = []
        if isZip {
            for e in ZipReader.entries(data) {
                let file = (e.name as NSString).lastPathComponent
                guard !e.name.contains("__MACOSX"), !file.hasPrefix("."),
                      ["otf", "ttf", "ttc"].contains((file as NSString).pathExtension.lowercased()),
                      let d = ZipReader.extract(data, e) else { continue }
                if save(file, d) { out.append(file) }
            }
        } else {
            var file = name
            if !["otf", "ttf", "ttc"].contains((file as NSString).pathExtension.lowercased()) { file += ".otf" }
            if save(file, data) { out.append(file) }
        }
        cache.removeAll()
        return out
    }

    private static func save(_ file: String, _ d: Data) -> Bool {
        let dest = dir.appendingPathComponent(file)
        try? FileManager.default.removeItem(at: dest)
        names[file] = nil
        registered.remove(file)
        guard (try? d.write(to: dest, options: .atomic)) != nil, postScriptName(for: file) != nil else {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
        return true
    }

    /// Skrift- og zip-filer lagt i appens mappe i Filer ("Bio" / Documents) hentes ind automatisk
    @discardableResult
    static func scanDocuments() -> [String] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let en = FileManager.default.enumerator(at: docs, includingPropertiesForKeys: nil) else { return [] }
        var out: [String] = []
        for case let u as URL in en {
            let ext = u.pathExtension.lowercased()
            guard ["otf", "ttf", "ttc", "zip"].contains(ext), let d = try? Data(contentsOf: u) else { continue }
            let got = importData(name: u.lastPathComponent, data: d)
            if !got.isEmpty {
                out += got
                try? FileManager.default.removeItem(at: u)   // ryd op, skriften ligger nu i appen
            }
        }
        // En tom mappe gør, at "Bio" vises i Filer
        let hint = docs.appendingPathComponent("Læg skrifter her.txt")
        if !FileManager.default.fileExists(atPath: hint.path) {
            try? "Læg SFAdaptiveNumeric-VF.otf eller hele zip-filen med urskrifter i denne mappe, og åbn Bio.".write(to: hint, atomically: true, encoding: .utf8)
        }
        return out
    }

    static func delete(_ file: String) {
        let u = dir.appendingPathComponent(file)
        CTFontManagerUnregisterFontsForURL(u as CFURL, .process, nil)
        try? FileManager.default.removeItem(at: u)
        cache.removeAll()
        registered.remove(file)
    }

    /// Skriften der skal bruges: den valgte, ellers SFAdaptiveNumeric, ellers ingen (tegnet systemskrift)
    static func resolve(_ chosen: String) -> String? {
        let all = list()
        if !chosen.isEmpty, all.contains(chosen) { return chosen }
        if all.contains(preferred) { return preferred }
        return nil
    }

    // MARK: CoreText

    private static var registered: Set<String> = []
    private static var names: [String: String] = [:]
    private static var cache: [String: CTFont] = [:]

    static func postScriptName(for file: String) -> String? {
        if let n = names[file] { return n }
        let url = dir.appendingPathComponent(file)
        // Virker for .otf, .ttf og .ttc (første skrift i samlingen)
        guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descs.first,
              let name = CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String else { return nil }
        if !registered.contains(file) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            registered.insert(file)
        }
        names[file] = name
        return name
    }

    // MARK: Find skrifterne på telefonen

    /// Låseskærmens urskrifter (iOS 16+) ligger i systemet. Navnene fra iOS 26.3.
    static let systemStems = [
        "SFAdaptiveNumeric", "SFAdaptiveSoftNumeric", "SFNumeric", "SFSoftNumeric", "SFRoundedNumeric",
        "SFStencilNumeric", "SFRailNumeric", "SFRailRoundedNumeric", "NewYorkNumeric", "NewYorkSoftNumeric",
        "ADTSlabNumeric", "ADTSlabSoftNumeric", "SFCompactSoft",
    ]

    /// Søger i iOS' egne skrift-mapper og kopierer urskrifterne til appen (kun til eget brug på telefonen).
    /// Kører uden for main-tråden. Returnerer kopierede filnavne og en kort log.
    static func findOnDevice() -> (found: [String], log: [String]) {
        let fm = FileManager.default
        let roots = [
            "/System/Library/PrivateFrameworks/FontServices.framework",
            "/System/Library/Fonts",
            "/System/Library/PrivateFrameworks/SpringBoardFoundation.framework",
            "/System/Library/PrivateFrameworks/PosterBoardServices.framework",
            "/System/Library/PrivateFrameworks",
        ]
        let dest = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fonts", isDirectory: true)
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        var found: [String] = []
        var log: [String] = []
        var seen = Set<String>()
        for root in roots {
            guard fm.fileExists(atPath: root) else { log.append("\(root): findes ikke/ingen adgang"); continue }
            guard let en = fm.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: nil,
                                         options: [.skipsHiddenFiles]) else { log.append("\(root): kan ikke læses"); continue }
            var scanned = 0
            for case let u as URL in en {
                scanned += 1
                if scanned > 400_000 { break }
                let name = u.lastPathComponent
                let ext = u.pathExtension.lowercased()
                guard ["otf", "ttf", "ttc"].contains(ext),
                      systemStems.contains(where: { name.hasPrefix($0) }), !seen.contains(name) else { continue }
                seen.insert(name)
                let to = dest.appendingPathComponent(name)
                try? fm.removeItem(at: to)
                if (try? fm.copyItem(at: u, to: to)) != nil {
                    found.append(name)
                    log.append("Fundet: \(u.path)")
                }
            }
            log.append("\(root): \(scanned) filer gennemset")
            // Har vi den vigtigste, behøver vi ikke gennemsøge alle private frameworks
            if found.contains(where: { $0.hasPrefix("SFAdaptiveNumeric") }) { break }
        }
        return (found, log)
    }

    /// Hent en skriftfil fra et link (fx dit eget iCloud/Drive-link til en .otf)
    static func download(_ link: String) async throws -> String {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw URLError(.badURL) }
        let (tmp, resp) = try await URLSession.shared.download(from: url)
        guard (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { throw URLError(.badServerResponse) }
        var name = resp.suggestedFilename ?? url.lastPathComponent
        if !["otf", "ttf", "ttc"].contains((name as NSString).pathExtension.lowercased()) { name += ".otf" }
        let dest = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        cache.removeAll()
        names[name] = nil
        guard postScriptName(for: name) != nil else {
            try? FileManager.default.removeItem(at: dest)
            throw NSError(domain: "Bio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Filen er ikke en skrift (.otf/.ttf). Er linket et direkte download-link?"])
        }
        return name
    }

    static func didAdd() { cache.removeAll(); names.removeAll() }

    static func axes(for file: String) -> Set<String> {
        guard let name = postScriptName(for: file) else { return [] }
        let f = CTFontCreateWithName(name as CFString, 12, nil)
        guard let list = CTFontCopyVariationAxes(f) as? [[String: Any]] else { return [] }
        return Set(list.compactMap { ($0[kCTFontVariationAxisIdentifierKey as String] as? NSNumber).map { tagString($0.uint32Value) } })
    }

    /// Skrift med variable akser, fx ["HGHT": 230, "wght": 600]
    static func font(file: String, size: CGFloat, axes: [String: Double]) -> CTFont? {
        let key = "\(file)|\(Int(size * 10))|" + axes.keys.sorted().map { "\($0)=\(Int(axes[$0]! * 10))" }.joined(separator: ",")
        if let f = cache[key] { return f }
        guard let name = postScriptName(for: file) else { return nil }
        var vars: [NSNumber: NSNumber] = [:]
        for (tag, v) in axes { vars[NSNumber(value: tagValue(tag))] = NSNumber(value: v) }
        let desc = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: name,
            kCTFontVariationAttribute: vars,
        ] as CFDictionary)
        let f = CTFontCreateWithFontDescriptor(desc, size, nil)
        if cache.count > 400 { cache.removeAll() }
        cache[key] = f
        return f
    }

    static func tagValue(_ s: String) -> UInt32 {
        s.utf8.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
    }

    static func tagString(_ v: UInt32) -> String {
        String(bytes: [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)], encoding: .ascii) ?? ""
    }
}

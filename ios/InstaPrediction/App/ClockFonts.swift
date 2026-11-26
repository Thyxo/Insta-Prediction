// Apples urskrifter (fx SFAdaptiveNumeric-VF.otf fra iOS 26.3) importeres af brugeren og gemmes
// kun på telefonen (Application Support/Fonts). De må ikke ligge i det offentlige repo.
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
        return files.filter { $0.lowercased().hasSuffix(".otf") || $0.lowercased().hasSuffix(".ttf") }.sorted()
    }

    /// Kopiér valgte filer ind (fra Filer/AirDrop). Returnerer navnene.
    @discardableResult
    static func importFiles(_ urls: [URL]) -> [String] {
        var out: [String] = []
        for u in urls {
            let scoped = u.startAccessingSecurityScopedResource()
            defer { if scoped { u.stopAccessingSecurityScopedResource() } }
            let dest = dir.appendingPathComponent(u.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            if (try? FileManager.default.copyItem(at: u, to: dest)) != nil, postScriptName(for: u.lastPathComponent) != nil {
                out.append(u.lastPathComponent)
            } else {
                try? FileManager.default.removeItem(at: dest)
            }
        }
        cache.removeAll()
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
        guard let provider = CGDataProvider(url: url as CFURL), let cg = CGFont(provider),
              let name = cg.postScriptName as String? else { return nil }
        if !registered.contains(file) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            registered.insert(file)
        }
        names[file] = name
        return name
    }

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

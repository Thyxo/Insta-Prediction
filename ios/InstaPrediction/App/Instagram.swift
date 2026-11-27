// Instagram via din egen login-session.
//
// Du logger ind i en WKWebView (LoginView) på instagram.com. Cookies gemmes af iOS i
// WKWebsiteDataStore.default(); koden ser vi aldrig. Vi sender så de samme kald, som
// instagram.com selv bruger under "Rediger profil", fra din egen telefon.
//
// Der er ingen officiel API til at skrive i bioen (Graph API: "Updating: not supported").
// Disse endpoints er uofficielle og kan ændre sig. Se CLAUDE.md → "Nemme at ødelægge".
import Foundation
import WebKit

struct IGProfile {
    var username: String
    var biography: String
    var form: [String: Any]
}

enum IGError: LocalizedError {
    case notLoggedIn
    case tooFast
    case http(Int, String)
    case refused(String)
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: "Ikke logget ind på Instagram (eller sessionen er udløbet)."
        case .tooFast: "Instagram siger: for mange ændringer. Vent et par minutter."
        case .http(let c, let s): "HTTP \(c): \(s)"
        case .refused(let m): "Instagram afviste: \(m)"
        case .unexpected(let m): m
        }
    }
}

@MainActor
final class Instagram {
    /// Samme user agent i login-vinduet og i kaldene, så Instagram ser én og samme "browser".
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"
    /// instagram.com's egen web-app-id (sendes af hjemmesiden i alle API-kald)
    static let appID = "936619743392459"
    static let base = URL(string: "https://www.instagram.com")!
    static let loginURL = URL(string: "https://www.instagram.com/accounts/login/")!

    private var store: WKHTTPCookieStore { WKWebsiteDataStore.default().httpCookieStore }

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.httpShouldSetCookies = false        // vi styrer cookies selv (fra WKWebView)
        c.httpCookieAcceptPolicy = .never
        c.timeoutIntervalForRequest = 20
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }()

    // MARK: Session

    /// Cookies fra login-vinduet. Bio gemmer også selv en kopi (CookieVault), fordi WebKit ikke altid
    /// husker login mellem starter (fx i LiveContainer). Mangler WebKit sessionen, lægges kopien tilbage.
    func cookies() async -> [HTTPCookie] {
        let now = Date()
        let all: [HTTPCookie] = await withCheckedContinuation { cont in
            store.getAllCookies { cont.resume(returning: $0) }
        }
        var ig = all.filter { $0.domain.hasSuffix("instagram.com") && ($0.expiresDate.map { $0 > now } ?? true) }
        if ig.contains(where: { $0.name == "sessionid" && !$0.value.isEmpty }) {
            CookieVault.save(ig)
        } else if let saved = CookieVault.load(), saved.contains(where: { $0.name == "sessionid" }) {
            for c in saved {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    store.setCookie(c) { cont.resume() }
                }
            }
            ig = saved
        }
        return ig
    }

    func isLoggedIn() async -> Bool {
        await cookies().contains { $0.name == "sessionid" && !$0.value.isEmpty }
    }

    func logout() async {
        CookieVault.clear()
        let ds = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { cont in
            ds.fetchDataRecords(ofTypes: types) { cont.resume(returning: $0) }
        }
        let mine = records.filter { $0.displayName.contains("instagram") || $0.displayName.contains("facebook") }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            ds.removeData(ofTypes: types, for: mine) { cont.resume() }
        }
    }

    // MARK: Kald

    func profile() async throws -> IGProfile {
        let obj = try await send("/api/v1/accounts/edit/web_form_data/")
        guard let f = obj["form_data"] as? [String: Any] else { throw IGError.unexpected("Svar uden form_data") }
        return IGProfile(username: f["username"] as? String ?? "", biography: f["biography"] as? String ?? "", form: f)
    }

    /// Skriv bio. method: "bio" (kun bio-feltet), "web" (hele profil-formularen) eller "auto" (bio, så web).
    /// Returnerer den metode, der virkede.
    func setBio(_ text: String, method: String) async throws -> String {
        if method != "web" {
            do {
                _ = try await send("/api/v1/accounts/set_biography/", form: [("raw_text", text)])
                return "bio"
            } catch IGError.notLoggedIn {
                throw IGError.notLoggedIn
            } catch IGError.tooFast {
                throw IGError.tooFast
            } catch {
                if method == "bio" { throw error }
            }
        }
        // Web-formularen kræver alle felter. Vi sender præcis det, Instagram selv har udfyldt.
        let p = try await profile()
        guard !p.username.isEmpty else { throw IGError.unexpected("Brugernavn mangler i profilen. Stopper for ikke at ødelægge noget.") }
        func str(_ k: String) -> String { (p.form[k] as? String) ?? "" }
        var fields: [(String, String)] = [
            ("biography", text),
            ("username", p.username),
            ("first_name", str("first_name")),
            ("email", str("email")),
            ("phone_number", str("phone_number")),
            ("external_url", str("external_url")),
        ]
        if (p.form["chaining_enabled"] as? Bool) ?? true { fields.append(("chaining_enabled", "on")) }
        _ = try await send("/api/v1/web/accounts/edit/", form: fields)
        return "web"
    }

    // MARK: HTTP

    private func send(_ path: String, form: [(String, String)]? = nil) async throws -> [String: Any] {
        let cs = await cookies()
        guard cs.contains(where: { $0.name == "sessionid" && !$0.value.isEmpty }) else { throw IGError.notLoggedIn }
        guard let url = URL(string: path, relativeTo: Self.base) else { throw IGError.unexpected("Ugyldig sti") }

        var req = URLRequest(url: url)
        req.setValue(cs.map { "\($0.name)=\($0.value)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(Self.appID, forHTTPHeaderField: "X-IG-App-ID")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue("https://www.instagram.com/accounts/edit/", forHTTPHeaderField: "Referer")
        req.setValue("https://www.instagram.com", forHTTPHeaderField: "Origin")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        req.setValue("da-DK,da;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        if let csrf = cs.first(where: { $0.name == "csrftoken" })?.value {
            req.setValue(csrf, forHTTPHeaderField: "X-CSRFToken")
        }
        if let form {
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data(Self.encode(form).utf8)
        }

        let (data, resp) = try await session.data(for: req)
        let http = resp as? HTTPURLResponse
        await keepCookies(from: http, url: url)

        let code = http?.statusCode ?? 0
        let snippet = String(decoding: data.prefix(240), as: UTF8.self)
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if code == 429 { throw IGError.tooFast }
        if obj?["message"] as? String == "login_required" || obj?["require_login"] as? Bool == true
            || snippet.contains("<!DOCTYPE") || snippet.contains("<html") {
            throw IGError.notLoggedIn
        }
        if let m = obj?["message"] as? String, m.contains("wait a few minutes") { throw IGError.tooFast }
        guard (200..<300).contains(code), let obj else { throw IGError.http(code, snippet) }
        if let st = obj["status"] as? String, st != "ok" {
            throw IGError.refused(obj["message"] as? String ?? snippet)
        }
        return obj
    }

    /// Instagram skifter csrftoken m.m. undervejs; gem dem tilbage i WKWebView'ens cookies.
    private func keepCookies(from http: HTTPURLResponse?, url: URL) async {
        guard let http else { return }
        var headers: [String: String] = [:]
        for (k, v) in http.allHeaderFields { if let k = k as? String, let v = v as? String { headers[k] = v } }
        let fresh = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        for c in fresh {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                store.setCookie(c) { cont.resume() }
            }
        }
        if !fresh.isEmpty, var saved = CookieVault.load() {
            for c in fresh { saved.removeAll { $0.name == c.name }; saved.append(c) }
            CookieVault.save(saved)
        }
    }

    static func encode(_ form: [(String, String)]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        func e(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        return form.map { "\(e($0.0))=\(e($0.1))" }.joined(separator: "&")
    }
}

/// Bios egen kopi af Instagram-cookies i appens Application Support (kun på telefonen, aldrig delt).
/// Filen kan læses, også når telefonen er låst (efter første oplåsning), så afsløringen virker med sort skærm.
enum CookieVault {
    private struct Stored: Codable {
        var name, value, domain, path: String
        var expires: Date?
        var secure: Bool
        var httpOnly: Bool
    }

    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("instagram-session.json")
    }

    static func save(_ cookies: [HTTPCookie]) {
        let list = cookies.map {
            Stored(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path,
                   expires: $0.expiresDate, secure: $0.isSecure, httpOnly: $0.isHTTPOnly)
        }
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func load() -> [HTTPCookie]? {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Stored].self, from: data) else { return nil }
        let now = Date()
        let cookies = list.compactMap { c -> HTTPCookie? in
            if let e = c.expires, e < now { return nil }
            var p: [HTTPCookiePropertyKey: Any] = [.name: c.name, .value: c.value, .domain: c.domain, .path: c.path]
            if let e = c.expires { p[.expires] = e }
            if c.secure { p[.secure] = "TRUE" }
            if c.httpOnly { p[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
            return HTTPCookie(properties: p)
        }
        return cookies.isEmpty ? nil : cookies
    }

    static func clear() { try? FileManager.default.removeItem(at: url) }
}

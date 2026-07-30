// MARK: - Fathom Pro license (hidden HQ site code + legacy keys)

enum FathomProLicense {
    static let defaultsKey = "fathompro.licenseKey"
    static let unlockedKey = "fathompro.unlocked"
    private static let legacyUnlockedKey = "fathomplus.unlocked"
    private static let legacyDefaultsKey = "fathomplus.licenseKey"
    private static let secret = "chopstickshq.fathompro.unlock.v1"
    private static let legacySecret = "chopstickshq.fathomplus.unlock.v1"
    /// Canonical scavenger-hunt code on chopstickshq.com (homepage first L in “Small”).
    static let siteUnlockCode = "oi-pl-c0ffee-faded1-358dc51a"
    /// Previous Plus branding code (still accepted).
    static let legacySiteUnlockCode = "oi-pl-c0ffee-faded1-21657207"

    static var isUnlocked: Bool {
        get {
            if UserDefaults.standard.bool(forKey: unlockedKey) { return true }
            // Migrate from Fathom Plus install
            if UserDefaults.standard.bool(forKey: legacyUnlockedKey) {
                UserDefaults.standard.set(true, forKey: unlockedKey)
                return true
            }
            return false
        }
        set { UserDefaults.standard.set(newValue, forKey: unlockedKey) }
    }

    static var storedKey: String {
        get {
            let v = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
            if !v.isEmpty { return v }
            return UserDefaults.standard.string(forKey: legacyDefaultsKey) ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static func fnv1a32(_ string: String) -> UInt32 {
        var h: UInt32 = 0x811c9dc5
        for b in string.utf8 {
            h ^= UInt32(b)
            h = h &* 0x01000193
        }
        return h
    }

    static func verifyLoose(_ raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key == siteUnlockCode.lowercased() || key == legacySiteUnlockCode.lowercased() {
            return true
        }

        let pattern = #"^oi-pl-([0-9a-f]{6})-([0-9a-f]{6})-([0-9a-f]{8})$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        let range = NSRange(key.startIndex..., in: key)
        guard let m = re.firstMatch(in: key, options: [], range: range), m.numberOfRanges == 4,
              let r1 = Range(m.range(at: 1), in: key),
              let r2 = Range(m.range(at: 2), in: key),
              let r3 = Range(m.range(at: 3), in: key) else { return false }
        let n1 = String(key[r1]).lowercased()
        let n2 = String(key[r2]).lowercased()
        let sig = String(key[r3]).lowercased()
        let body = n1 + n2
        for sec in [secret, legacySecret] {
            let expectWeb = String(format: "%08x", fnv1a32(sec + "|" + body + "|web"))
            let expect3 = String(format: "%08x", fnv1a32(sec + "|" + body + "|3"))
            let expect5 = String(format: "%08x", fnv1a32(sec + "|" + body + "|5"))
            if sig == expectWeb || sig == expect3 || sig == expect5 { return true }
        }
        return false
    }

    @discardableResult
    static func activate(_ raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard verifyLoose(key) else { return false }
        storedKey = key
        isUnlocked = true
        return true
    }

    static func deactivate() {
        storedKey = ""
        isUnlocked = false
    }
}

// MARK: - Weather (Open-Meteo + CoreLocation)

final class WeatherStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherStore()

    @Published var summary = "Locating…"
    @Published var detail = ""
    @Published var tempC: Double?
    @Published var humidity: Int?
    @Published var windKmh: Double?
    @Published var code: Int?
    @Published var place = ""
    @Published var error: String?
    @Published var lastUpdated: Date?

    private let manager = CLLocationManager()
    private var lastFetch: CFAbsoluteTime = 0

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else if status == .authorizedAlways || status == .authorized {
            manager.requestLocation()
        } else {
            error = "Location denied — enable in System Settings"
            summary = "Location off"
            detail = "Allow location for local weather"
        }
    }

    func refresh() {
        guard CFAbsoluteTimeGetCurrent() - lastFetch > 8 else { return }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorized {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            DispatchQueue.main.async {
                self.error = "Location denied"
                self.summary = "Location off"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastFetch = CFAbsoluteTimeGetCurrent()
        fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        reverseGeocode(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.summary = "Weather unavailable"
        }
    }

    private func reverseGeocode(_ loc: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] marks, _ in
            let name = marks?.first.flatMap { m in
                [m.locality, m.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            } ?? ""
            DispatchQueue.main.async { self?.place = name }
        }
    }

    private func fetchWeather(lat: Double, lon: Double) {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
        ]
        guard let url = c.url else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
            DispatchQueue.main.async {
                guard let self else { return }
                if let err {
                    self.error = err.localizedDescription
                    self.summary = "Weather error"
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let cur = json["current"] as? [String: Any] else {
                    self.summary = "Weather error"
                    return
                }
                let t = cur["temperature_2m"] as? Double
                let h = cur["relative_humidity_2m"] as? Int ?? (cur["relative_humidity_2m"] as? Double).map { Int($0) }
                let w = cur["wind_speed_10m"] as? Double
                let code = cur["weather_code"] as? Int ?? (cur["weather_code"] as? Double).map { Int($0) }
                self.tempC = t
                self.humidity = h
                self.windKmh = w
                self.code = code
                self.error = nil
                self.lastUpdated = Date()
                let label = Self.weatherLabel(code ?? -1)
                if let t {
                    self.summary = String(format: "%.0f°C · %@", t, label)
                } else {
                    self.summary = label
                }
                var bits: [String] = []
                if let h { bits.append("Humidity \(h)%") }
                if let w { bits.append(String(format: "Wind %.0f km/h", w)) }
                self.detail = bits.joined(separator: " · ")
            }
        }.resume()
    }

    static func weatherLabel(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Local weather"
        }
    }
}

// MARK: - AI Chat (OpenRouter · Gemini · OpenAI · Anthropic)

struct PlusChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: String
    var text: String
    var isError: Bool
    init(id: UUID = UUID(), role: String, text: String, isError: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isError = isError
    }
}

enum PlusAIProvider: String, CaseIterable, Identifiable {
    case openRouter = "OpenRouter"
    case gemini = "Gemini"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    var id: String { rawValue }

    var defaultModel: String {
        switch self {
        case .openRouter: return "openrouter/auto"
        case .gemini: return "gemini-2.0-flash"
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-haiku-20241022"
        }
    }

    var model: String {
        if self == .openRouter {
            return PlusOpenRouterModels.selected
        }
        return defaultModel
    }

    var keyURL: URL? {
        switch self {
        case .openRouter: return URL(string: "https://openrouter.ai/keys")
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        }
    }

    var storageKey: String { "fathompro.ai.key.\(rawValue)" }
}

enum PlusOpenRouterModels {
    static let storageKey = "fathompro.ai.openrouter.model"
    static let presets: [String] = [
        "openrouter/auto",
        "openai/gpt-4o-mini",
        "openai/gpt-4o",
        "anthropic/claude-3.5-sonnet",
        "anthropic/claude-3-haiku",
        "google/gemini-2.0-flash-001",
        "google/gemini-2.5-pro-preview",
        "meta-llama/llama-3.3-70b-instruct",
        "deepseek/deepseek-chat",
        "mistralai/mistral-small-3.1-24b-instruct",
        "qwen/qwen-2.5-72b-instruct",
    ]

    static var selected: String {
        get {
            let s = UserDefaults.standard.string(forKey: storageKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return s.isEmpty ? "openrouter/auto" : s
        }
        set {
            let v = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(v.isEmpty ? "openrouter/auto" : v, forKey: storageKey)
        }
    }
}

enum PlusAIKeyStore {
    private static let service = "com.chopstickshq.fathompro.ai"
    private static let migratedKey = "fathompro.ai.keychain.migrated.v1"

    static func get(_ p: PlusAIProvider) -> String {
        migrateFromDefaultsIfNeeded()
        if let k = keychainGet(account: p.rawValue), !k.isEmpty { return k }
        return UserDefaults.standard.string(forKey: p.storageKey) ?? ""
    }

    static func set(_ p: PlusAIProvider, _ value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty {
            keychainDelete(account: p.rawValue)
            UserDefaults.standard.removeObject(forKey: p.storageKey)
        } else {
            _ = keychainSet(account: p.rawValue, value: v)
            UserDefaults.standard.removeObject(forKey: p.storageKey)
        }
    }

    private static func migrateFromDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        for p in PlusAIProvider.allCases {
            if let legacy = UserDefaults.standard.string(forKey: p.storageKey), !legacy.isEmpty {
                _ = keychainSet(account: p.rawValue, value: legacy)
                UserDefaults.standard.removeObject(forKey: p.storageKey)
            }
        }
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    private static func keychainGet(account: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    @discardableResult
    private static func keychainSet(account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        keychainDelete(account: account)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    private static func keychainDelete(account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(q as CFDictionary)
    }
}

enum PlusFileDownloads {
    static var downloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }

    static func uniqueURL(named name: String, ext: String) -> URL {
        let safe = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        var url = downloadsDirectory.appendingPathComponent("\(safe).\(ext)")
        var i = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = downloadsDirectory.appendingPathComponent("\(safe)-\(i).\(ext)")
            i += 1
        }
        return url
    }

    @discardableResult
    static func saveText(_ text: String, suggestedName: String, ext: String = "txt") throws -> URL {
        let url = uniqueURL(named: suggestedName, ext: ext)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func savePanel(defaultName: String, ext: String, contents: String) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultName.hasSuffix(".\(ext)") ? defaultName : "\(defaultName).\(ext)"
        panel.allowedFileTypes = [ext, "txt", "md"]
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            try? contents.write(to: url, atomically: true, encoding: .utf8)
            reveal(url)
        }
    }

    static func downloadRemote(urlString: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let remote = URL(string: urlString),
              let scheme = remote.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            completion(.failure(NSError(domain: "Download", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: "Not a downloadable URL"])))
            return
        }
        let name = remote.lastPathComponent.isEmpty ? "download" : remote.lastPathComponent
        let dest = downloadsDirectory.appendingPathComponent(name)
        let task = URLSession.shared.downloadTask(with: remote) { temp, _, err in
            if let err {
                DispatchQueue.main.async { completion(.failure(err)) }
                return
            }
            guard let temp else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Download", code: 0,
                                                userInfo: [NSLocalizedDescriptionKey: "Empty download"])))
                }
                return
            }
            do {
                var final = dest
                var i = 2
                let base = (name as NSString).deletingPathExtension
                let ext = (name as NSString).pathExtension
                while FileManager.default.fileExists(atPath: final.path) {
                    let suffix = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
                    final = downloadsDirectory.appendingPathComponent(suffix)
                    i += 1
                }
                try FileManager.default.moveItem(at: temp, to: final)
                DispatchQueue.main.async { completion(.success(final)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
    }

    static func urls(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range).compactMap { m in
            guard let r = Range(m.range, in: text) else { return nil }
            let s = String(text[r])
            if s.hasPrefix("http://") || s.hasPrefix("https://") { return s }
            return nil
        }
    }
}

final class PlusChatModel: ObservableObject {
    static let shared = PlusChatModel()

    @Published var provider: PlusAIProvider = {
        if let raw = UserDefaults.standard.string(forKey: "fathompro.ai.provider"),
           let p = PlusAIProvider(rawValue: raw) { return p }
        return .openRouter
    }() {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "fathompro.ai.provider") }
    }
    @Published var openRouterModel: String = PlusOpenRouterModels.selected {
        didSet { PlusOpenRouterModels.selected = openRouterModel }
    }
    @Published var openRouterCustom = ""
    @Published var messages: [PlusChatMessage] = []
    @Published var draft = ""
    @Published var busy = false
    @Published var status = "Ready"
    @Published var keyDraft = ""
    @Published var lastSavedPath = ""

    func loadKeyField() { keyDraft = PlusAIKeyStore.get(provider) }
    func saveKeyField() {
        PlusAIKeyStore.set(provider, keyDraft)
        status = keyDraft.isEmpty ? "No key saved" : "Key saved on this Mac"
    }

    func clearChat() {
        messages.removeAll()
        status = "Cleared"
    }

    var resolvedModel: String {
        if provider == .openRouter {
            let custom = openRouterCustom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !custom.isEmpty { return custom }
            return openRouterModel.isEmpty ? PlusOpenRouterModels.selected : openRouterModel
        }
        return provider.defaultModel
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        draft = ""
        messages.append(PlusChatMessage(role: "user", text: text))
        busy = true
        status = "Thinking…"
        let provider = self.provider
        let model = resolvedModel
        if provider == .openRouter {
            PlusOpenRouterModels.selected = model
        }
        let history = messages
        let apiKey = PlusAIKeyStore.get(provider)
        Task {
            do {
                let reply = try await PlusAIClient.request(
                    provider: provider, apiKey: apiKey, messages: history, modelOverride: model
                )
                await MainActor.run {
                    self.messages.append(PlusChatMessage(role: "assistant", text: reply))
                    self.busy = false
                    self.status = "Ready · \(model)"
                }
            } catch {
                await MainActor.run {
                    self.messages.append(PlusChatMessage(role: "assistant", text: error.localizedDescription, isError: true))
                    self.busy = false
                    self.status = "Error"
                }
            }
        }
    }

    func exportChatMarkdown() {
        var md = "# Fathom Pro chat\n\n"
        md += "Provider: \(provider.rawValue) · Model: \(resolvedModel)\n\n"
        for m in messages {
            let who = m.role == "user" ? "You" : provider.rawValue
            md += "## \(who)\n\n\(m.text)\n\n"
        }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        PlusFileDownloads.savePanel(defaultName: "fathom-pro-chat-\(stamp)", ext: "md", contents: md)
        status = "Export chat…"
    }

    func saveMessage(_ m: PlusChatMessage) {
        let stamp = Int(Date().timeIntervalSince1970)
        let name = m.role == "user" ? "fathom-pro-prompt-\(stamp)" : "fathom-pro-reply-\(stamp)"
        do {
            let url = try PlusFileDownloads.saveText(m.text, suggestedName: name, ext: "md")
            lastSavedPath = url.path
            status = "Saved \(url.lastPathComponent)"
            PlusFileDownloads.reveal(url)
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    func downloadLinks(from m: PlusChatMessage) {
        let links = PlusFileDownloads.urls(in: m.text)
        guard !links.isEmpty else {
            status = "No download links in that message"
            return
        }
        status = "Downloading \(links.count) file(s)…"
        var remaining = links.count
        for link in links {
            PlusFileDownloads.downloadRemote(urlString: link) { [weak self] result in
                remaining -= 1
                switch result {
                case .success(let url):
                    self?.lastSavedPath = url.path
                    self?.status = remaining == 0
                        ? "Downloaded to Downloads"
                        : "Downloaded \(url.lastPathComponent)…"
                    if remaining == 0 { PlusFileDownloads.reveal(url) }
                case .failure(let err):
                    self?.status = err.localizedDescription
                }
            }
        }
    }
}

enum PlusAIClient {
    static func sanitize(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func request(provider: PlusAIProvider, apiKey: String, messages: [PlusChatMessage], modelOverride: String? = nil) async throws -> String {
        let key = sanitize(apiKey)
        guard !key.isEmpty else {
            throw NSError(domain: provider.rawValue, code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Add your \(provider.rawValue) API key in API Config."])
        }
        let clean = messages.filter { !$0.isError }
        let model = (modelOverride?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        switch provider {
        case .gemini: return try await gemini(key: key, messages: clean)
        case .openai: return try await openAI(key: key, messages: clean)
        case .anthropic: return try await anthropic(key: key, messages: clean)
        case .openRouter: return try await openRouter(key: key, messages: clean, model: model ?? PlusOpenRouterModels.selected)
        }
    }

    private static func openAICompatible(url: String, key: String, model: String, messages: [PlusChatMessage], domain: String, extra: [String: String] = [:]) async throws -> String {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        for (k, v) in extra { req.setValue(v, forHTTPHeaderField: k) }
        req.timeoutInterval = 90
        let msgs: [[String: String]] = messages.map {
            ["role": $0.role == "user" ? "user" : "assistant", "content": $0.text]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "messages": msgs])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: domain, code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "\(domain) HTTP \(http.statusCode): \(body.prefix(180))"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw NSError(domain: domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty response from \(domain)"])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func openAI(key: String, messages: [PlusChatMessage]) async throws -> String {
        try await openAICompatible(
            url: "https://api.openai.com/v1/chat/completions",
            key: key, model: "gpt-4o-mini", messages: messages, domain: "OpenAI"
        )
    }

    private static func openRouter(key: String, messages: [PlusChatMessage], model: String) async throws -> String {
        try await openAICompatible(
            url: "https://openrouter.ai/api/v1/chat/completions",
            key: key, model: model, messages: messages, domain: "OpenRouter",
            extra: [
                "HTTP-Referer": "https://chopstickshq.com/fathom-pro/",
                "X-Title": "Fathom Pro"
            ]
        )
    }

    private static func anthropic(key: String, messages: [PlusChatMessage]) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 90
        let msgs: [[String: String]] = messages.map {
            ["role": $0.role == "user" ? "user" : "assistant", "content": $0.text]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "claude-3-5-haiku-20241022",
            "max_tokens": 1024,
            "messages": msgs
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Anthropic", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Anthropic HTTP \(http.statusCode): \(body.prefix(180))"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw NSError(domain: "Anthropic", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty response from Anthropic"])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func gemini(key: String, messages: [PlusChatMessage]) async throws -> String {
        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 90
        let contents: [[String: Any]] = messages.map { msg in
            ["role": msg.role == "user" ? "user" : "model", "parts": [["text": msg.text]]]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["contents": contents])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Gemini", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Gemini HTTP \(http.statusCode): \(body.prefix(180))"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw NSError(domain: "Gemini", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty response from Gemini"])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PlusWeatherSection: View {
    @ObservedObject var weather = WeatherStore.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weather")
                .font(.callout)
                .foregroundColor(.secondary)
            BatFiMainRow(label: weather.place.isEmpty ? "Local" : weather.place, value: weather.summary, emphasizeValue: true)
            if !weather.detail.isEmpty {
                BatFiDetailRow(label: "Conditions", value: weather.detail)
            }
            if let err = weather.error, !err.isEmpty {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Button("Refresh weather") { weather.refresh() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .onAppear { weather.start() }
    }
}

struct PlusChatSection: View {
    @ObservedObject var chat = PlusChatModel.shared
    @State private var showKeys = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Chat")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
                if chat.provider == .openRouter {
                    Text(chat.resolvedModel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Button(showKeys ? "Hide keys" : "API keys") {
                    showKeys.toggle()
                    chat.loadKeyField()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            if showKeys {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Provider", selection: $chat.provider) {
                        ForEach(PlusAIProvider.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .onChange(of: chat.provider) { _, _ in chat.loadKeyField() }
                    if chat.provider == .openRouter {
                        PlusOpenRouterModelPicker(chat: chat)
                    }
                    PlusPasteableKeyField(text: $chat.keyDraft, placeholder: "API key (⌘V)", isSecure: true)
                        .frame(height: 28)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save key") { chat.saveKeyField() }
                            .buttonStyle(.bordered)
                        if let url = chat.provider.keyURL {
                            Button("Get key…") { NSWorkspace.shared.open(url) }
                                .buttonStyle(.borderless)
                        }
                    }
                    Text("Keys stay on this Mac. OpenRouter models are selectable in API Config.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if chat.messages.isEmpty {
                        Text("Ask about battery drain, power tips, or anything else.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(chat.messages.suffix(12)) { m in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(m.role == "user" ? "You" : chat.provider.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !m.isError {
                                    Button("Save") { chat.saveMessage(m) }
                                        .buttonStyle(.borderless)
                                        .font(.caption2)
                                    if m.role != "user", !PlusFileDownloads.urls(in: m.text).isEmpty {
                                        Button("Download links") { chat.downloadLinks(from: m) }
                                            .buttonStyle(.borderless)
                                            .font(.caption2)
                                    }
                                }
                            }
                            Text(m.text)
                                .font(.callout)
                                .foregroundColor(m.isError ? .red : .primary)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(m.role == "user" ? 0.06 : 0.10))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 180)

            HStack(spacing: 6) {
                TextField("Message…", text: $chat.draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { chat.send() }
                Button(chat.busy ? "…" : "Send") { chat.send() }
                    .buttonStyle(.borderedProminent)
                    .disabled(chat.busy || chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                Text(chat.status)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("Export chat") { chat.exportChatMarkdown() }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                Button("Clear") { chat.clearChat() }
                    .buttonStyle(.borderless)
                    .font(.caption2)
            }
        }
    }
}

struct PlusOpenRouterModelPicker: View {
    @ObservedObject var chat: PlusChatModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OpenRouter model")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("Model", selection: $chat.openRouterModel) {
                ForEach(PlusOpenRouterModels.presets, id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            .labelsHidden()
            TextField("Or custom model id…", text: $chat.openRouterCustom)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
            Text("Active: \(chat.resolvedModel)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
}

// Plus preferences panes injected into the customization window via PreferencesRootPlus.

struct PlusPrefsWeatherPane: View {
    @ObservedObject var weather = WeatherStore.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather")
                .font(.system(size: 22, weight: .semibold))
            Text("Local conditions from your Mac’s location (Open-Meteo). Nothing is sent to Chopsticks HQ.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(weather.place.isEmpty ? "Local" : weather.place)
                    Spacer()
                    Text(weather.summary).foregroundColor(.secondary)
                }
                if !weather.detail.isEmpty {
                    Text(weather.detail).font(.caption).foregroundColor(.secondary)
                }
                if let err = weather.error, !err.isEmpty {
                    Text(err).font(.caption).foregroundColor(.red)
                }
                Button("Refresh weather") { weather.refresh() }
                    .buttonStyle(.bordered)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        }
        .onAppear { weather.start() }
    }
}

struct PlusPrefsAPIConfigPane: View {
    /// When true, omit large page title (AI Chat subtab).
    var embedded: Bool = false
    @ObservedObject var chat = PlusChatModel.shared
    @State private var drafts: [PlusAIProvider: String] = [:]
    @State private var statusByProvider: [PlusAIProvider: String] = [:]
    @State private var testing: PlusAIProvider?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !embedded {
                Text("API Config")
                    .font(.system(size: 22, weight: .semibold))
            } else {
                Text("Provider keys")
                    .font(.system(size: 15, weight: .semibold))
            }
            Text("Add your own provider keys (OpenRouter, Gemini, OpenAI, Anthropic). Stored in this Mac’s Keychain and only sent to that provider when you chat — not to Chopsticks HQ.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Text("Active provider")
                    .font(.system(size: 13, weight: .medium))
                Picker("", selection: $chat.provider) {
                    ForEach(PlusAIProvider.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Default model: \(chat.provider.defaultModel)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                if chat.provider == .openRouter {
                    PlusOpenRouterModelPicker(chat: chat)
                        .padding(.top, 4)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))

            ForEach(PlusAIProvider.allCases) { p in
                providerCard(p)
            }

            Text("Keys live in Keychain on this device. Fathom Pro does not sell or mint provider API keys.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            for p in PlusAIProvider.allCases {
                drafts[p] = PlusAIKeyStore.get(p)
            }
            chat.loadKeyField()
        }
    }

    private func providerCard(_ p: PlusAIProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(p.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                if chat.provider == p {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                        .foregroundColor(.green)
                }
                Spacer()
                let saved = !PlusAIKeyStore.get(p).isEmpty
                Text(saved ? "Key saved" : "No key")
                    .font(.caption)
                    .foregroundColor(saved ? .secondary : .orange)
            }
            Text(p == .openRouter
                  ? "Model · choose above (OpenRouter)"
                  : "Model · \(p.defaultModel)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            PlusPasteableKeyField(
                text: Binding(
                    get: { drafts[p] ?? "" },
                    set: { drafts[p] = $0 }
                ),
                placeholder: "Paste API key (⌘V)",
                isSecure: true
            )
            .frame(height: 28)

            HStack(spacing: 8) {
                Button("Paste") {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        drafts[p] = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                .buttonStyle(.bordered)
                Button("Save") {
                    let v = (drafts[p] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    PlusAIKeyStore.set(p, v)
                    if chat.provider == p {
                        chat.keyDraft = v
                        chat.saveKeyField()
                    }
                    statusByProvider[p] = v.isEmpty ? "Cleared" : "Saved on this Mac"
                }
                .buttonStyle(.borderedProminent)

                Button(testing == p ? "Testing…" : "Test") {
                    testProvider(p)
                }
                .buttonStyle(.bordered)
                .disabled(testing != nil)

                Button("Use") {
                    chat.provider = p
                    chat.loadKeyField()
                    statusByProvider[p] = "Set as active provider"
                }
                .buttonStyle(.bordered)

                if let url = p.keyURL {
                    Button("Get key…") { NSWorkspace.shared.open(url) }
                        .buttonStyle(.borderless)
                }

                Spacer()
            }

            if let msg = statusByProvider[p], !msg.isEmpty {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(chat.provider == p ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(chat.provider == p ? 0.14 : 0.06), lineWidth: 1)
                )
        )
    }

    private func testProvider(_ p: PlusAIProvider) {
        let key = (drafts[p] ?? PlusAIKeyStore.get(p)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            statusByProvider[p] = "Paste a key first"
            return
        }
        testing = p
        statusByProvider[p] = "Checking…"
        let probe = [PlusChatMessage(role: "user", text: "Reply with exactly: ok")]
        let model = p == .openRouter ? chat.resolvedModel : p.defaultModel
        Task {
            do {
                let reply = try await PlusAIClient.request(
                    provider: p, apiKey: key, messages: probe, modelOverride: model
                )
                await MainActor.run {
                    testing = nil
                    statusByProvider[p] = "Connected · \(model) · \(reply.prefix(40))"
                }
            } catch {
                await MainActor.run {
                    testing = nil
                    statusByProvider[p] = error.localizedDescription
                }
            }
        }
    }
}

struct PlusPrefsChatPane: View {
    @ObservedObject var chat = PlusChatModel.shared
    @State private var subtab: ChatSubtab = .chat

    private enum ChatSubtab: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case api = "API Config"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI")
                .font(.system(size: 22, weight: .semibold))
            Text("Chat and provider keys. API Config lives in a subtab so the sidebar stays clean.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Picker("", selection: $subtab) {
                ForEach(ChatSubtab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch subtab {
            case .chat:
                chatSubpane
            case .api:
                PlusPrefsAPIConfigPane(embedded: true)
            }
        }
        .onAppear { chat.loadKeyField() }
    }

    private var chatSubpane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chat uses the active provider from the API Config subtab.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            HStack {
                Text("Provider: \(chat.provider.rawValue)")
                    .font(.callout)
                Spacer()
                Text(PlusAIKeyStore.get(chat.provider).isEmpty ? "No key" : "Key ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            PlusChatSection()
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            Button("Open API Config…") { subtab = .api }
                .buttonStyle(.bordered)
        }
    }
}

struct PlusPrefsLicensePane: View {
    @State private var key = FathomProLicense.storedKey
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("License")
                .font(.system(size: 22, weight: .semibold))
            Text("Fathom Pro unlocks with an oi-pl key — from the private Vault (random keys) or the homepage scavenger (first L in “Small”). Client-side gate, not a paid license or free OpenAI/OpenRouter key. Provider API keys are separate and yours.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(FathomProLicense.isUnlocked ? "Unlocked" : "Locked")
                        .foregroundColor(FathomProLicense.isUnlocked ? .green : .secondary)
                }
                PlusPasteableKeyField(text: $key)
                    .frame(height: 28)
                HStack {
                    Button("Paste") {
                        if let s = NSPasteboard.general.string(forType: .string) {
                            key = s.trimmingCharacters(in: .whitespacesAndNewlines)
                            message = "Pasted from clipboard"
                        } else {
                            message = "Clipboard is empty"
                        }
                    }
                    .buttonStyle(.bordered)
                    Button("Activate") {
                        if FathomProLicense.activate(key) {
                            message = "Activated"
                        } else {
                            message = "Invalid key"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Deactivate") {
                        FathomProLicense.deactivate()
                        key = ""
                        message = "Deactivated — relaunch to lock"
                    }
                    .buttonStyle(.bordered)
                    Button("Search Chopsticks HQ") {
                        NSWorkspace.shared.open(URL(string: "https://chopstickshq.com/")!)
                    }
                    .buttonStyle(.borderless)
                }
                if !message.isEmpty {
                    Text(message).font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        }
    }
}

/// NSTextField that always handles ⌘V/⌘C/⌘X/⌘A itself.
/// SwiftUI TextField/SecureField + menubar apps often drop system paste; two-finger
/// context-menu paste still works because it bypasses the menu bar.
final class PlusPasteAwareTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control),
              let ch = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        switch ch {
        case "v":
            pasteFromClipboard()
            return true
        case "c":
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            return true
        case "x":
            NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            return true
        case "a":
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    @objc func pasteFromClipboard() {
        guard isEditable else { return }
        // Prefer field-editor paste (respects selection / undo)
        if let editor = currentEditor() as? NSTextView {
            editor.paste(nil)
            return
        }
        guard let raw = NSPasteboard.general.string(forType: .string) else { return }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        stringValue = s
        // Notify SwiftUI binding
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: self)
    }
}

struct PlusPasteableKeyField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "oi-pl-……"
    var isSecure: Bool = false

    func makeNSView(context: Context) -> NSTextField {
        let tf: NSTextField
        if isSecure {
            let sec = NSSecureTextField(string: text)
            // NSSecureTextField doesn't subclass our paste-aware class; wrap via cell config + monitor
            tf = sec
        } else {
            tf = PlusPasteAwareTextField(string: text)
        }
        tf.placeholderString = placeholder
        tf.isBordered = true
        tf.isBezeled = true
        tf.bezelStyle = .roundedBezel
        tf.isEditable = true
        tf.isSelectable = true
        tf.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tf.delegate = context.coordinator
        tf.focusRingType = .default
        tf.allowsEditingTextAttributes = false
        tf.usesSingleLineMode = true
        tf.lineBreakMode = .byTruncatingTail
        context.coordinator.installLocalMonitor(for: tf)
        DispatchQueue.main.async {
            tf.window?.makeFirstResponder(tf)
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PlusPasteableKeyField
        private var monitor: Any?

        init(_ parent: PlusPasteableKeyField) { self.parent = parent }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        func installLocalMonitor(for field: NSTextField) {
            if let monitor { NSEvent.removeMonitor(monitor) }
            // Nuclear fallback: catch ⌘V even when menu bar / hosting view swallows it
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak field, weak self] event in
                guard let field, let self else { return event }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard flags.contains(.command),
                      !flags.contains(.option),
                      !flags.contains(.control),
                      event.charactersIgnoringModifiers?.lowercased() == "v" else {
                    return event
                }
                // Only when this field (or its field editor) is first responder
                guard let win = field.window,
                      let fr = win.firstResponder else { return event }
                let focused: Bool
                if fr === field {
                    focused = true
                } else if let tv = fr as? NSTextView, tv.delegate as? NSTextField === field {
                    focused = true
                } else if let tv = fr as? NSText, (field.currentEditor() as AnyObject?) === (tv as AnyObject) {
                    focused = true
                } else {
                    focused = (field.currentEditor() != nil && fr === field.currentEditor())
                }
                guard focused else { return event }

                if let aware = field as? PlusPasteAwareTextField {
                    aware.pasteFromClipboard()
                } else if let raw = NSPasteboard.general.string(forType: .string) {
                    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let editor = field.currentEditor() as? NSTextView {
                        editor.paste(nil)
                    } else {
                        field.stringValue = s
                        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: field)
                    }
                    self.parent.text = field.stringValue
                }
                return nil // swallow so nothing else fights paste
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }
    }
}

struct PlusActivationView: View {
    @State private var key = ""
    @State private var error = ""
    var onUnlocked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fathom Pro")
                .font(.system(size: 22, weight: .semibold))
            Text("Paste an oi-pl unlock key from the private Vault (random each time) or the homepage scavenger (first L in “Small”). Client-side gate — not DRM, not a free OpenAI/OpenRouter key.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PlusPasteableKeyField(text: $key, placeholder: "Unlock code…")
                .frame(height: 28)
            HStack(spacing: 8) {
                // Click-to-paste helper — do NOT bind ⌘V here (that steals it from the field)
                Button("Paste") {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        key = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        error = ""
                    } else {
                        error = "Clipboard is empty."
                    }
                }
                .buttonStyle(.bordered)
                Button("Clear") { key = ""; error = "" }
                    .buttonStyle(.borderless)
            }
            if !error.isEmpty {
                Text(error).font(.caption).foregroundColor(.red)
            }
            HStack {
                Button("Activate") {
                    if FathomProLicense.activate(key) {
                        error = ""
                        onUnlocked()
                    } else {
                        error = "Invalid code. Hunt chopstickshq.com for the hidden unlock, then paste it exactly."
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                Button("Open Chopsticks HQ") {
                    NSWorkspace.shared.open(URL(string: "https://chopstickshq.com/")!)
                }
                .buttonStyle(.bordered)
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            Text("Everything in Fathom, plus local weather and multi-provider AI chat. ⌘V pastes into the field.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            PlusEditMenu.ensureInstalled()
        }
    }
}

/// Shared Edit menu so ⌘V/⌘C reach text fields app-wide.
enum PlusEditMenu {
    static func ensureInstalled() {
        if NSApp.mainMenu?.items.contains(where: { $0.submenu?.title == "Edit" }) == true {
            return
        }
        let main = NSApp.mainMenu ?? NSMenu()
        if NSApp.mainMenu == nil {
            let appItem = NSMenuItem()
            main.addItem(appItem)
            let appMenu = NSMenu(title: "Fathom Pro")
            appMenu.addItem(NSMenuItem(title: "Quit Fathom Pro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            appItem.submenu = appMenu
        }
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }
}

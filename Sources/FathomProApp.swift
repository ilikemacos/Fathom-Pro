import Cocoa
import SwiftUI
import Combine
import Darwin
import IOKit
import IOKit.ps
import UserNotifications
import ServiceManagement
import CoreLocation
import Security


let FATHOM_VERSION = "v0.1.5-Pro-Beta"
let FATHOM_CHANNEL = "pro"

let kPopoverWidth: CGFloat = 300

let kMenuPanelTick: TimeInterval = 0.45

let kMenuChromeStyle = "fathompro.menuChromeStyle"


enum FathomType {
    static let hero: CGFloat = 28
    static let title: CGFloat = 13
    static let body: CGFloat = 13
    static let caption: CGFloat = 12
    static let micro: CGFloat = 11
    static let label: CGFloat = 10
}
enum FathomSpace {
    static let padH: CGFloat = 20
    static let padHTight: CGFloat = 16
    static let section: CGFloat = 14
    static let row: CGFloat = 8
    static let hairline: CGFloat = 16
}

let kReplaceSystemBattery = "fathompro.replaceSystemBattery"

let kMenuBarPosition = "fathompro.menuBarPosition"
let kMenuBarAutosaveName = "FathomProBattery"

let kMenuBarDisplayMode = "fathompro.menuBarDisplayMode"

let kDrainAlertsEnabled = "fathompro.drainAlerts.enabled"

let kDrainAlertsDropPercent = "fathompro.drainAlerts.dropPercent"

let kDrainAlertsWindowMinutes = "fathompro.drainAlerts.windowMinutes"

let kWattHistorySlots = 700

let kPowerPollIdle: TimeInterval = 4.0
let kPowerPollUI: TimeInterval = 2.0
let kPowerPollACIdle: TimeInterval = 10.0
let kPowerPollOnBattery: TimeInterval = 3.0
let kProcPollIdle: TimeInterval = 20.0
let kProcPollUI: TimeInterval = 5.0

let kBatteryShellCrossCheck: TimeInterval = 45.0

let kDashboardPrefs = "fathompro.dashboard.prefs.v1"

let kOnboardingSeen = "fathompro.onboarding.seen.v1"

let kLaunchAtLogin = "fathompro.launchAtLogin"

let kCriticalBatteryPercent = "fathompro.criticalBatteryPercent"

let kCriticalBatteryPercentDefault = 20

extension Notification.Name {
    static let fathomRebuildStatusItem = Notification.Name("fathompro.rebuildStatusItem")
    static let fathomOpenDashboard = Notification.Name("fathompro.openDashboard")
    static let fathomMenuBarDisplayChanged = Notification.Name("fathompro.menuBarDisplayChanged")
    static let fathomDashboardPrefsChanged = Notification.Name("fathompro.dashboardPrefsChanged")
    static let fathomToggleCustomize = Notification.Name("fathompro.toggleCustomize")
    static let fathomCloseDashboard = Notification.Name("fathompro.closeDashboard")
    static let fathomClosePopover = Notification.Name("fathompro.closePopover")
    static let fathomOpenPreferences = Notification.Name("fathompro.openPreferences")
}


enum FathomCopy {
    static let fullWindow = "Full Window"
    static let customize = "Customize…"
    static let preferences = "Preferences…"
    static let batteryMenu = "Battery Menu"
    static let powerDraw = "Mac power draw"
    static let whatsUsingPower = "What’s using power"
    static let whyBatteryDropped = "Why did battery drop?"
    static let useFathomAsBattery = "Use Fathom as the battery icon"
    static let nothingHeavy = "Nothing heavy running right now"
    static let whyCold =
        "Keep Fathom open for about 15 minutes so it can learn your drain pattern."
    static let estimatingTime = "Estimating time left…"
    static let doubleClickHint = "Double-click the menu bar icon for the full window"
    static let localOnly = "Local only · no telemetry"
    static let clickMenuDoubleWindow = "Click: menu · Double-click: full window"

    static func statusChip(power: PowerStore, why: DrainLog.WhyDrain) -> String {
        if !power.batteryPresent { return "Desktop" }
        if power.isCharging { return "Charging" }
        if power.isOnAC {
            return power.levelPercent >= 100 ? "Full" : "Plugged in"
        }
        if why.dropPercent >= 5 { return "Draining fast" }
        return "On battery"
    }

    static func friendlyTime(power: PowerStore) -> String {
        if !power.batteryPresent { return "Running on power adapter" }
        if power.timeText == "Calculating…" || power.remainingMinutes == nil {
            if power.isOnAC && !power.isCharging { return power.timeText }
            return estimatingTime
        }
        
        return power.timeText
    }
}

enum FathomOnboarding {
    static var hasSeen: Bool {
        UserDefaults.standard.bool(forKey: kOnboardingSeen)
    }
    static func markSeen() {
        UserDefaults.standard.set(true, forKey: kOnboardingSeen)
    }
}

struct FathomOnboardingSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Fathom")
                .font(uiFont(18, weight: .semibold))
                .foregroundColor(.labelPrimary)
            VStack(alignment: .leading, spacing: 12) {
                tipRow(num: "1", title: "Click the battery icon",
                       detail: "Opens a quick battery menu — like the system one, with extra detail.")
                tipRow(num: "2", title: "Double-click for the full window",
                       detail: "A larger rNitro-style view with charts and why-drain analysis.")
                tipRow(num: "3", title: "“Why did battery drop?”",
                       detail: "Fathom learns on-device. Leave it running a bit for better answers.")
            }
            Text(FathomCopy.localOnly)
                .font(uiFont(11))
                .foregroundColor(.labelTertiary)
            Button {
                FathomOnboarding.markSeen()
                isPresented = false
            } label: {
                Text("Got it")
                    .font(uiFont(13, weight: .semibold))
                    .foregroundColor(.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.labelPrimary))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(width: 340)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .preferredColorScheme(.dark)
    }

    private func tipRow(num: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(uiFont(12, weight: .bold))
                .foregroundColor(.bg)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.labelPrimary))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(uiFont(13, weight: .semibold))
                    .foregroundColor(.labelPrimary)
                Text(detail)
                    .font(uiFont(12))
                    .foregroundColor(.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum MenuBarDisplayMode: String {
    case percent
    case watts

    static var current: MenuBarDisplayMode {
        let raw = UserDefaults.standard.string(forKey: kMenuBarDisplayMode) ?? "percent"
        return MenuBarDisplayMode(rawValue: raw) ?? .percent
    }

    static func set(_ mode: MenuBarDisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: kMenuBarDisplayMode)
        NotificationCenter.default.post(name: .fathomMenuBarDisplayChanged, object: nil)
    }
}


enum MenuChromeStyle: String, CaseIterable {
    case newer
    case original

    var title: String {
        switch self {
        case .newer: return "Newer"
        case .original: return "Original"
        }
    }

    static var current: MenuChromeStyle {
        
        if UserDefaults.standard.object(forKey: kMenuChromeStyle) == nil {
            return .newer
        }
        let raw = UserDefaults.standard.string(forKey: kMenuChromeStyle) ?? "newer"
        return MenuChromeStyle(rawValue: raw) ?? .newer
    }

    static func set(_ style: MenuChromeStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: kMenuChromeStyle)
        NotificationCenter.default.post(name: .fathomMenuBarDisplayChanged, object: nil)
    }

    var isNewer: Bool { self == .newer }
    var padH: CGFloat { isNewer ? 16 : FathomSpace.padH }
    var heroPct: CGFloat { isNewer ? 36 : FathomType.hero }
    var heroIcon: CGFloat { isNewer ? 52 : 40 }
}


private struct BatFiMainRow: View {
    let label: String
    let value: String
    var emphasizeValue: Bool = true
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.primary)
            Spacer(minLength: 20)
            Text(value)
                .font(.body)
                .fontWeight(emphasizeValue ? .semibold : .regular)
                .foregroundStyle(emphasizeValue ? Color.primary : Color.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .monospacedDigit()
        }
    }
}


private struct BatFiDetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
            Spacer(minLength: 20)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .monospacedDigit()
        }
        .font(.callout)
        .foregroundColor(.secondary)
    }
}


private struct BatFiSeparator: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().frame(height: 1)
                .foregroundColor(Color.black.opacity(0.17))
            Rectangle().frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1))
        }
        .padding(.vertical, 2)
    }
}


private struct BatFiMenuAction: View {
    let title: String
    var trailing: String? = nil
    var showChevron: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer(minLength: 12)
                if let trailing {
                    Text(trailing)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.secondary.opacity(0.55))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
let UPDATE_CHECK_URL = URL(string: "https://chopstickshq.com/fathom-pro/version.json")!
let UPDATE_PAGE_URL = URL(string: "https://chopstickshq.com/fathom-pro/")!
let UPDATE_CDN_BASE = "https://chopstickshq.com/fathom-pro"
let SUPPORT_DIR: URL = {
    let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Fathom", isDirectory: true)
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}()
let RNITRO_SITE_URL = URL(string: "https://chopstickshq.com/rnitro/")!
let RNITRO_BUNDLE_ID = "com.chopstickshq.rnitro"
let FATHOM_PRO_SITE_URL = URL(string: "https://chopstickshq.com/fathom-pro/")!
let FATHOM_PRO_BUNDLE_ID = "com.chopstickshq.fathompro"


enum RNitroLink {
    static var isInstalled: Bool {
        if #available(macOS 12.0, *),
           NSWorkspace.shared.urlForApplication(withBundleIdentifier: RNITRO_BUNDLE_ID) != nil {
            return true
        }
        let paths = [
            "\(NSHomeDirectory())/Applications/rNitro.app",
            "/Applications/rNitro.app",
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    static func openOrInstall() {
        if #available(macOS 12.0, *),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: RNITRO_BUNDLE_ID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            return
        }
        for p in ["\(NSHomeDirectory())/Applications/rNitro.app", "/Applications/rNitro.app"] {
            if FileManager.default.fileExists(atPath: p) {
                NSWorkspace.shared.open(URL(fileURLWithPath: p))
                return
            }
        }
        NSWorkspace.shared.open(RNITRO_SITE_URL)
    }
}

/// Open installed Fathom Pro (or legacy Fathom Plus), or the download page if missing.
enum FathomProLink {
    private static var candidatePaths: [String] {
        [
            "\(NSHomeDirectory())/Applications/Fathom Pro.app",
            "/Applications/Fathom Pro.app",
            "\(NSHomeDirectory())/Applications/FathomPro.app",
            "/Applications/FathomPro.app",
            // Legacy Fathom Plus installs
            "\(NSHomeDirectory())/Applications/Fathom Plus.app",
            "/Applications/Fathom Plus.app",
        ]
    }

    private static var bundleIDs: [String] {
        [FATHOM_PRO_BUNDLE_ID, "com.chopstickshq.fathomproplus"]
    }

    static var isInstalled: Bool {
        if #available(macOS 12.0, *) {
            for bid in bundleIDs {
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) != nil {
                    return true
                }
            }
        }
        return candidatePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    static var buttonTitle: String {
        isInstalled ? "Open Fathom Pro" : "Get Fathom Pro"
    }

    @discardableResult
    static func openOrInstall() -> Bool {
        if #available(macOS 12.0, *) {
            for bid in bundleIDs {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                    let cfg = NSWorkspace.OpenConfiguration()
                    cfg.activates = true
                    NSWorkspace.shared.openApplication(at: url, configuration: cfg, completionHandler: nil)
                    return true
                }
            }
        }
        for p in candidatePaths {
            if FileManager.default.fileExists(atPath: p) {
                NSWorkspace.shared.open(URL(fileURLWithPath: p))
                return true
            }
        }
        NSWorkspace.shared.open(FATHOM_PRO_SITE_URL)
        return false
    }
}


extension Color {
    
    static let bg = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let card = Color(red: 0.10, green: 0.10, blue: 0.14)
    static let cardElevated = Color(red: 0.14, green: 0.14, blue: 0.18)
    
    static let border = Color.white.opacity(0.12)
    static let divider = Color.white.opacity(0.08)
    
    static let labelPrimary = Color.white.opacity(0.92)
    static let labelSecondary = Color.white.opacity(0.55)
    static let labelTertiary = Color.white.opacity(0.38)
    
    static let accent = Color(red: 0.35, green: 0.75, blue: 1.0)
    static let nGreen = Color(red: 0.1, green: 1.0, blue: 0.5)
    static let nOrange = Color(red: 1.0, green: 0.55, blue: 0.1)
    static let nRed = Color(red: 1.0, green: 0.25, blue: 0.25)
    static let nPurple = Color(red: 0.72, green: 0.45, blue: 1.0)
}


func uiFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .default)
}
func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .rounded)
}


struct MonitorRow: View {
    let label: String
    let value: String
    var valueColor: Color = .labelPrimary
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(uiFont(13, weight: .regular))
                .foregroundColor(.labelSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(uiFont(13, weight: .medium))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 5)
    }
}

struct MinimalButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(uiFont(12, weight: .medium))
                .foregroundColor(.labelPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct MenuHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: 0.5)
            .padding(.vertical, 2)
    }
}

struct MonitorSection<Content: View>: View {
    let title: String
    let accent: Color
    let summary: String
    var sparkline: [Double]? = nil
    let storageKey: String
    var icon: String = "circle.fill"
    @ViewBuilder let content: () -> Content
    @AppStorage private var isExpanded: Bool

    init(title: String, accent: Color, summary: String, sparkline: [Double]? = nil,
         storageKey: String, defaultExpanded: Bool = true, icon: String = "circle.fill",
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.accent = accent
        self.summary = summary
        self.sparkline = sparkline
        self.storageKey = storageKey
        self.icon = icon
        self.content = content
        self._isExpanded = AppStorage(wrappedValue: defaultExpanded, storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.labelSecondary)
                        .frame(width: 18, alignment: .center)
                    Text(title.capitalized)
                        .font(uiFont(13, weight: .semibold))
                        .foregroundColor(.labelPrimary)
                    Spacer(minLength: 8)
                    Text(summary)
                        .font(uiFont(12, weight: .regular))
                        .foregroundColor(.labelSecondary)
                        .lineLimit(1)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.labelTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                MenuHairline()
                    .padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 2) {
                    if let sparkline, !sparkline.isEmpty {
                        Sparkline(values: sparkline, color: .labelSecondary)
                            .frame(height: 32)
                            .padding(.bottom, 6)
                            .padding(.top, 2)
                    }
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color = .labelSecondary
    var body: some View {
        GeometryReader { g in
            let vals = values.isEmpty ? [0.0] : values
            let maxV = max(vals.max() ?? 1, 0.001)
            Path { p in
                for (i, v) in vals.enumerated() {
                    let x = g.size.width * CGFloat(i) / CGFloat(max(vals.count - 1, 1))
                    let y = g.size.height * (1 - CGFloat(v / maxV))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
        }
    }
}


@_silgen_name("IOReportCopyAllChannels")
private func IOReportCopyAllChannels(_ a: UInt64, _ b: UInt64) -> Unmanaged<CFDictionary>?
@_silgen_name("IOReportChannelGetGroup")
private func IOReportChannelGetGroup(_ item: CFDictionary) -> Unmanaged<CFString>?
@_silgen_name("IOReportChannelGetChannelName")
private func IOReportChannelGetChannelName(_ item: CFDictionary) -> Unmanaged<CFString>?
@_silgen_name("IOReportChannelGetUnitLabel")
private func IOReportChannelGetUnitLabel(_ item: CFDictionary) -> Unmanaged<CFString>?
@_silgen_name("IOReportCreateSubscription")
private func IOReportCreateSubscription(_ a: UnsafeRawPointer?, _ b: CFMutableDictionary,
                                        _ out: UnsafeMutablePointer<CFMutableDictionary?>,
                                        _ flags: UInt64, _ opts: UnsafeRawPointer?) -> UnsafeMutableRawPointer?
@_silgen_name("IOReportCreateSamples")
private func IOReportCreateSamples(_ sub: UnsafeMutableRawPointer, _ chan: CFMutableDictionary,
                                   _ opts: UnsafeRawPointer?) -> Unmanaged<CFDictionary>?
@_silgen_name("IOReportCreateSamplesDelta")
private func IOReportCreateSamplesDelta(_ a: CFDictionary, _ b: CFDictionary,
                                        _ opts: UnsafeRawPointer?) -> Unmanaged<CFDictionary>?
@_silgen_name("IOReportSimpleGetIntegerValue")
private func IOReportSimpleGetIntegerValue(_ item: CFDictionary, _ index: Int32) -> Int64

struct SocPowerSample {
    var cpuWatts: Double = 0
    var gpuWatts: Double = 0
    var aneWatts: Double = 0
    var dramWatts: Double = 0
    var otherWatts: Double = 0
    var hasData: Bool { cpuWatts > 0 || gpuWatts > 0 || aneWatts > 0 || dramWatts > 0 || otherWatts > 0 }
    
    var packageWatts: Double { cpuWatts + gpuWatts + aneWatts + dramWatts }
    var totalWatts: Double { packageWatts + otherWatts }
    var domainCount: Int {
        (cpuWatts > 0.02 ? 1 : 0) + (gpuWatts > 0.02 ? 1 : 0)
            + (aneWatts > 0.02 ? 1 : 0) + (dramWatts > 0.02 ? 1 : 0)
    }
}

fileprivate final class IOReportPowerReader {
    static let shared = IOReportPowerReader()
    private enum ChannelKind { case cpu, gpu, ane, dram, other }
    private struct ChannelMeta { let kind: ChannelKind; let unit: String }
    private let queue = DispatchQueue(label: "fathompro.ioreport", qos: .utility)
    private(set) var isAvailable = false
    private var allChannels: CFDictionary?
    private var subscription: UnsafeMutableRawPointer?
    private var sampleChannels: CFMutableDictionary?
    private var channels: [ChannelMeta] = []
    private var prevSample: Unmanaged<CFDictionary>?
    private var prevTime: CFAbsoluteTime = 0
    private var permanentlyDisabled = false
    private init() { setup() }
    private func cfStr(_ ref: Unmanaged<CFString>?) -> String {
        guard let ref else { return "" }
        return ref.takeUnretainedValue() as String
    }
    private func energyDeltaToWatts(_ delta: Double, unit: String, durationMs: Double) -> Double {
        let joules: Double
        switch unit {
        case "mJ": joules = delta / 1e3
        case "uJ": joules = delta / 1e6
        case "nJ": joules = delta / 1e9
        case "J": joules = delta
        default:
            
            joules = abs(delta) > 1_000 ? delta / 1e3 : 0
        }
        return joules / max(durationMs / 1000.0, 0.001)
    }
    private func deltaChannelItems(_ delta: CFDictionary) -> [CFDictionary] {
        let key = "IOReportChannels" as CFString
        guard let ptr = CFDictionaryGetValue(delta, Unmanaged.passUnretained(key).toOpaque()) else { return [] }
        let arr = unsafeBitCast(ptr, to: CFArray.self)
        let n = CFArrayGetCount(arr)
        return (0..<n).map { i in unsafeBitCast(CFArrayGetValueAtIndex(arr, i)!, to: CFDictionary.self) }
    }
    
    private func channelKind(group: String, channel: String) -> ChannelKind? {
        let g = group
        let c = channel
        let energyish = g == "Energy Model" || g.contains("Energy") || g == "PMP"
        guard energyish else { return nil }
        if c.hasSuffix("CPU Energy") || c == "CPU Energy" || c.contains("CPU Complex Energy") { return .cpu }
        if c == "GPU Energy" || c.hasSuffix("GPU Energy") || c.contains("GPU Complex") { return .gpu }
        if c.hasPrefix("ANE") || c.contains("ANE Energy") || c.contains("Neural") { return .ane }
        if c.contains("DRAM") || c.contains("Memory") { return .dram }
        if c.contains("ISP") || (c.contains("Display") && c.contains("Energy")) { return .other }
        return nil
    }
    private func disablePermanently() {
        permanentlyDisabled = true
        isAvailable = false
    }
    private func setup() {
        guard let allRaw = IOReportCopyAllChannels(0, 0)?.takeRetainedValue() else { return }
        let channelsKey = "IOReportChannels" as CFString
        guard let itemsPtr = CFDictionaryGetValue(allRaw, Unmanaged.passUnretained(channelsKey).toOpaque()) else { return }
        let allItems = unsafeBitCast(itemsPtr, to: CFArray.self)
        let itemCount = CFArrayGetCount(allItems)
        guard let selected = CFArrayCreateMutable(kCFAllocatorDefault, 0, nil) else { return }
        var metas: [ChannelMeta] = []
        for i in 0..<itemCount {
            let itemPtr = CFArrayGetValueAtIndex(allItems, i)!
            let item = unsafeBitCast(itemPtr, to: CFDictionary.self)
            let group = cfStr(IOReportChannelGetGroup(item))
            let channel = cfStr(IOReportChannelGetChannelName(item))
            guard let kind = channelKind(group: group, channel: channel) else { continue }
            CFArrayAppendValue(selected, itemPtr)
            let unit = cfStr(IOReportChannelGetUnitLabel(item)).trimmingCharacters(in: .whitespaces)
            metas.append(ChannelMeta(kind: kind, unit: unit))
        }
        guard !metas.isEmpty else { return }
        guard let chan = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, allRaw) else { return }
        CFDictionarySetValue(chan, Unmanaged.passUnretained(channelsKey).toOpaque(),
                             Unmanaged.passUnretained(selected).toOpaque())
        var subInfo: CFMutableDictionary?
        guard let sub = IOReportCreateSubscription(nil, chan, &subInfo, 0, nil) else { return }
        allChannels = allRaw
        subscription = sub
        sampleChannels = chan
        channels = metas
        isAvailable = true
    }
    func sample() -> SocPowerSample? {
        guard isAvailable, !permanentlyDisabled else { return nil }
        return queue.sync { sampleUnsafe() }
    }
    private func sampleUnsafe() -> SocPowerSample? {
        guard let sub = subscription, let chan = sampleChannels else { return nil }
        guard let sample = IOReportCreateSamples(sub, chan, nil)?.takeRetainedValue() else {
            disablePermanently()
            return nil
        }
        let now = CFAbsoluteTimeGetCurrent()
        guard let prevBox = prevSample else {
            prevSample = Unmanaged.passRetained(sample)
            prevTime = now
            return nil
        }
        let prev = prevBox.takeUnretainedValue()
        let elapsedMs = (now - prevTime) * 1000.0
        var result: SocPowerSample? = nil
        
        if elapsedMs >= 150, elapsedMs <= 15_000,
           let deltaRaw = IOReportCreateSamplesDelta(prev, sample, nil)?.takeRetainedValue() {
            let deltaItems = deltaChannelItems(deltaRaw)
            var out = SocPowerSample()
            for (j, item) in deltaItems.enumerated() where j < channels.count {
                let val = Double(IOReportSimpleGetIntegerValue(item, 0))
                let w = energyDeltaToWatts(val, unit: channels[j].unit, durationMs: elapsedMs)
                guard w > 0, w < 500 else { continue }
                switch channels[j].kind {
                case .cpu: out.cpuWatts += w
                case .gpu: out.gpuWatts += w
                case .ane: out.aneWatts += w
                case .dram: out.dramWatts += w
                case .other: out.otherWatts += w
                }
            }
            if out.hasData { result = out }
        }
        prevBox.release()
        prevSample = Unmanaged.passRetained(sample)
        prevTime = now
        return result
    }
}


final class PowerStore: ObservableObject {
    static let shared = PowerStore()

    @Published var batteryPresent = false
    @Published var levelPercent = 0
    @Published var isCharging = false
    @Published var isOnAC = false
    @Published var chargeWatts: Double = 0
    @Published var packageWatts: Double = 0
    @Published var packageSource: String = "estimate"
    @Published var cpuDomainWatts: Double = 0
    @Published var gpuDomainWatts: Double = 0
    @Published var aneDomainWatts: Double = 0
    @Published var dramDomainWatts: Double = 0
    @Published var otherDomainWatts: Double = 0
    @Published var hasPowerDistribution: Bool = false
    
    @Published var batterySourcesUsed: String = "—"
    
    @Published var timeEstimateSource: String = "—"
    @Published var pCoreShare: Double = 0
    @Published var eCoreShare: Double = 0
    @Published var cycleCount: Int?
    @Published var healthPercent: Int?
    @Published var capacityRaw: Int?
    @Published var designCapacity: Int?
    @Published var timeText = "—"
    @Published var statusText = "—"
    
    @Published var remainingMinutes: Int? = nil
    @Published var minutesIsLiveEstimate: Bool = false
    
    @Published var wattHistory: [Double] = []
    
    @Published var wattHistorySpark: [Double] = []

    private var timer: Timer?
    private var wattRing = Array(repeating: 0.0, count: kWattHistorySlots)
    private var wattIdx = 0
    private var wattFilled = 0
    
    private var packageEma: Double = 0
    private var chargeEma: Double = 0
    private var hasPackageEma = false
    private var hasChargeEma = false

    
    private var fastMode = false
    
    private var lastShellCrossCheck: CFAbsoluteTime = 0
    private var lastDrainLog: CFAbsoluteTime = 0
    private var lastCoreShareRead: CFAbsoluteTime = 0
    private var lastPublishedSpark: CFAbsoluteTime = 0
    private var pollGeneration = 0
    
    private let workQ = DispatchQueue(label: "fathompro.power", qos: .utility)
    private var pollInFlight = false
    
    private var minutesHoldUntil: CFAbsoluteTime = 0
    private var minutesEma: Double = 0
    private var hasMinutesEma = false
    private var ampEmaMA: Double = 0
    private var hasAmpEma = false
    /// Sticky published % — never flip-flop between sources or raw/display SoC.
    private var stickyLevel: Int = -1
    private var pendingLevel: Int = -1
    private var pendingLevelHits: Int = 0
    private var minutesSamples: [Double] = []
    private let minutesSampleCap = 12
    private var lastTimePublishAt: CFAbsoluteTime = 0
    private var lastPublishedTimeText = ""
    private var lastPowerModeKey = ""
    private var lastDisplayedMinutes: Int = -1
    private static let maxDischargeMinutes = 20 * 60
    private static let maxChargeMinutes = 8 * 60
    private static let minLiveAmpMA = 150.0
    private static let minLiveChargeW = 0.7
    /// Max minutes the displayed estimate may move per poll (stops 4h↔3h thrash).
    private static let maxMinutesStepPerPoll = 2

    func notePowerTransition(wake: Bool) {
        if wake {
            minutesHoldUntil = CFAbsoluteTimeGetCurrent() + 30
            hasAmpEma = false
            ampEmaMA = 0
            minutesSamples.removeAll()
            // Allow % to resync after wake without multi-hit debounce
            pendingLevel = -1
            pendingLevelHits = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.poll() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.poll() }
        } else {
            minutesHoldUntil = CFAbsoluteTimeGetCurrent() + 1
        }
    }

    private func resetTimeSmoothers() {
        hasMinutesEma = false
        minutesEma = 0
        minutesSamples.removeAll()
        lastTimePublishAt = 0
        lastPublishedTimeText = ""
        lastDisplayedMinutes = -1
    }

    /// Display % with hysteresis: ignore 1-point flicker; require 2 agreeing polls to step.
    private func stabilizeLevel(_ raw: Int) -> Int {
        let v = min(100, max(0, raw))
        if stickyLevel < 0 {
            stickyLevel = v
            pendingLevel = v
            pendingLevelHits = 1
            return v
        }
        if v == stickyLevel {
            pendingLevel = v
            pendingLevelHits = 0
            return stickyLevel
        }
        // Large jump (plug event already handled by mode reset) — take immediately if ≥3 pts.
        if abs(v - stickyLevel) >= 3 {
            stickyLevel = v
            pendingLevel = v
            pendingLevelHits = 0
            return stickyLevel
        }
        // 1–2 pt change: need consecutive agreement so IOPS/SMC don't bounce.
        if v == pendingLevel {
            pendingLevelHits += 1
        } else {
            pendingLevel = v
            pendingLevelHits = 1
        }
        if pendingLevelHits >= 2 {
            stickyLevel = pendingLevel
            pendingLevelHits = 0
        }
        return stickyLevel
    }

    /// Smooth remaining-time: EMA + hard per-poll step cap so load spikes don't thrash the UI.
    private func stabilizeMinutes(_ raw: Int, charging: Bool, onAC: Bool) -> Int? {
        guard let clean = Self.sanitizeMinutes(raw, charging: charging, onAC: onAC) else { return nil }
        let r = Double(clean)
        if !hasMinutesEma {
            minutesEma = r
            hasMinutesEma = true
            minutesSamples = [r]
            return clean
        }
        // Soft pull toward SMC; never chase single-frame spikes.
        let delta = abs(r - minutesEma)
        let alpha: Double
        if delta >= 40 { alpha = 0.12 }      // huge jump (load spike) — crawl toward it
        else if delta >= 15 { alpha = 0.10 }
        else if delta >= 5 { alpha = 0.14 }
        else { alpha = 0.18 }
        minutesEma = minutesEma * (1 - alpha) + r * alpha
        minutesSamples.append(r)
        if minutesSamples.count > minutesSampleCap {
            minutesSamples.removeFirst(minutesSamples.count - minutesSampleCap)
        }
        let sorted = minutesSamples.sorted()
        let median = sorted[sorted.count / 2]
        var blended = minutesEma * 0.75 + median * 0.25
        // Hard rate-limit published minutes
        let prev = minutesEma // already updated; use last displayed if available
        let anchor = lastDisplayedMinutes > 0 ? Double(lastDisplayedMinutes) : prev
        let maxStep = Double(Self.maxMinutesStepPerPoll)
        if abs(blended - anchor) > maxStep {
            blended = anchor + (blended > anchor ? maxStep : -maxStep)
        }
        minutesEma = blended
        return max(1, Int(blended.rounded()))
    }

    private static func formatRemaining(_ m: Int, charging: Bool) -> String {
        let d = max(1, m)
        if charging {
            if d >= 60 { return String(format: "%dh %dm to full", d / 60, d % 60) }
            return "\(d) min to full"
        }
        if d >= 60 { return String(format: "%dh %dm left", d / 60, d % 60) }
        return "\(d) min left"
    }

    func start() {
        restartTimer(interval: currentInterval())
        poll()
    }

    func setFastMode(_ on: Bool) {
        guard fastMode != on else { return }
        fastMode = on
        restartTimer(interval: currentInterval())
        
        
    }

    private func currentInterval() -> TimeInterval {
        if fastMode { return kPowerPollUI }
        if batteryPresent && isOnAC && !isCharging && levelPercent >= 100 {
            return kPowerPollACIdle
        }
        // Discharge: poll a bit faster so % and time track the pack more closely.
        if batteryPresent && !isOnAC {
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                return max(kPowerPollOnBattery, 8.0)
            }
            return kPowerPollOnBattery
        }
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return max(kPowerPollIdle, 12.0)
        }
        return kPowerPollIdle
    }

    private func restartTimer(interval: TimeInterval) {
        timer?.invalidate()
        
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        t.tolerance = min(1.5, interval * 0.25)
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func poll() {
        
        if pollInFlight { return }
        pollInFlight = true
        let wantShell: Bool = {
            let now = CFAbsoluteTimeGetCurrent()
            
            if lastShellCrossCheck == 0 { return true }
            if fastMode && (now - lastShellCrossCheck) > 45 { return true }
            return (now - lastShellCrossCheck) >= kBatteryShellCrossCheck
        }()
        let needCores = (CFAbsoluteTimeGetCurrent() - lastCoreShareRead) >= 30 || fastMode
        workQ.async { [weak self] in
            defer {
                DispatchQueue.main.async { self?.pollInFlight = false }
            }
            guard let self else { return }
            let bat = Self.readBattery(includeShellCrossCheck: wantShell)
            if wantShell {
                DispatchQueue.main.async { self.lastShellCrossCheck = CFAbsoluteTimeGetCurrent() }
            }
            
            let pkg = Self.readPackageWattsDetailed()
            let cores: (p: Double, e: Double)
            if needCores {
                cores = Self.readCoreShares()
                DispatchQueue.main.async { self.lastCoreShareRead = CFAbsoluteTimeGetCurrent() }
            } else {
                cores = (self.pCoreShare, self.eCoreShare)
            }
            DispatchQueue.main.async {
                self.applyBattery(bat)
                if pkg.watts > 0 {
                    let delta = abs(pkg.watts - self.packageEma)
                    let alpha = !self.hasPackageEma ? 1.0 : (delta > 4 ? 0.55 : (delta > 1.5 ? 0.35 : 0.22))
                    self.packageEma = self.hasPackageEma
                        ? self.packageEma * (1 - alpha) + pkg.watts * alpha
                        : pkg.watts
                    self.hasPackageEma = true
                    let rounded = (self.packageEma * 10).rounded() / 10
                    if abs(rounded - self.packageWatts) >= 0.05 || self.packageSource != pkg.source {
                        self.packageWatts = self.packageEma
                        self.packageSource = pkg.source
                    }
                }
                if let dist = pkg.distribution {
                    let smooth: (Double, Double) -> Double = { prev, next in
                        prev <= 0.01 ? next : prev * 0.55 + next * 0.45
                    }
                    self.cpuDomainWatts = smooth(self.cpuDomainWatts, dist.cpuWatts)
                    self.gpuDomainWatts = smooth(self.gpuDomainWatts, dist.gpuWatts)
                    self.aneDomainWatts = smooth(self.aneDomainWatts, dist.aneWatts)
                    self.dramDomainWatts = smooth(self.dramDomainWatts, dist.dramWatts)
                    self.otherDomainWatts = smooth(self.otherDomainWatts, dist.otherWatts)
                    self.hasPowerDistribution = dist.hasData
                } else if pkg.source == "estimate" {
                    self.hasPowerDistribution = false
                }
                if needCores {
                    if abs(cores.p - self.pCoreShare) > 0.02 { self.pCoreShare = cores.p }
                    if abs(cores.e - self.eCoreShare) > 0.02 { self.eCoreShare = cores.e }
                }
                let n = kWattHistorySlots
                self.wattRing[self.wattIdx % n] = self.packageWatts
                self.wattIdx += 1
                self.wattFilled = min(self.wattFilled + 1, n)
                self.pollGeneration += 1
                
                let now = CFAbsoluteTimeGetCurrent()
                let publishHist = self.fastMode || (now - self.lastPublishedSpark) >= 12 || self.wattFilled < 8
                if publishHist {
                    var hist: [Double] = []
                    hist.reserveCapacity(self.wattFilled)
                    let start = self.wattIdx - self.wattFilled
                    for i in 0..<self.wattFilled {
                        hist.append(self.wattRing[((start + i) % n + n) % n])
                    }
                    self.wattHistory = hist
                    self.wattHistorySpark = Self.downsample(hist, maxPoints: 60)
                    self.lastPublishedSpark = now
                }
                
                if now - self.lastDrainLog >= 30 {
                    self.lastDrainLog = now
                    DrainLog.shared.recordPower(
                        level: self.levelPercent,
                        packageW: self.packageWatts,
                        chargeW: self.chargeWatts,
                        charging: self.isCharging
                    )
                }
                DrainAlertMonitor.shared.evaluate(
                    level: self.levelPercent,
                    onBattery: self.batteryPresent && !self.isOnAC && !self.isCharging
                )
                
                let want = self.currentInterval()
                if abs((self.timer?.timeInterval ?? 0) - want) > 0.4 {
                    self.restartTimer(interval: want)
                }
            }
        }
    }

    private static func downsample(_ values: [Double], maxPoints: Int) -> [Double] {
        guard values.count > maxPoints, maxPoints > 1 else { return values }
        var out: [Double] = []
        out.reserveCapacity(maxPoints)
        let step = Double(values.count - 1) / Double(maxPoints - 1)
        for i in 0..<maxPoints {
            let idx = min(Int((Double(i) * step).rounded()), values.count - 1)
            out.append(values[idx])
        }
        return out
    }

    private func applyBattery(_ s: BatSnap) {
        if batteryPresent != s.present { batteryPresent = s.present }

        let modeKey = "\(s.charging)-\(s.onAC)-\(s.present)"
        if modeKey != lastPowerModeKey {
            lastPowerModeKey = modeKey
            resetTimeSmoothers()
            hasAmpEma = false
            ampEmaMA = 0
            // Force % to resync on plug/unplug/charge transitions
            stickyLevel = -1
            pendingLevel = -1
            pendingLevelHits = 0
        }

        let smoothLevel = stabilizeLevel(s.level)
        if levelPercent != smoothLevel { levelPercent = smoothLevel }

        if isCharging != s.charging { isCharging = s.charging }
        if isOnAC != s.onAC { isOnAC = s.onAC }
        let srcLabel = s.sourcesLabel.isEmpty ? "—" : s.sourcesLabel
        if batterySourcesUsed != srcLabel { batterySourcesUsed = srcLabel }

        if let amp = s.amperageMA, abs(amp) >= 25 {
            let a = Double(amp)
            if hasAmpEma {
                let maxStep = max(100.0, abs(ampEmaMA) * 0.2)
                let capped = min(max(a, ampEmaMA - maxStep), ampEmaMA + maxStep)
                ampEmaMA = ampEmaMA * 0.88 + capped * 0.12
            } else {
                ampEmaMA = a
                hasAmpEma = true
            }
        } else if !s.charging && s.onAC {
            hasAmpEma = false
            ampEmaMA = 0
        }

        var chargeW = s.chargeW
        if hasAmpEma, let v = s.voltageMV, v > 0 {
            let wFromAmp = abs(ampEmaMA) / 1000.0 * Double(v) / 1000.0
            if wFromAmp > 0.08 { chargeW = wFromAmp }
        }
        if chargeW > 0.05 {
            let alpha: Double = hasChargeEma ? 0.15 : 1.0
            chargeEma = hasChargeEma ? chargeEma * (1 - alpha) + chargeW * alpha : chargeW
            hasChargeEma = true
            if abs(chargeWatts - chargeEma) >= 0.2 { chargeWatts = chargeEma }
        } else if chargeWatts != 0 {
            chargeWatts = 0
            hasChargeEma = false
            chargeEma = 0
        }
        if cycleCount != s.cycles { cycleCount = s.cycles }
        if healthPercent != s.health { healthPercent = s.health }
        if capacityRaw != s.rawMax { capacityRaw = s.rawMax }
        if designCapacity != s.design { designCapacity = s.design }

        let holding = CFAbsoluteTimeGetCurrent() < minutesHoldUntil
        let now = CFAbsoluteTimeGetCurrent()

        var rawEstimate: Int? = nil
        var liveEst = s.minutesIsLiveEstimate
        if !holding, (!s.onAC || s.charging) {
            if let sys = Self.sanitizeMinutes(s.minutes, charging: s.charging, onAC: s.onAC) {
                rawEstimate = sys
                // Honor merge: only "Pack draw" when system had no estimate at all
                liveEst = s.minutesIsLiveEstimate
            } else if !s.minutesIsLiveEstimate {
                // System estimate missing this frame — hold last displayed, don't invent from amp
                rawEstimate = remainingMinutes
                liveEst = false
            }
        }

        let newMins: Int? = {
            if holding { return remainingMinutes }
            guard let raw = rawEstimate else { return remainingMinutes }
            return stabilizeMinutes(raw, charging: s.charging, onAC: s.onAC)
        }()

        if let nm = newMins, remainingMinutes != nm { remainingMinutes = nm }

        let tes: String
        if holding { tes = "—" }
        else if newMins != nil { tes = liveEst ? "Pack draw" : "SMC gauge" }
        else { tes = "—" }
        if minutesIsLiveEstimate != liveEst { minutesIsLiveEstimate = liveEst }
        if timeEstimateSource != tes { timeEstimateSource = tes }

        if !s.present {
            if statusText != "No battery" { statusText = "No battery" }
            if timeText != "Desktop / AC" { timeText = "Desktop / AC" }
            remainingMinutes = nil
            minutesIsLiveEstimate = false
            resetTimeSmoothers()
            hasAmpEma = false
            return
        }

        let showW = chargeWatts > 0.05 ? chargeWatts : chargeW
        let newStatus: String
        if s.charging {
            newStatus = showW > 0.05 ? String(format: "Charging · %.1f W", showW) : "Charging"
        } else if s.onAC {
            newStatus = smoothLevel >= 100 ? "Full · on AC" : "Plugged in"
            remainingMinutes = nil
            minutesIsLiveEstimate = false
            resetTimeSmoothers()
            hasAmpEma = false
        } else {
            newStatus = showW > 0.05 ? String(format: "On battery · %.1f W", showW) : "On battery"
        }

        let candidateTime: String = {
            if s.onAC && !s.charging { return "On AC power" }
            if holding {
                return lastPublishedTimeText.isEmpty ? "Calculating…" : lastPublishedTimeText
            }
            if let m = remainingMinutes, m > 0 {
                return Self.formatRemaining(m, charging: s.charging)
            }
            return lastPublishedTimeText.isEmpty ? "Calculating…" : lastPublishedTimeText
        }()

        let displayMins = remainingMinutes ?? -1
        let minsMoved = lastDisplayedMinutes < 0 || abs(displayMins - lastDisplayedMinutes) >= 1
        let timedOut = now - lastTimePublishAt >= 8
        if candidateTime == "On AC power" || lastPublishedTimeText.isEmpty || (candidateTime != lastPublishedTimeText && (minsMoved || timedOut)) {
            lastTimePublishAt = now
            lastPublishedTimeText = candidateTime
            lastDisplayedMinutes = displayMins
            if timeText != candidateTime { timeText = candidateTime }
        }
        if statusText != newStatus { statusText = newStatus }
    }

    
    private static func sanitizeMinutes(_ minutes: Int?, charging: Bool, onAC: Bool) -> Int? {
        guard let m = minutes, m > 0, m < 65535 else { return nil }
        if onAC && !charging { return nil }
        if charging {
            guard m <= maxChargeMinutes else { return nil }
        } else {
            guard m <= maxDischargeMinutes else { return nil }
        }
        return m
    }

    struct BatSnap {
        var present = false
        var level = 0
        var charging = false
        var onAC = false
        var chargeW: Double = 0
        var adapterW: Double = 0
        var minutes: Int?
        var minutesIsLiveEstimate = false
        var cycles: Int?
        var health: Int?
        var rawMax: Int?
        var design: Int?
        var rawCurrent: Int?
        var amperageMA: Int?
        var voltageMV: Int?
        var sourcesLabel = ""
        var sourceNames: [String] = []
    }

    
    struct BatSourceReading {
        var name: String
        var present: Bool?
        var level: Int?
        var charging: Bool?
        var onAC: Bool?
        var chargeW: Double?
        var adapterW: Double?
        var minutes: Int?
        var cycles: Int?
        var health: Int?
        var rawMax: Int?
        var design: Int?
        var rawCurrent: Int?
        var amperageMA: Int?
        var voltageMV: Int?
        var ok: Bool { present == true || level != nil || charging != nil || minutes != nil }
    }

    private static func cfInt(_ v: CFTypeRef?) -> Int? {
        guard let v else { return nil }
        if let n = v as? NSNumber { return n.intValue }
        if CFGetTypeID(v) == CFNumberGetTypeID() {
            var i: Int32 = 0
            CFNumberGetValue(v as! CFNumber, .sInt32Type, &i)
            return Int(i)
        }
        return nil
    }

    private static func cfBool(_ v: CFTypeRef?) -> Bool? {
        guard let v else { return nil }
        if let n = v as? NSNumber { return n.intValue != 0 }
        if CFGetTypeID(v) == CFBooleanGetTypeID() { return CFBooleanGetValue(v as! CFBoolean) }
        return nil
    }

    private static func prop(_ s: io_service_t, _ k: String) -> CFTypeRef? {
        IORegistryEntryCreateCFProperty(s, k as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private static func propInt(_ s: io_service_t, _ k: String) -> Int? { cfInt(prop(s, k)) }
    private static func propBool(_ s: io_service_t, _ k: String) -> Bool? { cfBool(prop(s, k)) }

    
    private static func propDict(_ s: io_service_t, _ k: String) -> [String: Any]? {
        guard let v = prop(s, k) else { return nil }
        if let d = v as? [String: Any] { return d }
        if let nd = v as? NSDictionary {
            var out: [String: Any] = [:]
            nd.enumerateKeysAndObjects { key, obj, _ in
                if let ks = key as? String {
                    out[ks] = obj
                } else if let ks = key as? NSString {
                    out[ks as String] = obj
                }
            }
            return out.isEmpty ? nil : out
        }
        return nil
    }

    private static func dictInt(_ d: [String: Any], _ k: String) -> Int? {
        if let n = d[k] as? NSNumber { return n.intValue }
        if let i = d[k] as? Int { return i }
        return nil
    }

    private static func dictSignedMA(_ d: [String: Any], _ k: String) -> Int? {
        guard let n = d[k] as? NSNumber else {
            if let i = d[k] as? Int { return signedMA(i) }
            return nil
        }
        let s64 = Int64(bitPattern: n.uint64Value)
        if abs(s64) <= 50_000 { return Int(s64) }
        let i64 = n.int64Value
        if abs(i64) <= 50_000 { return Int(i64) }
        return Int(Int32(bitPattern: UInt32(truncatingIfNeeded: n.uint64Value)))
    }

    
    private static func signedMA(_ raw: Int) -> Int {
        if raw > -500_000 && raw < 500_000 { return raw }
        
        let as32 = Int(Int32(bitPattern: UInt32(truncatingIfNeeded: UInt64(bitPattern: Int64(raw)))))
        if as32 > -500_000 && as32 < 500_000 { return as32 }
        let s64 = Int64(bitPattern: UInt64(bitPattern: Int64(raw)))
        if abs(s64) < 500_000 { return Int(s64) }
        return raw
    }

    
    private static func propSignedAmperage(_ s: io_service_t, _ keys: [String]) -> Int? {
        for k in keys {
            guard let v = prop(s, k) else { continue }
            if let n = v as? NSNumber {
                // InstantAmperage is often a full-width UInt64 two's complement (−mA while discharging).
                let u = n.uint64Value
                let s64 = Int64(bitPattern: u)
                if abs(s64) <= 50_000 { return Int(s64) }
                let i64 = n.int64Value
                if abs(i64) <= 50_000 { return Int(i64) }
                // Lower 32 bits as signed (common packing on some firmware)
                let s32 = Int32(bitPattern: UInt32(truncatingIfNeeded: u))
                if abs(Int(s32)) <= 50_000 { return Int(s32) }
                continue
            }
            if let i = cfInt(v) {
                let s = signedMA(i)
                if abs(s) <= 50_000 { return s }
            }
        }
        return nil
    }

    
    static func readBattery(includeShellCrossCheck: Bool = false) -> BatSnap {
        
        
        var readings: [BatSourceReading] = [
            readBatteryIOPS(),
            readBatterySmartBattery(),
            readBatteryGauge(),
            readBatteryTelemetry(),
        ]
        if includeShellCrossCheck {
            readings.append(readBatteryPmset())
            readings.append(readBatteryIoreg())
        } else {
            
            let iops = readings[0]
            if iops.level == nil || iops.minutes == nil {
                readings.append(readBatteryPmset())
            }
        }
        return mergeBatterySources(readings)
    }

    
    static func readBattery() -> BatSnap {
        readBattery(includeShellCrossCheck: true)
    }

    
    private static func readBatteryIOPS() -> BatSourceReading {
        var r = BatSourceReading(name: "IOPS")
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return r
        }
        for src in list {
            guard let d = IOPSGetPowerSourceDescription(info, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            let type = d[kIOPSTypeKey] as? String ?? ""
            let name = (d[kIOPSNameKey] as? String) ?? (d["Name"] as? String) ?? ""
            
            let isInternal = type.isEmpty
                || type == kIOPSInternalBatteryType
                || type == "InternalBattery"
                || name.contains("InternalBattery")
                || name.contains("Internal Battery")
            if !isInternal, list.count > 1 { continue }
            r.present = true
            let capAny = d[kIOPSCurrentCapacityKey]
            let maxAny = d[kIOPSMaxCapacityKey]
            let cap = (capAny as? Int) ?? (capAny as? NSNumber)?.intValue
            let maxC = (maxAny as? Int) ?? (maxAny as? NSNumber)?.intValue
            
            if let cap, let maxC, maxC > 100, cap >= 0 {
                r.level = min(100, Int((Double(cap) / Double(maxC) * 100.0).rounded()))
            } else if let cap, cap >= 0, cap <= 100 {
                r.level = cap
            }
            let state = d[kIOPSPowerSourceStateKey] as? String ?? ""
            r.onAC = state == kIOPSACPowerValue || state == "AC Power"
            if let ch = d[kIOPSIsChargingKey] as? Bool {
                r.charging = ch
            } else if let n = d[kIOPSIsChargingKey] as? NSNumber {
                r.charging = n.boolValue
            }
            func iopsInt(_ key: String) -> Int? {
                if let t = d[key] as? Int { return t }
                if let n = d[key] as? NSNumber { return n.intValue }
                return nil
            }
            if let t = iopsInt(kIOPSTimeToEmptyKey), t > 0, t < 65535, r.charging != true {
                r.minutes = t
            }
            if let t = iopsInt(kIOPSTimeToFullChargeKey), t > 0, t < 65535, r.charging == true {
                r.minutes = t
            }
            break
        }
        return r
    }

    
    private static func readBatterySmartBattery() -> BatSourceReading {
        var r = BatSourceReading(name: "SmartBattery")
        let service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return r }
        defer { IOObjectRelease(service) }
        r.present = true

        // mAh pack values (for health + coulomb time estimates — not for menu % display)
        let rawCur = propInt(service, "AppleRawCurrentCapacity")
        let rawMax = propInt(service, "AppleRawMaxCapacity")
            ?? propInt(service, "NominalChargeCapacity")
        let nominal = propInt(service, "NominalChargeCapacity")
        r.rawCurrent = rawCur
        r.rawMax = rawMax ?? nominal

        let batData = propDict(service, "BatteryData")

        // Display % must match Apple menu bar / Control Center:
        // CurrentCapacity (0–100) and MaxCapacity=100 are the published SoC.
        // BatteryData.StateOfCharge is the raw fuel-gauge and often lags 1–3%.
        let displayCap = propInt(service, "CurrentCapacity")
        let maxCap = propInt(service, "MaxCapacity")
        let gaugeSoc = batData.flatMap { dictInt($0, "StateOfCharge") }
        if let cur = displayCap, cur >= 0, cur <= 100, maxCap == nil || maxCap == 100 || maxCap == cur || (maxCap ?? 0) <= 100 {
            r.level = cur
        } else if let cur = displayCap, let mx = maxCap, mx > 100, cur >= 0 {
            r.level = min(100, max(0, Int((Double(cur) / Double(mx) * 100.0).rounded())))
        } else if let soc = gaugeSoc, soc >= 0, soc <= 100 {
            r.level = soc
        } else if let raw = rawCur, let mx = r.rawMax, mx > 50 {
            r.level = min(100, max(0, Int((Double(raw) / Double(mx) * 100.0).rounded())))
        }

        if let c = propBool(service, "IsCharging") { r.charging = c; if c { r.onAC = true } }
        if let e = propBool(service, "ExternalConnected")
            ?? propBool(service, "AppleRawExternalConnected") {
            r.onAC = e || (r.charging == true)
        }
        if let fully = propBool(service, "FullyCharged"), fully {
            r.charging = false
            r.onAC = true
        }
        r.cycles = propInt(service, "CycleCount")
            ?? (batData.flatMap { dictInt($0, "CycleCount") })
        let design = propInt(service, "DesignCapacity")
            ?? batData.flatMap { dictInt($0, "DesignCapacity") }
            ?? 0
        r.design = design > 0 ? design : nil

        // Health = full-charge capacity vs design (AppleRawMax / Design)
        if let mx = r.rawMax ?? nominal, design > 0 {
            r.health = min(100, max(0, Int((Double(mx) / Double(design) * 100.0).rounded())))
        }

        var voltage = propInt(service, "AppleRawBatteryVoltage")
            ?? propInt(service, "Voltage")
            ?? 0
        if voltage == 0, let batData {
            voltage = dictInt(batData, "Voltage") ?? dictInt(batData, "AppleRawBatteryVoltage") ?? 0
        }
        // Cell sum is often more stable than pack Voltage on Apple Silicon
        if voltage <= 0, let cells = batData?["CellVoltage"] as? [Any] {
            let vals = cells.compactMap { ($0 as? NSNumber)?.intValue }.filter { $0 > 500 }
            if !vals.isEmpty { voltage = vals.reduce(0, +) }
        }
        r.voltageMV = voltage > 0 ? voltage : nil

        if let signed = propSignedAmperage(service, ["InstantAmperage", "Amperage"]) {
            r.amperageMA = signed
            if signed != 0, voltage > 0 {
                let w = abs(Double(signed)) / 1000.0 * Double(voltage) / 1000.0
                if (r.charging == true && signed > 0)
                    || (r.charging != true && signed < 0)
                    || abs(signed) > 40 {
                    r.chargeW = w
                }
            }
        }
        if let adapter = prop(service, "AdapterDetails") as? [String: Any] {
            if let w = (adapter["Watts"] as? NSNumber)?.doubleValue, w > 0 {
                r.adapterW = w
            }
        }
        if r.charging == true, (r.chargeW ?? 0) <= 0.1, let aw = r.adapterW, aw > 0 {
            r.chargeW = min(aw, 140)
        }
        if r.charging == true, (r.chargeW ?? 0) <= 0,
           let charger = prop(service, "ChargerData") as? [String: Any],
           let cc = (charger["ChargingCurrent"] as? NSNumber)?.intValue, cc > 0, voltage > 0 {
            r.chargeW = Double(cc) / 1000.0 * Double(voltage) / 1000.0
        }

        func validMin(_ t: Int?) -> Int? {
            guard let t, t > 0, t < 65535 else { return nil }
            return t
        }
        // TimeRemaining is the same value Apple exposes via pmset / menu bar.
        if r.charging == true {
            r.minutes = validMin(propInt(service, "TimeRemaining"))
                ?? validMin(propInt(service, "AvgTimeToFull"))
        } else if r.onAC != true {
            r.minutes = validMin(propInt(service, "TimeRemaining"))
                ?? validMin(propInt(service, "AvgTimeToEmpty"))
        } else {
            r.minutes = validMin(propInt(service, "TimeRemaining"))
        }
        return r
    }

    
    private static func readBatteryGauge() -> BatSourceReading {
        var r = BatSourceReading(name: "Gauge")
        let service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return r }
        defer { IOObjectRelease(service) }
        guard let batData = propDict(service, "BatteryData") else { return r }
        r.present = true
        if let soc = dictInt(batData, "StateOfCharge"), soc >= 0, soc <= 100 {
            r.level = soc
        }
        if let cyc = dictInt(batData, "CycleCount") { r.cycles = cyc }
        if let design = dictInt(batData, "DesignCapacity"), design > 0 {
            r.design = design
            if let fcc = dictInt(batData, "FccComp1") ?? dictInt(batData, "FccComp2"), fcc > 0 {
                r.rawMax = fcc
                r.health = min(100, max(0, Int((Double(fcc) / Double(design) * 100.0).rounded())))
            }
        }
        if let v = dictInt(batData, "Voltage"), v > 0 { r.voltageMV = v }
        
        if r.voltageMV == nil, let cells = batData["CellVoltage"] as? [Any] {
            let vals = cells.compactMap { ($0 as? NSNumber)?.intValue }.filter { $0 > 0 }
            if !vals.isEmpty {
                r.voltageMV = vals.reduce(0, +)
            }
        }
        return r
    }

    
    private static func readBatteryTelemetry() -> BatSourceReading {
        var r = BatSourceReading(name: "Telemetry")
        let service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return r }
        defer { IOObjectRelease(service) }
        guard let tel = propDict(service, "PowerTelemetryData") else { return r }
        r.present = true

        
        if let load = (tel["SystemLoad"] as? NSNumber)?.doubleValue, load > 150 {
            r.chargeW = load / 1000.0
        }
        
        if let bp = dictSignedMA(tel, "BatteryPower") {
            
            let watts = abs(Double(bp)) / 1000.0
            if watts > 0.15 && watts < 100 {
                
                if r.chargeW == nil || abs((r.chargeW ?? 0) - watts) > 1.5 {
                    r.chargeW = watts
                } else {
                    
                    r.chargeW = ((r.chargeW ?? watts) + watts) / 2.0
                }
            }
        }
        
        if let w = r.chargeW, w > 0.15 {
            let v = propInt(service, "AppleRawBatteryVoltage")
                ?? propInt(service, "Voltage")
                ?? 0
            if v > 8000 {
                r.voltageMV = v
                
                let ma = Int((w / (Double(v) / 1000.0) * 1000.0).rounded())
                let charging = propBool(service, "IsCharging") == true
                r.amperageMA = charging ? ma : -ma
            }
        }
        if let c = propBool(service, "IsCharging") { r.charging = c }
        if let e = propBool(service, "ExternalConnected") { r.onAC = e }
        return r
    }

    
    private static func readBatteryPmset() -> BatSourceReading {
        var r = BatSourceReading(name: "pmset")
        let out = shellCapture("/usr/bin/pmset", ["-g", "batt"])
        guard !out.isEmpty else { return r }
        
        if out.range(of: #"InternalBattery|Battery Power|AC Power"#, options: .regularExpression) != nil {
            r.present = out.contains("InternalBattery") || out.contains("Battery Power") || out.contains("%")
        }
        if let m = out.range(of: #"(\d{1,3})\s*%"#, options: .regularExpression) {
            let s = String(out[m]).replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            if let v = Int(s), v >= 0, v <= 100 { r.level = v }
        }
        let lower = out.lowercased()
        if lower.contains("charging") && !lower.contains("discharging") {
            r.charging = true
            r.onAC = true
        } else if lower.contains("discharging") {
            r.charging = false
            r.onAC = false
        } else if lower.contains("charged") || lower.contains("finishing charge") {
            r.charging = false
            r.onAC = true
        }
        if lower.contains("ac power") || lower.contains("attached") {
            r.onAC = true
        }
        
        if let m = out.range(of: #"(\d{1,3}):(\d{2})\s+remaining"#, options: [.regularExpression, .caseInsensitive]) {
            let s = String(out[m])
            if let hm = s.range(of: #"(\d{1,3}):(\d{2})"#, options: .regularExpression) {
                let parts = String(s[hm]).split(separator: ":")
                if parts.count == 2, let h = Int(parts[0]), let mins = Int(parts[1]) {
                    let total = h * 60 + mins
                    if total > 0, total < 65535 { r.minutes = total }
                }
            }
        }
        if lower.contains("no estimate") || lower.contains("calculating") {
            
        }
        return r
    }

    
    private static func readBatteryIoreg() -> BatSourceReading {
        var r = BatSourceReading(name: "ioreg")
        let out = shellCapture("/usr/sbin/ioreg", ["-rn", "AppleSmartBattery", "-c", "AppleSmartBattery"])
        guard out.contains("AppleSmartBattery") || out.contains("MaxCapacity") || out.contains("CurrentCapacity") else {
            return r
        }
        r.present = true
        func matchInt(_ pattern: String) -> Int? {
            guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            let range = NSRange(out.startIndex..., in: out)
            guard let m = re.firstMatch(in: out, options: [], range: range), m.numberOfRanges >= 2,
                  let r1 = Range(m.range(at: 1), in: out) else { return nil }
            return Int(out[r1])
        }
        func matchBool(_ key: String) -> Bool? {
            if out.range(of: "\"\(key)\"\\s*=\\s*Yes", options: .regularExpression) != nil { return true }
            if out.range(of: "\"\(key)\"\\s*=\\s*No", options: .regularExpression) != nil { return false }
            if let v = matchInt("\"\(key)\"\\s*=\\s*([01])\\b") { return v != 0 }
            return nil
        }

        let rawCur = matchInt("\"AppleRawCurrentCapacity\"\\s*=\\s*(\\d+)")
            ?? matchInt("\"AppleRawCurrentCapacity\"\\s*=\\s*(-?\\d+)")
        let rawMax = matchInt("\"AppleRawMaxCapacity\"\\s*=\\s*(\\d+)")
            ?? matchInt("\"MaxCapacity\"\\s*=\\s*(\\d+)")
        let curPct = matchInt("\"CurrentCapacity\"\\s*=\\s*(\\d+)")
        r.rawCurrent = rawCur
        r.rawMax = rawMax
        if let raw = rawCur, let mx = rawMax, mx > 0 {
            r.level = min(100, max(0, Int((Double(raw) / Double(mx) * 100).rounded())))
        } else if let curPct, curPct <= 100 {
            r.level = curPct
        }
        r.charging = matchBool("IsCharging")
        r.onAC = matchBool("ExternalConnected")
        if r.charging == true { r.onAC = true }
        r.cycles = matchInt("\"CycleCount\"\\s*=\\s*(\\d+)")
        let design = matchInt("\"DesignCapacity\"\\s*=\\s*(\\d+)")
        r.design = design
        if let rawMax, let design, design > 0 {
            r.health = min(100, max(0, Int((Double(rawMax) / Double(design) * 100).rounded())))
        }
        let voltage = matchInt("\"AppleRawBatteryVoltage\"\\s*=\\s*(\\d+)")
            ?? matchInt("\"Voltage\"\\s*=\\s*(\\d+)")
        r.voltageMV = voltage
        
        if let ampRaw = matchInt("\"InstantAmperage\"\\s*=\\s*(-?\\d+)")
            ?? matchInt("\"Amperage\"\\s*=\\s*(-?\\d+)") {
            let signed: Int = {
                if abs(ampRaw) <= 30_000 { return ampRaw }
                
                if let re = try? NSRegularExpression(pattern: "\"InstantAmperage\"\\s*=\\s*(\\d+)", options: []),
                   let m = re.firstMatch(in: out, range: NSRange(out.startIndex..., in: out)),
                   let r1 = Range(m.range(at: 1), in: out),
                   let u = UInt64(out[r1]) {
                    let s = Int64(bitPattern: u)
                    if abs(s) <= 30_000 { return Int(s) }
                }
                return signedMA(ampRaw)
            }()
            r.amperageMA = signed
            if let voltage, voltage > 0, signed != 0 {
                r.chargeW = abs(Double(signed)) / 1000.0 * Double(voltage) / 1000.0
            }
        }
        if let t = matchInt("\"AvgTimeToEmpty\"\\s*=\\s*(\\d+)"), t > 0, t < 65535, r.charging != true {
            r.minutes = t
        }
        if let t = matchInt("\"AvgTimeToFull\"\\s*=\\s*(\\d+)"), t > 0, t < 65535, r.charging == true {
            r.minutes = t
        }
        if let t = matchInt("\"TimeRemaining\"\\s*=\\s*(\\d+)"), t > 0, t < 65535, r.minutes == nil {
            r.minutes = t
        }
        return r
    }

    private static func shellCapture(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return ""
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    
    private static func mergeBatterySources(_ readings: [BatSourceReading]) -> BatSnap {
        var snap = BatSnap()
        let ok = readings.filter(\.ok)
        let byName = Dictionary(uniqueKeysWithValues: readings.map { ($0.name, $0) })
        let iops = byName["IOPS"]
        let pmset = byName["pmset"]
        let sb = byName["SmartBattery"]
        let gauge = byName["Gauge"]
        let telem = byName["Telemetry"]
        let ioreg = byName["ioreg"]

        snap.present = readings.contains { $0.present == true }

        if let c = sb?.charging { snap.charging = c }
        else if let c = iops?.charging { snap.charging = c }
        else if let c = pmset?.charging { snap.charging = c }
        if let ac = sb?.onAC { snap.onAC = ac }
        else if let ac = iops?.onAC { snap.onAC = ac }
        else if let ac = pmset?.onAC { snap.onAC = ac }
        if snap.charging { snap.onAC = true }

        // Single stable display % path — never mix raw mAh / StateOfCharge with menu bar SoC.
        // Order is fixed so consecutive polls don't flip between IOPS and SmartBattery.
        snap.level = pickDisplayPercent(
            smartBattery: sb?.level,
            iops: iops?.level,
            pmset: pmset?.level
        )

        for hw in [sb, gauge, telem, ioreg, iops, pmset].compactMap({ $0 }) {
            if snap.cycles == nil { snap.cycles = hw.cycles }
            if snap.health == nil { snap.health = hw.health }
            if snap.rawMax == nil { snap.rawMax = hw.rawMax }
            if snap.design == nil { snap.design = hw.design }
            if snap.rawCurrent == nil { snap.rawCurrent = hw.rawCurrent }
            if snap.amperageMA == nil { snap.amperageMA = hw.amperageMA }
            if snap.voltageMV == nil { snap.voltageMV = hw.voltageMV }
            if snap.chargeW <= 0, let w = hw.chargeW, w > 0 { snap.chargeW = w }
            if snap.adapterW <= 0, let w = hw.adapterW, w > 0 { snap.adapterW = w }
        }
        if let amp = sb?.amperageMA { snap.amperageMA = amp }
        if let v = sb?.voltageMV ?? gauge?.voltageMV { snap.voltageMV = v }

        if let amp = snap.amperageMA, let v = snap.voltageMV, v > 0, abs(amp) >= 20 {
            let wAmp = abs(Double(amp)) / 1000.0 * Double(v) / 1000.0
            if wAmp > 0.08 {
                // Watts for UI only — do not feed remaining-time math (causes thrash).
                snap.chargeW = wAmp
            }
        } else if let tw = telem?.chargeW, tw > 0.15 {
            snap.chargeW = tw
        }

        // Remaining time: SMC / IOPS / pmset only. Never blend live amp estimates into the
        // published number while a system estimate exists — that is what made time jump around.
        let smcMin = sanitizeMinutes(sb?.minutes, charging: snap.charging, onAC: snap.onAC)
            ?? sanitizeMinutes(ioreg?.minutes, charging: snap.charging, onAC: snap.onAC)
        let iopsMin = sanitizeMinutes(iops?.minutes, charging: snap.charging, onAC: snap.onAC)
        let pmsetMin = sanitizeMinutes(pmset?.minutes, charging: snap.charging, onAC: snap.onAC)

        if let smc = smcMin {
            snap.minutes = smc
            snap.minutesIsLiveEstimate = false
        } else if let m = iopsMin ?? pmsetMin {
            snap.minutes = m
            snap.minutesIsLiveEstimate = false
        } else if let live = computeLiveRemainingMinutes(snap) {
            // Fallback only when the pack has no estimate (still smoothed in applyBattery).
            snap.minutes = live
            snap.minutesIsLiveEstimate = true
        }

        if snap.charging { snap.onAC = true }
        if !snap.present && (snap.level > 0 || snap.rawCurrent != nil) { snap.present = true }

        var labels: [String] = []
        if sb?.ok == true || gauge?.ok == true { labels.append("SMC") }
        if sb?.amperageMA != nil { labels.append("IOKit") }
        if iops?.ok == true { labels.append("IOPS") }
        if pmset?.ok == true { labels.append("pmset") }
        snap.sourcesLabel = labels.isEmpty ? ok.map(\.name).joined(separator: " · ") : labels.joined(separator: " + ")
        snap.sourceNames = labels.isEmpty ? ok.map(\.name) : labels

        return finalizeBatterySnap(snap)
    }

    /// Fixed-priority display SoC (matches Apple menu bar). Never use raw mAh ratio here.
    private static func pickDisplayPercent(
        smartBattery: Int?,
        iops: Int?,
        pmset: Int?
    ) -> Int {
        // Prefer SmartBattery CurrentCapacity (same key Apple publishes), then IOPS, then pmset.
        if let b = smartBattery, b >= 0, b <= 100 { return b }
        if let a = iops, a >= 0, a <= 100 { return a }
        if let p = pmset, p >= 0, p <= 100 { return p }
        return 0
    }

    
    private static func computeLiveRemainingMinutes(_ snap: BatSnap) -> Int? {
        guard snap.present else { return nil }
        var candidates: [Int] = []
        guard let raw = snap.rawCurrent, let mx = snap.rawMax, mx > 50 else { return nil }
        let remaining = Double(min(max(raw, 0), mx))
        let need = Double(max(0, mx - raw))
        let v = Double(snap.voltageMV ?? 11_500) / 1000.0

        if let amp = snap.amperageMA {
            let ma = abs(Double(amp))
            if ma >= minLiveAmpMA {
                if snap.charging && amp > 0 {
                    if need <= 8 { return 1 }
                    let mins = Int((need / ma * 60.0).rounded())
                    if let s = sanitizeMinutes(mins, charging: true, onAC: true) { candidates.append(s) }
                } else if !snap.charging && !snap.onAC && amp < 0 {
                    let mins = Int((remaining / ma * 60.0).rounded())
                    if let s = sanitizeMinutes(mins, charging: false, onAC: false) { candidates.append(s) }
                }
            }
        }

        let drawW = snap.chargeW
        if drawW >= minLiveChargeW, v > 5 {
            if snap.charging {
                let whNeed = need / 1000.0 * v
                let mins = Int((whNeed / drawW * 60.0).rounded())
                if let s = sanitizeMinutes(mins, charging: true, onAC: true) { candidates.append(s) }
            } else if !snap.onAC {
                let whLeft = remaining / 1000.0 * v
                let mins = Int((whLeft / drawW * 60.0).rounded())
                if let s = sanitizeMinutes(mins, charging: false, onAC: false) { candidates.append(s) }
            }
        }

        guard !candidates.isEmpty else { return nil }
        let sorted = candidates.sorted()
        return sorted[(sorted.count - 1) / 2]
    }

    private static func finalizeBatterySnap(_ snap: BatSnap) -> BatSnap {
        var s = snap
        s.level = min(100, max(0, s.level))
        if s.charging { s.onAC = true }
        if s.sourcesLabel.isEmpty, !s.sourceNames.isEmpty {
            s.sourcesLabel = s.sourceNames.joined(separator: " · ")
        }
        s.minutes = sanitizeMinutes(s.minutes, charging: s.charging, onAC: s.onAC)
        return s
    }

    
    static func readPackageWattsDetailed() -> (watts: Double, source: String, distribution: SocPowerSample?) {
        if let sample = IOReportPowerReader.shared.sample(), sample.hasData {
            let pkg = sample.packageWatts
            if pkg > 0.05 {
                let src: String
                if sample.domainCount > 1 {
                    src = "sensor (\(sample.domainCount) domains)"
                } else {
                    src = "sensor"
                }
                return (min(max(pkg, 0.1), 120), src, sample)
            }
        }
        
        var load = loadavg()
        var sz = MemoryLayout<loadavg>.size
        guard sysctlbyname("vm.loadavg", &load, &sz, nil, 0) == 0, load.fscale > 0 else {
            return (0, "estimate", nil)
        }
        let l1 = Double(load.ldavg.0) / Double(load.fscale)
        var ncpu: Int32 = 1
        var nsz = MemoryLayout<Int32>.size
        sysctlbyname("hw.logicalcpu", &ncpu, &nsz, nil, 0)
        let util = min(1.0, l1 / Double(max(ncpu, 1)))
        
        let idle: Double = ncpu >= 10 ? 3.5 : 2.2
        let span: Double = ncpu >= 10 ? 28.0 : 18.0
        return (idle + util * span, "estimate", nil)
    }

    static func readPackageWatts() -> Double { readPackageWattsDetailed().watts }

    static func readCoreShares() -> (p: Double, e: Double) {
        var pcores: Int32 = 0
        var ecores: Int32 = 0
        var sz = MemoryLayout<Int32>.size
        
        if sysctlbyname("hw.perflevel0.logicalcpu", &pcores, &sz, nil, 0) != 0 {
            pcores = 0
        }
        sz = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel1.logicalcpu", &ecores, &sz, nil, 0) != 0 {
            ecores = 0
        }
        let total = Double(max(1, pcores + ecores))
        if pcores + ecores == 0 {
            return (0.5, 0.5)
        }
        
        return (Double(pcores) / total, Double(ecores) / total)
    }
}


struct ProcEnergy: Identifiable {
    let id: Int32
    let name: String
    let path: String
    var energyScore: Double
    var cpuPercent: Double
    
    var powerShare: Double
    
    var estimatedWatts: Double
    var samples: [Double]
}

final class ProcessEnergyStore: ObservableObject {
    static let shared = ProcessEnergyStore()
    @Published var top: [ProcEnergy] = []
    private var timer: Timer?
    private var lastCPU: [Int32: Double] = [:]
    private var lastWall = Date()
    private var history: [Int32: [Double]] = [:]
    private var wattsEma: [Int32: Double] = [:]
    private let historyCap = 30
    private var fastMode = false
    private var sampleInFlight = false
    private let workQ = DispatchQueue(label: "fathompro.proc", qos: .utility)
    private var lastTopLog: CFAbsoluteTime = 0
    private let ncpu: Double = {
        var n: Int32 = 1
        var sz = MemoryLayout<Int32>.size
        sysctlbyname("hw.logicalcpu", &n, &sz, nil, 0)
        return Double(max(1, n))
    }()

    func start() {
        restartTimer(interval: fastMode ? kProcPollUI : kProcPollIdle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.sample()
        }
    }

    func setFastMode(_ on: Bool) {
        guard fastMode != on else { return }
        fastMode = on
        restartTimer(interval: on ? kProcPollUI : kProcPollIdle)
        
        if on {
            workQ.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.sample()
            }
        }
    }

    private func restartTimer(interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
        t.tolerance = min(2.0, interval * 0.3)
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func sample() {
        if sampleInFlight { return }
        sampleInFlight = true
        let wantPaths = fastMode
        
        let packageW = PowerStore.shared.packageWatts
        let chargeW = PowerStore.shared.chargeWatts
        let onBatt = PowerStore.shared.batteryPresent && !PowerStore.shared.isOnAC && !PowerStore.shared.isCharging
        
        let attrWatts = onBatt && chargeW > 0.2 ? chargeW : max(packageW, 0)
        workQ.async { [weak self] in
            defer {
                DispatchQueue.main.async { self?.sampleInFlight = false }
            }
            guard let self else { return }
            let now = Date()
            let dt = max(1.0, now.timeIntervalSince(self.lastWall))
            self.lastWall = now
            struct Row {
                var pid: Int32
                var name: String
                var path: String
                var cores: Double
                var cpuPct: Double
            }
            var nextCPU: [Int32: Double] = [:]
            var candidates: [Row] = []

            var pids = [Int32](repeating: 0, count: 2048)
            let bufBytes = Int32(MemoryLayout<Int32>.stride * pids.count)
            let n = proc_listallpids(&pids, bufBytes) / Int32(MemoryLayout<Int32>.stride)
            let count = max(0, min(Int(n), pids.count))
            let minCores: Double = wantPaths ? 0.02 : 0.08
            for i in 0..<count {
                let pid = pids[i]
                if pid <= 0 || pid == getpid() { continue }
                var info = proc_taskallinfo()
                let sz = Int32(MemoryLayout<proc_taskallinfo>.stride)
                guard proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, sz) == sz else { continue }
                
                let user = Double(info.ptinfo.pti_total_user) / 1_000_000_000.0
                let sys = Double(info.ptinfo.pti_total_system) / 1_000_000_000.0
                let total = user + sys
                nextCPU[pid] = total
                let prev = self.lastCPU[pid] ?? total
                let delta = max(0, total - prev)
                
                let cores = min(self.ncpu, delta / dt)
                if cores < minCores { continue }
                
                let cpuPct = cores * 100.0
                var nameBuf = [CChar](repeating: 0, count: 256)
                let name: String
                if proc_name(pid, &nameBuf, UInt32(nameBuf.count)) > 0 {
                    name = String(cString: nameBuf)
                } else {
                    name = "pid \(pid)"
                }
                var path = ""
                if wantPaths {
                    var pathBuf = [CChar](repeating: 0, count: 1024)
                    if proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count)) > 0 {
                        path = String(cString: pathBuf)
                    }
                }
                candidates.append(Row(pid: pid, name: name, path: path, cores: cores, cpuPct: cpuPct))
            }
            let live = Set(nextCPU.keys)
            for k in self.history.keys where !live.contains(k) {
                self.history.removeValue(forKey: k)
                self.wattsEma.removeValue(forKey: k)
            }
            self.lastCPU = nextCPU

            
            let sumCores = candidates.reduce(0.0) { $0 + $1.cores }
            
            let denom = max(sumCores, 0.05)
            var rows: [ProcEnergy] = []
            rows.reserveCapacity(candidates.count)
            for c in candidates {
                let share = c.cores / denom
                
                
                var est = attrWatts * share
                
                
                let prevW = self.wattsEma[c.pid] ?? est
                est = prevW * 0.55 + est * 0.45
                self.wattsEma[c.pid] = est
                
                let score = est * 10.0 + c.cpuPct * 0.05
                var hist = self.history[c.pid] ?? []
                hist.append(est)
                if hist.count > self.historyCap { hist.removeFirst(hist.count - self.historyCap) }
                self.history[c.pid] = hist
                rows.append(ProcEnergy(
                    id: c.pid, name: c.name, path: c.path,
                    energyScore: score, cpuPercent: c.cpuPct,
                    powerShare: share, estimatedWatts: est, samples: hist
                ))
            }
            rows.sort { $0.estimatedWatts > $1.estimatedWatts }
            
            let topN = wantPaths ? 8 : 5
            var top = Array(rows.prefix(topN))
            let topSum = top.reduce(0.0) { $0 + max($1.estimatedWatts, 0) }
            if topSum > 0.05, attrWatts > 0.05 {
                
                let scale = attrWatts / topSum
                
                let capped = min(max(scale, 0.6), 1.35)
                for i in top.indices {
                    top[i].estimatedWatts = (self.wattsEma[top[i].id] ?? top[i].estimatedWatts) * capped
                    top[i].powerShare = top[i].estimatedWatts / max(attrWatts, 0.01)
                    top[i].energyScore = top[i].estimatedWatts * 10
                }
                top.sort { $0.estimatedWatts > $1.estimatedWatts }
            }
            DispatchQueue.main.async {
                let same = self.top.count == top.count
                    && zip(self.top, top).allSatisfy { a, b in
                        a.id == b.id
                            && abs(a.estimatedWatts - b.estimatedWatts) < 0.15
                            && abs(a.cpuPercent - b.cpuPercent) < 2
                    }
                if !same { self.top = top }
                if let first = top.first {
                    let t = CFAbsoluteTimeGetCurrent()
                    if t - self.lastTopLog >= 25 {
                        self.lastTopLog = t
                        DrainLog.shared.recordTopProcess(name: first.name, score: first.energyScore, cpu: first.cpuPercent)
                    }
                }
            }
        }
    }
}


final class DrainLog: ObservableObject {
    static let shared = DrainLog()
    @Published var retentionDays: Int = {
        let v = UserDefaults.standard.integer(forKey: "fathompro.retentionDays")
        return v > 0 ? v : 14
    }()

    private let fileURL = SUPPORT_DIR.appendingPathComponent("drain.jsonl")
    private let queue = DispatchQueue(label: "fathompro.drainlog")
    private var lastTopName = ""
    private var lastTopScore = 0.0

    func setRetention(_ days: Int) {
        retentionDays = max(1, min(30, days))
        UserDefaults.standard.set(retentionDays, forKey: "fathompro.retentionDays")
        prune()
    }

    func recordPower(level: Int, packageW: Double, chargeW: Double, charging: Bool) {
        queue.async {
            let line: [String: Any] = [
                "t": ISO8601DateFormatter().string(from: Date()),
                "kind": "power",
                "level": level,
                "packageW": packageW,
                "chargeW": chargeW,
                "charging": charging,
                "top": self.lastTopName,
                "topScore": self.lastTopScore
            ]
            self.append(line)
        }
    }

    func recordEvent(_ name: String) {
        queue.async {
            let line: [String: Any] = [
                "t": ISO8601DateFormatter().string(from: Date()),
                "kind": "event",
                "name": name
            ]
            self.append(line)
        }
    }

    func recordTopProcess(name: String, score: Double, cpu: Double) {
        lastTopName = name
        lastTopScore = score
        queue.async {
            let line: [String: Any] = [
                "t": ISO8601DateFormatter().string(from: Date()),
                "kind": "proc",
                "name": name,
                "score": score,
                "cpu": cpu
            ]
            self.append(line)
        }
    }

    private func append(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              var str = String(data: data, encoding: .utf8) else { return }
        str += "\n"
        if let d = str.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path),
               let h = try? FileHandle(forWritingTo: fileURL) {
                defer { try? h.close() }
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: d)
            } else {
                try? d.write(to: fileURL)
            }
        }
        
        if Int.random(in: 0..<30) == 0 { prune() }
    }

    func prune() {
        queue.async {
            guard let text = try? String(contentsOf: self.fileURL, encoding: .utf8) else { return }
            let cutoff = Date().addingTimeInterval(-Double(self.retentionDays) * 86400)
            let iso = ISO8601DateFormatter()
            var kept: [String] = []
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ts = obj["t"] as? String,
                      let d = iso.date(from: ts), d >= cutoff else { continue }
                kept.append(String(line))
            }
            try? (kept.joined(separator: "\n") + (kept.isEmpty ? "" : "\n")).write(to: self.fileURL, atomically: true, encoding: .utf8)
        }
    }

    func clearAll() {
        queue.async { try? FileManager.default.removeItem(at: self.fileURL) }
    }

    struct WhyDrain {
        let dropPercent: Int
        let windowLabel: String
        let culprits: [(name: String, share: Double, note: String)]
        let summary: String
    }

    func whyLastHour() -> WhyDrain {
        let iso = ISO8601DateFormatter()
        let since = Date().addingTimeInterval(-3600)
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return WhyDrain(dropPercent: 0, windowLabel: "last hour", culprits: [], summary: "Not enough local history yet — leave Fathom running while on battery.")
        }
        var levels: [(Date, Int)] = []
        var scores: [String: Double] = [:]
        var eventCounts: [String: Int] = [:]
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ts = obj["t"] as? String,
                  let d = iso.date(from: ts), d >= since else { continue }
            if obj["kind"] as? String == "power", let lv = obj["level"] as? Int {
                levels.append((d, lv))
                if let top = obj["top"] as? String, !top.isEmpty, let sc = obj["topScore"] as? Double {
                    scores[top, default: 0] += sc
                }
            }
            if obj["kind"] as? String == "proc", let n = obj["name"] as? String, let sc = obj["score"] as? Double {
                scores[n, default: 0] += sc
            }
            if obj["kind"] as? String == "event", let n = obj["name"] as? String {
                eventCounts[n, default: 0] += 1
            }
        }
        levels.sort { $0.0 < $1.0 }
        let drop: Int
        if let first = levels.first, let last = levels.last {
            drop = max(0, first.1 - last.1)
        } else {
            drop = 0
        }
        let total = scores.values.reduce(0, +)
        let ranked = scores.sorted { $0.value > $1.value }.prefix(3)
        var culprits: [(String, Double, String)] = []
        for (name, sc) in ranked {
            let share = total > 0 ? sc / total : 0
            culprits.append((name, share, String(format: "%.0f%% of attributed energy samples", share * 100)))
        }
        let summary: String
        if drop <= 0 {
            summary = culprits.isEmpty
                ? "Battery held steady over the last hour (or you were charging)."
                : "Battery held steady. Highest energy activity still logged for reference."
        } else if let top = culprits.first {
            summary = "\(top.0) was responsible for the largest share of energy use while battery dropped ~\(drop)% in the last hour."
        } else {
            summary = "Battery dropped ~\(drop)% in the last hour, but no dominant process was logged yet."
        }
        var notes: [String] = []
        if (eventCounts["display_wake"] ?? 0) >= 2 {
            notes.append("Display woke \(eventCounts["display_wake"]!)× in this window")
        }
        if (eventCounts["display_sleep"] ?? 0) >= 1 {
            notes.append("Display slept \(eventCounts["display_sleep"]!)×")
        }
        if (eventCounts["system_sleep"] ?? 0) >= 1 {
            notes.append("System sleep recorded")
        }
        var fullSummary = summary
        if !notes.isEmpty {
            fullSummary += " " + notes.joined(separator: ". ") + "."
        }
        return WhyDrain(dropPercent: drop, windowLabel: "last hour", culprits: culprits.map { ($0.0, $0.1, $0.2) }, summary: fullSummary)
    }
}


struct PowerSection: View {
    @ObservedObject var power = PowerStore.shared
    var body: some View {
        let summary: String = {
            if !power.batteryPresent { return String(format: "%.1f W pkg", power.packageWatts) }
            return "\(power.levelPercent)% · \(String(format: "%.1fW", power.packageWatts))"
        }()
        MonitorSection(title: "Power", accent: .accent, summary: summary,
                       sparkline: power.wattHistory, storageKey: "fathompro.section.power",
                       icon: "bolt.fill") {
            MonitorRow(label: "Battery", value: power.batteryPresent ? "\(power.levelPercent)%" : "—",
                       valueColor: .accent)
            MonitorRow(label: "Status", value: power.statusText)
            MonitorRow(label: "Time", value: power.timeText, valueColor: .labelSecondary)
            MonitorRow(label: "Package", value: String(format: "%.1f W", power.packageWatts), valueColor: .labelPrimary)
            MonitorRow(label: "Power source",
                       value: power.packageSource == "sensor" ? "IOReport sensor" : "load estimate",
                       valueColor: .labelSecondary)
            if power.isCharging {
                MonitorRow(label: "Charge in", value: String(format: "%.1f W", power.chargeWatts), valueColor: .labelPrimary)
            } else if power.chargeWatts > 0 {
                MonitorRow(label: power.batteryPresent && !power.isOnAC ? "Battery draw" : "Draw",
                           value: String(format: "%.1f W", power.chargeWatts), valueColor: .labelPrimary)
            }
            if let h = power.healthPercent {
                MonitorRow(label: "Health", value: "\(h)%", valueColor: .labelPrimary)
            }
            if let c = power.cycleCount {
                MonitorRow(label: "Cycles", value: "\(c)")
            }
            if let raw = power.capacityRaw, let design = power.designCapacity {
                MonitorRow(label: "Capacity", value: "\(raw) / \(design) mAh")
            }
            MonitorRow(label: "P-cores", value: String(format: "~%.0f%%", power.pCoreShare * 100))
            MonitorRow(label: "E-cores", value: String(format: "~%.0f%%", power.eCoreShare * 100))
            Text("CPU package (60s)")
                .font(uiFont(11, weight: .regular))
                .foregroundColor(.labelTertiary)
                .padding(.top, 6)
        }
    }
}

struct EnergySection: View {
    @ObservedObject var store = ProcessEnergyStore.shared
    @State private var expanded: Int32?
    var body: some View {
        let topName = store.top.first?.name ?? "…"
        MonitorSection(title: "Energy", accent: .nOrange, summary: topName,
                       storageKey: "fathompro.section.energy", icon: "cpu") {
            Text("Estimated watts = package/battery draw × each app’s CPU core share. Not Activity Monitor’s private Energy Impact.")
                .font(uiFont(11, weight: .regular))
                .foregroundColor(.labelTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            if store.top.isEmpty {
                Text("Sampling processes…")
                    .font(uiFont(13))
                    .foregroundColor(.labelSecondary)
            }
            ForEach(store.top.prefix(8)) { p in
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        expanded = expanded == p.id ? nil : p.id
                    } label: {
                        HStack(spacing: 10) {
                            Text(p.name)
                                .font(uiFont(13, weight: .medium))
                                .foregroundColor(.labelPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(BatteryMenuChrome.energyLabel(cpuPercent: p.cpuPercent, estimatedWatts: p.estimatedWatts))
                                .font(uiFont(13, weight: .semibold))
                                .foregroundColor(.labelPrimary)
                                .monospacedDigit()
                            Text(String(format: "%.0f%%", min(p.cpuPercent, 999)))
                                .font(uiFont(12, weight: .regular))
                                .foregroundColor(.labelSecondary)
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    if expanded == p.id {
                        Sparkline(values: p.samples, color: .labelSecondary)
                            .frame(height: 32)
                        Text(String(format: "~%.0f%% of measured CPU · pid %d", p.powerShare * 100, p.id))
                            .font(uiFont(10, weight: .regular))
                            .foregroundColor(.labelTertiary)
                        Text(p.path.isEmpty ? "path unknown" : p.path)
                            .font(uiFont(10, weight: .regular))
                            .foregroundColor(.labelTertiary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

struct WhySection: View {
    @State private var why = DrainLog.shared.whyLastHour()
    var body: some View {
        let summary = why.dropPercent > 0 ? "−\(why.dropPercent)%" : "steady"
        MonitorSection(title: "Why drain?", accent: .nPurple, summary: summary,
                       storageKey: "fathompro.section.why", icon: "questionmark.circle") {
            Text(why.summary)
                .font(uiFont(13, weight: .regular))
                .foregroundColor(.labelPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)
            if why.dropPercent > 0 {
                MonitorRow(label: "Drop", value: "~\(why.dropPercent)% · \(why.windowLabel)", valueColor: .labelPrimary)
            }
            ForEach(Array(why.culprits.enumerated()), id: \.offset) { _, c in
                MonitorRow(label: c.name, value: c.note, valueColor: .labelPrimary)
            }
            MinimalButton(title: "Refresh analysis") {
                why = DrainLog.shared.whyLastHour()
            }
            .padding(.top, 8)
        }
    }
}


enum LaunchAtLoginHelper {
    static var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return UserDefaults.standard.bool(forKey: kLaunchAtLogin)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kLaunchAtLogin)
            apply(newValue)
        }
    }

    static func apply(_ on: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if on {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                
                NSLog("Fathom LaunchAtLogin: %@", error.localizedDescription)
            }
        }
    }

    
    static func syncFromSystem() {
        if #available(macOS 13.0, *) {
            UserDefaults.standard.set(SMAppService.mainApp.status == .enabled, forKey: kLaunchAtLogin)
        }
    }
}

struct SettingsSection: View {
    @ObservedObject var log = DrainLog.shared
    @State private var days: Double = Double(DrainLog.shared.retentionDays)
    var body: some View {
        MonitorSection(title: "Settings", accent: .labelSecondary, summary: FATHOM_VERSION,
                       storageKey: "fathompro.section.settings", defaultExpanded: false,
                       icon: "gearshape") {
            MonitorRow(label: "Version", value: UpdateChecker.displayLabel(FATHOM_VERSION), valueColor: .labelPrimary)
            MonitorRow(label: "Channel", value: FATHOM_CHANNEL)
            MonitorRow(label: "Install", value: UpdateChecker.installPathLabel())
            Toggle(isOn: Binding(
                get: { LaunchAtLoginHelper.isEnabled },
                set: { LaunchAtLoginHelper.isEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login")
                        .font(uiFont(12, weight: .regular))
                        .foregroundColor(.labelPrimary)
                    Text("Start Fathom when you log in.")
                        .font(uiFont(10))
                        .foregroundColor(.labelTertiary)
                }
            }
            .toggleStyle(.switch)
            .tint(Color.white.opacity(0.55))
            .padding(.vertical, 4)
            HStack(spacing: 8) {
                MinimalButton(title: "Check for Updates") { UpdateChecker.checkManually() }
                MinimalButton(title: "Open website") { NSWorkspace.shared.open(UPDATE_PAGE_URL) }
            }
            .padding(.vertical, 6)
            Text("History retention: \(Int(days)) days")
                .font(uiFont(12, weight: .regular))
                .foregroundColor(.labelSecondary)
            Slider(value: $days, in: 1...30, step: 1)
                .tint(Color.white.opacity(0.55))
                .onChange(of: days) { _, newVal in log.setRetention(Int(newVal)) }
            HStack(spacing: 8) {
                MinimalButton(title: "Clear local history") { log.clearAll() }
                MinimalButton(title: "Reveal data folder") { NSWorkspace.shared.open(SUPPORT_DIR) }
            }
            Text(SUPPORT_DIR.path)
                .font(uiFont(10, weight: .regular))
                .foregroundColor(.labelTertiary)
                .lineLimit(2)
            Text("Local only — no accounts, no telemetry.")
                .font(uiFont(11, weight: .regular))
                .foregroundColor(.labelTertiary)
                .padding(.top, 6)
        }
    }
}


final class DrainAlertMonitor {
    static let shared = DrainAlertMonitor()
    private let lastAlertKey = "fathompro.drainAlerts.lastFire"
    private var levelTrail: [(Date, Int)] = []

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: kDrainAlertsEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: kDrainAlertsEnabled)
            if newValue { shared.requestPermission() }
        }
    }

    static var dropPercent: Int {
        get {
            let v = UserDefaults.standard.object(forKey: kDrainAlertsDropPercent) as? Int
            return max(2, min(v ?? 5, 30))
        }
        set { UserDefaults.standard.set(max(2, min(newValue, 30)), forKey: kDrainAlertsDropPercent) }
    }

    static var windowMinutes: Int {
        get {
            let v = UserDefaults.standard.object(forKey: kDrainAlertsWindowMinutes) as? Int
            return max(5, min(v ?? 15, 60))
        }
        set { UserDefaults.standard.set(max(5, min(newValue, 60)), forKey: kDrainAlertsWindowMinutes) }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(level: Int, onBattery: Bool) {
        let now = Date()
        levelTrail.append((now, level))
        let keep = now.addingTimeInterval(-Double(Self.windowMinutes + 5) * 60)
        levelTrail.removeAll { $0.0 < keep }
        guard Self.isEnabled, onBattery else { return }

        let window = TimeInterval(Self.windowMinutes * 60)
        guard let oldest = levelTrail.first(where: { now.timeIntervalSince($0.0) >= window * 0.85 })
                ?? levelTrail.first else { return }
        let drop = oldest.1 - level
        guard drop >= Self.dropPercent else { return }

        
        if let last = UserDefaults.standard.object(forKey: lastAlertKey) as? Date,
           now.timeIntervalSince(last) < 30 * 60 {
            return
        }
        UserDefaults.standard.set(now, forKey: lastAlertKey)

        let top = ProcessEnergyStore.shared.top.first?.name
        let body: String
        if let top {
            body = "Battery dropped \(drop)% in ~\(Self.windowMinutes) min. Top energy: \(top)."
        } else {
            body = "Battery dropped \(drop)% in ~\(Self.windowMinutes) min while on battery."
        }
        let content = UNMutableNotificationContent()
        content.title = "Fathom · drain alert"
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "fathompro.drain.\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}


enum BatteryMenuChrome {
    static func openBatterySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Battery-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.battery",
            "x-apple.systempreferences:com.apple.settings.Battery",
        ]
        for s in candidates {
            if let u = URL(string: s), NSWorkspace.shared.open(u) { return }
        }
        if let u = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(u)
        }
    }

    
    static func energyLabel(cpuPercent: Double, estimatedWatts: Double = 0) -> String {
        if estimatedWatts >= 0.08 {
            if estimatedWatts >= 10 { return String(format: "%.0f W", estimatedWatts) }
            if estimatedWatts >= 1 { return String(format: "%.1f W", estimatedWatts) }
            return String(format: "%.2f W", estimatedWatts)
        }
        return batFiEnergyLabel(cpuPercent: cpuPercent)
    }

    
    static func batFiEnergyLabel(cpuPercent: Double) -> String {
        if cpuPercent >= 80 { return "High" }
        if cpuPercent >= 25 { return "Moderate" }
        return "Low"
    }

    static func batterySymbol(level: Int, charging: Bool, onAC: Bool, present: Bool) -> String {
        if !present { return "powerplug.fill" }
        if charging || (onAC && level < 100) {
            if level >= 95 { return "battery.100.bolt" }
            if level >= 70 { return "battery.75.bolt" }
            if level >= 45 { return "battery.50.bolt" }
            if level >= 20 { return "battery.25.bolt" }
            return "battery.0.bolt"
        }
        if level >= 95 { return "battery.100" }
        if level >= 70 { return "battery.75" }
        if level >= 45 { return "battery.50" }
        if level >= 20 { return "battery.25" }
        return "battery.0"
    }

    
    static var criticalBatteryPercent: Int {
        get {
            let v = UserDefaults.standard.object(forKey: kCriticalBatteryPercent) as? Int
            return max(5, min(v ?? kCriticalBatteryPercentDefault, 50))
        }
        set {
            UserDefaults.standard.set(max(5, min(newValue, 50)), forKey: kCriticalBatteryPercent)
            NotificationCenter.default.post(name: .fathomMenuBarDisplayChanged, object: nil)
        }
    }

    
    /// Menu bar battery glyph color.
    /// green = charging · red = critical · yellow = Low Power Mode · white = discharging
    enum BatteryTint {
        case discharging, charging, lowPower, critical
    }

    static func batteryTint(
        level: Int,
        charging: Bool,
        onAC: Bool,
        present: Bool,
        lowPower: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    ) -> BatteryTint {
        if !present { return .discharging }
        // Priority: charging → critical → Low Power Mode → normal discharge
        if charging { return .charging }
        if !onAC && level <= criticalBatteryPercent { return .critical }
        if lowPower { return .lowPower }
        return .discharging
    }

    static func tintNSColor(_ tint: BatteryTint) -> NSColor {
        switch tint {
        case .charging:
            // Green
            return NSColor(calibratedRed: 0.20, green: 0.86, blue: 0.40, alpha: 1)
        case .lowPower:
            // Yellow (Low Power Mode)
            return NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.12, alpha: 1)
        case .critical:
            // Red
            return NSColor(calibratedRed: 0.98, green: 0.26, blue: 0.26, alpha: 1)
        case .discharging:
            // White (discharging / default)
            return NSColor.white
        }
    }

    static func tintSwiftUI(_ tint: BatteryTint) -> Color {
        switch tint {
        case .charging: return Color(red: 0.20, green: 0.86, blue: 0.40)
        case .lowPower: return Color(red: 1.0, green: 0.80, blue: 0.12)
        case .critical: return Color(red: 0.98, green: 0.26, blue: 0.26)
        case .discharging: return .white
        }
    }
}

struct MenuSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(uiFont(FathomType.caption, weight: .semibold))
            .foregroundColor(.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }
}

struct MenuRowButton: View {
    let title: String
    var systemImage: String? = nil
    var trailing: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.labelPrimary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                Text(title)
                    .font(uiFont(13, weight: .regular))
                    .foregroundColor(.labelPrimary)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(uiFont(13, weight: .regular))
                        .foregroundColor(.labelSecondary)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


enum FathomStatusCopy {
    static func powerSourceLine(power: PowerStore) -> String {
        if !power.batteryPresent { return "Power Adapter" }
        if power.isCharging { return "Power Adapter" }
        if power.isOnAC { return "Power Adapter" }
        return "Battery"
    }

    static func onBatteryLine(power: PowerStore) -> String {
        if !power.batteryPresent { return "Desktop · AC only" }
        if power.isCharging {
            return "Charging · package \(String(format: "%.1f W", power.packageWatts))"
        }
        if power.isOnAC {
            if power.levelPercent >= 100 {
                return "Fully Charged · package \(String(format: "%.1f W", power.packageWatts))"
            }
            return "On Adapter · package \(String(format: "%.1f W", power.packageWatts))"
        }
        return "On Battery · package \(String(format: "%.1f W", power.packageWatts))"
    }

    static func timeDetail(power: PowerStore) -> String {
        if !power.batteryPresent { return "AC power" }
        if power.isCharging { return power.timeText }
        if power.isOnAC {
            return power.levelPercent >= 100 ? "Fully Charged" : power.statusText
        }
        return power.timeText
    }

    static func topAppLine(energy: ProcessEnergyStore) -> String {
        guard let top = energy.top.first else { return "None" }
        let label = BatteryMenuChrome.energyLabel(cpuPercent: top.cpuPercent, estimatedWatts: top.estimatedWatts)
        return "\(top.name) · \(label)"
    }

    static func energyModeLine(lowPower: Bool) -> String {
        lowPower ? "Low Power On" : "Low Power Off"
    }
}


struct StatusKVRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.white.opacity(0.45))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.white.opacity(0.92))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}


struct BatFiSectionTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }
}


final class MenuPanelModel: ObservableObject {
    static let shared = MenuPanelModel()

    @Published var levelPercent = 0
    @Published var isCharging = false
    @Published var isOnAC = false
    @Published var batteryPresent = false
    @Published var packageWatts: Double = 0
    @Published var chargeWatts: Double = 0
    @Published var cpuDomainWatts: Double = 0
    @Published var gpuDomainWatts: Double = 0
    @Published var aneDomainWatts: Double = 0
    @Published var dramDomainWatts: Double = 0
    @Published var otherDomainWatts: Double = 0
    @Published var hasPowerDistribution = false
    @Published var timeDetail = "—"
    @Published var powerSource = "—"
    @Published var lowPower = false
    @Published var statusText = "—"
    @Published var cycleCount: Int?
    @Published var healthPercent: Int?
    @Published var spark: [Double] = []
    @Published var sparkLabel = "Power"
    @Published var topApps: [ProcEnergy] = []

    private var timer: Timer?
    private var tracking = false

    func startTracking() {
        guard !tracking else { return }
        tracking = true
        refreshNow()
        let t = Timer(timeInterval: kMenuPanelTick, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
        t.tolerance = 0.12
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func stopTracking() {
        tracking = false
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        let p = PowerStore.shared
        let e = ProcessEnergyStore.shared
        
        var dirty = false
        if levelPercent != p.levelPercent { levelPercent = p.levelPercent; dirty = true }
        if isCharging != p.isCharging { isCharging = p.isCharging; dirty = true }
        if isOnAC != p.isOnAC { isOnAC = p.isOnAC; dirty = true }
        if batteryPresent != p.batteryPresent { batteryPresent = p.batteryPresent; dirty = true }
        let pkg = (p.packageWatts * 10).rounded() / 10
        if abs(packageWatts - pkg) >= 0.05 { packageWatts = p.packageWatts; dirty = true }
        let ch = (p.chargeWatts * 10).rounded() / 10
        if abs(chargeWatts - ch) >= 0.05 { chargeWatts = p.chargeWatts; dirty = true }
        if abs(cpuDomainWatts - p.cpuDomainWatts) >= 0.05 { cpuDomainWatts = p.cpuDomainWatts; dirty = true }
        if abs(gpuDomainWatts - p.gpuDomainWatts) >= 0.05 { gpuDomainWatts = p.gpuDomainWatts; dirty = true }
        if abs(aneDomainWatts - p.aneDomainWatts) >= 0.05 { aneDomainWatts = p.aneDomainWatts; dirty = true }
        if abs(dramDomainWatts - p.dramDomainWatts) >= 0.05 { dramDomainWatts = p.dramDomainWatts; dirty = true }
        if abs(otherDomainWatts - p.otherDomainWatts) >= 0.05 { otherDomainWatts = p.otherDomainWatts; dirty = true }
        if hasPowerDistribution != p.hasPowerDistribution { hasPowerDistribution = p.hasPowerDistribution; dirty = true }
        let td = FathomStatusCopy.timeDetail(power: p)
        if timeDetail != td { timeDetail = td; dirty = true }
        let ps = FathomStatusCopy.powerSourceLine(power: p)
        if powerSource != ps { powerSource = ps; dirty = true }
        let lp = ProcessInfo.processInfo.isLowPowerModeEnabled
        if lowPower != lp { lowPower = lp; dirty = true }
        let st = p.statusText
        if statusText != st { statusText = st; dirty = true }
        if cycleCount != p.cycleCount { cycleCount = p.cycleCount; dirty = true }
        if healthPercent != p.healthPercent { healthPercent = p.healthPercent; dirty = true }

        
        let src = p.wattHistorySpark
        if !src.isEmpty {
            let step = max(1, src.count / 40)
            var slim: [Double] = []
            slim.reserveCapacity(min(40, src.count))
            var i = 0
            while i < src.count {
                slim.append(src[i])
                i += step
            }
            if slim.count != spark.count || zip(slim, spark).contains(where: { abs($0 - $1) > 0.15 }) {
                spark = slim
                dirty = true
            }
        }
        let n = max(1, p.wattHistory.count)
        
        let secs = n * 6
        let label: String
        if secs >= 50 * 60 { label = "\(FathomCopy.powerDraw) · last hour" }
        else if secs >= 60 { label = "\(FathomCopy.powerDraw) · last \(max(1, secs / 60)) min" }
        else { label = "\(FathomCopy.powerDraw)" }
        if sparkLabel != label { sparkLabel = label; dirty = true }

        let tops = Array(e.top.prefix(5))
        if tops.count != topApps.count
            || zip(tops, topApps).contains(where: {
                $0.id != $1.id || abs($0.estimatedWatts - $1.estimatedWatts) > 0.12
            }) {
            topApps = tops
            dirty = true
        }
        _ = dirty
    }
}


struct MainRoot: View {
    
    var panelWidth: CGFloat = kPopoverWidth
    var panelHeight: CGFloat = 480

    @ObservedObject private var ui = MenuPanelModel.shared
    @ObservedObject private var charge = ChargeLimitController.shared
    @State private var whySummary = ""
    @State private var whyDrop = 0
    @State private var whyWindow = ""
    @State private var whyCulprit: String?
    @State private var whyNote: String?
    @State private var showOnboarding = !FathomOnboarding.hasSeen
    @State private var refreshedWhy = false
    @State private var whyLoaded = false
    @State private var chromeStyle = MenuChromeStyle.current

    private var padH: CGFloat { chromeStyle.padH }

    private var battTint: BatteryMenuChrome.BatteryTint {
        BatteryMenuChrome.batteryTint(
            level: ui.levelPercent,
            charging: ui.isCharging,
            onAC: ui.isOnAC,
            present: ui.batteryPresent,
            lowPower: ui.lowPower
        )
    }

    
    private var batFiTimeParts: (label: String, value: String)? {
        if !ui.batteryPresent { return nil }
        let t = ui.timeDetail
        if charge.forceDischarge {
            return ("Status", "Discharging")
        }
        if ui.isCharging || charge.forceFullCharge {
            if t == "—" || t.isEmpty || t == "Calculating…" {
                return ("Time to Full", "Calculating…")
            }
            return ("Time to Full", shortTime(t))
        }
        if ui.isOnAC {
            if charge.isEnabled && charge.status == .holding {
                return ("Status", "Inhibiting charging")
            }
            if ui.levelPercent >= 100 { return ("Status", "Fully Charged") }
            return ("Status", t == "—" ? "On Power Adapter" : t)
        }
        if t == "—" || t.isEmpty || t == "Calculating…" {
            return ("Time Remaining", "Calculating…")
        }
        return ("Time Remaining", shortTime(t))
    }

    
    private var batFiAppMode: String {
        if !ui.batteryPresent { return "Desktop · AC only" }
        if charge.isEnabled { return charge.appModeLabel }
        if ui.lowPower { return "Low Power Mode" }
        if ui.isCharging { return "Charging" }
        if ui.isOnAC {
            return ui.levelPercent >= 100 ? "Fully Charged" : "Connected to Power"
        }
        return "Discharging"
    }

    private func shortTime(_ raw: String) -> String {
        
        var s = raw
        for drop in [" remaining", " remaining.", " until full", " left"] {
            if let r = s.range(of: drop, options: .caseInsensitive) { s.removeSubrange(r) }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func appIcon(for p: ProcEnergy) -> NSImage {
        if !p.path.isEmpty, FileManager.default.fileExists(atPath: p.path) {
            return NSWorkspace.shared.icon(forFile: p.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    var body: some View {
        
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                
                VStack(alignment: .leading, spacing: 8) {
                    BatFiMainRow(
                        label: "Battery",
                        value: ui.batteryPresent ? "\(ui.levelPercent)%" : "—",
                        emphasizeValue: true
                    )
                    if let time = batFiTimeParts {
                        BatFiDetailRow(label: time.label, value: time.value)
                    }
                    BatFiDetailRow(label: "App Mode", value: batFiAppMode)
                }

                BatFiSeparator()

                
                VStack(alignment: .leading, spacing: 8) {
                    BatFiDetailRow(label: "Power Source", value: ui.powerSource)
                    if let cycles = ui.cycleCount {
                        BatFiDetailRow(label: "Cycle Count", value: "\(cycles)")
                    }
                    if let health = ui.healthPercent {
                        BatFiDetailRow(label: "Battery Capacity", value: "\(health)%")
                    }
                    BatFiDetailRow(
                        label: "Low Power Mode",
                        value: ui.lowPower ? "On" : "Off"
                    )
                    if ui.packageWatts > 0.05 {
                        BatFiDetailRow(
                            label: "Power Draw",
                            value: String(format: "%.1f W", ui.packageWatts)
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                BatFiSeparator()

                // Charge management
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $charge.isEnabled) {
                        Text("Manage charging")
                            .font(.callout)
                    }
                    .toggleStyle(.switch)

                    if charge.isEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Charge limit")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(charge.limitPercent))%")
                                    .font(.callout.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $charge.limitPercent, in: 50...100, step: 1)
                            Text(charge.detail)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let err = charge.lastError, !err.isEmpty {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }

                        VStack(spacing: 2) {
                            if charge.forceFullCharge || charge.forceDischarge {
                                BatFiMenuAction(title: "Stop override", showChevron: false) {
                                    charge.stopOverride()
                                }
                            } else {
                                BatFiMenuAction(title: "Charge to 100%", showChevron: false) {
                                    charge.chargeToFullNow()
                                }
                                BatFiMenuAction(title: "Discharge battery", showChevron: false) {
                                    charge.dischargeBattery()
                                }
                            }
                        }
                    }
                }

                if ui.hasPowerDistribution || ui.packageWatts > 0.05 {
                    BatFiSeparator()
                    PowerDistributionView(
                        cpu: ui.cpuDomainWatts,
                        gpu: ui.gpuDomainWatts,
                        ane: ui.aneDomainWatts,
                        dram: ui.dramDomainWatts,
                        other: ui.otherDomainWatts,
                        package: ui.packageWatts,
                        compact: true
                    )
                }

                
                BatFiSeparator()
                PlusWeatherSection()
                BatFiSeparator()
                PlusChatSection()

BatFiSeparator()

                
                VStack(alignment: .leading, spacing: 12) {
                    Text("High Energy Usage")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if ui.topApps.isEmpty {
                        Text(whyLoaded ? "None" : "Loading…")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(ui.topApps.prefix(5)) { p in
                                HStack(spacing: 8) {
                                    Image(nsImage: appIcon(for: p))
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    Text(p.name)
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(BatteryMenuChrome.batFiEnergyLabel(cpuPercent: p.cpuPercent))
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                BatFiSeparator()

                
                VStack(alignment: .leading, spacing: 2) {
                    BatFiMenuAction(title: "Settings…", showChevron: true) {
                        NotificationCenter.default.post(name: .fathomClosePopover, object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NotificationCenter.default.post(name: .fathomOpenPreferences, object: nil)
                        }
                    }
                    BatFiMenuAction(title: FathomCopy.fullWindow, showChevron: true) {
                        NotificationCenter.default.post(name: .fathomOpenDashboard, object: nil)
                    }
                    BatFiMenuAction(title: FathomProLink.buttonTitle, showChevron: true) {
                        NotificationCenter.default.post(name: .fathomClosePopover, object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            FathomProLink.openOrInstall()
                        }
                    }
                    BatFiMenuAction(title: "Open Battery Settings…", showChevron: true) {
                        BatteryMenuChrome.openBatterySettings()
                    }

                    BatFiMenuAction(title: "Quit Fathom Pro") {
                        NotificationCenter.default.post(name: .fathomClosePopover, object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NSApp.terminate(nil)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .transaction { $0.animation = nil }
        .onExitCommand {
            NotificationCenter.default.post(name: .fathomClosePopover, object: nil)
        }
        .sheet(isPresented: $showOnboarding) {
            FathomOnboardingSheet(isPresented: $showOnboarding)
        }
        .onAppear {
            chromeStyle = .newer
            MenuChromeStyle.set(.newer)
            if !whyLoaded { loadWhy(force: false) }
            if !FathomOnboarding.hasSeen { showOnboarding = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fathomMenuBarDisplayChanged)) { _ in
            chromeStyle = MenuChromeStyle.current
        }
    }

    private func loadWhy(force: Bool) {
        DispatchQueue.global(qos: .utility).async {
            let w = DrainLog.shared.whyLastHour()
            DispatchQueue.main.async {
                whySummary = w.summary
                whyDrop = w.dropPercent
                whyWindow = w.windowLabel
                if let c = w.culprits.first {
                    whyCulprit = c.name
                    whyNote = c.note
                } else {
                    whyCulprit = nil
                    whyNote = nil
                }
                whyLoaded = true
            }
        }
        _ = force
    }

    private func wattsChip(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(uiFont(9, weight: .semibold))
                .foregroundColor(.labelTertiary)
                .tracking(0.6)
            Text(String(format: "%.1f W", value))
                .font(uiFont(14, weight: .semibold))
                .foregroundColor(.labelPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}


final class DashboardPrefs: ObservableObject {
    static let shared = DashboardPrefs()

    
    @Published var showFauxMenubar = true
    @Published var showFathomPill = true
    @Published var showPackageLine = true
    @Published var largePercent = true
    
    @Published var showPowerSource = true
    @Published var showEnergyMode = true
    @Published var showAppsRow = true
    @Published var showWhyRow = true
    
    @Published var showSparkline = false
    @Published var showTopAppsList = false
    @Published var showWhyDetail = false
    @Published var showHealth = false
    @Published var showTimeRemaining = false
    @Published var showPowerDistribution = true
    
    @Published var density: Density = .comfortable
    @Published var width: CardWidth = .regular
    @Published var cornerRadius: Double = 18

    enum Density: String, CaseIterable, Identifiable {
        case compact, comfortable, roomy
        var id: String { rawValue }
        var label: String {
            switch self {
            case .compact: return "Compact"
            case .comfortable: return "Comfortable"
            case .roomy: return "Roomy"
            }
        }
        var rowPad: CGFloat {
            switch self {
            case .compact: return 8
            case .comfortable: return 13
            case .roomy: return 17
            }
        }
        var hPad: CGFloat {
            switch self {
            case .compact: return 20
            case .comfortable: return 28
            case .roomy: return 32
            }
        }
        var heroSize: CGFloat {
            switch self {
            case .compact: return 42
            case .comfortable: return 56
            case .roomy: return 64
            }
        }
    }

    enum CardWidth: String, CaseIterable, Identifiable {
        case narrow, regular, wide
        var id: String { rawValue }
        var label: String {
            switch self {
            case .narrow: return "Narrow"
            case .regular: return "Regular"
            case .wide: return "Wide"
            }
        }
        var points: CGFloat {
            switch self {
            case .narrow: return 360
            case .regular: return 440
            case .wide: return 520
            }
        }
    }

    private init() { load() }

    func load() {
        let d = UserDefaults.standard
        func b(_ k: String, _ def: Bool) -> Bool {
            if d.object(forKey: kDashboardPrefs + "." + k) == nil { return def }
            return d.bool(forKey: kDashboardPrefs + "." + k)
        }
        showFauxMenubar = b("fauxMenubar", true)
        showFathomPill = b("pill", true)
        showPackageLine = b("packageLine", true)
        largePercent = b("largePercent", true)
        showPowerSource = b("powerSource", true)
        showEnergyMode = b("energyMode", true)
        showAppsRow = b("appsRow", true)
        showWhyRow = b("whyRow", true)
        showSparkline = b("sparkline", false)
        showTopAppsList = b("topApps", false)
        showWhyDetail = b("whyDetail", false)
        showHealth = b("health", false)
        showTimeRemaining = b("timeRemaining", false)
        showPowerDistribution = b("powerDistribution", true)
        if let s = d.string(forKey: kDashboardPrefs + ".density"),
           let v = Density(rawValue: s) { density = v }
        if let s = d.string(forKey: kDashboardPrefs + ".width"),
           let v = CardWidth(rawValue: s) { width = v }
        let cr = d.double(forKey: kDashboardPrefs + ".corner")
        if cr >= 8 { cornerRadius = cr } else { cornerRadius = 18 }
    }

    func save() {
        let d = UserDefaults.standard
        func setB(_ k: String, _ v: Bool) { d.set(v, forKey: kDashboardPrefs + "." + k) }
        setB("fauxMenubar", showFauxMenubar)
        setB("pill", showFathomPill)
        setB("packageLine", showPackageLine)
        setB("largePercent", largePercent)
        setB("powerSource", showPowerSource)
        setB("energyMode", showEnergyMode)
        setB("appsRow", showAppsRow)
        setB("whyRow", showWhyRow)
        setB("sparkline", showSparkline)
        setB("topApps", showTopAppsList)
        setB("whyDetail", showWhyDetail)
        setB("health", showHealth)
        setB("timeRemaining", showTimeRemaining)
        setB("powerDistribution", showPowerDistribution)
        d.set(density.rawValue, forKey: kDashboardPrefs + ".density")
        d.set(width.rawValue, forKey: kDashboardPrefs + ".width")
        d.set(cornerRadius, forKey: kDashboardPrefs + ".corner")
        NotificationCenter.default.post(name: .fathomDashboardPrefsChanged, object: nil)
    }

    func resetToMockDefaults() {
        showFauxMenubar = true
        showFathomPill = true
        showPackageLine = true
        largePercent = true
        showPowerSource = true
        showEnergyMode = true
        showAppsRow = true
        showWhyRow = true
        showSparkline = false
        showTopAppsList = false
        showWhyDetail = false
        showHealth = false
        showTimeRemaining = false
        showPowerDistribution = true
        density = .comfortable
        width = .regular
        cornerRadius = 18
        save()
    }

    func applyPreset(_ name: String) {
        switch name {
        case "minimal":
            showFauxMenubar = false
            showFathomPill = false
            showPackageLine = true
            largePercent = true
            showPowerSource = false
            showEnergyMode = false
            showAppsRow = false
            showWhyRow = true
            showSparkline = false
            showTopAppsList = false
            showWhyDetail = false
            showHealth = false
            showTimeRemaining = true
            showPowerDistribution = true
            density = .compact
            width = .narrow
        case "full":
            showFauxMenubar = true
            showFathomPill = true
            showPackageLine = true
            largePercent = true
            showPowerSource = true
            showEnergyMode = true
            showAppsRow = true
            showWhyRow = true
            showSparkline = true
            showTopAppsList = true
            showWhyDetail = true
            showHealth = true
            showTimeRemaining = true
            showPowerDistribution = true
            density = .roomy
            width = .wide
        default:
            resetToMockDefaults()
            return
        }
        save()
    }
}

struct PowerDistributionBar: View {
    let label: String
    let watts: Double
    let total: Double
    let tint: Color

    var body: some View {
        let share = total > 0.05 ? min(1, max(0, watts / total)) : 0
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(share > 0.001 ? 4 : 0, geo.size.width * share))
                }
            }
            .frame(height: 7)
            Text(watts < 0.05 ? "—" : String(format: "%.1f W", watts))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

struct PowerDistributionView: View {
    let cpu: Double
    let gpu: Double
    let ane: Double
    let dram: Double
    let other: Double
    let package: Double
    let compact: Bool

    private var total: Double {
        max(package, cpu + gpu + ane + dram + other, 0.01)
    }

    private var rows: [(String, Double, Color)] {
        var r: [(String, Double, Color)] = [
            ("CPU", cpu, Color(red: 0.35, green: 0.75, blue: 1.0)),
            ("GPU", gpu, Color(red: 0.55, green: 0.85, blue: 0.45)),
            ("ANE", ane, Color(red: 0.95, green: 0.55, blue: 0.85)),
            ("Memory", dram, Color(red: 1.0, green: 0.75, blue: 0.35)),
        ]
        if other > 0.05 {
            r.append(("Other", other, Color.white.opacity(0.45)))
        }
        return r
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Power Distribution")
                    .font(compact ? .callout : .system(size: 13, weight: .semibold))
                    .foregroundColor(compact ? .secondary : .primary)
                Spacer()
                Text(String(format: "%.1f W", package > 0.05 ? package : total))
                    .font(.system(size: compact ? 12 : 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        let w = max(0, row.1)
                        let frac = total > 0 ? w / total : 0
                        if frac > 0.002 {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(row.2.opacity(0.95))
                                .frame(width: max(3, geo.size.width * frac))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .frame(height: compact ? 9 : 11)

            VStack(spacing: compact ? 6 : 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    PowerDistributionBar(label: row.0, watts: row.1, total: total, tint: row.2)
                }
            }
        }
        .padding(compact ? 0 : 2)
    }
}


struct DashboardCustomizePanel: View {
    @ObservedObject var prefs: DashboardPrefs
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Layout")
                    .font(uiFont(14, weight: .semibold))
                    .foregroundColor(.labelPrimary)
                Spacer()
                Button("Done", action: onDone)
                    .font(uiFont(12, weight: .semibold))
                    .foregroundColor(.labelPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.cardElevated))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            MenuHairline()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("Presets")
                    presetRow
                    Text("Simple = essentials. Detailed = charts + apps. Pro = everything.")
                        .font(uiFont(10))
                        .foregroundColor(.labelTertiary)

                    sectionTitle("Show")
                    toggle("Large battery %", $prefs.largePercent)
                    toggle("Power draw line", $prefs.showPackageLine)
                    toggle("Time remaining", $prefs.showTimeRemaining)
                    toggle("Power section", $prefs.showPowerSource)
                    toggle("Energy Mode", $prefs.showEnergyMode)
                    toggle(FathomCopy.whatsUsingPower, $prefs.showAppsRow)
                    toggle(FathomCopy.whyBatteryDropped, $prefs.showWhyRow)
                    toggle("Power chart", $prefs.showSparkline)
                    toggle("Power distribution", $prefs.showPowerDistribution)
                    toggle("Full app list", $prefs.showTopAppsList)
                    toggle("Why-drain details", $prefs.showWhyDetail)
                    toggle("Health & cycles", $prefs.showHealth)

                    sectionTitle("Size")
                    labeledPicker("Density", selection: $prefs.density) {
                        ForEach(DashboardPrefs.Density.allCases) { d in
                            Text(d.label).tag(d)
                        }
                    }
                    labeledPicker("Width", selection: $prefs.width) {
                        ForEach(DashboardPrefs.CardWidth.allCases) { w in
                            Text(w.label).tag(w)
                        }
                    }
                }
                .padding(16)
            }

            MenuHairline()
            Button(action: onDone) {
                Text("Done")
                    .font(uiFont(13, weight: .semibold))
                    .foregroundColor(.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.labelPrimary))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: 280)
        .background(Color.bg)
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            presetButton("Simple") { prefs.applyPreset("minimal") }
            presetButton("Detailed") {
                prefs.applyPreset("mock")
                prefs.showSparkline = true
                prefs.showTopAppsList = true
                prefs.showWhyDetail = true
                prefs.showTimeRemaining = true
                prefs.showPowerDistribution = true
                prefs.showFauxMenubar = false
                prefs.showFathomPill = false
                prefs.density = .comfortable
                prefs.width = .regular
                prefs.save()
            }
            presetButton("Pro") { prefs.applyPreset("full") }
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(uiFont(10, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(.labelTertiary)
            .padding(.top, 4)
    }

    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0; prefs.save() }
        )) {
            Text(title)
                .font(uiFont(12.5))
                .foregroundColor(.labelPrimary)
        }
        .toggleStyle(.switch)
        .tint(Color.white.opacity(0.55))
    }

    private func labeledPicker<V: Hashable, Content: View>(
        _ title: String,
        selection: Binding<V>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(uiFont(12))
                .foregroundColor(.labelSecondary)
            Picker("", selection: Binding(
                get: { selection.wrappedValue },
                set: { selection.wrappedValue = $0; prefs.save() }
            ), content: content)
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }
}


struct DashboardKeyCatcher: NSViewRepresentable {
    var onEscape: () -> Void
    var onComma: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let v = KeyView()
        v.onEscape = onEscape
        v.onComma = onComma
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }
    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onEscape = onEscape
        nsView.onComma = onComma
    }

    final class KeyView: NSView {
        var onEscape: (() -> Void)?
        var onComma: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 {
                onEscape?()
                return
            }
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "," {
                onComma?()
                return
            }
            super.keyDown(with: event)
        }
    }
}


struct DashboardRoot: View {
    @ObservedObject private var power = PowerStore.shared
    @ObservedObject private var energy = ProcessEnergyStore.shared
    @ObservedObject private var prefs = DashboardPrefs.shared
    @State private var why = DrainLog.shared.whyLastHour()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var showCustomize = false
    @State private var showOnboarding = !FathomOnboarding.hasSeen

    private var topApp: String { FathomStatusCopy.topAppLine(energy: energy) }

    private var batterySummary: String {
        if !power.batteryPresent { return "AC" }
        var parts = ["\(power.levelPercent)%"]
        if let m = power.remainingMinutes, m > 0, m < 65535 {
            let h = m / 60, mins = m % 60
            parts.append(h > 0 ? String(format: "%dh %02dm", h, mins) : "\(mins)m")
        }
        return parts.joined(separator: " · ")
    }

    private var packageSummary: String {
        String(format: "%.1f W", power.packageWatts)
    }

    var body: some View {
        HStack(spacing: 0) {
            
            VStack(spacing: 0) {
                headerBar
                MenuHairline()
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 10) {
                        if prefs.largePercent || prefs.showPackageLine || prefs.showTimeRemaining {
                            heroCard
                        }
                        if prefs.showPowerSource || prefs.showHealth || prefs.showSparkline {
                            powerSection
                        }
                        if prefs.showEnergyMode {
                            energyModeSection
                        }
                        if prefs.showAppsRow || prefs.showTopAppsList {
                            appsSection
                        }
                        if prefs.showWhyRow || prefs.showWhyDetail {
                            whySection
                        }
                        footerActions
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
            .frame(minWidth: prefs.width.points, idealWidth: prefs.width.points)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showCustomize {
                Rectangle()
                    .fill(Color.border)
                    .frame(width: 1)
                DashboardCustomizePanel(prefs: prefs) {
                    withAnimation(.easeInOut(duration: 0.15)) { showCustomize = false }
                }
            }
        }
        .background(Color.bg)
        .preferredColorScheme(.dark)
        .onAppear {
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            why = DrainLog.shared.whyLastHour()
            
            if !UserDefaults.standard.bool(forKey: "fathompro.dashboard.rnitroStyleSeeded") {
                prefs.showSparkline = true
                prefs.showTopAppsList = true
                prefs.showWhyDetail = true
                prefs.showTimeRemaining = true
                prefs.showFauxMenubar = false
                prefs.showFathomPill = false
                prefs.save()
                UserDefaults.standard.set(true, forKey: "fathompro.dashboard.rnitroStyleSeeded")
            }
            if !FathomOnboarding.hasSeen { showOnboarding = true }
        }
        .sheet(isPresented: $showOnboarding) {
            FathomOnboardingSheet(isPresented: $showOnboarding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
            why = DrainLog.shared.whyLastHour()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fathomToggleCustomize)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { showCustomize.toggle() }
        }
        .background(
            
            DashboardKeyCatcher(
                onEscape: {
                    if showCustomize {
                        withAnimation(.easeInOut(duration: 0.15)) { showCustomize = false }
                    } else {
                        NotificationCenter.default.post(name: .fathomCloseDashboard, object: nil)
                    }
                },
                onComma: {
                    withAnimation(.easeInOut(duration: 0.15)) { showCustomize.toggle() }
                }
            )
            .frame(width: 0, height: 0)
        )
    }

    
    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: BatteryMenuChrome.batterySymbol(
                level: power.levelPercent,
                charging: power.isCharging,
                onAC: power.isOnAC,
                present: power.batteryPresent
            ))
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.nGreen)
            .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Fathom — Battery")
                        .font(uiFont(13, weight: .semibold))
                        .foregroundColor(.labelPrimary)
                    statusChip
                }
                Text(batterySummary)
                    .font(uiFont(11, weight: .regular))
                    .foregroundColor(.labelSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            Text(packageSummary)
                .font(uiFont(12, weight: .semibold))
                .foregroundColor(.labelPrimary)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.border, lineWidth: 0.5)
                )
                .help(FathomCopy.powerDraw)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showCustomize.toggle() }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(showCustomize ? .labelPrimary : .labelSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(showCustomize ? Color.cardElevated : Color.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.border, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Layout (⌘,)")
            .accessibilityLabel("Layout options")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bg)
    }

    private var statusChip: some View {
        let label = FathomCopy.statusChip(power: power, why: why)
        let color: Color = {
            switch label {
            case "Draining fast": return .nOrange
            case "Charging": return .nGreen
            case "Full": return .nGreen
            default: return .labelSecondary
            }
        }()
        return Text(label)
            .font(uiFont(10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    
    private var heroCard: some View {
        HStack(alignment: .center, spacing: 14) {
            if prefs.largePercent {
                Text(power.batteryPresent ? "\(power.levelPercent)%" : "AC")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundColor(.labelPrimary)
                    .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(FathomStatusCopy.powerSourceLine(power: power))
                    .font(uiFont(13, weight: .semibold))
                    .foregroundColor(.labelPrimary)
                if prefs.showPackageLine {
                    Text(String(format: "Package %.1f W · %@", power.packageWatts, power.packageSource))
                        .font(uiFont(11, weight: .regular))
                        .foregroundColor(.labelSecondary)
                }
                if prefs.showTimeRemaining {
                    Text(FathomCopy.friendlyTime(power: power))
                        .font(uiFont(11, weight: .regular))
                        .foregroundColor(.labelTertiary)
                }
            }
            Spacer(minLength: 0)
            if prefs.showFathomPill {
                Text("FATHOM")
                    .font(uiFont(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.labelSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Color.border, lineWidth: 1))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    
    private var powerSection: some View {
        MonitorSection(
            title: "Power",
            accent: .nGreen,
            summary: batterySummary,
            sparkline: prefs.showSparkline ? power.wattHistorySpark : nil,
            storageKey: "fathompro.dash.section.power",
            icon: "bolt.fill"
        ) {
            if prefs.showPowerSource {
                MonitorRow(label: "Source", value: FathomStatusCopy.powerSourceLine(power: power))
            }
            MonitorRow(label: "Battery feeds", value: power.batterySourcesUsed, valueColor: .labelSecondary)
            MonitorRow(label: FathomCopy.powerDraw, value: String(format: "%.1f W", power.packageWatts), valueColor: .labelPrimary)
            MonitorRow(label: "Power sensor", value: power.packageSource, valueColor: .labelTertiary)
            if ChargeLimitController.shared.isEnabled {
                MonitorRow(label: "App mode", value: ChargeLimitController.shared.appModeLabel, valueColor: .labelSecondary)
                MonitorRow(label: "Charge limit", value: "\(Int(ChargeLimitController.shared.limitPercent))%", valueColor: .labelSecondary)
            }
            if prefs.showPowerDistribution, power.hasPowerDistribution {
                PowerDistributionView(
                    cpu: power.cpuDomainWatts,
                    gpu: power.gpuDomainWatts,
                    ane: power.aneDomainWatts,
                    dram: power.dramDomainWatts,
                    other: power.otherDomainWatts,
                    package: power.packageWatts,
                    compact: false
                )
                .padding(.vertical, 6)
            }
            if power.isCharging {
                MonitorRow(label: "Charging at", value: String(format: "%.1f W", power.chargeWatts), valueColor: .nGreen)
            } else if power.chargeWatts > 0.05, !power.isOnAC {
                MonitorRow(label: "Battery draw", value: String(format: "%.1f W", power.chargeWatts), valueColor: .nOrange)
            }
            let timeVal = FathomCopy.friendlyTime(power: power)
            MonitorRow(
                label: "Time left",
                value: power.minutesIsLiveEstimate ? "\(timeVal) · draw" : timeVal,
                valueColor: .labelSecondary
            )
            if prefs.showHealth {
                if let h = power.healthPercent {
                    MonitorRow(label: "Health", value: "\(h)%", valueColor: .labelPrimary)
                }
                if let c = power.cycleCount {
                    MonitorRow(label: "Cycles", value: "\(c)")
                }
            }
        }
    }

    private var energyModeSection: some View {
        MonitorSection(
            title: "Energy Mode",
            accent: .nBlueish,
            summary: lowPower ? "Low Power On" : "Low Power Off",
            storageKey: "fathompro.dash.section.energyMode",
            defaultExpanded: false,
            icon: lowPower ? "leaf.fill" : "leaf"
        ) {
            MonitorRow(label: "Low Power", value: lowPower ? "On" : "Off",
                       valueColor: lowPower ? .nGreen : .labelSecondary)
            Button {
                BatteryMenuChrome.openBatterySettings()
            } label: {
                HStack {
                    Text("Open Battery Settings…")
                        .font(uiFont(12, weight: .medium))
                        .foregroundColor(.labelPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.labelTertiary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var appsSection: some View {
        let sum = energy.top.first.map { "\($0.name) · \(BatteryMenuChrome.energyLabel(cpuPercent: $0.cpuPercent, estimatedWatts: $0.estimatedWatts))" } ?? "—"
        return MonitorSection(
            title: FathomCopy.whatsUsingPower,
            accent: .nOrange,
            summary: sum,
            storageKey: "fathompro.dash.section.apps",
            defaultExpanded: false,
            icon: "cpu"
        ) {
            if energy.top.isEmpty {
                Text(FathomCopy.nothingHeavy)
                    .font(uiFont(12))
                    .foregroundColor(.labelTertiary)
                    .padding(.vertical, 4)
            } else {
                let limit = prefs.showTopAppsList ? 8 : 1
                ForEach(energy.top.prefix(limit)) { p in
                    HStack(spacing: 8) {
                        Text(p.name)
                            .font(uiFont(13, weight: .regular))
                            .foregroundColor(.labelPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(String(format: "%.0f%%", min(p.cpuPercent, 999)))
                            .font(uiFont(12, weight: .regular))
                            .foregroundColor(.labelTertiary)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                        Text(BatteryMenuChrome.energyLabel(cpuPercent: p.cpuPercent, estimatedWatts: p.estimatedWatts))
                            .font(uiFont(12, weight: .medium))
                            .foregroundColor(.labelSecondary)
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private var whySection: some View {
        let sum = why.dropPercent > 0 ? "−\(why.dropPercent)%" : "steady"
        return MonitorSection(
            title: FathomCopy.whyBatteryDropped,
            accent: .nPurple,
            summary: sum,
            storageKey: "fathompro.dash.section.why",
            icon: "questionmark.circle"
        ) {
            if prefs.showWhyRow || prefs.showWhyDetail {
                let cold = why.summary.contains("Not enough local history") || why.summary.lowercased().contains("not enough")
                Text(cold ? FathomCopy.whyCold : why.summary)
                    .font(uiFont(13, weight: .regular))
                    .foregroundColor(.labelPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
            if prefs.showWhyDetail {
                if why.dropPercent > 0 {
                    MonitorRow(label: "Drop", value: "~\(why.dropPercent)% · \(why.windowLabel)", valueColor: .labelPrimary)
                }
                ForEach(Array(why.culprits.prefix(5).enumerated()), id: \.offset) { _, c in
                    MonitorRow(label: c.name, value: c.note, valueColor: .labelPrimary)
                }
                MinimalButton(title: "Refresh analysis") {
                    why = DrainLog.shared.whyLastHour()
                }
                .padding(.top, 6)
            }
        }
    }

    private var footerActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MinimalButton(title: "Battery Settings") { BatteryMenuChrome.openBatterySettings() }
                MinimalButton(title: FathomProLink.buttonTitle) {
                    FathomProLink.openOrInstall()
                }
                MinimalButton(title: RNitroLink.isInstalled ? "Open rNitro" : "Get rNitro") {
                    RNitroLink.openOrInstall()
                }
                MinimalButton(title: "Updates") { UpdateChecker.checkManually() }
                Spacer(minLength: 0)
            }
            HStack {
                Text(FathomCopy.localOnly)
                    .font(uiFont(10))
                    .foregroundColor(.labelTertiary)
                Spacer()
                Text(UpdateChecker.displayLabel(FATHOM_VERSION))
                    .font(uiFont(10))
                    .foregroundColor(.labelTertiary)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}


extension Color {
    static let nBlueish = Color.white.opacity(0.55)
}

private extension DashboardPrefs {
    var hasExtraModules: Bool {
        showSparkline || showTopAppsList || showWhyDetail
    }
}


enum MenuBarBatteryIcon {
    
    static func compactRemaining(minutes: Int?, charging: Bool, onAC: Bool, present: Bool, level: Int) -> String? {
        guard present else { return "AC" }
        if onAC && !charging {
            return level >= 100 ? "Full" : "AC"
        }
        guard let m = minutes, m > 0, m < 65535 else { return nil }
        let h = m / 60
        let mins = m % 60
        if h > 0 {
            
            return String(format: "%dh %02dm", h, mins)
        }
        return "\(mins)m"
    }

    
    static func menubarLabel(
        level: Int,
        charging: Bool,
        onAC: Bool,
        present: Bool,
        packageWatts: Double,
        remainingMinutes: Int?,
        mode: MenuBarDisplayMode
    ) -> String {
        if mode == .watts {
            
            let w: String
            if packageWatts >= 10 {
                w = String(format: "%.0fW", packageWatts)
            } else {
                w = String(format: "%.1fW", packageWatts)
            }
            if !present { return w }
            return "\(level)% \(w)"
        }
        
        if !present { return "AC" }
        let pct = "\(level)%"
        if onAC && !charging {
            return level >= 100 ? "\(pct) Full" : "\(pct) AC"
        }
        if let t = compactRemaining(
            minutes: remainingMinutes,
            charging: charging,
            onAC: onAC,
            present: present,
            level: level
        ), t != "AC", t != "Full" {
            return "\(pct) \(t)"
        }
        
        return pct
    }

    
    static func image(
        level: Int,
        charging: Bool,
        onAC: Bool,
        present: Bool,
        packageWatts: Double = 0,
        remainingMinutes: Int? = nil,
        mode: MenuBarDisplayMode = .current
    ) -> NSImage? {
        let label = menubarLabel(
            level: level,
            charging: charging,
            onAC: onAC,
            present: present,
            packageWatts: packageWatts,
            remainingMinutes: remainingMinutes,
            mode: mode
        )
        let tint = BatteryMenuChrome.batteryTint(
            level: level, charging: charging, onAC: onAC, present: present
        )
        // Always paint explicit colors (never template) so green/red/yellow/white always show.
        let iconColor = BatteryMenuChrome.tintNSColor(tint)
        // Percentage text matches the battery glyph.
        let labelColor = iconColor

        let name = BatteryMenuChrome.batterySymbol(
            level: level, charging: charging, onAC: onAC, present: present
        )
        
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        guard let symbolRaw = NSImage(systemSymbolName: name, accessibilityDescription: "Battery")?
            .withSymbolConfiguration(config) else {
            return textOnlyImage(label, ink: labelColor, template: false)
        }
        let symbol = symbolRaw.copy() as! NSImage
        symbol.isTemplate = false

        let fontSize: CGFloat = label.count > 6 ? 11.5 : 12.5
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        let textSize = (label as NSString).size(withAttributes: [.font: font])

        let gap: CGFloat = 5
        let padX: CGFloat = 2
        let symW = min(max(symbol.size.width, 22), 34)
        let symH = min(max(symbol.size.height, 13), 18)
        let canvasH: CGFloat = 20
        let canvasW = (padX + symW + gap + textSize.width + padX + 1).rounded(.up)

        let img = NSImage(size: NSSize(width: canvasW, height: canvasH), flipped: false) { rect in
            let sy = ((rect.height - symH) / 2).rounded(.down)
            let sRect = NSRect(x: padX, y: sy, width: symW, height: symH)
            symbol.draw(in: sRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            
            iconColor.set()
            sRect.fill(using: .sourceIn)

            let tx = padX + symW + gap
            let ty = ((rect.height - textSize.height) / 2 - 0.5).rounded(.down)
            (label as NSString).draw(
                at: NSPoint(x: tx, y: ty),
                withAttributes: [
                    .font: font,
                    .foregroundColor: labelColor,
                ]
            )
            return true
        }
        
        img.isTemplate = false
        return img
    }

    private static func textOnlyImage(_ label: String, ink: NSColor = .white, template: Bool = false) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let textSize = (label as NSString).size(withAttributes: [.font: font])
        let canvasW = (textSize.width + 8).rounded(.up)
        let img = NSImage(size: NSSize(width: canvasW, height: 16), flipped: false) { _ in
            (label as NSString).draw(
                at: NSPoint(x: 4, y: 1),
                withAttributes: [.font: font, .foregroundColor: ink]
            )
            return true
        }
        img.isTemplate = template
        return img
    }

    
    static func preferredLength(title: String, image: NSImage?) -> CGFloat {
        _ = title
        let w = (image?.size.width ?? 40) + 8
        return min(max(w.rounded(.up), 36), 160)
    }
}


struct VersionInfo: Decodable {
    let latest: String
    let beta: String?
    let experimental: String?
}

private struct VersionManifest: Decodable {
    let latest: String
    let beta: String?
    let experimental: String?
    let releases: ReleaseMap?
    struct ReleaseMap: Decodable {
        let stable: Channel?
        let beta: Channel?
        let experimental: Channel?
    }
    struct Channel: Decodable {
        let zip: String?
    }
    func zipName(for versionId: String) -> String {
        if let z = releases?.beta?.zip, versionId == beta || versionId == latest { return z }
        if let z = releases?.stable?.zip, versionId == latest { return z }
        if let z = releases?.experimental?.zip, versionId == experimental { return z }
        if let z = releases?.beta?.zip { return z }
        return "Fathom-\(versionId).zip"
    }
}

enum UpdateChecker {
    static func versionNumbers(_ v: String) -> [Int] {
        var s = v.trimmingCharacters(in: .whitespaces)
        if s.lowercased().hasPrefix("v") { s.removeFirst() }
        var nums: [Int] = [], cur = ""
        for ch in s {
            if ch.isNumber { cur.append(ch) }
            else if !cur.isEmpty {
                if let n = Int(cur) { nums.append(n) }
                cur = ""
            }
        }
        if !cur.isEmpty, let n = Int(cur) { nums.append(n) }
        return nums
    }
    private static func channelRank(_ id: String) -> Int {
        let s = id.lowercased()
        if s.contains("experimental") { return 3 }
        if s.contains("beta") { return 2 }
        if s.contains("final") || s.contains("stable") { return 1 }
        return 0
    }
    static func isNewer(_ remote: String, than current: String) -> Bool {
        if remote == current { return false }
        let rn = versionNumbers(remote), cn = versionNumbers(current)
        let count = max(rn.count, cn.count)
        for i in 0..<count {
            let r = i < rn.count ? rn[i] : 0
            let c = i < cn.count ? cn[i] : 0
            if r != c { return r > c }
        }
        let rr = channelRank(remote), cr = channelRank(current)
        if rr != cr { return rr > cr }
        return remote.localizedCaseInsensitiveCompare(current) == .orderedDescending
    }
    static func displayLabel(_ versionId: String) -> String {
        versionId
            .replacingOccurrences(of: "-Experimental", with: " Experimental")
            .replacingOccurrences(of: "-Beta", with: " Beta")
            .replacingOccurrences(of: "-Final", with: " Final")
    }
    private static func fetchVersionInfo(completion: @escaping (VersionInfo?) -> Void) {
        var req = URLRequest(url: UPDATE_CHECK_URL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 12
        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data, let info = try? JSONDecoder().decode(VersionInfo.self, from: data) {
                completion(info)
            } else {
                completion(nil)
            }
        }.resume()
    }
    static func checkOnLaunch() {
        checkPendingUpdateResult()
        fetchVersionInfo { info in
            guard let info else { return }
            evaluateRemoteVersions(info, manual: false)
        }
    }
    private static func checkPendingUpdateResult() {
        let resultURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Fathom/update-result.txt")
        guard let raw = try? String(contentsOf: resultURL, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: resultURL)
        let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let parts = content.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let status = parts.first.map(String.init) ?? ""
        if status == "ok" { return }
        let detail = parts.count > 1 ? String(parts[1]) : "The update helper did not finish successfully."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let alert = NSAlert()
            alert.messageText = "Previous Update Did Not Complete"
            alert.informativeText = detail + "\n\nCheck ~/Library/Logs/Fathom/update.log or reinstall from chopstickshq.com/fathom."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Website")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(UPDATE_PAGE_URL)
            }
        }
    }
    static func checkManually() {
        fetchVersionInfo { info in
            DispatchQueue.main.async {
                guard let info else {
                    let alert = NSAlert()
                    alert.messageText = "Could Not Check for Updates"
                    alert.informativeText = "Could not reach chopstickshq.com. Check your internet connection and try again."
                    alert.alertStyle = .warning
                    alert.runModal()
                    return
                }
                evaluateRemoteVersions(info, manual: true)
            }
        }
    }
    static func installPathLabel() -> String {
        let path = Bundle.main.bundlePath
        if path.contains("AppTranslocation") { return "Downloads (translocated)" }
        if UpdateInstaller.isSystemApplicationsBundle(path) { return "/Applications" }
        if path.contains("/Applications/") { return path }
        return path
    }
    private static func evaluateRemoteVersions(_ info: VersionInfo, manual: Bool) {
        
        let preferred = info.beta ?? info.latest
        let newer = isNewer(preferred, than: FATHOM_VERSION)
        let onMain = {
            if !newer {
                if manual {
                    let alert = NSAlert()
                    alert.messageText = "You're Up to Date"
                    alert.informativeText = "Fathom \(displayLabel(FATHOM_VERSION)) is the newest build available."
                    alert.alertStyle = .informational
                    alert.runModal()
                }
                return
            }
            presentUpdate(remote: preferred)
        }
        if manual { onMain() }
        else if newer { DispatchQueue.main.async(execute: onMain) }
    }
    private static func presentUpdate(remote: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Fathom Update Available"
        alert.informativeText = "You're running \(displayLabel(FATHOM_VERSION)).\n\n\(displayLabel(remote)) is available.\n\nDownload and install now? Fathom will restart when done."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            UpdateInstaller.install(remoteVersion: remote)
        }
    }
}

enum UpdateInstaller {
    private static var progressPanel: NSPanel?
    private static var progressBar: NSProgressIndicator?
    private static var progressDetail: NSTextField?
    private static var downloadProgressObservation: NSKeyValueObservation?
    private static let updateLogURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Fathom/update.log")
    private static let updateResultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Fathom/update-result.txt")

    static func isSystemApplicationsBundle(_ path: String) -> Bool {
        if path.hasPrefix("/Applications/") { return true }
        if path.contains("/System/Volumes/Data/Applications/") { return true }
        return false
    }
    private static func log(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        let dir = updateLogURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: updateLogURL.path),
           let h = try? FileHandle(forWritingTo: updateLogURL) {
            h.seekToEndOfFile()
            h.write(line.data(using: .utf8) ?? Data())
            try? h.close()
        } else {
            try? line.write(to: updateLogURL, atomically: true, encoding: .utf8)
        }
    }
    static func zipURL(for zipName: String) -> URL {
        URL(string: "\(UPDATE_CDN_BASE)/\(zipName)")!
    }
    private static func fetchManifest() -> VersionManifest? {
        let sem = DispatchSemaphore(value: 0)
        var manifest: VersionManifest?
        var req = URLRequest(url: UPDATE_CHECK_URL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 12
        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data { manifest = try? JSONDecoder().decode(VersionManifest.self, from: data) }
            sem.signal()
        }.resume()
        sem.wait()
        return manifest
    }
    static func install(remoteVersion: String) {
        log("Update requested for \(remoteVersion) from \(FATHOM_VERSION)")
        DispatchQueue.main.async { showDownloadProgress(for: remoteVersion) }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = performInstall(remoteVersion: remoteVersion)
            DispatchQueue.main.async {
                hideDownloadProgress()
                if case .failure(let msg) = result {
                    let alert = NSAlert()
                    alert.messageText = "Update Failed"
                    alert.informativeText = msg
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open Website")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(UPDATE_PAGE_URL)
                    }
                }
            }
        }
    }
    private static func showDownloadProgress(for version: String) {
        hideDownloadProgress()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 132),
                            styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Fathom Update"
        panel.isFloatingPanel = true
        panel.level = .floating
        let stack = NSStackView(frame: NSRect(x: 16, y: 16, width: 328, height: 100))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        let label = NSTextField(labelWithString: "Downloading update…")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        let detail = NSTextField(labelWithString: "Fetching \(version) from chopstickshq.com")
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        let bar = NSProgressIndicator()
        bar.isIndeterminate = true
        bar.controlSize = .regular
        bar.frame = NSRect(x: 0, y: 0, width: 328, height: 8)
        bar.startAnimation(nil)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(detail)
        stack.addArrangedSubview(bar)
        panel.contentView = stack
        panel.center()
        panel.orderFrontRegardless()
        progressPanel = panel
        progressBar = bar
        progressDetail = detail
    }
    private static func hideDownloadProgress() {
        progressPanel?.orderOut(nil)
        progressPanel = nil
        progressBar = nil
        progressDetail = nil
    }
    private static func updateDownloadProgress(received: Int, expected: Int, version: String) {
        DispatchQueue.main.async {
            guard let bar = progressBar else { return }
            if expected > 0 {
                bar.isIndeterminate = false
                bar.maxValue = Double(expected)
                bar.doubleValue = Double(received)
                let pct = min(100, Int((Double(received) / Double(expected)) * 100))
                progressDetail?.stringValue = "\(pct)% · \(formatBytes(received)) of \(formatBytes(expected))"
            } else {
                progressDetail?.stringValue = "\(formatBytes(received)) downloaded · \(version)"
            }
        }
    }
    private static func formatBytes(_ n: Int) -> String {
        if n >= 1_048_576 { return String(format: "%.1f MB", Double(n) / 1_048_576) }
        if n >= 1024 { return String(format: "%.0f KB", Double(n) / 1024) }
        return "\(n) B"
    }
    private enum InstallResult { case success; case failure(String) }

    private static func performInstall(remoteVersion: String) -> InstallResult {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        let manifest = fetchManifest()
        let zipName = manifest?.zipName(for: remoteVersion) ?? "Fathom-\(remoteVersion).zip"
        let zipFile = tmp.appendingPathComponent(zipName)
        let extractDir = tmp.appendingPathComponent("Fathom-update-extract", isDirectory: true)
        try? fm.removeItem(at: zipFile)
        try? fm.removeItem(at: extractDir)
        log("Resolved zip: \(zipName)")

        let sem = DispatchSemaphore(value: 0)
        var dlError: Error?
        var httpStatus = 0
        var req = URLRequest(url: zipURL(for: zipName))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 180
        let task = URLSession.shared.downloadTask(with: req) { tempURL, resp, error in
            dlError = error
            if let http = resp as? HTTPURLResponse { httpStatus = http.statusCode }
            guard error == nil, let tempURL else { sem.signal(); return }
            do {
                if fm.fileExists(atPath: zipFile.path) { try fm.removeItem(at: zipFile) }
                try fm.moveItem(at: tempURL, to: zipFile)
            } catch { dlError = error }
            sem.signal()
        }
        downloadProgressObservation = task.progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
            updateDownloadProgress(received: Int(progress.completedUnitCount),
                                   expected: Int(progress.totalUnitCount), version: remoteVersion)
        }
        task.resume()
        sem.wait()
        downloadProgressObservation = nil

        if let dlError {
            return .failure("Could not download \(zipName): \(dlError.localizedDescription)")
        }
        if httpStatus != 0 && httpStatus != 200 {
            return .failure("Server returned HTTP \(httpStatus) for \(zipName). Download manually from chopstickshq.com/fathom.")
        }
        guard fm.fileExists(atPath: zipFile.path) else {
            return .failure("Download did not save \(zipName).")
        }
        let size = (try? fm.attributesOfItem(atPath: zipFile.path)[.size] as? Int) ?? 0
        log("Downloaded \(zipName): \(size) bytes")
        let head = (try? Data(contentsOf: zipFile, options: [.mappedIfSafe]).prefix(64)) ?? Data()
        if head.count >= 2, head[0] == 0x3C {
            return .failure("Got HTML instead of App ZIP. File may be missing on the server.")
        }
        guard head.count >= 4, head[0] == 0x50, head[1] == 0x4B else {
            return .failure("Downloaded file is not a valid ZIP.")
        }
        if size < 40_000 {
            return .failure("Downloaded package is too small (\(size) bytes).")
        }
        DispatchQueue.main.async {
            progressDetail?.stringValue = "Installing \(remoteVersion)…"
            progressBar?.isIndeterminate = true
            progressBar?.startAnimation(nil)
        }
        if let extractError = extractApp(from: zipFile, to: extractDir) {
            return .failure("Could not extract \(zipName): \(extractError)")
        }
        guard let staged = findAppBundle(in: extractDir) else {
            return .failure("Fathom.app not found inside \(zipName).")
        }
        let dest = installDestination()
        log("Installing to \(dest.path)")
        let replace = replaceApp(stagedApp: staged, destination: dest)
        if let installError = replace.error {
            return .failure(installError)
        }
        if replace.opensBeforeQuit {
            try? "ok|\n".write(to: updateResultURL, atomically: true, encoding: .utf8)
        }
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Update Installed"
            alert.informativeText = "Fathom will restart now to finish applying \(UpdateChecker.displayLabel(remoteVersion))."
            alert.alertStyle = .informational
            alert.runModal()
            if replace.opensBeforeQuit { NSWorkspace.shared.open(dest) }
            NSApp.terminate(nil)
        }
        return .success
    }
    private struct ReplaceResult { var error: String?; var opensBeforeQuit = false }
    private static func shellQuote(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }
    private static func runCommand(_ launchPath: String, _ args: [String]) -> (Int32, String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let err = Pipe()
        proc.standardError = err
        proc.standardOutput = Pipe()
        guard (try? proc.run()) != nil else { return (-1, "Could not run \(launchPath)") }
        proc.waitUntilExit()
        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (proc.terminationStatus, msg.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    private static func extractApp(from zipURL: URL, to destDir: URL) -> String? {
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let ditto = runCommand("/usr/bin/ditto", ["-xk", zipURL.path, destDir.path])
        if ditto.0 == 0 { return nil }
        let unzip = runCommand("/usr/bin/unzip", ["-qo", zipURL.path, "-d", destDir.path])
        if unzip.0 == 0 { return nil }
        return [ditto.1, unzip.1].filter { !$0.isEmpty }.joined(separator: " | ")
    }
    private static func installDestination() -> URL {
        let current = URL(fileURLWithPath: Bundle.main.bundlePath)
        let homeApp = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/Fathom.app", isDirectory: true)
        let path = current.path
        if path.contains("AppTranslocation") || path.hasPrefix("/Volumes/") { return homeApp }
        if isSystemApplicationsBundle(path) {
            return URL(fileURLWithPath: "/Applications/Fathom.app")
        }
        let parent = current.deletingLastPathComponent()
        if FileManager.default.isWritableFile(atPath: parent.path) { return current }
        return homeApp
    }
    private static func findAppBundle(in dir: URL) -> URL? {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        for case let url as URL in e {
            var isDir: ObjCBool = false
            if url.lastPathComponent == "Fathom.app",
               FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return nil
    }
    private static func replaceApp(stagedApp: URL, destination: URL) -> ReplaceResult {
        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try? fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let cacheDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Fathom/update-staging", isDirectory: true)
        let durableStage = cacheDir.appendingPathComponent("Fathom.app", isDirectory: true)
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try? fm.removeItem(at: durableStage)
        let stageCopy = runCommand("/usr/bin/ditto", [stagedApp.path, durableStage.path])
        if stageCopy.0 != 0 {
            return ReplaceResult(error: stageCopy.1.isEmpty ? "Could not stage the update package." : stageCopy.1)
        }
        let adminDest = isSystemApplicationsBundle(destination.path)
            ? URL(fileURLWithPath: "/Applications/Fathom.app") : destination
        let staged = shellQuote(durableStage.path)
        let target = shellQuote(adminDest.path)
        let parentPath = shellQuote(adminDest.deletingLastPathComponent().path)
        let pid = ProcessInfo.processInfo.processIdentifier
        let logPath = shellQuote(updateLogURL.path)
        let resultPath = shellQuote(updateResultURL.path)

        if isSystemApplicationsBundle(destination.path) {
            let errPipe = Pipe()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = [
                "-e",
                "do shell script \"mkdir -p /Applications && rm -rf '\(target)' && /usr/bin/ditto '\(staged)' '\(target)' && /usr/bin/xattr -cr '\(target)'\" with administrator privileges"
            ]
            proc.standardError = errPipe
            proc.standardOutput = Pipe()
            guard (try? proc.run()) != nil else {
                return ReplaceResult(error: "Could not request administrator access.")
            }
            proc.waitUntilExit()
            if proc.terminationStatus != 0 {
                return ReplaceResult(error: "Could not replace Fathom in /Applications. Use ~/Applications or download from the website.")
            }
            return ReplaceResult(opensBeforeQuit: true)
        }

        let scriptURL = fm.temporaryDirectory.appendingPathComponent("fathom-apply-update.sh")
        let script = """
#!/bin/bash
LOG='\(logPath)'
RESULT='\(resultPath)'
write_result() { printf '%s|%s\\n' "$1" "$2" > "$RESULT"; }
trap 'code=$?; if [ ! -f "$RESULT" ] || [ ! -s "$RESULT" ]; then write_result fail "Update helper exited with code $code"; fi' EXIT
write_result pending "Update in progress…"
while kill -0 \(pid) 2>/dev/null; do sleep 0.25; done
sleep 0.5
mkdir -p '\(parentPath)' || { write_result fail "Could not create install folder"; exit 1; }
rm -rf '\(target)' || { write_result fail "Could not remove old Fathom.app"; exit 1; }
if ! /usr/bin/ditto '\(staged)' '\(target)' 2>>"$LOG"; then
  write_result fail "ditto failed"; exit 1
fi
xattr -cr '\(target)' 2>/dev/null || true
write_result ok ""
open '\(target)'
"""
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            return ReplaceResult(error: "Could not prepare the update helper script.")
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptURL.path]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else {
            return ReplaceResult(error: "Could not launch the update helper.")
        }
        return ReplaceResult(opensBeforeQuit: false)
    }
}


enum MenuBarPositionStore {
    
    static var normalized: Double {
        get {
            if UserDefaults.standard.object(forKey: kMenuBarPosition) == nil { return 0.15 }
            return min(1, max(0, UserDefaults.standard.double(forKey: kMenuBarPosition)))
        }
        set {
            UserDefaults.standard.set(min(1, max(0, newValue)), forKey: kMenuBarPosition)
            applyPreferredPosition()
            NotificationCenter.default.post(name: .fathomRebuildStatusItem, object: nil)
        }
    }

    
    static var preferredScore: Double {
        
        80 + normalized * 420
    }

    static func applyPreferredPosition() {
        let score = preferredScore
        let keys = [
            "NSStatusItem Preferred Position \(kMenuBarAutosaveName)",
            "NSStatusItem Preferred Position Fathom",
            "NSStatusItem Preferred Position com.chopstickshq.fathompro",
            "NSStatusItem Preferred Position Item-Fathom",
        ]
        for key in keys {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            p.arguments = ["-currentHost", "write", "com.apple.controlcenter", key, "-float", String(score)]
            p.standardOutput = Pipe()
            p.standardError = Pipe()
            try? p.run()
            p.waitUntilExit()
        }
        
        UserDefaults.standard.set(score, forKey: "NSStatusItem Preferred Position")
        UserDefaults.standard.set(score, forKey: "NSStatusItem Preferred Position \(kMenuBarAutosaveName)")
    }

    static func configureStatusItem(_ item: NSStatusItem) {
        
        (item as NSObject).setValue(kMenuBarAutosaveName, forKey: "autosaveName")
        applyPreferredPosition()
    }
}


enum SystemBatteryMenuHider {
    private static let domain = "com.apple.controlcenter"
    private static let batteryKey = "Battery"
    private static let visibleKey = "NSStatusItem Visible Battery"
    private static let savedValueKey = "fathompro.savedSystemBatteryMenuValue"
    private static let didHideKey = "fathompro.didHideSystemBattery"
    
    private static let hideValue = 8
    
    private static let showValue = 18

    private static var enforceTimer: Timer?

    static var isEnabled: Bool {
        get {
            
            if UserDefaults.standard.object(forKey: kReplaceSystemBattery) == nil { return true }
            return UserDefaults.standard.bool(forKey: kReplaceSystemBattery)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kReplaceSystemBattery)
            if newValue {
                hideIfNeeded(forceReload: true)
                startEnforcing()
            } else {
                stopEnforcing()
                restoreIfNeeded()
            }
        }
    }

    
    static func startEnforcing() {
        guard isEnabled else { return }
        enforceTimer?.invalidate()
        
        let t = Timer(timeInterval: 45, repeats: true) { _ in
            hideIfNeeded(forceReload: false)
        }
        t.tolerance = 10
        enforceTimer = t
        RunLoop.main.add(t, forMode: .common)
    }

    static func stopEnforcing() {
        enforceTimer?.invalidate()
        enforceTimer = nil
    }

    
    static func readBatteryPref() -> Int? {
        runDefaults(["-currentHost", "read", domain, batteryKey])
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func runDefaults(_ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func writeDefaults(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = args
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
    }

    
    private static func applyHidePrefs() {
        
        writeDefaults(["-currentHost", "write", domain, batteryKey, "-int", "\(hideValue)"])
        writeDefaults(["-currentHost", "write", domain, visibleKey, "-bool", "false"])
        
        writeDefaults(["-currentHost", "write", domain, "BatteryShowPercentage", "-bool", "false"])
        
        writeDefaults(["write", domain, batteryKey, "-int", "\(hideValue)"])
        writeDefaults(["write", domain, visibleKey, "-bool", "false"])
        
        writeDefaults(["write", "com.apple.systemuiserver", "NSStatusItem Visible com.apple.menuextra.battery", "-bool", "false"])
    }

    private static func writeBatteryPref(_ value: Int) {
        writeDefaults(["-currentHost", "write", domain, batteryKey, "-int", "\(value)"])
        writeDefaults(["write", domain, batteryKey, "-int", "\(value)"])
        let show = value != hideValue && value != 0
        writeDefaults(["-currentHost", "write", domain, visibleKey, "-bool", show ? "true" : "false"])
    }

    private static func reloadControlCenter() {
        for name in ["ControlCenter", "SystemUIServer"] {
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            kill.arguments = [name]
            kill.standardOutput = Pipe()
            kill.standardError = Pipe()
            try? kill.run()
            kill.waitUntilExit()
        }
    }

    
    static func hideIfNeeded(forceReload: Bool = true) {
        guard isEnabled else { return }
        let current = readBatteryPref()
        
        if let current, current != hideValue, current != 0 {
            UserDefaults.standard.set(current, forKey: savedValueKey)
        } else if UserDefaults.standard.object(forKey: savedValueKey) == nil {
            UserDefaults.standard.set(showValue, forKey: savedValueKey)
        }
        let alreadyHidden = (current == hideValue)
        applyHidePrefs()
        UserDefaults.standard.set(true, forKey: didHideKey)
        UserDefaults.standard.set(true, forKey: kReplaceSystemBattery)
        
        if forceReload || !alreadyHidden {
            reloadControlCenter()
        }
    }

    
    static func restoreIfNeeded() {
        guard UserDefaults.standard.bool(forKey: didHideKey) else { return }
        stopEnforcing()
        var saved = UserDefaults.standard.object(forKey: savedValueKey) as? Int ?? showValue
        
        if saved == 0 || saved == hideValue { saved = showValue }
        writeBatteryPref(saved)
        writeDefaults(["-currentHost", "write", domain, "BatteryShowPercentage", "-bool", "true"])
        writeDefaults(["-currentHost", "write", domain, visibleKey, "-bool", "true"])
        UserDefaults.standard.set(false, forKey: didHideKey)
        reloadControlCenter()
    }
}


// MARK: - Preferences window (non-menubar customization)

// MARK: - Charge control (SMC modes)

enum ChargeSMCMode: Equatable {
    case auto
    case inhibit
    case forceDischarge
}

enum ChargeLimitStatus: String {
    case off = "Off"
    case onBattery = "Charger not connected"
    case chargingToLimit = "Charging"
    case holding = "Inhibiting charging"
    case chargeToFull = "Charging to 100%"
    case discharging = "Discharging"
    case unsupported = "Control unavailable"
}

final class ChargeLimitController: ObservableObject {
    static let shared = ChargeLimitController()

    private static let enabledKey = "fathompro.chargeLimit.enabled"
    private static let percentKey = "fathompro.chargeLimit.percent"
    private static let forceFullKey = "fathompro.chargeLimit.forceFull"
    private static let dischargeKey = "fathompro.chargeLimit.discharge"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled { forceFullCharge = false; forceDischarge = false }
            evaluate(force: true)
        }
    }
    @Published var limitPercent: Double {
        didSet {
            let c = min(100, max(50, limitPercent.rounded()))
            if c != limitPercent { limitPercent = c; return }
            UserDefaults.standard.set(Int(c), forKey: Self.percentKey)
            evaluate(force: true)
        }
    }
    @Published var forceFullCharge: Bool {
        didSet {
            UserDefaults.standard.set(forceFullCharge, forKey: Self.forceFullKey)
            if forceFullCharge { forceDischarge = false }
            evaluate(force: true)
        }
    }
    @Published var forceDischarge: Bool {
        didSet {
            UserDefaults.standard.set(forceDischarge, forKey: Self.dischargeKey)
            if forceDischarge { forceFullCharge = false }
            evaluate(force: true)
        }
    }
    @Published private(set) var status: ChargeLimitStatus = .off
    @Published private(set) var detail = "Manage charging: hold a limit, charge to full, or discharge on AC."
    @Published private(set) var backendName = "—"
    @Published private(set) var lastError: String?
    @Published private(set) var modeDescription = "Automatic"

    private var timer: Timer?
    private let hysteresis = 2
    private var appliedMode: ChargeSMCMode?

    private init() {
        let d = UserDefaults.standard
        isEnabled = d.object(forKey: Self.enabledKey) == nil ? true : d.bool(forKey: Self.enabledKey)
        let p = d.object(forKey: Self.percentKey) as? Int ?? 80
        limitPercent = Double(min(100, max(50, p)))
        forceFullCharge = d.bool(forKey: Self.forceFullKey)
        forceDischarge = d.bool(forKey: Self.dischargeKey)
        backendName = ChargeSMC.shared.isAvailable ? "AppleSMC (CH0B/CH0C/CH0I)" : "Unavailable"
        start()
    }

    func start() {
        timer?.invalidate()
        let t = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.evaluate(force: false)
        }
        t.tolerance = 0.8
        timer = t
        RunLoop.main.add(t, forMode: .common)
        evaluate(force: true)
    }

    var statusLine: String {
        let lim = Int(limitPercent)
        switch status {
        case .holding: return "Inhibiting charging · \(lim)%"
        case .chargingToLimit: return "Charging to \(lim)%"
        case .chargeToFull: return "Charging to 100%"
        case .discharging: return "Discharging"
        case .onBattery: return "Charger not connected"
        case .unsupported: return "Charge control unavailable"
        case .off: return "Automatic"
        }
    }

    var appModeLabel: String {
        if !isEnabled { return "Automatic" }
        if forceDischarge { return "Discharging" }
        if forceFullCharge { return "Charging to 100%" }
        switch status {
        case .holding: return "Inhibiting charging"
        case .chargingToLimit: return "Charging"
        case .onBattery: return "Charger not connected"
        case .unsupported: return "Automatic"
        case .off: return "Automatic"
        case .chargeToFull: return "Charging to 100%"
        case .discharging: return "Discharging"
        }
    }

    func chargeToFullNow() { forceFullCharge = true }
    func dischargeBattery() { forceDischarge = true }
    func stopOverride() {
        forceFullCharge = false
        forceDischarge = false
        evaluate(force: true)
    }

    func disableAll() {
        isEnabled = false
        forceFullCharge = false
        forceDischarge = false
        _ = ChargeSMC.shared.setMode(.auto)
        appliedMode = .auto
        status = .off
        modeDescription = "Automatic"
        detail = "Charge management off — macOS controls charging."
    }

    private func evaluate(force: Bool) {
        let p = PowerStore.shared
        let level = p.levelPercent
        let lim = Int(limitPercent)

        if !ChargeSMC.shared.isAvailable {
            status = .unsupported
            backendName = "Unavailable"
            detail = "AppleSMC not available. Charge control needs SMC access (often requires a privileged helper on locked-down Macs)."
            modeDescription = "Automatic"
            return
        }
        backendName = "AppleSMC (CH0B/CH0C/CH0I)"

        if !isEnabled {
            applyMode(.auto)
            status = .off
            modeDescription = "Automatic"
            detail = "Turn on “Manage charging” to hold \(lim)% on AC."
            return
        }

        if !p.batteryPresent {
            applyMode(.auto)
            status = .unsupported
            detail = "No internal battery."
            return
        }

        if forceDischarge {
            applyMode(.forceDischarge)
            status = .discharging
            modeDescription = "Discharging"
            detail = "Forcing discharge even if the charger is connected. Stop override to resume normal management."
            return
        }

        if forceFullCharge {
            if p.isOnAC && level >= 99 {
                forceFullCharge = false
            } else {
                applyMode(.auto)
                status = .chargeToFull
                modeDescription = "Charging to 100%"
                detail = "Temporarily charging to full. Stops at 100% or when you stop the override."
                return
            }
        }

        if !p.isOnAC {
            applyMode(.auto)
            status = .onBattery
            modeDescription = "Charger not connected"
            detail = "Charge limit applies when a power adapter is connected."
            return
        }

        if level >= lim {
            applyMode(.inhibit)
            status = .holding
            modeDescription = "Inhibiting charging"
            detail = p.isCharging
                ? "At \(lim)% — inhibit requested (IsCharging may lag briefly)."
                : "Holding near \(lim)% with the charger connected."
        } else if level <= lim - hysteresis {
            applyMode(.auto)
            status = .chargingToLimit
            modeDescription = "Charging"
            detail = "Charging toward \(lim)%."
        } else if appliedMode == .inhibit {
            status = .holding
            modeDescription = "Inhibiting charging"
            detail = "Holding near \(lim)%."
        } else {
            applyMode(.auto)
            status = .chargingToLimit
            modeDescription = "Charging"
            detail = "Approaching \(lim)%."
        }
        _ = force
    }

    private func applyMode(_ mode: ChargeSMCMode) {
        if mode == appliedMode { return }
        if ChargeSMC.shared.setMode(mode) {
            appliedMode = mode
            lastError = nil
        } else {
            lastError = ChargeSMC.shared.lastError
            if mode == .inhibit || mode == .forceDischarge {
                status = .unsupported
                detail = lastError ?? "SMC write failed — may need a privileged helper."
            }
        }
    }
}

/// AppleSMC charging control (CH0I / CH0B / CH0C).
/// May require elevated privilege on some systems.
final class ChargeSMC {
    static let shared = ChargeSMC()
    private(set) var isAvailable = false
    private(set) var lastError: String?
    private var connection: io_connect_t = 0

    private init() { open() }

    private func open() {
        let service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            lastError = "AppleSMC not found"
            return
        }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard kr == KERN_SUCCESS else {
            lastError = "IOServiceOpen failed (\(kr)) — not privileged?"
            return
        }
        connection = conn
        isAvailable = true
        // Verify struct size matches AppleSMC expectations
        if MemoryLayout<FathomSMCParamStruct>.stride != 80 {
            lastError = "SMCParamStruct stride \(MemoryLayout<FathomSMCParamStruct>.stride) != 80"
            isAvailable = false
        }
    }

    @discardableResult
    func setMode(_ mode: ChargeSMCMode) -> Bool {
        guard isAvailable, connection != 0 else {
            lastError = "SMC unavailable"
            return false
        }
        let disable: UInt8
        let inhibit: UInt8
        switch mode {
        case .forceDischarge:
            disable = 1; inhibit = 0
        case .inhibit:
            disable = 0; inhibit = 2
        case .auto:
            disable = 0; inhibit = 0
        }
        do {
            try writeUInt8("CH0I", disable)
            try writeUInt8("CH0C", inhibit)
            try writeUInt8("CH0B", inhibit)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            // best-effort reset to auto
            try? writeUInt8("CH0I", 0)
            try? writeUInt8("CH0C", 0)
            try? writeUInt8("CH0B", 0)
            return false
        }
    }

    private func writeUInt8(_ key: String, _ value: UInt8) throws {
        var input = FathomSMCParamStruct()
        input.key = fourChar(key)
        input.keyInfo.dataSize = 1
        input.data8 = FathomSMCParamStruct.Selector.kSMCWriteKey.rawValue
        input.bytes.0 = value
        _ = try callDriver(&input)
    }

    private func callDriver(_ input: inout FathomSMCParamStruct) throws -> FathomSMCParamStruct {
        var output = FathomSMCParamStruct()
        let inSize = MemoryLayout<FathomSMCParamStruct>.stride
        var outSize = MemoryLayout<FathomSMCParamStruct>.stride
        let result = IOConnectCallStructMethod(
            connection,
            UInt32(FathomSMCParamStruct.Selector.kSMCHandleYPCEvent.rawValue),
            &input,
            inSize,
            &output,
            &outSize
        )
        if result == kIOReturnNotPrivileged {
            throw NSError(domain: "SMC", code: Int(result),
                          userInfo: [NSLocalizedDescriptionKey: "Not privileged — SMC write blocked on this Mac."])
        }
        if result != kIOReturnSuccess || output.result != 0 {
            throw NSError(domain: "SMC", code: Int(result),
                          userInfo: [NSLocalizedDescriptionKey: "SMC error \(result)/\(output.result) for key"])
        }
        return output
    }

    private func fourChar(_ s: String) -> UInt32 {
        precondition(s.utf8.count == 4)
        var r: UInt32 = 0
        for b in s.utf8 { r = (r << 8) | UInt32(b) }
        return r
    }
}

/// 80-byte SMC param struct (Apple PowerManagement layout)
private struct FathomSMCParamStruct {
    enum Selector: UInt8 {
        case kSMCHandleYPCEvent = 2
        case kSMCReadKey = 5
        case kSMCWriteKey = 6
        case kSMCGetKeyInfo = 9
    }
    struct Version {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }
    struct PLimit {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }
    struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }
    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = PLimit()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

enum PreferencesSection: String, CaseIterable, Identifiable {
    case menuBar, layout, charging, alerts, weather, chat, license, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .menuBar: return "Menu Bar"
        case .layout: return "Layout"
        case .charging: return "Charging"
        case .alerts: return "Alerts"
        case .weather: return "Weather"
        case .chat: return "AI"
        case .license: return "License"
        case .about: return "About"
        }
    }
    var symbol: String {
        switch self {
        case .menuBar: return "menubar.rectangle"
        case .layout: return "rectangle.3.group"
        case .charging: return "battery.100.bolt"
        case .alerts: return "bell.badge"
        case .weather: return "cloud.sun"
        case .chat: return "bubble.left.and.bubble.right"
        case .license: return "lock"
        case .about: return "info.circle"
        }
    }
}

struct PreferencesRoot: View {
    @ObservedObject private var prefs = DashboardPrefs.shared
    @ObservedObject private var chargeLimit = ChargeLimitController.shared
    @State private var section: PreferencesSection = .menuBar
    @State private var criticalPct = Double(BatteryMenuChrome.criticalBatteryPercent)
    @State private var hideSystemBattery = SystemBatteryMenuHider.isEnabled
    @State private var launchAtLogin = LaunchAtLoginHelper.isEnabled
    @State private var drainAlerts = DrainAlertMonitor.isEnabled
    @State private var menuMode = MenuBarDisplayMode.current

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().background(Color.white.opacity(0.08))
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        .preferredColorScheme(.dark)
        .onAppear {
            criticalPct = Double(BatteryMenuChrome.criticalBatteryPercent)
            hideSystemBattery = SystemBatteryMenuHider.isEnabled
            launchAtLogin = LaunchAtLoginHelper.isEnabled
            drainAlerts = DrainAlertMonitor.isEnabled
            menuMode = MenuBarDisplayMode.current
            chargeLimit.start()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Customize")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ForEach(PreferencesSection.allCases) { s in
                Button {
                    section = s
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: s.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 18)
                        Text(s.title)
                            .font(.system(size: 13, weight: section == s ? .semibold : .regular))
                        Spacer()
                    }
                    .foregroundColor(section == s ? .white : .white.opacity(0.65))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(section == s ? Color.white.opacity(0.10) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            Text(UpdateChecker.displayLabel(FATHOM_VERSION))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .padding(14)
        }
        .frame(width: 188)
        .background(Color.black.opacity(0.28))
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                switch section {
                case .menuBar: menuBarPane
                case .layout: layoutPane
                case .charging: chargingPane
                case .alerts: alertsPane
                case .weather: PlusPrefsWeatherPane()
                case .chat: PlusPrefsChatPane()
                case .license: PlusPrefsLicensePane()
                case .about: aboutPane
                }
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    private var menuBarPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            paneTitle("Menu Bar", subtitle: "How Fathom appears next to Control Center.")

            prefCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Icon shows")
                        .font(.system(size: 13, weight: .medium))
                    Picker("", selection: $menuMode) {
                        Text("% + Time").tag(MenuBarDisplayMode.percent)
                        Text("% + Watts").tag(MenuBarDisplayMode.watts)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: menuMode) { _, v in MenuBarDisplayMode.set(v) }

                    Divider().opacity(0.3)

                    Toggle(isOn: $hideSystemBattery) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FathomCopy.useFathomAsBattery)
                            Text("Hides Apple’s battery icon so only Fathom is shown.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: hideSystemBattery) { _, v in SystemBatteryMenuHider.isEnabled = v }

                    Toggle(isOn: $launchAtLogin) {
                        Text("Launch at Login")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, v in LaunchAtLoginHelper.isEnabled = v }
                }
            }
        }
    }

    private var layoutPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            paneTitle("Full Window Layout", subtitle: "Controls the Full Window dashboard — not the menu bar popover.")

            prefCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presets")
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 8) {
                        layoutPreset("Simple") {
                            prefs.applyPreset("minimal")
                        }
                        layoutPreset("Detailed") {
                            prefs.applyPreset("mock")
                            prefs.showSparkline = true
                            prefs.showTopAppsList = true
                            prefs.showWhyDetail = true
                            prefs.showTimeRemaining = true
                            prefs.showFauxMenubar = false
                            prefs.showFathomPill = false
                            prefs.density = .comfortable
                            prefs.width = .regular
                            prefs.save()
                        }
                        layoutPreset("Pro") {
                            prefs.applyPreset("full")
                        }
                    }

                    Divider().opacity(0.3)

                    prefToggle("Large battery %", $prefs.largePercent)
                    prefToggle("Power draw line", $prefs.showPackageLine)
                    prefToggle("Time remaining", $prefs.showTimeRemaining)
                    prefToggle("Power section", $prefs.showPowerSource)
                    prefToggle("Energy Mode", $prefs.showEnergyMode)
                    prefToggle(FathomCopy.whatsUsingPower, $prefs.showAppsRow)
                    prefToggle(FathomCopy.whyBatteryDropped, $prefs.showWhyRow)
                    prefToggle("Power chart", $prefs.showSparkline)
                    prefToggle("Power distribution", $prefs.showPowerDistribution)
                    prefToggle("Full app list", $prefs.showTopAppsList)
                    prefToggle("Why-drain details", $prefs.showWhyDetail)
                    prefToggle("Health & cycles", $prefs.showHealth)

                    Divider().opacity(0.3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Density")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("", selection: $prefs.density) {
                            ForEach(DashboardPrefs.Density.allCases) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Window width")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("", selection: $prefs.width) {
                            ForEach(DashboardPrefs.CardWidth.allCases) { w in
                                Text(w.label).tag(w)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
            }
            .onChange(of: prefs.largePercent) { _, _ in prefs.save() }
            .onChange(of: prefs.showPackageLine) { _, _ in prefs.save() }
            .onChange(of: prefs.showTimeRemaining) { _, _ in prefs.save() }
            .onChange(of: prefs.showPowerSource) { _, _ in prefs.save() }
            .onChange(of: prefs.showEnergyMode) { _, _ in prefs.save() }
            .onChange(of: prefs.showAppsRow) { _, _ in prefs.save() }
            .onChange(of: prefs.showWhyRow) { _, _ in prefs.save() }
            .onChange(of: prefs.showSparkline) { _, _ in prefs.save() }
            .onChange(of: prefs.showPowerDistribution) { _, _ in prefs.save() }
            .onChange(of: prefs.showTopAppsList) { _, _ in prefs.save() }
            .onChange(of: prefs.showWhyDetail) { _, _ in prefs.save() }
            .onChange(of: prefs.showHealth) { _, _ in prefs.save() }
            .onChange(of: prefs.density) { _, _ in prefs.save() }
            .onChange(of: prefs.width) { _, _ in prefs.save() }

            Button("Open Full Window") {
                NotificationCenter.default.post(name: .fathomOpenDashboard, object: nil)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var chargingPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            paneTitle("Charging", subtitle: "Hold a limit, charge to 100%, or force discharge while plugged in.")

            prefCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $chargeLimit.isEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage charging")
                            Text("Hold a user-chosen limit on AC instead of always charging to 100%.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Charge limit \(Int(chargeLimit.limitPercent))%")
                            .font(.system(size: 13, weight: .medium))
                        Slider(value: $chargeLimit.limitPercent, in: 50...100, step: 1)
                            .disabled(!chargeLimit.isEnabled)
                    }

                    HStack {
                        Text("App mode")
                        Spacer()
                        Text(chargeLimit.appModeLabel)
                            .foregroundColor(.secondary)
                    }
                    Text(chargeLimit.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let err = chargeLimit.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Text("Backend: \(chargeLimit.backendName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button("Charge to 100%") {
                            chargeLimit.chargeToFullNow()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!chargeLimit.isEnabled)

                        Button("Discharge") {
                            chargeLimit.dischargeBattery()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!chargeLimit.isEnabled)

                        Button("Stop override") {
                            chargeLimit.stopOverride()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!chargeLimit.isEnabled || (!chargeLimit.forceFullCharge && !chargeLimit.forceDischarge))
                    }

                    Button("Turn off charge management") {
                        chargeLimit.disableAll()
                    }
                    .buttonStyle(.bordered)

                    Text("Uses SMC charger keys (CH0B/CH0C/CH0I). On some Macs macOS blocks writes without a privileged helper — Fathom will say so. Don’t run two charge managers at once.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var alertsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            paneTitle("Alerts", subtitle: "Local notifications only — nothing leaves this Mac.")

            prefCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $drainAlerts) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Warn on fast drain")
                            Text("Notify when battery drops quickly over a short window.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: drainAlerts) { _, v in DrainAlertMonitor.isEnabled = v }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Critical battery at \(Int(criticalPct))%")
                            .font(.system(size: 13, weight: .medium))
                        Slider(value: $criticalPct, in: 5...50, step: 1)
                            .onChange(of: criticalPct) { _, v in
                                BatteryMenuChrome.criticalBatteryPercent = Int(v)
                            }
                        Text("Menu bar icon and full window use this threshold for the red critical state.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            paneTitle("About", subtitle: FathomCopy.localOnly)

            prefCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(UpdateChecker.displayLabel(FATHOM_VERSION))
                            .foregroundColor(.secondary)
                            .monospaced()
                    }
                    Text("Local-only battery monitor. Charge limiting is experimental hardware control when available. No account, no product telemetry.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        Button(FathomProLink.buttonTitle) { FathomProLink.openOrInstall() }
                            .buttonStyle(.borderedProminent)
                        Button("Check for Updates") { UpdateChecker.checkManually() }
                            .buttonStyle(.bordered)
                        Button("Website") { NSWorkspace.shared.open(UPDATE_PAGE_URL) }
                            .buttonStyle(.bordered)
                        Button("System Battery Settings…") { BatteryMenuChrome.openBatterySettings() }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func paneTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func prefCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private func prefToggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title)
                .font(.system(size: 13))
        }
        .toggleStyle(.switch)
    }

    private func layoutPreset(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}


final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverHosting: NSHostingController<MainRoot>?
    private var dashboardWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var titleTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var lastStatusKey = ""
    
    private var lastLeftClickAt: TimeInterval = 0
    
    private var lastStatusDrawAt: CFAbsoluteTime = 0
    private var statusDrawPending = false

    
    private var lastPopoverSize = NSSize(width: kPopoverWidth, height: 480)
    private var escapeMonitor: Any?
    private var clickOffGlobalMonitor: Any?
    private var clickOffLocalMonitor: Any?
    private var popoverWarm = false
    private var popoverClosedAt: CFAbsoluteTime = 0

    
    private func adaptivePopoverSize() -> NSSize {
        let button = statusItem?.button
        let screen = button?.window?.screen
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
        let visH = screen?.visibleFrame.height ?? 700
        
        
        let h = min(520, max(400, visH - 100))
        return NSSize(width: kPopoverWidth, height: h)
    }

    
    private func applyPopoverSizeIfNeeded() {
        let size = adaptivePopoverSize()
        let changed = abs(size.width - lastPopoverSize.width) > 8
            || abs(size.height - lastPopoverSize.height) > 8
        guard changed || !popoverWarm else {
            popover?.contentSize = lastPopoverSize
            return
        }
        lastPopoverSize = size
        popover?.contentSize = size
        guard let hosting = popoverHosting else { return }
        hosting.preferredContentSize = size
        
        hosting.rootView = MainRoot(panelWidth: size.width, panelHeight: size.height)
    }

    private var activationWindow: NSWindow?

    private func showActivationWindow() {
        NSApp.setActivationPolicy(.regular)
        let root = PlusActivationView { [weak self] in
            self?.activationWindow?.orderOut(nil)
            self?.activationWindow = nil
            NSApp.setActivationPolicy(.regular)
            self?.startUnlockedSession()
        }
        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Unlock Fathom Pro"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        activationWindow = win
    }

    private func startUnlockedSession() {
        NSApp.setActivationPolicy(.regular)
        WeatherStore.shared.start()

        
        PowerStore.shared.start()
        ProcessEnergyStore.shared.start()
        ChargeLimitController.shared.start()
        Self.installPowerEventObservers()
        installMainMenu()

        
        DispatchQueue.global(qos: .utility).async {
            
            UserDefaults.standard.set(true, forKey: kReplaceSystemBattery)
            SystemBatteryMenuHider.hideIfNeeded(forceReload: true)
            SystemBatteryMenuHider.startEnforcing()
        }

        createStatusItem()

        let pop = NSPopover()
        
        pop.behavior = .transient
        let warmSize = adaptivePopoverSize()
        lastPopoverSize = warmSize
        pop.contentSize = warmSize
        pop.animates = false
        pop.delegate = self
        pop.appearance = NSAppearance(named: .darkAqua)
        popover = pop
        
        warmPopoverContent()

        
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let isEsc = event.keyCode == 53
            let isCmdW = event.modifierFlags.contains(.command)
                && (event.charactersIgnoringModifiers == "w" || event.charactersIgnoringModifiers == "W")
            if (isEsc || isCmdW), self.popover?.isShown == true {
                self.closeMenubarPopover()
                return nil
            }
            return event
        }

        NotificationCenter.default.addObserver(
            forName: .fathomClosePopover, object: nil, queue: .main
        ) { [weak self] _ in
            self?.closeMenubarPopover()
        }

        
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.lastStatusKey = ""
            self?.scheduleStatusTitleUpdate(force: true)
        }

        
        PowerStore.shared.$packageWatts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleStatusTitleUpdate(force: false) }
            .store(in: &cancellables)
        PowerStore.shared.$levelPercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleStatusTitleUpdate(force: true) }
            .store(in: &cancellables)
        PowerStore.shared.$isOnAC
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleStatusTitleUpdate(force: true) }
            .store(in: &cancellables)
        PowerStore.shared.$isCharging
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleStatusTitleUpdate(force: true) }
            .store(in: &cancellables)

        
        let tt = Timer(timeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.scheduleStatusTitleUpdate(force: true)
        }
        tt.tolerance = 2.0
        titleTimer = tt
        RunLoop.main.add(tt, forMode: .common)

        NotificationCenter.default.addObserver(
            forName: .fathomRebuildStatusItem, object: nil, queue: .main
        ) { [weak self] _ in
            self?.createStatusItem()
        }
        NotificationCenter.default.addObserver(
            forName: .fathomOpenDashboard, object: nil, queue: .main
        ) { [weak self] _ in
            self?.openDashboard()
        }
        NotificationCenter.default.addObserver(
            forName: .fathomOpenPreferences, object: nil, queue: .main
        ) { [weak self] _ in
            self?.openPreferences()
        }
        NotificationCenter.default.addObserver(
            forName: .fathomMenuBarDisplayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.lastStatusKey = ""
            self?.updateStatusTitle()
        }
        NotificationCenter.default.addObserver(
            forName: .fathomDashboardPrefsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.resizeDashboardWindow()
        }
        NotificationCenter.default.addObserver(
            forName: .fathomCloseDashboard, object: nil, queue: .main
        ) { [weak self] _ in
            self?.closeDashboard()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            UpdateChecker.checkOnLaunch()
        }
    
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        LaunchAtLoginHelper.syncFromSystem()
        // Edit menu must exist before unlock field so ⌘V paste works
        installMainMenu()
        if !FathomProLicense.isUnlocked {
            showActivationWindow()
            return
        }
        startUnlockedSession()
    }

    private func createStatusItem() {
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
            statusItem = nil
        }
        
        let item = NSStatusBar.system.statusItem(withLength: 52)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseUp])
        item.button?.imagePosition = .imageOnly
        item.button?.setButtonType(.momentaryLight)
        
        MenuBarPositionStore.configureStatusItem(item)
        statusItem = item
        updateStatusTitle()
    }

    
    private func scheduleStatusTitleUpdate(force: Bool) {
        let now = CFAbsoluteTimeGetCurrent()
        if force {
            lastStatusDrawAt = now
            statusDrawPending = false
            updateStatusTitle()
            return
        }
        if now - lastStatusDrawAt >= 0.2 {
            lastStatusDrawAt = now
            statusDrawPending = false
            updateStatusTitle()
            return
        }
        guard !statusDrawPending else { return }
        statusDrawPending = true
        let delay = 0.2 - (now - lastStatusDrawAt)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.02, delay)) { [weak self] in
            guard let self else { return }
            self.statusDrawPending = false
            self.lastStatusDrawAt = CFAbsoluteTimeGetCurrent()
            self.updateStatusTitle()
        }
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button, let item = statusItem else { return }
        let p = PowerStore.shared
        let mode = MenuBarDisplayMode.current
        let remKey = p.remainingMinutes ?? -1
        let wattsKey = Int((p.packageWatts * 10).rounded())
        let lowP = ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0
        let crit = BatteryMenuChrome.criticalBatteryPercent
        let tint = BatteryMenuChrome.batteryTint(
            level: p.levelPercent, charging: p.isCharging, onAC: p.isOnAC, present: p.batteryPresent
        )
        let key = "\(mode.rawValue)|\(p.levelPercent)|\(remKey)|\(wattsKey)|\(p.isCharging ? 1 : 0)|\(p.isOnAC ? 1 : 0)|\(p.batteryPresent ? 1 : 0)|\(lowP)|\(crit)|\(tint)"
        guard key != lastStatusKey else { return }
        lastStatusKey = key

        let img = MenuBarBatteryIcon.image(
            level: p.levelPercent,
            charging: p.isCharging,
            onAC: p.isOnAC,
            present: p.batteryPresent,
            packageWatts: p.packageWatts,
            remainingMinutes: p.remainingMinutes,
            mode: mode
        )
        
        button.image = img
        button.title = ""
        button.imagePosition = .imageOnly
        button.appearsDisabled = false
        if let cell = button.cell as? NSButtonCell {
            cell.imageDimsWhenDisabled = false
            cell.lineBreakMode = .byClipping
        }
        item.length = MenuBarBatteryIcon.preferredLength(title: "", image: img)
        
        if forceTooltipNeeded(key: key) {
            if p.batteryPresent {
                button.toolTip = "\(p.levelPercent)% · \(p.timeText) · \(String(format: "%.1f W", p.packageWatts))\n\(FathomCopy.clickMenuDoubleWindow)"
                button.setAccessibilityLabel("Fathom battery \(p.levelPercent) percent, \(p.timeText)")
            } else {
                button.toolTip = "Fathom Pro · AC power\n\(FathomCopy.clickMenuDoubleWindow)"
                button.setAccessibilityLabel("Fathom, AC power")
            }
        }
    }

    private var lastTooltipKey = ""
    private func forceTooltipNeeded(key: String) -> Bool {
        
        let parts = key.split(separator: "|")
        let identity = parts.enumerated().filter { $0.offset != 3 }.map { String($0.element) }.joined(separator: "|")
        if identity == lastTooltipKey { return false }
        lastTooltipKey = identity
        return true
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Fathom")
        let dash = NSMenuItem(title: FathomCopy.fullWindow, action: #selector(openDashboard), keyEquivalent: "d")
        dash.keyEquivalentModifierMask = .command
        dash.target = self
        appMenu.addItem(dash)
        let prefs = NSMenuItem(title: FathomCopy.preferences, action: #selector(openPreferences), keyEquivalent: ",")
        prefs.keyEquivalentModifierMask = .command
        prefs.target = self
        appMenu.addItem(prefs)
        let closeDash = NSMenuItem(title: "Close Window", action: #selector(closeDashboard), keyEquivalent: "w")
        closeDash.keyEquivalentModifierMask = .command
        closeDash.target = self
        appMenu.addItem(closeDash)
        appMenu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Quit Fathom Pro", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command
        quit.target = self
        appMenu.addItem(quit)
        appMenuItem.submenu = appMenu

        // Edit menu — required for ⌘V / ⌘C / ⌘X / ⌘A in text fields (esp. menubar apps)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func toggleDashboardLayout() {
        openPreferences()
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc private func togglePopover() {
        guard let event = NSApp.currentEvent, let button = statusItem?.button else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: FathomCopy.fullWindow, action: #selector(openDashboard), keyEquivalent: "")
            menu.addItem(withTitle: FathomCopy.customize, action: #selector(openPreferences), keyEquivalent: "")
            menu.addItem(withTitle: FathomCopy.batteryMenu, action: #selector(forceShowPopover), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            let plus = menu.addItem(
                withTitle: FathomProLink.buttonTitle,
                action: #selector(openFathomPro),
                keyEquivalent: ""
            )
            plus.target = self
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Check for Updates", action: #selector(checkUpdates), keyEquivalent: "")
            menu.addItem(withTitle: "Website", action: #selector(openWebsite), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            let quit = menu.addItem(withTitle: "Quit Fathom Pro", action: #selector(quitApp(_:)), keyEquivalent: "q")
            quit.keyEquivalentModifierMask = .command
            for i in menu.items { i.target = self }
            statusItem?.menu = menu
            button.performClick(nil)
            statusItem?.menu = nil
            return
        }

        if event.clickCount >= 2 {
            lastLeftClickAt = 0
            if popover?.isShown == true {
                closeMenubarPopover()
            }
            openDashboard()
            return
        }

        lastLeftClickAt = ProcessInfo.processInfo.systemUptime
        performPopoverToggle()
    }

    private func closeMenubarPopover() {
        guard let pop = popover, pop.isShown else {
            removeClickOffMonitors()
            return
        }
        pop.performClose(nil)
        removeClickOffMonitors()
        MenuPanelModel.shared.stopTracking()
        setPopoverFastMode(false)
    }

    private func installClickOffMonitors() {
        removeClickOffMonitors()
        clickOffGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.closeMenubarPopover()
        }
        clickOffLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self, let pop = self.popover, pop.isShown else { return event }
            if let popWin = pop.contentViewController?.view.window {
                if event.window == popWin { return event }
                let loc = event.locationInWindow
                if let win = event.window {
                    let screenPt = win.convertPoint(toScreen: loc)
                    if popWin.frame.contains(screenPt) { return event }
                }
            }
            if let btnWin = self.statusItem?.button?.window, event.window == btnWin {
                return event
            }
            self.closeMenubarPopover()
            return event
        }
    }

    private func removeClickOffMonitors() {
        if let m = clickOffGlobalMonitor {
            NSEvent.removeMonitor(m)
            clickOffGlobalMonitor = nil
        }
        if let m = clickOffLocalMonitor {
            NSEvent.removeMonitor(m)
            clickOffLocalMonitor = nil
        }
    }

    private func performPopoverToggle() {
        guard let button = statusItem?.button, let pop = popover else { return }

        if pop.isShown {
            closeMenubarPopover()
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        if now - popoverClosedAt < 0.35 {
            return
        }

        if !popoverWarm { warmPopoverContent() }
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installClickOffMonitors()
        MenuPanelModel.shared.startTracking()
        setPopoverFastMode(true)
        applyPopoverSizeIfNeeded()
    }

    private func setPopoverFastMode(_ on: Bool) {
        PowerStore.shared.setFastMode(on)
        ProcessEnergyStore.shared.setFastMode(on)
    }

    @objc private func forceShowPopover() {
        guard let button = statusItem?.button, let pop = popover else { return }
        if pop.isShown { return }
        if !popoverWarm { warmPopoverContent() }
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installClickOffMonitors()
        DispatchQueue.main.async {
            MenuPanelModel.shared.startTracking()
            self.setPopoverFastMode(true)
            self.applyPopoverSizeIfNeeded()
        }
    }

    @objc func openDashboard() {
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        }
        setPopoverFastMode(false)
        NSApp.activate(ignoringOtherApps: true)
        if let win = dashboardWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: AnyView(DashboardRoot()))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.08, alpha: 1).cgColor

        
        let baseW = max(DashboardPrefs.shared.width.points, 420)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: baseW, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Fathom Pro"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isOpaque = true
        win.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        win.hasShadow = true
        win.isMovableByWindowBackground = true
        win.level = .normal
        win.collectionBehavior = [.fullScreenPrimary]
        win.appearance = NSAppearance(named: .darkAqua)
        win.minSize = NSSize(width: 360, height: 420)
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: baseW, height: 560))
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        dashboardWindow = win
    }

    @objc func openPreferences() {
        if popover?.isShown == true {
            closeMenubarPopover()
        }
        setPopoverFastMode(false)
        NSApp.activate(ignoringOtherApps: true)
        if let win = preferencesWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: AnyView(PreferencesRoot()))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.08, alpha: 1).cgColor
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Customize"
        win.isOpaque = true
        win.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.08, alpha: 1)
        win.hasShadow = true
        win.level = .normal
        win.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        win.appearance = NSAppearance(named: .darkAqua)
        win.minSize = NSSize(width: 640, height: 420)
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 780, height: 560))
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        preferencesWindow = win
    }

    private func resizeDashboardWindow() {
        guard let win = dashboardWindow else { return }
        let w = max(DashboardPrefs.shared.width.points, 400)
        var frame = win.frame
        
        let targetW = max(frame.width, w)
        if abs(frame.width - targetW) > 8 {
            frame.size.width = targetW
            win.setFrame(frame, display: true, animate: true)
        }
    }

    @objc func closeDashboard() {
        dashboardWindow?.orderOut(nil)
    }

    @objc private func checkUpdates() { UpdateChecker.checkManually() }
    @objc private func openWebsite() { NSWorkspace.shared.open(UPDATE_PAGE_URL) }

    @objc private func openFathomPro() {
        FathomProLink.openOrInstall()
    }

    
    private func warmPopoverContent() {
        let size = lastPopoverSize.width > 0 ? lastPopoverSize : adaptivePopoverSize()
        lastPopoverSize = size
        if popoverHosting != nil {
            popover?.contentSize = size
            popoverWarm = true
            return
        }
        let root = MainRoot(panelWidth: size.width, panelHeight: size.height)
        let hosting = NSHostingController(rootView: root)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1).cgColor
        hosting.view.layer?.cornerRadius = 12
        hosting.view.layer?.masksToBounds = true
        
        hosting.view.layer?.drawsAsynchronously = true
        hosting.preferredContentSize = size
        popoverHosting = hosting
        popover?.contentSize = size
        popover?.contentViewController = hosting
        
        hosting.view.layoutSubtreeIfNeeded()
        popoverWarm = true
        
        MenuPanelModel.shared.refreshNow()
    }

    
    private func releasePopoverContent() {
        
    }

    func popoverDidClose(_ notification: Notification) {
        popoverClosedAt = CFAbsoluteTimeGetCurrent()
        removeClickOffMonitors()
        MenuPanelModel.shared.stopTracking()
        setPopoverFastMode(false)
    }

    func popoverWillShow(_ notification: Notification) {
        
    }

    private static func installPowerEventObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let map: [(NSNotification.Name, String, Bool?)] = [
            (NSWorkspace.screensDidSleepNotification, "display_sleep", false),
            (NSWorkspace.screensDidWakeNotification, "display_wake", true),
            (NSWorkspace.willSleepNotification, "system_sleep", false),
            (NSWorkspace.didWakeNotification, "system_wake", true),
        ]
        for (name, event, wake) in map {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                DrainLog.shared.recordEvent(event)
                if let wake {
                    PowerStore.shared.notePowerTransition(wake: wake)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            dashboardWindow?.makeKeyAndOrderFront(nil)
        } else {
            openDashboard()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        titleTimer?.invalidate()
        titleTimer = nil
        cancellables.removeAll()
        
        SystemBatteryMenuHider.restoreIfNeeded()
    }
}

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


private let fathomProAppDelegate = AppDelegate()

@main
struct FathomProAppMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = fathomProAppDelegate
        app.run()
    }
}

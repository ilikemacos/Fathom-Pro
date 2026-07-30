#!/usr/bin/env python3
"""Build FathomProApp.swift from Fathom + Plus modules (license, weather, AI chat)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC_IN = ROOT.parent / "fathom-site" / "Sources" / "FathomApp.swift"
SRC_OUT = ROOT / "Sources" / "FathomProApp.swift"
MODULES = ROOT / "Sources" / "FathomProModules.swift.inc"

def main() -> None:
    text = SRC_IN.read_text(encoding="utf-8")
    modules = MODULES.read_text(encoding="utf-8")

    if "import CoreLocation" not in text:
        text = text.replace(
            "import ServiceManagement\n",
            "import ServiceManagement\nimport CoreLocation\n",
        )

    text = re.sub(
        r'let FATHOM_VERSION = "v[^"]+"',
        'let FATHOM_VERSION = "v0.1.5-Pro-Beta"',
        text,
        count=1,
    )
    # Appear in Dock + Command-Tab (not menubar-only agent)
    text = text.replace("setActivationPolicy(.accessory)", "setActivationPolicy(.regular)")
    text = text.replace('let FATHOM_CHANNEL = "beta"', 'let FATHOM_CHANNEL = "pro"')
    text = text.replace('let FATHOM_CHANNEL = "plus"', 'let FATHOM_CHANNEL = "pro"')

    # Protect already-Pro identifiers before wholesale renames
    text = text.replace("com.chopstickshq.fathompro", "@@FATHOM_PRO_BUNDLE@@")
    text = text.replace("com.chopstickshq.fathom", "com.chopstickshq.fathompro")
    text = text.replace("@@FATHOM_PRO_BUNDLE@@", "com.chopstickshq.fathompro")
    text = text.replace('"fathompro.', '"@@PROKEY@@.')
    text = text.replace('"fathom.', '"fathompro.')
    text = text.replace('"@@PROKEY@@.', '"fathompro.')

    reps = [
        ("Quit Fathom", "Quit Fathom Pro"),
        ("Fathom-only", "Fathom Pro–only"),
        ("Fathom · AC power", "Fathom Pro · AC power"),
        ('title = "Fathom"', 'title = "Fathom Pro"'),
        ('kMenuBarAutosaveName = "FathomBattery"', 'kMenuBarAutosaveName = "FathomProBattery"'),
        (
            'let UPDATE_CHECK_URL = URL(string: "https://chopstickshq.com/fathom/version.json")!',
            'let UPDATE_CHECK_URL = URL(string: "https://chopstickshq.com/fathom-pro/version.json")!',
        ),
        (
            'let UPDATE_PAGE_URL = URL(string: "https://chopstickshq.com/fathom/")!',
            'let UPDATE_PAGE_URL = URL(string: "https://chopstickshq.com/fathom-pro/")!',
        ),
        (
            'let UPDATE_CDN_BASE = "https://chopstickshq.com/fathom"',
            'let UPDATE_CDN_BASE = "https://chopstickshq.com/fathom-pro"',
        ),
        ("FathomAppMain", "FathomProAppMain"),
        ("fathomAppDelegate", "fathomProAppDelegate"),
        ("Leave on for Fathom", "Leave on for Fathom Pro"),
        ("Fathom \\(FATHOM_VERSION)", "Fathom Pro \\(FATHOM_VERSION)"),
        ("Fathom Pro Pro", "Fathom Pro"),  # guard double rename
    ]
    for a, b in reps:
        text = text.replace(a, b)

    # Insert weather + chat before High Energy Usage
    he = 'Text("High Energy Usage")'
    idx = text.find(he)
    if idx < 0:
        raise SystemExit("High Energy Usage not found")
    sep = text.rfind("BatFiSeparator()", 0, idx)
    if sep < 0:
        raise SystemExit("separator not found")
    inject = """
                BatFiSeparator()
                PlusWeatherSection()
                BatFiSeparator()
                PlusChatSection()

"""
    text = text[:sep] + inject + text[sep:]

    # Expand preferences sidebar for Plus (weather / AI chat with API Config subtab / license)
    # API Config is nested under AI Chat as a subtab — not a top-level sidebar item.
    text = text.replace(
        "case menuBar, layout, charging, alerts, about",
        "case menuBar, layout, charging, alerts, weather, chat, license, about",
    )
    text = text.replace(
        "case menuBar, layout, alerts, about",
        "case menuBar, layout, charging, alerts, weather, chat, license, about",
    )
    # If a previous Plus build left `api` in the enum, normalize it out.
    text = text.replace(
        "case menuBar, layout, charging, alerts, weather, api, chat, license, about",
        "case menuBar, layout, charging, alerts, weather, chat, license, about",
    )
    text = text.replace(
        """        case .menuBar: return "Menu Bar"
        case .layout: return "Layout"
        case .charging: return "Charging"
        case .alerts: return "Alerts"
        case .about: return "About"
        }
    }
    var symbol: String {
        switch self {
        case .menuBar: return "menubar.rectangle"
        case .layout: return "rectangle.3.group"
        case .charging: return "battery.100.bolt"
        case .alerts: return "bell.badge"
        case .about: return "info.circle"
        }
    }
}""",
        """        case .menuBar: return "Menu Bar"
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
}""",
    )
    text = text.replace(
        """                switch section {
                case .menuBar: menuBarPane
                case .layout: layoutPane
                case .charging: chargingPane
                case .alerts: alertsPane
                case .about: aboutPane
                }""",
        """                switch section {
                case .menuBar: menuBarPane
                case .layout: layoutPane
                case .charging: chargingPane
                case .alerts: alertsPane
                case .weather: PlusPrefsWeatherPane()
                case .chat: PlusPrefsChatPane()
                case .license: PlusPrefsLicensePane()
                case .about: aboutPane
                }""",
    )

    # Insert modules before singleton
    marker = "private let fathomProAppDelegate = AppDelegate()"
    if marker not in text:
        raise SystemExit("delegate marker missing")
    text = text.replace(marker, modules + "\n\n" + marker)

    # Rewrite applicationDidFinishLaunching with license gate + extract body to startUnlockedSession
    pattern = re.compile(
        r"func applicationDidFinishLaunching\(_ notification: Notification\) \{",
        re.M,
    )
    m = pattern.search(text)
    if not m:
        raise SystemExit("applicationDidFinishLaunching missing")

    # Find matching brace for the function — naive brace count from m.end()-1
    start = m.start()
    brace_at = text.find("{", m.start())
    i = brace_at
    depth = 0
    end = None
    while i < len(text):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    if end is None:
        raise SystemExit("could not find end of applicationDidFinishLaunching")

    old_fn = text[start:end]
    # body without outer braces
    body = old_fn[old_fn.find("{") + 1 : old_fn.rfind("}")]
    # strip leading activation policy / login sync so we control them
    body_lines = body.splitlines()
    filtered = []
    skip_next_blank = False
    for line in body_lines:
        s = line.strip()
        if "setActivationPolicy(" in s:
            continue
        if "LaunchAtLoginHelper.syncFromSystem()" in s:
            continue
        filtered.append(line)

    new_fn = f'''private var activationWindow: NSWindow?

    private func showActivationWindow() {{
        NSApp.setActivationPolicy(.regular)
        let root = PlusActivationView {{ [weak self] in
            self?.activationWindow?.orderOut(nil)
            self?.activationWindow = nil
            NSApp.setActivationPolicy(.regular)
            self?.startUnlockedSession()
        }}
        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Unlock Fathom Pro"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        activationWindow = win
    }}

    private func startUnlockedSession() {{
        NSApp.setActivationPolicy(.regular)
        WeatherStore.shared.start()
{chr(10).join(filtered)}
    }}

    func applicationDidFinishLaunching(_ notification: Notification) {{
        NSApp.setActivationPolicy(.regular)
        LaunchAtLoginHelper.syncFromSystem()
        // Edit menu must exist before unlock field so ⌘V paste works
        installMainMenu()
        if !FathomProLicense.isUnlocked {{
            showActivationWindow()
            return
        }}
        startUnlockedSession()
    }}'''

    text = text[:start] + new_fn + text[end:]

    SRC_OUT.write_text(text, encoding="utf-8")
    print(f"OK {SRC_OUT} ({len(text.splitlines())} lines)")


if __name__ == "__main__":
    main()

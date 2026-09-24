# Fathom Pro

**Fathom Pro** is the premium sibling of [Fathom](https://github.com/ilikemacos/Fathom): local-only macOS battery monitoring plus **weather** and **multi-provider AI chat** (OpenRouter, Gemini, OpenAI, Anthropic) with keys you own.

- Product site: [chopstickshq.com/fathom-pro](https://chopstickshq.com/fathom-pro/)
- Studio: [Chopsticks HQ](https://chopstickshq.com/) (Chopsticks · ilikemacos)

## Install

```bash
curl -fsSL https://chopstickshq.com/fathom-pro/install-fathom-pro.sh | bash
```

Or download the ZIP from [Releases](https://github.com/ilikemacos/Fathom-Pro/releases) / the product site, then open **Fathom Pro.app** (right-click → Open the first time if Gatekeeper prompts).

Requires **macOS 14+**.

## Unlock

Fathom Pro requires a paid $2 license now
1. **Pay for it here at** https://chopstickshq.com/fathom-pro/#unlock
2. Then put your username and your license will be generated
**NOTE**
Fathom Pro licenses are not to be distrubuted and may only be used 3 times.

Provider API keys (OpenAI etc.) are **yours**, stored in Keychain on this Mac. The unlock token is not a free cloud API key.

## Build from source

```bash
# From this repo (Apple Silicon / arm64 recommended)
swiftc Sources/FathomProApp.swift -o /tmp/FathomPro \
  -framework SwiftUI -framework Cocoa -framework IOKit \
  -framework CoreLocation -framework ServiceManagement -framework Security \
  -lIOReport -parse-as-library -O
```

Or regenerate from Fathom + modules:

```bash
python3 scripts/build-fathom-pro.py   # needs sibling fathom-site Sources
```

## Privacy

Local-first. No Chopsticks HQ account. Chat keys leave your Mac only when you send a message to the provider you chose.

## License

MIT — see [LICENSE](LICENSE).

# Glass probe

Smallest native iPhone app that answers one question: does Apple's public Liquid Glass (`UIGlassEffect` inside a `UIVisualEffectView`, iOS 26 or later) placed above a `WKWebView` bend the live web content under it? It also shows a glass input bar, a glass pop-up menu and a glass bottom sheet over a scrolling chat-like page.

No Mac, no Apple account, no signing. A GitHub-hosted macOS runner builds it and runs it in the iOS Simulator.

## Run

1. Put this folder in a new GitHub repository (public repositories get free macOS minutes) with the default branch `main`.
2. Push, or open Actions, pick "sim", Run workflow. Inputs (all optional): `runner` (default `xcode-27`; use `macos-26` for an iOS 26 image), `xcode` (default `/Applications/Xcode_27.2.app`; use `/Applications/Xcode_26.6.app` on `macos-26`), `url` (extra screenshot of a remote page).
3. Download the `glass-sim` artifact: `native.png`, `bar.png`, `bar-light.png`, `bar-edge.png`, `bar-insets.png`, `menu.png`, `realmenu.png`, `sheet.png`, `toolbar.png`, `remote.png` (only with a url), `bar.mp4`, `build.log`, `env.txt`, `device.txt`, `devices.json`.

## What each shot is

- `native`: the control. The same two pills and glass button over a native striped view, no web view.
- `bar`: two same-size pills side by side at the bottom (plain blur left, glass right) and a round glass button at top right, over the web page with fixed stripes and coloured bars behind them. Stills are frozen (no scrolling); the video scrolls.
- `bar-light`: same in light appearance (all other shots are dark).
- `bar-edge`: same, with `UIScrollEdgeElementContainerInteraction` on the bars.
- `bar-insets`: same, with `WKWebView.obscuredContentInsets` set.
- `menu`: a home-made glass panel styled as a pop-up menu above the bars.
- `realmenu`: the real `UIMenu` opened from the plus button of the glass pill.
- `sheet`: a system sheet with a medium detent, shown 1 second after launch.
- `toolbar`: a stock `UIToolbar`, for reference.
- `bar.mp4`: 6 seconds of the bar state, page scrolling.
- `remote`: look only (an arbitrary page has no guaranteed pattern), not a lensing test.

## Reading the result

Compare the glass pill with the blur pill in `native.png` first. Glass that lenses shows stripes and colours bending at the pill edge.

- Bends in `native`, bends in `bar`: glass samples the web view.
- Bends in `native`, flat in `bar`: the web view is the cause.
- Flat in both: the virtual machine does not render glass; nothing else is learned.

`env.txt` and `device.txt` tell you which Xcode, runtime and device ran. `xcode-27` still has a Preview badge in the runner-images README; if it fails, run by hand with runner `macos-26` and xcode `/Applications/Xcode_26.6.app`.

## Launch arguments

`-state bar|native|menu|realmenu|sheet|toolbar`, `-url <http url>`, `-edge 1`, `-insets 1`, `-freeze 1`, `-light 1`; state `native` added.

## Files

`project.yml` (XcodeGen, writes Info.plist), `Sources/App.swift`, `Sources/page.html`, `.github/workflows/sim.yml`, `NOTES.md` (sources and API details).

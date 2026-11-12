# Notes: sources behind the kit (checked 2026-11-12)

## Runner and Xcode

- Newest image with an iOS 27 simulator runtime: label `xcode-27` (arm64 only, standard size, also `xcode-27-xlarge`). Runs macOS 27.0.1, image 20261104.0337.1. Xcode 27.2 (27B52, /Applications/Xcode_27.2.app), 27.1 (default, /Applications/Xcode.app) and 27.0. Simulator runtimes iOS 27.0 and 27.2 with iPhone 17, 17e, 18 Pro, 18 Pro Max, Air; iOS 27.1 and 27.2 also list "iPhone Duo".
  - https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md
  - https://github.com/actions/runner-images/blob/main/README.md (table: `xcode-27` carries a Preview badge there; `macos-latest` and `macos-26` are macOS 26 arm64)
  - https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available (says generally available, arm64 only, runs on macOS 27; it names no simulator runtime, the software list above does)
  - https://docs.github.com/en/actions/reference/runners/github-hosted-runners (`xcode-27` is in the standard arm64 row, 3 vCPU M1, 7 GB; standard runners are free on public repos)
- Fallback image: `macos-26` (arm64): Xcode 26.6 default, 26.5 to 26.0.1 also installed, simulators iOS 26.2, 26.4, 26.5 only (no iOS 27). https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md . If only this image is used, the kit targets iOS 26: run the workflow by hand with runner `macos-26` and xcode `/Applications/Xcode_26.6.app`.
- Select Xcode: job env `DEVELOPER_DIR=<Xcode app>/Contents/Developer` (no sudo needed). Paths come from the software lists above.
- XcodeGen is NOT preinstalled on either image (not in the tool lists); `brew install xcodegen` is the install line in https://github.com/yonaskolb/XcodeGen . Homebrew 7.0.12 is on the image. jq 1.8.2 and Python 3 are present.
- Shell: a run step without `shell:` is `bash -e {0}`; `shell: bash` is `bash --noprofile --norc -eo pipefail {0}`. The workflow sets `shell: bash` so `xcodebuild | tee` fails when xcodebuild fails. https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- Action majors: `actions/checkout@v7`, `actions/upload-artifact@v7` (inputs `name`, `path`, `if-no-files-found`). https://github.com/actions/checkout , https://github.com/actions/upload-artifact

## simctl

- Screenshot: `xcrun simctl io <device> screenshot <file>.png` (`--type` png default). Video: `recordVideo [--codec=<codec>] [--display=<display>] [--mask=<policy>] [--force] <file>`, codec h264 or hevc (hevc default), stop with Ctrl-C which is SIGINT.
  - https://sarunw.com/posts/take-screenshot-and-record-video-in-ios-simulator/
  - https://developer.apple.com/forums/thread/694901 (usage line)
- `boot`, `bootstatus`, `install`, `launch <device> <bundle id> [args]`, `terminate`, `list devices available -j` are used as in the same community sources; no Apple-hosted page for them was found. The kit avoids the `launch --terminate-running-process` flag (could not confirm it) and calls `terminate` instead.

## Does Liquid Glass render in the Simulator on these VMs

No primary source either way. Indirect evidence only:
- A project reports the iOS 26 simulator drawing tab bar glass in one of two states (normal, or flatter, less tinted, no scroll-edge effect, content dimmed), correlating with runner load; runner type not stated. https://github.com/water-rs/apple-backend/issues/245
- A glass library issue says glass renders in the Simulator but fails on a physical device. https://github.com/callstack/liquid-glass/issues/33
- GitHub's own docs say nothing about GPU or Metal in the macOS VM. So the kit's screenshots ARE the test. The `native` state puts the same two pills over a native striped UIView (no WKWebView). Glass bends the native stripes but not the web stripes: the web view is the cause. Glass flat in both: the VM does not render glass. Glass bends both: the web view is sampled.

## UIKit and WebKit API (Apple pages, markdown form, all copyright 2026)

- `UIGlassEffect`: `@MainActor class`, iOS 26.0+, inherits `UIVisualEffect`. Only listed initialiser `init(style: UIGlassEffect.Style)`; `enum Style { case clear, regular }`; `var isInteractive: Bool`; `var tintColor: UIColor?`. The kit uses `UIGlassEffect(style: .regular)` (the plain `UIGlassEffect()` seen in WWDC25 code is not listed on the page). https://developer.apple.com/documentation/uikit/uiglasseffect.md
- `UIGlassContainerEffect`: `@MainActor class`; `var spacing: CGFloat` (distance at which elements start to merge); nested `UIVisualEffectView`s with `UIGlassEffect` go in the container view's `contentView`. Not used in the app (to keep it small). https://developer.apple.com/documentation/uikit/uiglasscontainereffect.md
- `UIButton.Configuration` static functions `glass()`, `prominentGlass()`, `clearGlass()`, `prominentClearGlass()`, iOS 26.0+. Kit uses `glass()`. https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct.md
- `UIScrollEdgeElementContainerInteraction`: properties `scrollView: UIScrollView?`, `edge: UIRectEdge`; add to a container of views overlaying the scroll view edge with `addInteraction`. https://developer.apple.com/documentation/uikit/uiscrolledgeelementcontainerinteraction.md
- `WKWebView.obscuredContentInsets`: `var obscuredContentInsets: UIEdgeInsets { get set }`, iOS 26.0+. https://developer.apple.com/documentation/webkit/wkwebview/obscuredcontentinsets.md
- `UISheetPresentationController`: `detents`, `selectedDetentIdentifier`, `largestUndimmedDetentIdentifier`, `prefersGrabberVisible`; `Detent.medium()` is "approximately half the height of the screen". https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller.md
- Corner shape of a glass view: `view.cornerConfiguration = .capsule(maximumRadius: nil)` (the page lists `static func capsule(maximumRadius: Double?)`) or `.corners(radius: 22.0)` (UICornerConfiguration, iOS 26.0+). The UIView.cornerConfiguration page itself could not be fetched; whether it clips a plain UIBlurEffect view is unverified, so the blur pill also gets layer.cornerRadius and clipsToBounds. https://developer.apple.com/documentation/uikit/uicornerconfiguration-swift.struct.md
- `UIControl.showsMenuAsPrimaryAction`, `UIControl.performPrimaryAction()` (iOS 17.4+, "presents further UI, for example a contextual menu"). https://developer.apple.com/documentation/uikit/uicontrol/performprimaryaction().md
- Scene life cycle: with the SDK after iOS 26 an app without a `UIApplicationSceneManifest` "won't launch", so the kit uses a SceneDelegate and the manifest in project.yml. https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle.md
- Deployment target is iOS 26.0 (the test only means something on 26 or later), so the app has no `#if compiler` or `#available` guards; an Xcode without the iOS 26 SDK fails the build instead of silently comparing blur with blur. Swift language mode is 5 (avoids Swift 6 concurrency errors). Whether Xcode 27 accepts a 26.0 minimum is not stated on a page I fetched; it is lower than the SDK, so expected to work.
- `xcode-27` still carries a Preview badge in the runner-images README (changelog says generally available); keep the manual fallback `macos-26` with `/Applications/Xcode_26.6.app`.
- Background jobs in a non-interactive bash ignore SIGINT unless job control is on, so the video step runs `set -m` before starting the recorder. https://www.gnu.org/software/bash/manual/bash.html#Signals
- Stills use `-freeze 1`: the app injects a `WKUserScript` (`window.FREEZE = true`, `.atDocumentStart`) and the page skips its scroll loop. Only the video scrolls.

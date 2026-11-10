# UI Aesthetic Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PurgeQuest look composed and deliberate: a hero that fills its stage, one primary action above the fold, surfaces with depth, and progress that reads as reward, without changing what the app does.

**Architecture:** Almost all of the upgrade lives in four shared pieces (a panel surface, a progress bar, a body-framed hero sprite, a hero stage), so every screen that already uses the shared components improves together. Two screens are recomposed by hand: the Library (dashboard) and the Trophies grid. Nothing in the data, classification, deletion or purchase paths is touched.

**Tech Stack:** SwiftUI (iOS 18+), Swift language mode 5 with default main-actor isolation, Swift Testing, XCUITest. No dependencies. Pure logic is also compiled and tested on Linux by `tools/swift_harness/run.sh`.

## Global Constraints

- **Do not change behavior.** No edits under `ios/PurgeQuest/Services/` except the one new file this plan names, none under `ios/PurgeQuest/ViewModels/`, and none to SwiftData models. Deletion, classification, StoreKit and widgets are out of scope.
- **Never** add a network call, an analytics call, a package, or a permanent-delete path. `python3 -I tools/ci/repo_guard.py` must print `repo_guard ok` before every commit.
- **Keep these strings exactly**; UI tests find elements by them: the button label `Enter the Dungeon` and its accessibility label `Enter the dungeon and start a cleanup session`; the Hero tab line `"\(race) · \(class) · LV \(level)"`; `No hero found.`; the accessibility label `Open the hero forge to customize your hero's look`; the accessibility identifiers `forge.open` and `forge.summary`.
- **Keep the storage wording exactly.** The three ledger titles and captions in Task 5 are copied from the current screen. Do not shorten or rephrase them: they say which numbers are estimates and which are measured.
- **Palette rules** (from `ios/PurgeQuest/Extensions/Color+Theme.swift`): use the existing tokens only (`.dungeonStone`, `.dungeonAsh`, `.questAmber`, `.gemEmerald`, `.combatCrimson`, `.videoSapphire`, `.textPrimary`, `.textSecondary`, …). No new hues, no neon, no pastel, no purple. The only literal colors this plan introduces are `Color.white` and `Color.black` at low opacity, for sheen and shadow.
- **Both appearances and both palettes.** Every change must look right in Light and Dark, Classic and Verdigris. Never pin a color scheme (`repo_guard` fails on `preferredColorScheme(.dark)`).
- **Motion:** springs on value change only. Nothing loops, drifts or pulses. Honor Reduce Motion where an animation is added.
- **New Swift files need no project edit.** The Xcode project uses file-system-synchronized groups: a file saved under `ios/PurgeQuest/` or `ios/PurgeQuestTests/` joins its target automatically. Do not edit `project.pbxproj`.
- **You cannot compile SwiftUI locally.** Only the Linux harness (pure Foundation files) runs here. SwiftUI code is compiled by the pull request's macOS jobs. Follow "The CI gate" below exactly; do not guess that code compiles.
- Every commit message ends with the attribution lines your own session's instructions give for commits (a `Co-Authored-By:` line and a `Claude-Session:` line). The commit commands below show `<attribution lines>` where they go; replace it each time. If your instructions give none, delete the placeholder.

- Work on branch `claude/optimistic-brahmagupta-9mbyay`. Push with `git push -u origin claude/optimistic-brahmagupta-9mbyay`. Never push to another branch.

---

## Why these changes (read once)

The current screens are in `docs/design/` only as three mockups; the live app was reviewed from CI screenshots on 2026-11-10. What that showed:

1. **The hero is tiny.** `HeroSpriteView(size:)` scales the art pack's *whole canvas* to `size`. The canvas is sized for every animation frame, so the standing hero fills only part of it: on the Hero tab the figure is about 60 pt tall inside a 210 pt plaque. The fix is to let a caller ask for the hero's own height (Task 2), not a bigger frame.
2. **The primary action is below the fold.** On the Library tab, "Enter the Dungeon" sits under a 300 pt storage card, three stat tiles, the hero strip, the next-dive strip and four quests.
3. **Every surface is the same flat grey rectangle** with the same hairline, so nothing has priority.
4. **Progress looks like a system control** (`ProgressView`) next to engraved type and gold plate.
5. **The Trophies grid is ragged**: cards differ in height because subtitles wrap to one or two lines.

Design direction, in one line: *a torchlit vault*. Charcoal or parchment canvas, engraved Cinzel titles, brand gold used sparingly as the one thing that glows; depth from a soft top sheen and a low shadow, not from color.

## File structure

| File | Status | Responsibility |
|---|---|---|
| `ios/PurgeQuest/Models/SpriteBodyBounds.swift` | create | Pure: bounding box of the opaque pixels of an alpha buffer |
| `ios/PurgeQuestTests/SpriteBodyBoundsTests.swift` | create | Tests for the above (also run on Linux) |
| `ios/PurgeQuest/Services/SpriteBodyFraming.swift` | create | Finds, once per art pack, the standing hero's box in the canvas |
| `ios/PurgeQuest/Views/Hero/HeroSpriteView.swift` | modify | Adds `framing: .body` |
| `ios/PurgeQuest/Views/Components/DungeonSurface.swift` | create | `DungeonRadius`, `DungeonPanelBackground`, `DungeonProgressBar` |
| `ios/PurgeQuest/Views/Components/DungeonChips.swift` | create | `LevelChip`, `StreakChip` |
| `ios/PurgeQuest/Views/Components/HeroStageView.swift` | create | The hero on a lit pedestal |
| `ios/PurgeQuest/Views/Components/DungeonBackgroundView.swift` | modify | A faint glow from above |
| `ios/PurgeQuest/Views/Components/XPBarView.swift` | modify | Bars use `DungeonProgressBar` |
| `ios/PurgeQuest/Views/Components/GemCounterView.swift` | modify | `GemCounterView` and `StatTile` use the panel surface |
| `ios/PurgeQuest/Views/Hero/CharacterAvatarView.swift` | modify | Portrait uses body framing |
| `ios/PurgeQuest/Views/Hero/HeroTabView.swift` | modify | Card surface |
| `ios/PurgeQuest/Views/Dashboard/DashboardView.swift` | modify | Recomposed Library screen |
| `ios/PurgeQuest/Views/Achievements/AchievementsView.swift` | modify | Even grid, new bar and surface |
| `ios/PurgeQuestUITests/AppearanceTourUITests.swift` | modify | Tour finds the moved button and waits for a card |
| `tools/swift_harness/run.sh` | modify | Adds the new pure file and its suite |
| `docs/design/DESIGN_SYSTEM.md` | create | The rules this plan establishes |

Already in place (committed with this plan, do not recreate): `.github/workflows/ui-snapshots.yml` and `tools/ci/make_library_fixtures.py`.

---

## Setup (do once, before Task 1)

- [ ] **Step 1: Confirm the branch and a clean tree**

```bash
cd /home/user/PurgeQuest-PhotoCleanv2
git status -sb
```

Expected: first line `## claude/optimistic-brahmagupta-9mbyay...`, no modified files.

- [ ] **Step 2: Make the Swift toolchain available for the Linux harness**

```bash
export SWIFT_BIN=/tmp/claude-0/-home-user-PurgeQuest-PhotoCleanv2/e252b72a-ca0e-55d9-9bea-b9aa4b8b7f19/scratchpad/swift-toolchain/swift-6.2-RELEASE-ubuntu24.04/usr/bin/swift
[ -x "$SWIFT_BIN" ] && "$SWIFT_BIN" --version | head -1
```

Expected: `Swift version 6.2 (swift-6.2-RELEASE)`. If the file does not exist (a new machine), download it once and point `SWIFT_BIN` at the new copy:

```bash
mkdir -p "$HOME/swift-toolchain" && cd "$HOME/swift-toolchain" \
  && curl -sSL -o swift.tar.gz https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz \
  && tar xzf swift.tar.gz && rm swift.tar.gz \
  && export SWIFT_BIN="$HOME/swift-toolchain/swift-6.2-RELEASE-ubuntu24.04/usr/bin/swift" \
  && cd /home/user/PurgeQuest-PhotoCleanv2
```

- [ ] **Step 3: Record the baseline**

```bash
tools/swift_harness/run.sh 2>&1 | grep "Test run with"
python3 -I tools/ci/repo_guard.py | tail -1
```

Expected: `✔ Test run with 262 tests in 18 suites passed` and a line starting `repo_guard ok`.

## The CI gate (referred to by later tasks)

SwiftUI code is checked only by the pull request's macOS jobs. After a push:

1. If no pull request is open for the branch, open one against `main` (GitHub MCP tool `create_pull_request`), title `UI aesthetic upgrade`, body: one paragraph per finished task.
2. Read the check runs for the PR (GitHub MCP tool `pull_request_read`, method `get_check_runs`). The two that matter:
   - **`build-and-analyze`**: the compiler. About 4 minutes.
   - **`tour`** (workflow "UI snapshots"): builds the app, fills the simulator with synthetic photos, and uploads screenshots as the artifact `ui-snapshots-tour`. About 15 minutes.
3. While either is `in_progress`, wait about four minutes and read again. Do not start the next task's edits on top of unchecked code that the next task depends on.
4. **If `build-and-analyze` fails:** get its log (GitHub MCP tool `get_job_logs` with the run id from the check's URL, `failed_only: true`, `return_content: true`), find the lines containing `error:`, fix exactly those, commit as `Fix build: <what>`, push, and repeat the gate. Do not rewrite surrounding code.
5. **When `tour` succeeds, look at the screenshots.** List the run's artifacts (`actions_list`, method `list_workflow_run_artifacts`, the run id from the `tour` check's URL), get the download URL (`actions_get`, method `download_workflow_run_artifact`), then:

```bash
SNAP=/tmp/ui-snapshots && rm -rf "$SNAP" && mkdir -p "$SNAP" && cd "$SNAP" \
  && curl -sSL -o ui.zip '<download_url>' && unzip -q -o ui.zip && rm ui.zip && ls | head -40 \
  && cd /home/user/PurgeQuest-PhotoCleanv2
```

   Shrink before viewing, so each image is cheap to read (replace the names as each task says):

```bash
python3 -I - <<'EOF'
from PIL import Image
import os
d = "/tmp/ui-snapshots"
for name in ["tour-dark-10-library.png", "tour-light-10-library.png"]:
    im = Image.open(os.path.join(d, name)).convert("RGB")
    im = im.resize((420, int(im.height * 420 / im.width)), Image.LANCZOS)
    im.save(os.path.join(d, "small-" + name.replace(".png", ".jpg")), quality=88)
    print("wrote small-" + name.replace(".png", ".jpg"))
EOF
```

   Then open each `small-*.jpg` with the Read tool and check it against the task's "Looks right when" list. If a point fails, fix it and repeat the gate. If the artifact is missing because the tour itself failed, read the `tour` job log the same way as a build failure.

---

### Task 1: Find the hero inside its canvas (pure logic)

**Files:**
- Create: `ios/PurgeQuest/Models/SpriteBodyBounds.swift`
- Create: `ios/PurgeQuestTests/SpriteBodyBoundsTests.swift`
- Modify: `tools/swift_harness/run.sh`

**Interfaces:**
- Produces: `struct NormalizedRect { let x, y, width, height: Double; static let full }` and `SpriteBodyBounds.normalizedRect(alpha: [UInt8], width: Int, height: Int, threshold: UInt8 = SpriteBodyBounds.threshold) -> NormalizedRect?`. Task 2 calls it.

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/SpriteBodyBoundsTests.swift`:

```swift
//
//  SpriteBodyBoundsTests.swift
//  PurgeQuestTests
//
//  Where the opaque part of a sprite sits inside its canvas. The hero is drawn on a canvas sized for
//  every animation frame, so the standing figure fills only part of it; this box is what lets a view
//  ask for the hero's own height.
//
//  Foundation only, so this runs in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct SpriteBodyBoundsTests {

    /// A `width` x `height` alpha buffer, opaque inside the given pixel box and clear outside it.
    private func buffer(width: Int, height: Int, box: (x: Int, y: Int, w: Int, h: Int), alpha: UInt8 = 255) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in box.y..<(box.y + box.h) {
            for x in box.x..<(box.x + box.w) {
                pixels[y * width + x] = alpha
            }
        }
        return pixels
    }

    @Test func aBlockIsFoundAsFractionsOfTheCanvasFromTheTopLeft() throws {
        let pixels = buffer(width: 10, height: 20, box: (x: 2, y: 5, w: 4, h: 10))
        let rect = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 10, height: 20))
        #expect(rect == NormalizedRect(x: 0.2, y: 0.25, width: 0.4, height: 0.5))
    }

    @Test func aSinglePixelIsOnePixelWideAndTall() throws {
        let pixels = buffer(width: 8, height: 4, box: (x: 7, y: 3, w: 1, h: 1))
        let rect = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 8, height: 4))
        #expect(rect == NormalizedRect(x: 0.875, y: 0.75, width: 0.125, height: 0.25))
    }

    @Test func aFullyOpaqueCanvasIsTheWholeCanvas() throws {
        let pixels = [UInt8](repeating: 255, count: 6 * 6)
        #expect(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 6, height: 6) == .full)
    }

    @Test func faintPixelsAtOrBelowTheThresholdAreNotPartOfTheBody() throws {
        // A soft shadow or an antialiasing fringe must not stretch the box.
        var pixels = buffer(width: 10, height: 10, box: (x: 4, y: 4, w: 2, h: 2))
        pixels[0] = SpriteBodyBounds.threshold            // top-left corner, exactly at the line: ignored
        let tight = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 10, height: 10))
        #expect(tight == NormalizedRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2))

        pixels[0] = SpriteBodyBounds.threshold + 1        // one step over: counted
        let stretched = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 10, height: 10))
        #expect(stretched == NormalizedRect(x: 0, y: 0, width: 0.6, height: 0.6))
    }

    @Test func anEmptyCanvasOrAMismatchedBufferHasNoBox() {
        #expect(SpriteBodyBounds.normalizedRect(alpha: [UInt8](repeating: 0, count: 16), width: 4, height: 4) == nil)
        #expect(SpriteBodyBounds.normalizedRect(alpha: [UInt8](repeating: 255, count: 15), width: 4, height: 4) == nil)
        #expect(SpriteBodyBounds.normalizedRect(alpha: [], width: 0, height: 0) == nil)
    }
}
```

- [ ] **Step 2: Add the file and the suite to the harness**

In `tools/swift_harness/run.sh` there are two lists. In the line that begins `for f in Models/ModularCharacterFoundation`, add `Models/SpriteBodyBounds` directly after `Models/GameContent`. In the line that begins `for t in ModularCharacterFoundationTests`, add `SpriteBodyBoundsTests` directly after `VideoFrameSignalTests`.

Check both edits landed:

```bash
grep -c "Models/SpriteBodyBounds" tools/swift_harness/run.sh; grep -c "SpriteBodyBoundsTests" tools/swift_harness/run.sh
```

Expected: `1` then `1`.

- [ ] **Step 3: Run the harness and see it fail**

```bash
tools/swift_harness/run.sh 2>&1 | grep -E "error:|No such file" | head -5
```

Expected: an error that `SpriteBodyBounds.swift` does not exist (the symlink points nowhere) or `cannot find 'SpriteBodyBounds' in scope`.

- [ ] **Step 4: Write the implementation**

Create `ios/PurgeQuest/Models/SpriteBodyBounds.swift`:

```swift
//
//  SpriteBodyBounds.swift
//  PurgeQuest
//
//  Where the opaque part of an image sits inside it. An art pack's canvas is sized to hold every
//  animation frame (a jump, a swing with the sword out), so the standing hero fills only part of it.
//  Knowing the hero's own box lets a view size the hero, not the canvas.
//
//  Foundation only: the caller reads the alpha bytes out of the bitmap (SpriteBodyFraming), this
//  file only finds their bounds, so the Linux harness tests it.
//

import Foundation

/// A rectangle in fractions of an image: origin at the top-left, 0...1 on both axes.
nonisolated struct NormalizedRect: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
}

nonisolated enum SpriteBodyBounds {
    /// Alpha at or below this is treated as empty: a soft shadow's edge, an antialiasing fringe.
    static let threshold: UInt8 = 24

    /// The smallest box holding every pixel whose alpha is above `threshold`, as fractions of the
    /// image. `alpha` is `width * height` bytes, row by row from the top. Nil when the image has no
    /// such pixel or the buffer is not that size.
    static func normalizedRect(
        alpha: [UInt8], width: Int, height: Int, threshold: UInt8 = SpriteBodyBounds.threshold
    ) -> NormalizedRect? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where alpha[row + x] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return NormalizedRect(
            x: Double(minX) / Double(width),
            y: Double(minY) / Double(height),
            width: Double(maxX - minX + 1) / Double(width),
            height: Double(maxY - minY + 1) / Double(height)
        )
    }
}
```

- [ ] **Step 5: Run the harness and see it pass**

```bash
tools/swift_harness/run.sh 2>&1 | grep -E "✘|error:|Test run with"
```

Expected: exactly one line, `✔ Test run with 267 tests in 19 suites passed`.

- [ ] **Step 6: Commit**

```bash
python3 -I tools/ci/repo_guard.py | tail -1
git add ios/PurgeQuest/Models/SpriteBodyBounds.swift ios/PurgeQuestTests/SpriteBodyBoundsTests.swift tools/swift_harness/run.sh
git commit -m "Find the opaque box of a sprite inside its canvas

The hero is drawn on a canvas sized for every animation frame, so the
standing figure fills only part of it. This pure helper finds the figure's
own box from the alpha channel; the next commit uses it to size the hero
instead of the canvas.


<attribution lines>"
```

---

### Task 2: Let a view ask for the hero's own height

**Files:**
- Create: `ios/PurgeQuest/Services/SpriteBodyFraming.swift`
- Modify: `ios/PurgeQuest/Views/Hero/HeroSpriteView.swift`

**Interfaces:**
- Consumes: `SpriteBodyBounds.normalizedRect(alpha:width:height:)`, `NormalizedRect` (Task 1). Existing: `SpriteRenderer.shared.frame(race:variant:animation:frameIndex:appearance:loadout:) -> SpriteFrame?`, `SpriteRenderer.shared.canvasSize(race:variant:) -> CGSize?`, `SpriteFrame.image: UIImage`, `SpriteFrame.layout: SpriteCanvasLayout` (`.left`, `.top` are `Double`; `.zero` exists).
- Produces: `HeroSpriteView.Framing` (`.canvas`, `.body`) and the new last parameter `framing: HeroSpriteView.Framing = .canvas`. With `.body`, `size` is the height of the standing hero, the view's box is the hero's own box, and the feet are on its bottom edge. Tasks 4 and 6 use it.

- [ ] **Step 1: Create the framing service**

Create `ios/PurgeQuest/Services/SpriteBodyFraming.swift`:

```swift
//
//  SpriteBodyFraming.swift
//  PurgeQuest
//
//  Finds, once per art pack, where the standing hero sits inside the pack's canvas. The answer is
//  measured from the first idle frame with nothing in the hands, so a sword or shield never changes
//  it, and cached: every later frame of that pack is placed with the same box and does not jitter.
//
//  The arithmetic is SpriteBodyBounds (Foundation, tested on Linux); this file only reads the alpha
//  bytes out of the rendered bitmap.
//

import UIKit

@MainActor
enum SpriteBodyFraming {
    private static var cache: [String: CGRect] = [:]
    private static var unmeasurable: Set<String> = []

    /// The standing hero's box in the pack's base canvas, in canvas units with the origin at the
    /// top-left. Nil when the pack cannot be rendered; the caller then falls back to canvas framing.
    static func bodyRect(race: HeroRace, variant: Int, appearance: HeroAppearance) -> CGRect? {
        let key = "\(race.rawValue)-\(variant)"
        if let known = cache[key] { return known }
        if unmeasurable.contains(key) { return nil }

        let renderer = SpriteRenderer.shared
        guard let frame = renderer.frame(
                race: race, variant: variant, animation: "Idle", frameIndex: 0,
                appearance: appearance, loadout: .none),
              frame.layout == .zero,
              let fractions = normalizedBounds(of: frame.image) else {
            unmeasurable.insert(key)
            return nil
        }
        let base = renderer.canvasSize(race: race, variant: variant) ?? frame.image.size
        let rect = CGRect(
            x: CGFloat(fractions.x) * base.width,
            y: CGFloat(fractions.y) * base.height,
            width: CGFloat(fractions.width) * base.width,
            height: CGFloat(fractions.height) * base.height
        )
        guard rect.width > 0, rect.height > 0 else {
            unmeasurable.insert(key)
            return nil
        }
        cache[key] = rect
        return rect
    }

    /// The opaque box of `image`, as fractions. Read at no more than 256 pixels wide: the box only
    /// needs to be right to about a pixel of the drawn size.
    private static func normalizedBounds(of image: UIImage) -> NormalizedRect? {
        guard let cg = image.cgImage, cg.width > 0, cg.height > 0 else { return nil }
        let width = min(cg.width, 256)
        let height = max(1, Int((Double(cg.height) * Double(width) / Double(cg.width)).rounded()))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var alpha = [UInt8](repeating: 0, count: width * height)
        for index in 0..<alpha.count { alpha[index] = pixels[index * 4 + 3] }
        return SpriteBodyBounds.normalizedRect(alpha: alpha, width: width, height: height)
    }
}
```

- [ ] **Step 2: Add the framing mode to `HeroSpriteView`**

In `ios/PurgeQuest/Views/Hero/HeroSpriteView.swift`, find:

```swift
    /// Increment to play the race's attack animation once.
    var attackPulse: Int = 0
```

Replace it with:

```swift
    /// Increment to play the race's attack animation once.
    var attackPulse: Int = 0
    /// What `size` measures. Defaults to the long-standing behavior.
    var framing: Framing = .canvas

    enum Framing {
        /// `size` is the height of the pack's whole canvas, which leaves room for every animation
        /// frame; the standing hero fills only part of it.
        case canvas
        /// `size` is the height of the standing hero. The view's box is the hero's own box with the
        /// feet on its bottom edge; a weapon and the rest of the canvas overflow it.
        case body
    }
```

- [ ] **Step 3: Use it when placing the image**

In the same file, find the whole function that begins `@ViewBuilder private func spriteImage(_ frame: SpriteFrame) -> some View {` and ends at its closing brace (it is the last member of the struct). Replace the whole function, including its doc comment, with:

```swift
    /// The standing hero's box in the pack's canvas, when the caller asked for body framing.
    private var bodyRect: CGRect? {
        guard framing == .body else { return nil }
        return SpriteBodyFraming.bodyRect(race: race, variant: variant, appearance: look)
    }

    /// Places the frame's bitmap. With body framing the hero's own box becomes the layout box and
    /// everything else overflows it. Otherwise the canvas fills `size`, and a Titan blade that
    /// enlarges the canvas overflows the box instead of shrinking the hero to fit it.
    @ViewBuilder private func spriteImage(_ frame: SpriteFrame) -> some View {
        if let box = bodyRect {
            let k = size / box.height
            Image(uiImage: frame.image)
                .resizable()
                .frame(width: frame.image.size.width * k, height: frame.image.size.height * k)
                .offset(x: -(CGFloat(frame.layout.left) + box.minX) * k,
                        y: -(CGFloat(frame.layout.top) + box.minY) * k)
                .frame(width: box.width * k, height: size, alignment: .topLeading)
        } else if frame.layout == .zero {
            Image(uiImage: frame.image)
                .resizable()
                .scaledToFit()
        } else {
            let base = renderer.canvasSize(race: race, variant: variant) ?? frame.image.size
            let k = CGFloat(SpriteCanvasLayout.pointsPerUnit(height: Double(size), baseHeight: Double(base.height)))
            Image(uiImage: frame.image)
                .resizable()
                .frame(width: frame.image.size.width * k, height: frame.image.size.height * k)
                .offset(x: -CGFloat(frame.layout.left) * k, y: -CGFloat(frame.layout.top) * k)
                .frame(width: base.width * k, height: size, alignment: .topLeading)
        }
    }
```

The last two branches are the existing code, unchanged. Confirm nothing else in the file changed:

```bash
git diff --stat -- ios/PurgeQuest/Views/Hero/HeroSpriteView.swift
```

Expected: one file, roughly `+25 -4`.

- [ ] **Step 4: Check and commit** (no caller uses `.body` yet, so nothing changes on screen)

```bash
python3 -I tools/ci/repo_guard.py | tail -1
tools/swift_harness/run.sh 2>&1 | grep -E "✘|error:|Test run with"
git add ios/PurgeQuest/Services/SpriteBodyFraming.swift ios/PurgeQuest/Views/Hero/HeroSpriteView.swift
git commit -m "Let a view size the hero by the hero's own height

HeroSpriteView scaled the art pack's whole canvas to the requested size, and
the canvas leaves room for every animation frame, so the standing hero came
out at a fraction of it. A caller can now pass framing: .body, and size then
means the height of the hero itself. The box is measured once per pack from
the first idle frame with empty hands and cached.

The default is unchanged, so no screen looks different yet.


<attribution lines>"
```

Expected from the two checks: `repo_guard ok …` and `✔ Test run with 267 tests in 19 suites passed`.

---

### Task 3: Surfaces, bars and chips

**Files:**
- Create: `ios/PurgeQuest/Views/Components/DungeonSurface.swift`
- Create: `ios/PurgeQuest/Views/Components/DungeonChips.swift`
- Modify: `ios/PurgeQuest/Views/Components/DungeonBackgroundView.swift`
- Modify: `ios/PurgeQuest/Views/Components/XPBarView.swift`
- Modify: `ios/PurgeQuest/Views/Components/GemCounterView.swift`

**Interfaces:**
- Produces:
  - `enum DungeonRadius { static let chip: CGFloat = 8; static let card: CGFloat = 12; static let hero: CGFloat = 16 }`
  - `DungeonPanelBackground(cornerRadius: CGFloat = DungeonRadius.card, accent: Color? = nil, fillOpacity: Double = 1, elevated: Bool = true)`, a `View` meant for `.background(…)`
  - `DungeonProgressBar(value: Double, tint: Color = .questAmber, height: CGFloat = 8)`
  - `LevelChip(level: Int)`, `StreakChip(days: Int)`
- Tasks 4, 5, 6 and 7 use all of them.

- [ ] **Step 1: Create the surface and the bar**

Create `ios/PurgeQuest/Views/Components/DungeonSurface.swift`:

```swift
//
//  DungeonSurface.swift
//  PurgeQuest
//
//  The app's one panel surface and its one progress bar. Depth comes from a faint sheen along the
//  top edge and a low shadow, never from color, so both palettes and both appearances keep their
//  own character.
//

import SwiftUI

/// Corner radii. Three sizes only: a chip, a card, and the one hero panel a screen may have.
enum DungeonRadius {
    static let chip: CGFloat = 8
    static let card: CGFloat = 12
    static let hero: CGFloat = 16
}

/// The stone panel behind every card. Use it as a background:
/// `.background(DungeonPanelBackground())`, or with `accent:` for a panel that belongs to something
/// (a race, a quest that is done), which tints the border and nothing else.
struct DungeonPanelBackground: View {
    var cornerRadius: CGFloat = DungeonRadius.card
    var accent: Color? = nil
    var fillOpacity: Double = 1
    /// False for small inline chips, which should sit flat on their panel.
    var elevated: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color.dungeonStone.opacity(fillOpacity))
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.045 : 0.35), Color.white.opacity(0)],
                        startPoint: .top, endPoint: .center
                    )
                )
            )
            .overlay(shape.strokeBorder(accent?.opacity(0.45) ?? Color.dungeonAsh, lineWidth: 1))
            .shadow(
                color: Color.black.opacity(elevated ? (colorScheme == .dark ? 0.32 : 0.07) : 0),
                radius: 8, x: 0, y: 3
            )
    }
}

/// A capsule progress bar: a recessed track and a filled run that springs when the value changes.
struct DungeonProgressBar: View {
    /// 0...1; values outside are clamped.
    let value: Double
    var tint: Color = .questAmber
    var height: CGFloat = 8

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.dungeonVoid)
                    .overlay(Capsule().strokeBorder(Color.dungeonAsh, lineWidth: 1))
                Capsule()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .top, endPoint: .bottom))
                    // Any progress at all shows at least a dot, so "started" never reads as "empty".
                    .frame(width: clamped > 0 ? max(height, geometry.size.width * clamped) : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: clamped)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}
```

- [ ] **Step 2: Create the chips**

Create `ios/PurgeQuest/Views/Components/DungeonChips.swift`:

```swift
//
//  DungeonChips.swift
//  PurgeQuest
//
//  Small inline badges shared by the Library and Hero screens.
//

import SwiftUI

/// The hero's level, as a gold-tinted capsule.
struct LevelChip: View {
    let level: Int

    var body: some View {
        Text("LV \(level)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.questAmber)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.questAmber.opacity(0.16)))
            .overlay(Capsule().strokeBorder(Color.questAmber.opacity(0.45), lineWidth: 1))
            .accessibilityLabel("Level \(level)")
    }
}

/// The daily streak: a flame and a count.
struct StreakChip: View {
    let days: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.combatCrimson)
            Text("\(days)")
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .contentTransition(.numericText(value: Double(days)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DungeonPanelBackground(cornerRadius: DungeonRadius.chip, accent: .combatCrimson, elevated: false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) day streak")
    }
}
```

- [ ] **Step 3: Give the canvas a faint light from above**

Replace the whole of `ios/PurgeQuest/Views/Components/DungeonBackgroundView.swift` with:

```swift
//
//  DungeonBackgroundView.swift
//  PurgeQuest
//
//  Static tonal canvas: the palette's base (green-black or charcoal in Dark, cream in Light), a
//  faint vignette, and one soft pool of brand gold falling from the top edge, as if from a torch
//  above the screen. It is a few percent strong and never moves: no particles, no dot grids, no
//  animation anywhere on the canvas.
//

import SwiftUI

struct DungeonBackgroundView: View {
    var intensity: Double = 0.0   // Kept for call-site compatibility; the canvas is intentionally static.

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient.dungeonBackground
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.goldInk.opacity(colorScheme == .dark ? 0.10 : 0.06), Color.goldInk.opacity(0)],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            RadialGradient(
                colors: [.clear, .canvasVignette],
                center: .center,
                startRadius: 260,
                endRadius: 720
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
```

- [ ] **Step 4: Bars use the new progress bar**

In `ios/PurgeQuest/Views/Components/XPBarView.swift`, inside `XPBarView`, replace this block:

```swift
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.dungeonVoid)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.dungeonAsh, lineWidth: 1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.questAmber)
                        .frame(width: max(0, geo.size.width * progress))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: compact ? 6 : 10)
```

with:

```swift
            DungeonProgressBar(value: progress, tint: .questAmber, height: compact ? 6 : 10)
```

In the same file, inside `HPBarView`, replace this block:

```swift
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.dungeonVoid)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.dungeonAsh, lineWidth: 1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.combatCrimson)
                        .frame(width: Swift.max(0, geo.size.width * fraction))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: fraction)
                }
            }
            .frame(height: 8)
```

with:

```swift
            DungeonProgressBar(value: fraction, tint: .combatCrimson, height: 8)
```

Also change the file's header comment line `//  Flat progress bars with crisp borders. Motion is limited to a spring fill` to `//  The XP and HP bars, drawn with DungeonProgressBar. Motion is limited to a spring fill`.

- [ ] **Step 5: The gem counter and the stat tile use the panel surface**

In `ios/PurgeQuest/Views/Components/GemCounterView.swift`, inside `GemCounterView`, replace:

```swift
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gemEmerald.opacity(0.4), lineWidth: 1))
        )
```

with:

```swift
        .background(DungeonPanelBackground(cornerRadius: DungeonRadius.chip, accent: .gemEmerald, elevated: false))
```

Inside `StatTile`, replace:

```swift
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonStone)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.dungeonAsh, lineWidth: 1)
                )
        )
```

with:

```swift
        .background(DungeonPanelBackground())
```

`StatTile` is used on the Hero tab, in Settings and on the Room Summary, so those three pick up the new surface with this one edit.

- [ ] **Step 6: Check and commit**

```bash
python3 -I tools/ci/repo_guard.py | tail -1
git add ios/PurgeQuest/Views/Components
git commit -m "Give panels depth and bars a shape of their own

Every card was the same flat rectangle with the same hairline, and progress
was drawn two ways: square bars for XP and HP, the system control for
quests and trophies.

- DungeonPanelBackground: one panel surface, with a faint sheen along the
  top edge, a low shadow and continuous corners. An accent tints the border
  only. The gem counter and the stat tile use it, which carries it to the
  Hero tab, Settings and the Room Summary.
- DungeonProgressBar: a capsule with a recessed track; XP and HP use it.
- LevelChip and StreakChip for the screens that follow.
- The canvas gains one soft pool of gold from the top edge, a few percent
  strong and static.


<attribution lines>"
```

- [ ] **Step 7: Push and pass the CI gate (compile only)**

```bash
git push -u origin claude/optimistic-brahmagupta-9mbyay
```

Follow "The CI gate" until `build-and-analyze` is green. This is the first time Tasks 1 to 3 meet a compiler; fix any `error:` lines before continuing. You do not need to wait for `tour` here.

---

### Task 4: The hero stage, and a hero that fills its portrait

**Files:**
- Create: `ios/PurgeQuest/Views/Components/HeroStageView.swift`
- Modify: `ios/PurgeQuest/Views/Hero/CharacterAvatarView.swift`
- Modify: `ios/PurgeQuest/Views/Hero/HeroTabView.swift`

**Interfaces:**
- Consumes: `HeroSpriteView(hero:appearance:equipped:size:isAnimated:attackPulse:framing:)` (Task 2), `DungeonPanelBackground`, `DungeonRadius` (Task 3). Existing: `Hero.race: HeroRace`, `HeroRace.accent: Color`, `HeroRace.displayName: String`, `HeroAppearance.race: HeroRace?`.
- Produces: `HeroStageView(hero: Hero, equipped: [CosmeticItem] = [], appearance: HeroAppearance? = nil, height: CGFloat = 120, accent: Color = .questAmber, isAnimated: Bool = true)`. Its own frame is `height * 1.5` wide and `height * 1.3` tall. Task 5 uses it.

- [ ] **Step 1: Create the stage**

Create `ios/PurgeQuest/Views/Components/HeroStageView.swift`:

```swift
//
//  HeroStageView.swift
//  PurgeQuest
//
//  The hero standing on a pedestal with a pool of light behind. `height` is the hero's own height,
//  not a canvas: the figure is the subject, so it is sized directly.
//

import SwiftUI

struct HeroStageView: View {
    let hero: Hero
    var equipped: [CosmeticItem] = []
    /// Draft appearance override, as in the Forge.
    var appearance: HeroAppearance? = nil
    /// Height of the standing hero.
    var height: CGFloat = 120
    /// Tints the light and the pedestal's rim. A race's accent reads best.
    var accent: Color = .questAmber
    var isAnimated: Bool = true

    private var raceName: String { (appearance?.race ?? hero.race).displayName }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Light pooling behind the hero. One still ellipse.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.22), accent.opacity(0)],
                        center: .center, startRadius: 0, endRadius: height * 0.75
                    )
                )
                .frame(width: height * 1.5, height: height * 1.25)

            // The pedestal the feet rest on.
            Ellipse()
                .fill(Color.dungeonVoid.opacity(0.55))
                .overlay(Ellipse().strokeBorder(accent.opacity(0.35), lineWidth: 1))
                .frame(width: height * 0.8, height: height * 0.16)
                .offset(y: height * 0.06)

            HeroSpriteView(
                hero: hero, appearance: appearance, equipped: equipped,
                size: height, isAnimated: isAnimated, framing: .body
            )
            .padding(.bottom, height * 0.04)
        }
        .frame(width: height * 1.5, height: height * 1.3, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(raceName) hero")
    }
}
```

- [ ] **Step 2: The portrait sizes the hero, not the canvas**

In `ios/PurgeQuest/Views/Hero/CharacterAvatarView.swift`, find:

```swift
            HeroSpriteView(hero: hero, appearance: appearance, equipped: equipped, size: size * 0.8)
                .frame(width: size * 0.62, height: size * 0.72)
                .overlay(alignment: .bottom) { petCompanion }
```

Replace it with:

```swift
            // The hero's own height is set here, not the canvas's: the figure stands 0.56 of the
            // portrait tall with its feet on the frame's bottom edge, which is the ground line the
            // pet below is placed on.
            HeroSpriteView(hero: hero, appearance: appearance, equipped: equipped, size: size * 0.56, framing: .body)
                .frame(width: size * 0.62, height: size * 0.72, alignment: .bottom)
                .overlay(alignment: .bottom) { petCompanion }
```

Change nothing else in this file. The badges, backdrops and pet are positioned from `size` and stay where they are.

- [ ] **Step 3: The Hero tab's card uses the panel surface**

In `ios/PurgeQuest/Views/Hero/HeroTabView.swift`, inside `characterCard`, replace:

```swift
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(hero.race.accent.opacity(0.5), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(hero.race.accent.opacity(0.25), lineWidth: 1).padding(2))
        )
```

with:

```swift
        .background(DungeonPanelBackground(cornerRadius: DungeonRadius.hero, accent: hero.race.accent))
```

Do not touch the `Text("\(hero.race.displayName) · \(hero.heroClass.displayName) · LV \(hero.level)")` line or the Forge button: a UI test reads both.

- [ ] **Step 4: Commit and push**

```bash
python3 -I tools/ci/repo_guard.py | tail -1
git add ios/PurgeQuest/Views/Components/HeroStageView.swift ios/PurgeQuest/Views/Hero/CharacterAvatarView.swift ios/PurgeQuest/Views/Hero/HeroTabView.swift
git commit -m "Make the hero fill its portrait

On the Hero tab and in the Forge the figure stood about 60 pt tall inside a
210 pt plaque, because the portrait scaled the art pack's canvas. It now
asks for the hero's own height, 0.56 of the portrait, with the feet on the
ground line the pet already uses. Badges, backdrops and the pet are placed
from the portrait size and do not move.

HeroStageView is the same idea as a reusable piece: the hero on a pedestal
with a pool of light, for the Library screen next.


<attribution lines>"
git push -u origin claude/optimistic-brahmagupta-9mbyay
```

- [ ] **Step 5: Pass the CI gate and look**

Follow "The CI gate" through the screenshots. View these (shrunk): `tour-dark-20-hero.png`, `tour-light-20-hero.png`, `tour-dark-23-forge.png`, `tour-newart-dark-20-hero-pet.png`, `tour-gear-dark-20-golem-hero.png`, `tour-held-valkyrie-v1.png`.

**Looks right when:**
- The hero is roughly twice as tall as before: its head-to-feet height is more than half the plaque's height.
- The hero is horizontally centered in the plaque and its feet are above the plaque's bottom border, not on or below it.
- In `hero-pet`, the pet stands beside the hero on the same ground line, not floating above the feet or sunk below them.
- In `golem-hero` and `held-valkyrie`, the held weapon is attached to the hand. It may extend past the plaque's border; it must not be cut off by a clipping edge.
- Cards have a soft shadow and a slightly lighter top edge in Dark; in Light the top sheen must not wash a card to pure white.

**If a point fails, the fix is one number, not a rewrite:**
- Hero too tall or weapon colliding with the name below: lower `size * 0.56` in `CharacterAvatarView` (try `0.50`).
- Hero sits too low in the plaque: lower the frame's `height: size * 0.72` (try `0.66`); the pet moves with it.
- Light-mode cards look washed: lower `0.35` in `DungeonPanelBackground` (try `0.22`).

Commit any such adjustment as `Tune the hero portrait: <what>` and repeat the gate.

---

### Task 5: Recompose the Library screen

**Files:**
- Modify: `ios/PurgeQuest/Views/Dashboard/DashboardView.swift`
- Modify: `ios/PurgeQuestUITests/AppearanceTourUITests.swift`

**Interfaces:**
- Consumes: `HeroStageView` (Task 4); `DungeonPanelBackground`, `DungeonRadius`, `DungeonProgressBar`, `LevelChip`, `StreakChip` (Task 3). Existing in the file: `hero`, `equippedItems`, `libraryStats`, `opportunityBytes`, `pendingDeletionBytes`, `reclaimValue`, `formattedBytes(_:)`, `hairline`, `themeStrip`, `questsPanel`, `enterDungeonButton`, `focusedDiveMenu`, `pickedHuntPicker`, `Quest.kind: QuestKind` (`.photoSlay`, `.videoSlay`, `.mbFreed`, `.anySlay`).

New order, top to bottom: title, storage ledger (compact), hero banner, **Enter the Dungeon**, the two secondary actions side by side, seasonal banner, next dive, daily quests. Storage still leads, as the file's header says it should; it is half the height, so the primary action lands above the fold.

- [ ] **Step 1: Reorder the screen**

In `DashboardView.body`, replace:

```swift
            VStack(alignment: .leading, spacing: 18) {
                libraryOverview
                if let event = SeasonalEventService.shared.activeEvent {
                    SeasonalEventBanner(event: event)
                }
                heroStrip
                themeStrip
                questsPanel
                enterDungeonButton
                focusedDiveMenu
                pickedHuntPicker
                Color.clear.frame(height: 16)
            }
```

with:

```swift
            VStack(alignment: .leading, spacing: 16) {
                libraryOverview
                heroStrip
                enterDungeonButton
                HStack(spacing: 10) {
                    focusedDiveMenu
                    pickedHuntPicker
                }
                if let event = SeasonalEventService.shared.activeEvent {
                    SeasonalEventBanner(event: event)
                }
                themeStrip
                questsPanel
                Color.clear.frame(height: 16)
            }
```

- [ ] **Step 2: Replace the storage card with a compact ledger**

Replace the whole `libraryOverview` property (from `private var libraryOverview: some View {` through its closing brace; keep the doc comment above it) with:

```swift
    private var libraryOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library")
                .font(.dungeonScreenTitle)
                .foregroundStyle(.textPrimary)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Storage")
                        .font(.dungeonHeader)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("\(libraryStats.photoCount) photos · \(libraryStats.videoCount) videos")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
                .padding(.bottom, 4)

                measurementRow(
                    title: "Identified opportunity",
                    value: opportunityBytes > 0 ? formattedBytes(opportunityBytes) : "All reviewed",
                    caption: "Estimated size of items selected for cleanup.",
                    tint: .questAmber
                )
                hairline
                measurementRow(
                    title: "Pending deletion",
                    value: formattedBytes(pendingDeletionBytes),
                    caption: "Items moved into Recently Deleted, still potentially occupying storage.",
                    tint: .videoSapphire
                )
                hairline
                measurementRow(
                    title: "Actually reclaimed",
                    value: reclaimValue,
                    caption: "Confirmed reduction in device storage, measured separately.",
                    tint: .gemEmerald
                )
            }
            .padding(14)
            .background(DungeonPanelBackground())
        }
    }
```

Then replace the whole `measurementRow` function (keep its doc comment) with a row that puts the value on the right:

```swift
    private func measurementRow(title: String, value: String, caption: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(title.uppercased())
                        .font(.dungeonCaption.weight(.bold))
                        .foregroundStyle(.textSecondary)
                }
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
```

The three titles and captions are the current ones, word for word. The photo and video counts moved into the ledger's header and the streak moves into the hero banner, so the row of three `StatTile`s is gone from this screen.

- [ ] **Step 3: Replace the hero strip with a banner**

Replace the whole `heroStrip` property (from `private var heroStrip: some View {` through its closing brace) with:

```swift
    private var heroStrip: some View {
        Group {
            if let hero {
                HStack(alignment: .center, spacing: 8) {
                    HeroStageView(hero: hero, equipped: equippedItems, height: 84, accent: hero.race.accent)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(hero.name)
                                .font(.dungeonHeader)
                                .foregroundStyle(.textPrimary)
                                .lineLimit(1)
                            LevelChip(level: hero.level)
                        }
                        Text("\(hero.race.displayName) · \(hero.heroClass.displayName)")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                        XPBarView(progress: hero.levelProgress, level: hero.level, compact: true)
                        HStack(spacing: 8) {
                            GemCounterView(count: hero.gems)
                            StreakChip(days: hero.streakDays)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DungeonPanelBackground(cornerRadius: DungeonRadius.hero, accent: hero.race.accent))
            }
        }
    }
```

- [ ] **Step 4: Make the two secondary actions fit side by side and sit quieter**

In `focusedDiveMenu`, replace its label:

```swift
            Label("Focused Dive", systemImage: "scope")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                )
                .foregroundStyle(.textPrimary)
```

with:

```swift
            Label("Focused Dive", systemImage: "scope")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DungeonPanelBackground())
                .foregroundStyle(.textPrimary)
```

In `pickedHuntPicker`, replace its label:

```swift
            Label("Hunt Chosen Monsters", systemImage: "hand.raised.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                )
                .foregroundStyle(.textPrimary)
```

with:

```swift
            Label("Hunt Chosen", systemImage: "hand.raised.fill")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DungeonPanelBackground())
                .foregroundStyle(.textPrimary)
```

Leave both `.accessibilityLabel(…)` lines and all of the logic below them untouched.

- [ ] **Step 5: The next-dive strip uses the panel surface**

In `themeStrip`, replace:

```swift
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone.opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.tintColor.opacity(0.35), lineWidth: 1))
            )
```

with:

```swift
            .background(DungeonPanelBackground(accent: theme.tintColor))
```

- [ ] **Step 6: Redraw the quest row**

Replace the whole `private struct QuestRow: View { … }` at the bottom of the file with:

```swift
private struct QuestRow: View {
    let quest: Quest

    /// What the quest asks for, as a glyph.
    private var icon: String {
        switch quest.kind {
        case .photoSlay: return "photo.fill"
        case .videoSlay: return "video.fill"
        case .mbFreed:   return "internaldrive.fill"
        case .anySlay:   return "shield.lefthalf.filled"
        }
    }

    private var tint: Color { quest.completed ? Color.gemEmerald : Color.questAmber }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: quest.completed ? "checkmark.seal.fill" : icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: DungeonRadius.chip, style: .continuous).fill(Color.dungeonStoneLight))
                .overlay(RoundedRectangle(cornerRadius: DungeonRadius.chip, style: .continuous).strokeBorder(tint.opacity(0.45), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(quest.title)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(quest.completed ? .gemEmerald : .textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(quest.currentCount) / \(quest.targetCount)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.textSecondary)
                }
                Text(quest.subtitle)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                DungeonProgressBar(value: quest.progressFraction, tint: tint, height: 6)
                HStack(spacing: 10) {
                    Label("+\(quest.rewardGems)", systemImage: "diamond.fill")
                        .foregroundStyle(.gemEmerald)
                    Text("+\(quest.rewardXP) XP")
                        .foregroundStyle(.questAmber)
                }
                .font(.caption2.monospacedDigit().weight(.bold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPanelBackground(accent: quest.completed ? Color.gemEmerald : nil))
    }
}
```

- [ ] **Step 7: Update the file's header comment**

At the top of `DashboardView.swift`, replace:

```swift
//  Storage-first. The Library overview (recoverable space, media counts) leads;
//  the hero strip and daily quests follow as framed dungeon panels.
```

with:

```swift
//  Storage-first. A compact storage ledger leads, then the hero on its stage and the one primary
//  action, Enter the Dungeon, all above the fold. The two optional ways in sit beside each other
//  under it; the next dive and the daily quests follow.
```

- [ ] **Step 8: Keep the screenshot tour able to find the button, and wait for a card**

"Enter the Dungeon" is now near the top, and the tour scrolls down before looking for it. In `ios/PurgeQuestUITests/AppearanceTourUITests.swift`, in `tourMainTabs`, replace:

```swift
        // A combat room: the simulator's sample photos, or the empty state without any.
        let enter = app.buttons["Enter the dungeon and start a cleanup session"]
        if enter.waitForExistence(timeout: 5) {
            enter.tap()
            dismissPhotoPrompt()
            settle(3.0)
            shot("\(mode)-11-combat")
```

with:

```swift
        // Back to the top: Enter the Dungeon sits just under the hero.
        app.swipeDown()
        settle(0.5)

        // A combat room: the simulator's photos, or the empty state without any.
        let enter = app.buttons["Enter the dungeon and start a cleanup session"]
        if enter.waitForExistence(timeout: 5) {
            enter.tap()
            dismissPhotoPrompt()
            // With photos in the library the room takes a while to scan. Wait for whichever arrives,
            // a card's way out or the empty state, then let the screen settle.
            let cardReady = app.buttons["Exit dungeon"]
            let emptyReady = app.buttons["Back to Library"]
            let deadline = Date().addingTimeInterval(45)
            while Date() < deadline, !cardReady.exists, !emptyReady.exists { settle(1.0) }
            settle(3.0)
            shot("\(mode)-11-combat")
```

Leave the lines after `shot(…)` as they are.

- [ ] **Step 9: Commit and push**

```bash
python3 -I tools/ci/repo_guard.py | tail -1
git add ios/PurgeQuest/Views/Dashboard/DashboardView.swift ios/PurgeQuestUITests/AppearanceTourUITests.swift
git commit -m "Recompose the Library screen around the hero and the one primary action

Enter the Dungeon sat below a 300 pt storage card, three stat tiles, the
hero strip, the next-dive strip and four quests. Storage still leads, as a
ledger half the height: the same three measurements with the same titles
and captions, the value set to the right of each. Under it the hero stands
on a stage with level, XP, gems and streak, then Enter the Dungeon, then
the two optional ways in side by side. All of that is above the fold.

Quests get an icon for what they ask, the capsule progress bar and a seal
when done. The screenshot tour scrolls back up before it looks for the
button, and waits for a card instead of a fixed three seconds.


<attribution lines>"
git push -u origin claude/optimistic-brahmagupta-9mbyay
```

- [ ] **Step 10: Pass the CI gate and look**

View (shrunk): `tour-dark-10-library.png`, `tour-light-10-library.png`, `tour-dark-12-library-scrolled.png`, `tour-verdigris-dark-10-library.png`, `tour-newart-dark-10-library-event.png`, `tour-dark-11-combat.png`.

**Looks right when:**
- In `10-library`, without scrolling, you can see in this order: the title "Library" in engraved capitals, the storage ledger, the hero on a pedestal with name, level chip, XP bar, gems and streak, the gold **Enter the Dungeon** button, and the two quieter buttons side by side.
- No text in the ledger is cut off with an ellipsis. Values such as "All reviewed" and "Not yet verified" are on one line at the right.
- The hero in the banner is clearly a figure (about a fifth of the banner's width), standing on the ellipse, not floating above it and not overlapping the text column.
- Both secondary buttons show their full labels on one line.
- In `12-library-scrolled`, each quest shows an icon tile, its title and count on one line, a capsule progress bar and its rewards.
- `11-combat` shows a photo on a card (the simulator library is filled by the workflow), not the "All clear" state. If it still shows "All clear", the photos did not arrive: read the `tour` job's log for the `addmedia` step and report it; do not change app code to work around it.

**If a point fails:**
- Ledger value truncated: in `measurementRow` change `.font(.title3.weight(.bold).monospacedDigit())` to `.font(.headline.weight(.bold).monospacedDigit())`.
- Hero overlaps the text column: in `heroStrip` lower `height: 84` to `72`.
- The primary button is not visible without scrolling on the screenshot: lower the hero `height` to `72` and the ledger's `.padding(.vertical, 9)` to `7`.

Commit an adjustment as `Tune the Library layout: <what>` and repeat the gate.

---

### Task 6: An even Trophies grid

**Files:**
- Modify: `ios/PurgeQuest/Views/Achievements/AchievementsView.swift`

**Interfaces:**
- Consumes: `DungeonPanelBackground`, `DungeonProgressBar` (Task 3). Existing: `Achievement.isUnlocked`, `.iconName`, `.title`, `.subtitle`, `.progress`, `.goal`.

- [ ] **Step 1: Redraw the card**

Replace the whole `private struct AchievementCard: View { … }` with:

```swift
private struct AchievementCard: View {
    let achievement: Achievement

    private var fraction: Double {
        min(Double(achievement.progress) / Double(max(1, achievement.goal)), 1.0)
    }

    private var tint: Color { achievement.isUnlocked ? Color.questAmber : Color.textSecondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: achievement.isUnlocked ? "medal.fill" : achievement.iconName)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(achievement.isUnlocked ? Color.questAmber.opacity(0.14) : Color.dungeonStoneLight)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(achievement.isUnlocked ? Color.questAmber.opacity(0.5) : Color.dungeonAsh, lineWidth: 1)
                )

            Text(achievement.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            // Two lines are always reserved, so every card in a row is the same height.
            Text(achievement.subtitle)
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            DungeonProgressBar(
                value: fraction,
                tint: achievement.isUnlocked ? Color.gemEmerald : Color.questAmber,
                height: 6
            )
            Text("\(min(achievement.progress, achievement.goal)) / \(achievement.goal)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPanelBackground(accent: achievement.isUnlocked ? Color.questAmber : nil))
        .opacity(achievement.isUnlocked ? 1.0 : 0.9)
    }
}
```

- [ ] **Step 2: The header's trophy tile uses the panel surface**

In the `header` property of `AchievementsView`, replace:

```swift
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.6), lineWidth: 1))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(2))
                )
```

with:

```swift
                .background(DungeonPanelBackground(accent: .questAmber))
```

- [ ] **Step 3: Commit and push**

```bash
python3 -I tools/ci/repo_guard.py | tail -1
git add ios/PurgeQuest/Views/Achievements/AchievementsView.swift
git commit -m "Even out the Trophies grid

Cards differed in height because a subtitle wrapped to one line or two,
which left the two columns ragged. Two lines are now always reserved. The
cards take the panel surface and the capsule progress bar, and an unlocked
trophy is marked by a gold border on the same surface, not a different
opacity.


<attribution lines>"
git push -u origin claude/optimistic-brahmagupta-9mbyay
```

- [ ] **Step 4: Pass the CI gate and look**

View (shrunk): `tour-dark-30-trophies.png`, `tour-light-30-trophies.png`, `tour-dark-31-settings.png`.

**Looks right when:**
- In `30-trophies`, the two cards in each row have the same height and their tops and bottoms line up across the row.
- Every card has a capsule progress bar, not the thin system line.
- In `31-settings`, the stat tiles have the soft shadow and top sheen from Task 3 and are otherwise unchanged.

---

### Task 7: Write down the rules

**Files:**
- Create: `docs/design/DESIGN_SYSTEM.md`
- Modify: `README.md`

- [ ] **Step 1: Create the design reference**

Create `docs/design/DESIGN_SYSTEM.md`:

```markdown
# PurgeQuest design system

How the app is meant to look, and the shared pieces that make it so. Colors and their contrast are
defined and tested in `ios/PurgeQuest/Models/ThemePalette.swift`; this file is about composition.

## Direction

A torchlit vault. A charcoal (or parchment) canvas, engraved Cinzel capitals for titles, and the
brand gold used sparingly as the one thing that glows. Depth comes from light, not color: a faint
sheen along a panel's top edge and a low shadow under it.

## Rules

1. **The hero is the subject.** Size the figure, not its canvas: `HeroSpriteView(framing: .body)`
   or `HeroStageView`. A hero should never be a small sprite in a large empty frame.
2. **One primary action per screen, above the fold, on the gold plate** (`.buttonStyle(.gold(…))`).
   Everything else is a quiet panel button.
3. **One panel surface.** `.background(DungeonPanelBackground())`. Pass `accent:` when the panel
   belongs to something (a race, a finished quest, an unlocked trophy); it tints the border only.
   Do not hand-roll `RoundedRectangle().fill(Color.dungeonStone)`.
4. **Three corner radii**: `DungeonRadius.chip` (8), `.card` (12), `.hero` (16, at most one per
   screen). Continuous corners.
5. **One progress bar**: `DungeonProgressBar`. Not `ProgressView`.
6. **Numbers are the reward.** Bold, monospaced digits, larger than their label. Labels are small
   capitals in `.dungeonCaption`; explanations are `.caption2` in the secondary text color.
7. **Wording that says what is measured stays.** The storage ledger's titles and captions separate
   an estimate from a measurement; restyle them, never shorten them.
8. **Motion is a spring when a value changes**, and nothing else. No loops, no drifting, no pulses.
9. **No new hues.** Use the tokens in `Color+Theme.swift`. No neon, pastel or purple. White and
   black appear only at low opacity, as sheen and shadow.
10. **Check all four looks**: Light and Dark, Classic and Verdigris.

## Seeing a change

Open a pull request that touches `ios/PurgeQuest/`. The "UI snapshots" workflow builds the app,
fills the simulator's library with synthetic pictures (`tools/ci/make_library_fixtures.py`) and
uploads every screen of the Light/Dark tour as the artifact `ui-snapshots-tour`, in about fifteen
minutes.

## Not yet brought into line

- The combat card and the Room Summary: now visible in the tour's `11-combat` screenshot, not yet
  redesigned.
- Armory tiles and the Forge's small previews still size the canvas, so the hero is small there.
- Trophies and Settings use the system navigation title; Library, Bestiary and Armory use Cinzel.
- Shop, Forge, Onboarding, Settings and Combat still hand-roll some panel backgrounds.
```

- [ ] **Step 2: Point the README at it**

In `README.md`, in the "Asset Organization" section, find the sentence that ends `the palette lives in \`Extensions/Color+Theme.swift\`.` and add directly after it, on the same line:

```
 Composition rules and the shared surface, bar and hero-stage components are in [`docs/design/DESIGN_SYSTEM.md`](docs/design/DESIGN_SYSTEM.md).
```

- [ ] **Step 3: Final checks, commit, push**

```bash
python3 -I tools/ci/repo_guard.py | tail -1
tools/swift_harness/run.sh 2>&1 | grep -E "✘|error:|Test run with"
git add docs/design/DESIGN_SYSTEM.md README.md
git commit -m "Write down the design rules the UI upgrade established


<attribution lines>"
git push -u origin claude/optimistic-brahmagupta-9mbyay
```

Expected: `repo_guard ok …` and `✔ Test run with 267 tests in 19 suites passed`.

- [ ] **Step 4: Final gate**

Wait for **all** of the pull request's checks, including `unit-tests` (about 35 minutes; it runs the unit tests, the Forge UI tests and the onboarding regression test). All must be green. If `unit-tests` fails, read its log as in "The CI gate", step 4, and fix the cause; a failing test is never skipped or edited to pass.

- [ ] **Step 5: Report**

Update the pull request's description with: what changed per task, the before/after in one line each, and the names of the screenshots that show it. Then report back with:
1. the commits made, one line each;
2. for every "Looks right when" list, each point and whether the screenshot met it, naming the file you looked at;
3. any number you tuned, and from what to what;
4. anything in the screenshots that looks wrong and is outside this plan (describe it; do not fix it);
5. what `tour-dark-11-combat.png` and `tour-light-11-combat.png` show, described plainly, since the combat card is the next screen to design.

---

## Out of scope (do not start these)

- Redesigning the combat card, the duplicate group card or the Room Summary. They are the core loop and need to be seen first; this plan makes them visible in CI and stops.
- Armory tiles, Forge previews, Onboarding and Settings beyond what the shared components change on their own.
- Replacing hand-rolled panel backgrounds in files this plan does not name.
- Navigation-bar title fonts.
- Any change to colors in `ThemePalette.swift`, to the widget, or to app behavior.

## Self-review notes (for the plan's author; the executor can skip)

- Every type used in a later task is produced by an earlier one: `NormalizedRect`/`SpriteBodyBounds` (1) → `SpriteBodyFraming`, `HeroSpriteView.Framing` (2) → `HeroStageView` (4) → Library banner (5); `DungeonPanelBackground`, `DungeonRadius`, `DungeonProgressBar`, `LevelChip`, `StreakChip` (3) → 4, 5, 6.
- Strings that UI tests match are unchanged: the Enter button and its accessibility label, the Hero tab's race/class/level line, the Forge button's accessibility label.
- Harness count after Task 1: 262 + 5 tests, 18 + 1 suites.

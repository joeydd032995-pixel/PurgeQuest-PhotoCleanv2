# Core ML Swap Pattern (protocol first)

This is an illustrative future design, not an interface currently present in PurgeQuest. The current `MonsterClassifier` is a static enum, and signal extraction lives in separate services. Introduce an abstraction only if it helps the actual model integration.

```swift
protocol PhotoClassifier: Sendable {
    func classify(_ item: MediaItem, image: UIImage?) async -> MonsterType
}

struct HeuristicPhotoClassifier: PhotoClassifier { ... }

struct CoreMLPhotoClassifier: PhotoClassifier {
    let model: BlurClassifier   // auto-generated from .mlmodel
    func classify(...) async -> MonsterType { ... }
}

enum ClassifierFactory {
    static func make() -> any PhotoClassifier {
        if let ml = try? CoreMLPhotoClassifier() { return ml }
        return HeuristicPhotoClassifier()
    }
}
```

With this proposed design, call sites could use a factory or injected protocol existential; no such factory currently exists in the repository.

# Detection benchmark

Measures the duplicate finder and the blur and dark rules on real photographs, using the app's own
Swift sources (`ios/PurgeQuest/Services/DuplicateDetection.swift`, `ThumbnailAnalysis.swift`). It never
reimplements the engine: `run.sh` links those files into a throwaway package and runs them.

Development machine only. It is not part of CI and the photos are not in the repository.

## Run it

Needs a Swift 6.2+ toolchain (Linux or macOS), Python 3 with Pillow and NumPy.

```bash
# 1. Real photographs with ground truth. INRIA CopyDays: 157 originals (GGGG00.jpg) and 229 strongly
#    edited copies (GGGGVV.jpg, same GGGG = same scene). Research use; do not commit the images.
mkdir -p /tmp/bench/orig /tmp/bench/copies
curl -L https://dl.fbaipublicfiles.com/vissl/datasets/copydays_original.tar.gz | tar xz -C /tmp/bench/orig
curl -L https://dl.fbaipublicfiles.com/vissl/datasets/copydays_strong.tar.gz  | tar xz -C /tmp/bench/copies

# 2. Turn them into the grayscale grids the app derives from its thumbnail (about a minute).
#    -I keeps Python from importing anything out of the data folders.
python3 -I tools/detection_bench/prepare.py --originals /tmp/bench/orig --copies /tmp/bench/copies --out /tmp/bench/data

# 3. Run the app's rules over them.
SWIFT_BIN=/path/to/swift tools/detection_bench/run.sh /tmp/bench/data            # everything
SWIFT_BIN=/path/to/swift tools/detection_bench/run.sh /tmp/bench/data dedupe     # or: quality, scaling
```

`prepare.py` adds samples derived from each original: Gaussian blur (σ 1.5 to 8 px at 600 px scale),
horizontal motion blur (15 and 31 px), underexposure (0.04, 0.08 and 0.15 of linear light), a brightened
copy, a messenger-style re-save (1600 px, JPEG 70) and a 92% centre crop. The last three, with the
CopyDays copies, are the "same picture" edits; the others test the blur and dark rules.

## What it reports

- **Duplicates**: how far apart the dHash puts different scenes and same-scene edits; then precision and
  recall of `findClusters` over the whole set and over random 150-asset batches (the size of a dive),
  with and without the luminance signature, and how often each kind of edit is found with its original.
- **Quality**: the shipped rule against the current one for blur and for dark, on sharp originals (false
  positives) and on degraded copies (hits).
- **Cost**: the engine at 150 to 20,000 assets, and `ThumbnailAnalysis.metrics` per photo.

## What it approximates, and what it cannot tell you

- The app asks PhotoKit for a 600 px thumbnail and renders it with CoreGraphics. Here Pillow scales to a
  600 px short side and area-averages to each grid. CoreGraphics interpolates a little differently, so
  absolute numbers are estimates; comparing two versions of the engine on the same data is exact.
- CopyDays is 157 scenes. It has no burst sequences, no screenshots, no night photography and few look-alike
  scenes. A threshold that looks safe here still needs measuring on a real library before it is tightened.
- Blur and darkness are synthetic degradations of sharp, well-exposed photographs, which is the usual
  stand-in for hand-labelled data but is not the same thing. Real camera shake and defocus differ.
- Nothing here measures scan *time* in the app (PhotoKit, Vision and AVFoundation are not available off
  Apple platforms), only the engine and the metric computation.
- It measures each photo rule on its own. Which rule gets to a photo first is the classifier's business
  (`MonsterClassifier`: a defect is named before age, so an old blurry photo is a Blur Beast, not an
  Ancient Archive); changing that order changes which photos reach a rule, not the figures here.
- There are no videos. The video rules (`VideoFrameSignals`: motionless, flicker, dark, the brightness
  jump behind the Shaky Ghost) have never been run against real footage. The motionless rule compares
  sampled frames cell by cell; its threshold was carried over from the brightness-only rule it replaced,
  which it can only be stricter than, and has not been tuned.

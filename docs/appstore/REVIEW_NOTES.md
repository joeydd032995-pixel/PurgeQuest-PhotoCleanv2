# App Review notes

Paste the block below into the Notes field. It is written for a reviewer who has a minute.

---

**What the app does.** PurgeQuest is a photo-library cleanup tool presented as a dungeon game. Photos and videos from the user's library appear as monsters on cards. Swiping left marks an item for deletion; swiping right keeps it.

**Nothing is deleted without two confirmations.** Swiping only marks an item. At the end of each room of 20, a Room Summary lists every marked item and lets the user un-mark any of them. Confirming there calls `PHAssetChangeRequest.deleteAssets`, which shows the system's own "Allow PurgeQuest to delete N items?" dialog. If the user declines either one, nothing is deleted.

**Deleted items are recoverable.** The app uses only the Photos framework's delete request, so items go to Photos > Recently Deleted for 30 days. The app has no other way to remove media and never deletes permanently. Settings shows the last seven days of deletions.

**No account, no network.** There is no sign-in. The app makes no network requests and contains no third-party SDK, analytics or advertising. All analysis (blur, darkness, duplicates, text and barcode detection) runs on the device with Apple frameworks. Photos may fetch an iCloud original when a thumbnail is requested; that is the system, not the app.

**Photo access.** The app asks for read/write library access because it both reads items and requests their deletion. It works with Limited access, showing only the selected items. The app never saves or adds anything to the library.

**Purchases.** Three consumable gem packs and three non-consumable cosmetic unlocks. All are cosmetic: every game mode and all cleanup functionality is free. Each purchase gives a named item or a fixed number of gems, never a random reward. Restore is at the top right of the Armory tab.

**How to test quickly.**
1. Launch, pass onboarding, allow photo access.
2. Tap "Enter the Dungeon" on the Library tab.
3. Swipe the room's cards, some left and some right. The Room Summary appears after the last card of the room (20 at most; fewer in a small library).
4. Tap an item in the summary to un-mark it, then confirm. Accept the system dialog.
5. Open Photos > Recently Deleted to see the items.

**Widgets.** Home Screen (Daily Quest, Streak) and two Lock Screen widgets show the hero's level, streak, gems and the current quest. They read a small snapshot from the App Group and show no photos.

---

## Before pasting, check these against the build you submit

- The tab and button names quoted above (Library, Enter the Dungeon, Armory, Restore): they were read from the source at the time of writing.
- If Live Activities are added before submission, add a line for them; as the code stands there are none, and the notes above correctly do not mention any.

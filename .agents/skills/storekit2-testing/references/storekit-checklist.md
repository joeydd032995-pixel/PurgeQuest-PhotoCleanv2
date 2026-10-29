# StoreKit 2 Local Testing Checklist

1. Open the Xcode scheme > Run > Options > StoreKit Configuration and select Configuration.storekit.
2. Confirm every Product ID in code exists in the .storekit file with the same type.
3. Launch the app, trigger a purchase, complete it in the system sheet.
4. Verify gems or ownership appear immediately and survive app restart.
5. Test Restore Purchases for non-consumables.
6. Cancel a purchase and confirm no grant occurred.
7. Kill and relaunch to ensure Transaction.updates still finishes any unfinished work.

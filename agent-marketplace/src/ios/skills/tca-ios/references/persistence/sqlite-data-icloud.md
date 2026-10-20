# Applies to: TCA 1.25+, iOS 16+

# SQLiteData iCloud

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [Project Setup](#project-setup)
- [Bootstrap](#bootstrap)
- [Share Acceptance](#share-acceptance)
- [Sharing Records](#sharing-records)
- [Metadata And Permissions](#metadata-and-permissions)
- [Pitfalls](#pitfalls)
- [Common Errors](#common-errors)
- [Tests](#tests)

## Use When

Use this for CloudKit sync, share acceptance, SyncEngine setup, iCloud entitlements, and sync metadata queries.

## Guidance

- Add iCloud/CloudKit entitlements additively.
- Add remote notification background mode when the app has an Info.plist.
- Configure `SyncEngine` during database bootstrap and set `defaultSyncEngine`.
- Use `startsImmediately: false` when sync is gated by account, purchase, or settings.
- Use `privateTables` for tables that should not travel with a shared root record.
- Add scene/app delegate handling for `CKShare.Metadata` acceptance.
- Attach the metadatabase in `prepareDatabase` when the app queries sync metadata.
- Import `CloudKit` anywhere that touches CloudKit share metadata or `CKShare`.
- Treat iCloud behavior as a real-device concern. Local validation can check build wiring, but CloudKit account and entitlement behavior needs a signed app.

## Project Setup

Entitlements should include CloudKit and the container:

```plist
<key>aps-environment</key>
<string>development</string>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
  <string>iCloud.com.example.MyApp</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
  <string>CloudKit</string>
</array>
```

If the app has an `Info.plist`, add remote notifications and sharing support when needed:

```plist
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
<key>CKSharingSupported</key>
<true/>
```

## Bootstrap

```swift
extension DependencyValues {
  mutating func bootstrapDatabase() throws {
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      try db.attachMetadatabase()
      db.add(function: $uuid)
    }

    let database = try SQLiteData.defaultDatabase(configuration: configuration)
    var migrator = DatabaseMigrator()
    try migrator.migrate(database)

    defaultDatabase = database
    defaultSyncEngine = try SyncEngine(
      for: database,
      tables: RemindersList.self, Reminder.self,
      startsImmediately: false
    )
  }
}
```

Pass `privateTables:` when the schema has tables that should remain device-private during record sharing.

## Share Acceptance

The app or scene delegate should handle both launch-time and already-running share acceptance, then call the sync engine from an async context:

```swift
import CloudKit
import Dependencies
import SQLiteData
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  @Dependency(\.defaultSyncEngine) var syncEngine

  func windowScene(
    _ windowScene: UIWindowScene,
    userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
  ) {
    Task { try await syncEngine.acceptShare(metadata: metadata) }
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
    Task { try await syncEngine.acceptShare(metadata: metadata) }
  }
}
```

## Sharing Records

Only root records can be shared. Associated rows are included when they have a single foreign key and are not listed in `privateTables`.

```swift
@Dependency(\.defaultSyncEngine) var syncEngine
@State private var sharedRecord: SharedRecord?

Button("Share") {
  Task {
    sharedRecord = try await syncEngine.share(record: remindersList) { share in
      share[CKShare.SystemFieldKey.title] = remindersList.title
    }
  }
}
.sheet(item: $sharedRecord) { sharedRecord in
  CloudSharingView(sharedRecord: sharedRecord)
}
```

## Metadata And Permissions

Attach the metadatabase before querying `SyncMetadata`. Use sync metadata to hide editing controls for read-only participants before a write fails:

```swift
let share = try await database.read { db in
  SyncMetadata
    .find(remindersList.syncMetadataID)
    .select(\.share)
    .fetchOne(db) ?? nil
}

let canWrite =
  share?.currentUserParticipant?.permission == .readWrite
  || share?.publicPermission == .readWrite
```

Still catch write-permission errors. Permissions can change after the read.

## Pitfalls

- Compound primary keys and unique indexes can conflict with sync support.
- Avoid CloudKit-reserved field names for synced columns.
- Do not start sync before migrations and database assignment are complete.
- Do not share child records directly. Share the root record.
- Do not forget `CKSharingSupported`; accepted shares can fail with an App Store version error when the key is absent.
- Do not query `SyncMetadata` before `attachMetadatabase()`.

## Common Errors

- `BadContainer`: the CloudKit container may not be ready, or the entitlement container string is wrong.
- `Not Authenticated` or `AccountUnavailableDueToBadAuthToken`: the simulator or device needs a valid iCloud login.
- `no such table: sqlitedata_icloud_metadata`: attach the metadatabase in `prepareDatabase`.
- `SyncEngine.writePermissionError`: the user does not have permission to write the shared record.

## Tests

Validate entitlements keys, Info.plist keys, `SyncEngine` bootstrap, scene delegate entry points, metadata queries, and permission error handling. Run signed-device checks for real CloudKit sync and share acceptance.

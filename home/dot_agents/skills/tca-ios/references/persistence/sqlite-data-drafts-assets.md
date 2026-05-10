# Applies to: TCA 1.25+, iOS 16+

# SQLiteData Drafts and Assets

## Use When

Use this for create/edit forms, draft rows, asset fields, images, blobs, and file-backed record data.

## Guidance

- Use draft types for primary-keyed create flows where the database should assign values.
- Use the same draft type for create and edit forms when the table has a primary key.
- Keep unsaved form edits in reducer state until save.
- Persist large binary assets through the app's chosen asset strategy, not as accidental large state.
- Store large asset blobs in a separate table or external file store when the parent table is high traffic.
- Store stable asset references in rows when the asset body lives outside SQLite.
- Validate drafts before writing.

## Draft Pattern

```swift
@Reducer
struct EditReminder {
  @ObservableState
  struct State: Equatable {
    var draft: Reminder.Draft
    var isSaving = false
  }

  enum Action {
    case saveButtonTapped
    case saveResponse(Result<Reminder.ID, Error>)
  }

  @Dependency(\.defaultDatabase) var database

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .saveButtonTapped:
        state.isSaving = true
        let draft = state.draft
        return .run { [database, draft] send in
          await send(.saveResponse(Result {
            try await database.write { db in
              try Reminder
                .upsert { draft }
                .returning(\.id)
                .fetchOne(db)!
            }
          }))
        }

      case .saveResponse:
        state.isSaving = false
        return .none
      }
    }
  }
}
```

Drafts with `id == nil` are not stable identities. Do not use them as `Identifiable` rows in SwiftUI lists.

## Asset Shape

```swift
@Table
struct RemindersListAsset: Identifiable {
  @Column(primaryKey: true)
  var remindersListID: RemindersList.ID

  var coverImageData: Data
  var id: RemindersList.ID { remindersListID }
}
```

Use a separate table when asset reads are less frequent than row reads, or when the asset can grow large.

## Pitfalls

- Do not upsert half-valid drafts.
- Do not keep large image/blob data in long-lived reducer state unless the product requires it.
- Do not let form state and database rows drift after save; reload or update the source of truth.
- Do not share preview-only image data with tests.
- Do not store user-generated assets in `UserDefaults`.

## Tests

Test validation failure, successful draft insert, edit save, and generated ID handling. For assets, assert both the table row and the external storage effect when assets live outside SQLite.

# Applies to: TCA 1.25+, iOS 16+

# Xcode and SPM Integration

## Use When

Use this when adding a local Swift package to an existing Xcode project/workspace or linking package products into app targets.

## Guidance

- Open the workspace when the app has one; do not edit the project in isolation if the workspace owns integration.
- Add local package references through the project/workspace structure the repo already uses.
- Link package products to the app target and relevant test targets.
- Keep generated project tools such as Tuist or XcodeGen as source of truth when present.
- If there is no workspace and the repo uses an `.xcodeproj`, create or update a workspace only when the project needs to coexist with a local package.
- Prefer manifest-level edits for Tuist, XcodeGen, or other generators. Regenerate project files instead of hand-editing generated output.
- Link feature products to the app target. Link test-support products to test targets.
- Open the workspace after adding local packages; otherwise Xcode can miss package references.

## Workspace Shape

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
  <FileRef location="group:MyApp.xcodeproj">
  </FileRef>
  <FileRef location="group:MyAppPackage">
  </FileRef>
</Workspace>
```

## Target Linking Checklist

- App target imports feature package products such as `AppFeature`.
- Feature target imports `ComposableArchitecture`.
- Persistence target imports `SQLiteData` and `StructuredQueries` products it uses directly.
- Test target imports the feature product and `DependenciesTestSupport`.
- UI test target imports app test support only when the repo already uses that pattern.
- Generated project manifests record package products before `.xcodeproj` files are regenerated.

## Existing Xcode Project

When hand-editing project files is unavoidable, keep changes narrow:

1. Add the package reference.
2. Add the product dependency to the target that imports it.
3. Add framework build-phase entries only for those products.
4. Avoid user-specific Xcode files.

## Pitfalls

- Do not hand-edit generated Xcode project files when a manifest generator owns them.
- Do not add package products to every target.
- Do not commit user-specific Xcode state.
- Do not tell someone to open the `.xcodeproj` after creating a workspace.
- Do not add local packages in Xcode UI and forget to update the generator manifest.

## Tests

Run the app target build and one test target that imports the linked product. If a generator owns the project, run the generator first, then build the workspace.

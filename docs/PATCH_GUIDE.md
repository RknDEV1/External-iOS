# Patch workspace guide

3105 patch packages map Application and App Group identifiers to their current containers. They never store container UUIDs because those change across devices and reinstalls.

## Workspace layout

Creating a patch named `ABC` creates two editable mapping scopes:

```text
On My iPhone/
└── 3105/
    └── Patches/
        └── ABC/
            ├── settings.json
            ├── Application/
            │   ├── com.abc.xyz/
            │   │   └── Documents/
            │   │       └── config.json
            │   └── com.example.second/
            │       └── Library/
            │           └── config.plist
            └── AppGroup/
                └── group.com.example.shared/
                    └── Library/
                        └── ConfigurationProfiles/
                            └── SharedDeviceConfiguration.plist
```

Each folder immediately below `Application` is an app bundle identifier. Each folder immediately below `AppGroup` is an identifier beginning with `group.`. Everything below an identifier folder is relative to that container. One patch can map multiple identifiers in both scopes. Never use an App Group container UUID because it differs between devices.

`settings.json` lives at the workspace root and only declares fields that users can fill in. It is embedded in the `.3105` package; it is not a target file and does not create a separate `3105.plist` on the device.

## Create a patch

### Start from the Patch tab

1. Open **Patch**, tap **+**, then choose **New Patch**.
2. Enter a project name. Leave the password blank to create an unprotected package.
3. Tap **Done**. 3105 creates `settings.json`, `Application`, and `AppGroup` in its editable workspace.
4. Open **Files → 3105 Workspace → Patches → project name**.
5. Create identifier folders in the matching scope, then recreate each destination tree and place replacement files at their final relative paths.

For example, to replace `Library/Preferences/com.abc.xyz.plist`, place it at `Application/com.abc.xyz/Library/Preferences/com.abc.xyz.plist`. For App Group, use a path such as `AppGroup/group.com.example.shared/Library/Preferences/shared.plist`. To add a complete folder, copy it into the correct parent; every regular file below it becomes part of the patch. Return to the patch detail, tap **Synchronize Workspace**, then open each mapping to choose **Replace Entire File**, **Edit Plist Contents**, or **Edit JSON Contents**.

Older beta packages containing `SystemAppGroup/systemgroup.*` mappings remain readable so their active patches can still be restored. New patch workspaces do not expose that mapping type.

## Define user options with settings.json

Authors edit `settings.json` directly in the workspace. For example:

```json
{
  "schemaVersion": 1,
  "fields": [
    {
      "id": "display_name",
      "label": "Display name",
      "type": "string",
      "default": "3105",
      "multiline": false,
      "canRemove": true
    },
    {
      "id": "enabled",
      "label": "Enable feature",
      "type": "boolean",
      "default": true
    },
    {
      "id": "mode",
      "label": "Mode",
      "type": "string",
      "default": "compact",
      "options": [
        { "label": "Compact", "value": "compact" },
        { "label": "Large", "value": "large" }
      ]
    }
  ]
}
```

Supported types are `string`, `boolean`, `integer`, `double`, `date`, and `data`. For `data`, use `encoding: "utf8"` for textual bytes or `encoding: "base64"` for arbitrary binary data; Base64 is the default. Every `id` must be unique. `options` is optional and renders the field as a picker. Set `canRemove: true` to show a **Remove this field** toggle. When enabled, a key whose complete value is the matching placeholder is removed; disabling it retains and reuses the entered value. After synchronization, these fields appear in the installed patch detail. Values and removal selections are stored separately for each patch on the device.

## Add, edit, and remove plist or JSON contents

The payload remains an ordinary plist or JSON file at its final destination path; do not create a separate `3105.plist`. For plist files, prefix the **workspace filename** with `%3105_Overwrite%` to infer merge behavior automatically. For example:

```text
Application/com.locket.Locket/Library/Preferences/%3105_Overwrite%com.locket.Locket.plist
```

The prefix is stripped when packaging and applying, so the device target remains `Library/Preferences/com.locket.Locket.plist`. The prefixed name controls the operation and is never written to the device. Existing workspaces without the prefix retain the operation stored in their metadata.

For example, the `com.locket.Locket.plist` payload only contains the two fields to add:

```xml
<dict>
    <key>/subscription_local_trial_started_at</key>
    <date>2026-09-05T08:26:04Z</date>
    <key>/subscription_local_trial_ended_at</key>
    <date>2099-12-31T23:59:59Z</date>
</dict>
```

### Read and edit a key that differs by device

When part of a dictionary key is a device-specific ID, prepend `%3105_MatchPrefix%` to its stable prefix. 3105 matches exactly one key whose remaining part is one non-empty component without `/`, so child endpoints such as `/attributes` and `/offerings` are excluded.

For a Locket target, place the payload at:

```text
Application/com.locket.Locket/Library/Preferences/
%3105_Overwrite%com.locket.Locket.revenuecat.etags.plist
```

Declare the editable field in `settings.json`:

```json
{
  "schemaVersion": 1,
  "fields": [
    {
      "id": "subscriber_cache",
      "label": "Subscriber cache",
      "type": "data",
      "encoding": "utf8",
      "default": "",
      "multiline": true
    }
  ]
}
```

The plist payload contains only the selector and placeholder:

```xml
<dict>
    <key>%3105_MatchPrefix%https://api.revenuecat.com/v1/subscribers/</key>
    <string>{{subscriber_cache}}</string>
</dict>
```

Opening the installed patch makes 3105 read the real target plist, locate `https://api.revenuecat.com/v1/subscribers/&lt;device ID&gt;`, decode its UTF-8 `Data`, and show the current content in the input. Apply encodes the edited text back to `Data` and writes it to the same matched key. No file is written if the selector finds zero or multiple matches.

3105 stores the apply method in the encrypted `.3105` package metadata. On apply, new keys are added, matching keys are updated, nested Dictionaries/Objects are merged, and unrelated keys are preserved. Arrays and scalar values replace the corresponding complete value. Both the payload and target file must use a Dictionary/Object root.

Payloads may use:

- `{{display_name}}`: when the complete value is a placeholder, 3105 preserves the setting's data type, including Boolean, Integer, or Date. An inline placeholder such as `Hello {{display_name}}` always produces a String.
- If `display_name` declares `canRemove: true`, enabling **Remove this field** deletes the key whose whole value is `{{display_name}}`. Embedded placeholders and array elements cannot act as removal owners, so the patch fails closed.
- `%3105_Remove%`: use as a value to remove the matching key from the destination.
- `%3105_Overwrite%`: add this key inside a Dictionary/Object to discard that object's previous contents before inserting the remaining payload keys.

Example dynamic plist:

```xml
<dict>
    <key>DisplayName</key>
    <string>{{display_name}}</string>
    <key>Enabled</key>
    <string>{{enabled}}</string>
    <key>ObsoleteKey</key>
    <string>%3105_Remove%</string>
    <key>Appearance</key>
    <dict>
        <key>%3105_Overwrite%</key>
        <true/>
        <key>Mode</key>
        <string>{{mode}}</string>
    </dict>
</dict>
```

One patch can apply many plist and JSON mappings across multiple bundles in one transaction. If a bundle is unavailable on the device, its rules are skipped while mappings for available bundles still apply.

The merged result is written as deterministic XML so journal hashes and patch reset do not fail because of binary-plist key ordering. Restore still recovers the exact target bytes and encoding that existed before apply.

### Start from an app-container file or folder

1. Open **Files**, enter an app container, then find the target file or folder.
2. Touch and hold it, then choose **Create Patch**.
3. 3105 captures the stable bundle identifier and relative path automatically and opens a patch draft.
4. Save the draft, open its workspace, and replace or rearrange the captured content as needed.

## Apply and restore

- **Apply** synchronizes the workspace into the `.3105` package, validates user-entered values, resolves every Application/App Group mapping to its current container, and validates every destination path.
- Existing targets are backed up before any replacement is written. Missing targets are created.
- Writes are journaled and verified. If applying fails partway through, 3105 attempts to roll the transaction back.
- **Restore Originals** returns files that existed before Apply, deletes files introduced by the patch, and removes directories created by the patch after they become empty.
- Restore fails closed if the current target or recovery data no longer matches the recorded transaction, instead of overwriting an unverified file.

Keep related apps closed while applying or restoring a patch. Do not rename the two mapping scope folders or place identifiers in the wrong scope.

## Export, import, and passwords

- **Export** synchronizes the latest workspace contents before sharing the `.3105` file.
- Import from Files by opening or sharing a `.3105` package to 3105.
- A website may open the app with `threeoneosfive://import?url=<percent-encoded HTTPS URL>`. Only HTTPS package URLs without embedded credentials are accepted.
- On a new device or installation, a protected package asks for its password once. 3105 stores the unlocked content key in Keychain; the exported package remains encrypted and tied to its original password.
- Legacy v1–v5 packages remain supported and retain their original behavior. Schema v6 adds `settings.json`, typed placeholders, and JSON editing; v7 adds App Group mappings; v8 adds `canRemove` dynamic removal choices; v9 adds prefix key selectors and device-loaded `Data` values. Older apps safely reject newer schemas instead of misinterpreting their operations.

## Safety rules

- Use patches only with apps and data you own.
- Keep a separate backup of important app data.
- Symbolic links, absolute paths, `..` traversal, invalid bundle identifiers, and duplicate destinations are rejected.
- `settings.json` has field and size limits, and plist/JSON processing has depth and node limits so untrusted payloads cannot exhaust memory unchecked.
- Do not use input fields for passwords or important secrets. Values are stored locally for reuse, but this is not a secrets vault.
- Version 1.0.1 removes the old fixed payload-size and file-count ceiling, but available storage, memory, filesystem, and iOS limits still apply.
- Device-level access requires the supported iOS build and enterprise-signing setup documented in the README.

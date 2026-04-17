# Sparkle Auto-Update Setup

Clippy's auto-update flow: you build + notarize + staple the DMG yourself,
upload it to a GitHub Release, and GitHub Actions handles the Sparkle
signing + appcast update automatically. Users get the update on their next
24-hour check (or an instant one via Settings → General → **Check Now**).

## One-time setup

### 1. Add Sparkle to Xcode

1. Open `Clippy.xcodeproj`.
2. **File → Add Package Dependencies…**
3. Paste `https://github.com/sparkle-project/Sparkle.git`
4. Dependency Rule: **Up to Next Major Version** · `2.0.0`
5. Add `Sparkle` to the **Clippy** target.
6. Build once to confirm the framework links.

### 2. Generate the EdDSA keypair

The public key is baked into the app so Sparkle can verify each update.
The private key lives on your machine + GitHub as a secret.

```bash
/opt/homebrew/Caskroom/sparkle/*/bin/generate_keys
```

Output includes:

```
<key>SUPublicEDKey</key>
<string>BASE64_PUBLIC_KEY</string>
```

Open `Clippy/Info.plist`, locate `SUPublicEDKey`, and replace the placeholder
with this value. (For the first build it's already set from the initial
keypair — only redo this if you rotate the keys.)

### 3. Export the private key for GitHub Actions

```bash
/opt/homebrew/Caskroom/sparkle/*/bin/generate_keys -x private_key.pem
base64 -i private_key.pem | pbcopy
rm private_key.pem
```

The base64-encoded private key is now in your clipboard.

### 4. Store it as a GitHub secret

On GitHub: **Settings → Secrets and variables → Actions → New repository
secret**.

| Name                  | Value                                |
|-----------------------|--------------------------------------|
| `SPARKLE_PRIVATE_KEY` | Paste the base64 blob you copied.    |

That's the only secret the workflow needs. Everything else — Apple signing,
notarization, stapling — happens on your Mac during the release build.

## Per-release flow

Once setup is done, this is what shipping a new version looks like:

### 1. Build, notarize, staple (your existing flow)

On your Mac:

```bash
# 1. Bump the version in Xcode (Target → General → Version)
# 2. Archive
xcodebuild -project Clippy.xcodeproj -scheme Clippy -configuration Release \
    -archivePath build/Clippy.xcarchive archive

# 3. Export Developer ID–signed .app
xcodebuild -exportArchive -archivePath build/Clippy.xcarchive \
    -exportPath build/export -exportOptionsPlist ExportOptions.plist

# 4. Make the DMG (create-dmg or hdiutil — whichever you prefer)
create-dmg --volname "Clippy" build/Clippy-<version>.dmg build/export/Clippy.app

# 5. Notarize
xcrun notarytool submit build/Clippy-<version>.dmg \
    --apple-id <your-apple-id> --password <app-specific-password> \
    --team-id <team-id> --wait

# 6. Staple
xcrun stapler staple build/Clippy-<version>.dmg
```

### 2. Create a GitHub Release

1. Tag the commit: `git tag v<version> && git push origin v<version>`
2. On GitHub, **Releases → Draft a new release** (or edit the tag).
3. Attach the notarized DMG you just built.
4. Write release notes (or let GitHub auto-generate them).
5. **Publish release.**

### 3. GitHub Actions picks it up automatically

The `.github/workflows/release.yml` workflow fires on `release.published` and:

1. Downloads the DMG you attached.
2. Signs it with Sparkle's EdDSA private key (from the secret).
3. Prepends a new `<item>` to `docs/appcast.xml` with the version, release
   notes link, DMG URL, signature, and size.
4. Commits the updated appcast back to `main`.

Within ~24 hours (or on the next **Check Now**) every running Clippy sees
the update.

## Verifying an update before shipping

First time through or after big changes, walk through the full loop:

1. Install the **previous** release locally.
2. Cut a new release (dummy `v2.0.0-test` is fine — remove later).
3. Wait for the workflow to finish and commit the appcast.
4. In your installed Clippy: **Settings → General → Check Now**.
5. Expect the native Sparkle update dialog.
6. Click install; confirm the new version starts.

If the dialog never appears:

- `curl https://raw.githubusercontent.com/yarasaa/Clippy/main/docs/appcast.xml`
  returns the feed? (Should show your new `<item>` at the top.)
- The `sparkle:edSignature` in the feed is non-empty?
- Your running app has the matching `SUPublicEDKey` in Info.plist?
- Both the `.app` and the DMG were signed with the same Developer ID team?

## Rolling back a bad release

Edit `docs/appcast.xml` on `main`, delete the offending `<item>`, and push.
Anyone who hasn't updated yet will stop seeing the offer immediately; users
who already installed it aren't affected. Ship a `v2.0.1` fix fast.

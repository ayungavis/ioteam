# TestFlight CI Setup

This document explains how to set up the GitHub Actions workflow in this repo so anyone on the team can upload the iOS app to TestFlight.

## What the workflow already assumes

These values are already fixed in the repo:

- Xcode project: `app/IoTeam.xcodeproj`
- scheme: `IoTeam`
- bundle identifier: `com.ayungavis.IoTeamApp`
- Apple team ID: `QHL64K2LPL`

The workflow file is:

- `.github/workflows/ios-testflight.yml`

## What the workflow does

- On pull requests and non-`main` branches:
  - builds the app for simulator
  - does not sign
  - does not upload
- On pushes to `main`:
  - imports the signing certificate
  - downloads the provisioning profile
  - archives the app
  - exports the IPA
  - uploads the IPA to TestFlight

## Values you need to prepare

### GitHub Secrets

Add these under:

- GitHub repository
- `Settings`
- `Secrets and variables`
- `Actions`
- `Secrets`

Required secrets:

- `APPSTORE_CERTIFICATES_FILE_BASE64`
- `APPSTORE_CERTIFICATES_PASSWORD`
- `APPSTORE_API_PRIVATE_KEY`

### GitHub Variables

Add these under:

- GitHub repository
- `Settings`
- `Secrets and variables`
- `Actions`
- `Variables`

Required variables:

- `APPSTORE_ISSUER_ID`
- `APPSTORE_API_KEY_ID`

## How to get each value

### 1. `APPSTORE_API_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_API_PRIVATE_KEY`

These come from App Store Connect API access.

Steps:

1. Open [App Store Connect](https://appstoreconnect.apple.com/)
2. Go to `Users and Access`
3. Open the API key section
4. Create a new API key
5. Give it a name like `github-actions-testflight`
6. Give it a role with enough access
   - simplest first setup: `Admin`
7. Download the `.p8` file

Now map the values:

- Key ID shown in App Store Connect -> `APPSTORE_API_KEY_ID`
- Issuer ID shown in App Store Connect -> `APPSTORE_ISSUER_ID`
- Full contents of the downloaded `.p8` file -> `APPSTORE_API_PRIVATE_KEY`

Store `APPSTORE_API_PRIVATE_KEY` as the raw key text, for example:

```text
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

Do not base64 this `.p8` file for the current workflow.

## 2. `APPSTORE_CERTIFICATES_FILE_BASE64` and `APPSTORE_CERTIFICATES_PASSWORD`

These come from an exported Apple Distribution certificate in `.p12` format.

### 2a. Make sure you have an Apple Distribution certificate

Steps:

1. Open [Apple Developer](https://developer.apple.com/account/)
2. Go to `Certificates, Identifiers & Profiles`
3. Open `Certificates`
4. Check whether you already have a valid `Apple Distribution` certificate for team `QHL64K2LPL`

If you do not have one:

1. Create a new `Apple Distribution` certificate
2. Use a Certificate Signing Request from the Mac that will hold the private key
3. Download the generated certificate
4. Open it on that Mac so it is imported into Keychain Access

Important:

- the certificate must exist together with its private key
- without the private key, the CI export will not work

### 2b. Export the certificate as `.p12`

On the Mac that owns the private key:

1. Open `Keychain Access`
2. Find the `Apple Distribution` certificate
3. Expand it and confirm the private key is visible under it
4. Right-click the certificate
5. Choose `Export`
6. Save it as a `.p12` file
7. Set an export password

Now map the values:

- `.p12` file -> `APPSTORE_CERTIFICATES_FILE_BASE64`
- password you chose while exporting -> `APPSTORE_CERTIFICATES_PASSWORD`

### 2c. Convert the `.p12` to base64

On macOS:

```bash
base64 -i YourCertificate.p12
```

If you want to copy it directly:

```bash
base64 -i YourCertificate.p12 | pbcopy
```

Paste the full base64 output into:

- `APPSTORE_CERTIFICATES_FILE_BASE64`

## 3. Provisioning profile

The workflow downloads the provisioning profile automatically, but Apple still needs that profile to exist first.

Steps:

1. Open `Certificates, Identifiers & Profiles`
2. Go to `Identifiers`
3. Confirm the App ID exists for:
   - `com.ayungavis.IoTeamApp`
4. Go to `Profiles`
5. Create or confirm an `App Store` provisioning profile for:
   - `com.ayungavis.IoTeamApp`
6. Make sure the profile is tied to the same `Apple Distribution` certificate you exported

Important:

- for TestFlight upload, the profile type must be `App Store`
- a `Development` profile will not work for archive/export to TestFlight

No extra GitHub variable is needed for the provisioning profile in this workflow.

## Where to put the values in GitHub

### Secrets

Create:

- `APPSTORE_CERTIFICATES_FILE_BASE64`
- `APPSTORE_CERTIFICATES_PASSWORD`
- `APPSTORE_API_PRIVATE_KEY`

### Variables

Create:

- `APPSTORE_ISSUER_ID`
- `APPSTORE_API_KEY_ID`

The names must match the workflow exactly.

## Sanity checks before the first upload

Before pushing to `main`, confirm:

- the shared scheme exists at `app/IoTeam.xcodeproj/xcshareddata/xcschemes/IoTeam.xcscheme`
- the bundle identifier in Apple matches `com.ayungavis.IoTeamApp`
- the App Store Connect API key belongs to the same Apple organization you want to upload with
- the distribution certificate and provisioning profile belong to team `QHL64K2LPL`
- all GitHub secrets and variables use the exact names expected by the workflow

## Safe way to test it

### Test 1: build only

Push to any branch other than `main`.

Expected result:

- GitHub Actions runs the workflow
- the simulator build runs
- no signing step runs
- no TestFlight upload step runs

### Test 2: upload flow

Push to `main`.

Expected result:

- certificate import succeeds
- provisioning profile download succeeds
- archive succeeds
- IPA export succeeds
- TestFlight upload succeeds

## Common failure points

### Upload step fails immediately

Likely causes:

- wrong `APPSTORE_API_KEY_ID`
- wrong `APPSTORE_ISSUER_ID`
- invalid or incomplete `APPSTORE_API_PRIVATE_KEY`

### Certificate import succeeds but archive/export fails

Likely causes:

- `.p12` was exported without the private key
- wrong `APPSTORE_CERTIFICATES_PASSWORD`
- provisioning profile does not match `com.ayungavis.IoTeamApp`
- provisioning profile and certificate belong to a different Apple team
- the provisioning profile is `Development` instead of `App Store`

### Build works on PRs but upload fails on `main`

That usually means the unsigned build path is fine, but one of the signing or App Store Connect values is wrong.

## Rotation guide

If someone needs to rotate credentials later:

- rotate the App Store Connect API key -> update:
  - `APPSTORE_API_KEY_ID`
  - `APPSTORE_ISSUER_ID` only if Apple account context changed
  - `APPSTORE_API_PRIVATE_KEY`
- rotate the distribution certificate -> update:
  - `APPSTORE_CERTIFICATES_FILE_BASE64`
  - `APPSTORE_CERTIFICATES_PASSWORD`

You do not need to change the workflow unless the project path, scheme, bundle identifier, or trigger policy changes.

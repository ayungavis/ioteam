# Technical Report

This report explains how our initial assumptions changed after we explored the real project. It focuses on what we first expected, what we actually found in the iOS app, backend, and firmware, what alternatives we considered, and why our final technical direction fits the MVP we want to present.

## 1. Present your team

- Richard @richardsonjp
- Steven @stevenchan7
- Vincent @v1nccc
- Andi @sgtandi
- Wahyu @ayungavis

We present ourselves as one app team building a single product across three lanes: iOS app, backend service, and ESP32 firmware.

## 2. Starting Assumption

We think we'll end up using:

- SwiftUI for the iOS app
- Sign in with Apple for login
- APNS for reminders
- a small custom backend
- a custom ESP32 BLE + Wi-Fi onboarding path for the hardware
- Core Bluetooth for connecting the device to our app
- Matter or HomeKit only as later options, not as the MVP path

Because:

That looked like the obvious fit from the repo shape alone. The project is split into `app`, `backend`, and `controller`, which strongly suggests a native app, a custom service layer, and custom device firmware. The PRD also pointed in that direction before we dug into the actual implementation.

## 3. The Exploration Log

What we browsed, and what surprised us:

- We started from the root `README.md` and confirmed the repo is intentionally split into iOS app, backend service, and micro-controller code.
- We read `docs/prd.md` to understand the intended product before treating the code as the final source of truth.
- We checked the app imports and found real Apple-framework usage instead of placeholders: `AuthenticationServices` for Apple sign-in, `UserNotifications` for push, and `NetworkExtension` for provisioning-related work.
- We checked the backend and found Express + Sequelize, not a Swift server or a Firebase-style shortcut.
- We checked the firmware entrypoint and found a custom BLE GATT service, Wi-Fi credential handling, local storage, and reed-switch event publishing on the ESP32.
- One thing that surprised us was localization: there is already a `LocaleManager` and app-language selection state, but the visible product strings are still mostly hardcoded English text.
- Another surprise was that some UI still labels parts of the product as prototype or mocked, even though other parts of the repo are already wired to real endpoints.

What we actually built or tested in code (not just read about):

- We implemented and validated Sign in with Apple integration between the iOS app and backend.
- We implemented and validated APNS token registration and backend push delivery wiring.
- We implemented onboarding with profile completion, create family, join family, and onboarding completion.
- We implemented the connection between the device and the app using the custom BLE path that exists in the current product.
- We verified the live app target with the project build command instead of assuming the code was already in a working state.

What we discovered that we didn't expect:

- The backend is doing more product work than we first assumed: family authorization, device ownership checks, dose generation, dose transitions, and notification fan-out are all explicit server concerns.
- The firmware is not just sending raw sensor noise. It already includes debounce logic, configuration persistence, BLE pairing, and Wi-Fi reconnect behavior.

## 4. What We Tried and Dropped

We considered:

- using Matter or HomeKit as the main onboarding and device-integration path

We dropped it because:

- The repo and PRD both point to custom Core Bluetooth plus Wi-Fi provisioning as the MVP path. Matter and HomeKit are mentioned, but they are clearly treated as later-stage options because certification, interoperability, and setup complexity would slow down the first usable version.
- APNS did not behave like an auth add-on. In practice, it has its own delivery path, topic, key material, and runtime behavior, so keeping it separate made the implementation more honest and easier to reason about.

## 5. Real Limitations Hit

Apple sign-in profile data did not behave like a long-term profile source.

How we worked around it (or how it changed our use case / mechanic):

- We treated Apple identity as the login boundary, not as the permanent source of editable user profile data.
- The app refreshes the backend profile and uses session fallback where necessary instead of assuming Apple will keep returning the same fields forever.

APNS was not interchangeable with the rest of the Apple auth setup.

How we worked around it (or how it changed our use case / mechanic):

- We separated push setup from sign-in setup.
- The backend uses the APNS token-based path and HTTP/2 delivery instead of trying to reuse a simpler HTTP client flow.

Localization support existed only partially.

How we worked around it (or how it changed our use case / mechanic):

- We did not claim full localization in this report.
- We treated language selection as scaffolded product state, not as a finished multilingual experience.

AI also could not safely guess the product boundaries without checking the repo.

How we worked around it (or how it changed our use case / mechanic):

- We grounded the report in the real checkout: firmware code, backend routes, Swift imports, and the current onboarding and notification flows.
- That changed the report from a generic reminder-app summary into a more accurate description of an IoT medication workflow with real device, family, and schedule constraints.

## 6. The Revised Decision

Final decision:

- SwiftUI as the app shell and feature UI layer
- `AuthenticationServices` for Sign in with Apple
- `UserNotifications` for reminder permissions and push handling
- `NetworkExtension` plus custom device provisioning flow for Wi-Fi setup
- Express + Sequelize for the backend product logic
- APNS token-based delivery for reminder notifications
- ESP32 firmware with custom BLE GATT provisioning, Wi-Fi connection, and reed-switch event publishing

What changed since Section 1, and why:

- Our first instinct mostly held, but the exploration made the boundaries much sharper.
- The biggest change was not the choice of frameworks, but our understanding of where the real complexity lives.
- We first guessed "SwiftUI app with some backend help." What we actually found was a three-part product where the backend owns important family, device, and dose rules, and the firmware already carries meaningful behavior instead of acting like a passive sensor.
- We also became more confident that Matter and HomeKit should stay out of the MVP path because the current custom BLE route is already enough to prove the device workflow.

In other words, our final combination fits the MVP because it solves the real product problem with the tools already working in this repo, without taking on unnecessary ecosystem complexity too early.

---

## App Track Addendum

### About the Frameworks

This use case does not work with just the main UI framework. SwiftUI is necessary, but not sufficient. The app genuinely needs multiple Apple frameworks working together:

- `Apple sign-in` for the login boundary
- `Push notifications` for reminder permissions and push behavior
- `Core bluetooth` for provisioning-related device setup

Without those, the app would still render screens, but it would not actually cover the product flow this repo is building.

### About Accessibility and Localization

We decided not to over-claim either one.

- Accessibility: we will try to implement the light/dark mode after develop the prototype.
- Localization: we found app-language state and settings UI, but the visible product strings are still mostly hardcoded in English. So the honest answer is that localization has been considered and partially scaffolded, but it is not finished enough to present as complete support yet.

### About Privacy

The app actually needs:

- Apple identity for sign-in
- basic user profile data such as full name, email, and date of birth
- family membership data
- device ownership and pairing data
- push token registration for reminders
- device event data from the smart medicine box
- medicine schedules and dose history

When the user says no to a permission:

- If the user denies notification permission, login and onboarding can still continue, but push reminders and notification-based routing will not work.
- If the device setup path cannot access the required system capability for provisioning, the hardware onboarding flow becomes limited or blocked rather than silently pretending the device is connected.
- If the user never joins or creates a family, the rest of the shared medicine/device model does not make much sense, which is why the product flow pushes family setup early.

# Soccer Live

A small iPhone app that makes kids' soccer games feel like the pros: a live clock and score
for parents who can't make it to the field, run by a team admin from the sideline.

- **Fans** follow a team with an invite link, QR code or 6-character code. No account needed.
- **Admins** create the team, schedule games, and run the clock and score at the field.

## Layout

| Path | What it is |
|---|---|
| `App/` | The iOS app: onboarding, the Scores tab for fans and the Sideline tab for admins. |
| `SoccerKit/` | Swift package: models and clock math, the backend protocol with an in-memory fake, and the scoreboard views. |
| `project.yml` | Generates the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen). |
| `docs/plan.md` | The overall plan: signup and roles, backend, data model, build order. |

More (Live Activity widgets, Firebase rules and functions) lands as it's built.

## Running the app

```sh
brew install xcodegen
xcodegen generate
open SoccerLive.xcodeproj
```

Run the `SoccerLive` scheme on a simulator or your phone. For now it runs on an in-memory demo
backend: tap **Follow a team** and enter `NETS22` to follow the demo team with a game in progress,
or **Start a team** to try the admin side. Nothing is saved between launches yet.

## Running the tests

```sh
cd SoccerKit
swift test
```

Requires Xcode 16 or later.

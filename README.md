# Soccer Live

A small iPhone app that makes kids' soccer games feel like the pros: a live clock and score
for parents who can't make it to the field, run by a team admin from the sideline.

- **Fans** follow a team with an invite link, QR code or 6-character code. No account needed.
- **Admins** create the team, schedule games, and run the clock and score at the field.

## Layout

| Path | What it is |
|---|---|
| `SoccerKit/` | Swift package shared by the app: models, roles, invite codes, clock math. |
| `docs/plan.md` | The overall plan: signup and roles, backend, data model, build order. |

More (the app, Live Activity widgets, Firebase rules and functions) lands as it's built.

## Running the tests

```sh
cd SoccerKit
swift test
```

Requires Xcode 16 or later.

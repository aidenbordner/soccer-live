# Live Scores for the Team: Plan

One iPhone app, **Soccer Live**, with two sides that share one tiny backend:

- **Fan side** (everyone): live clock and score with an ESPN / Apple Sports feel, a Lock Screen Live Activity and Dynamic Island, and a game history.
- **Sideline side** (team admins only): create the team, schedule games, and run the clock and score at the field.

The same person can be a fan of one team and an admin of another. The Sideline tools only appear for teams where you're an admin.

Goal: polish over scale. Expected running cost is **$0 per month** beyond the Apple Developer Program ($99/yr, which you need anyway to put the app on parents' phones).

Repo: [aidenbordner/soccer-live](https://github.com/aidenbordner/soccer-live) (public; no kids' data ever goes in the repo).

---

## 1. Signup and roles

### First launch: two doors

```
┌──────────────────────────────┐
│        Soccer Live           │
│                              │
│  [ Follow a team ]           │  ← big, primary. Parents.
│    Enter code or scan QR     │
│                              │
│  Start a team                │  ← smaller, secondary. Coaches / you.
└──────────────────────────────┘
```

**Follow a team (parents): no account, no password.**
1. Parent taps an invite link in the team group chat (or scans a QR code shown at the field, or types a 6-character code).
2. The app signs them in anonymously behind the scenes and adds them to the team as a **fan**.
3. They land straight on the team's scoreboard. Optional prompt: "Add your name so the coach knows who's following" (first name only).

Optional later: "Sign in with Apple to keep your teams on a new phone." Nobody is forced to.

**Start a team (admins): Sign in with Apple required.**
1. Sign in with Apple, so admin access survives a lost phone and can't be grabbed by someone with the same device.
2. Create the team: name, short name (3 letters for the score bug), colors, crest, default half length.
3. You're the team's **owner**. The app opens on the Sideline tab with "Invite fans" and "Schedule a game" as next steps.

### Roles

| Role | Sees scores | Runs games | Edits team, invites admins | How you get it |
|---|---|---|---|---|
| **Fan** | ✓ | | | Fan link, QR or code |
| **Admin** | ✓ | ✓ | | Admin invite from the owner |
| **Owner** | ✓ | ✓ | ✓ | Created the team |

### Invites

- **Fan invite:** one reusable code per team, shareable as a link (`https://soccer-live.web.app/join/K7QX2M`), a QR code from the Sideline tab, or typed in. The owner can **rotate** it to stop new joins and **remove** individual fans.
- **Admin invite:** single-use link that expires in 7 days and requires Sign in with Apple to accept. That's how you'd add a second parent to run the clock or a backup scorer.

Links open the app directly (Universal Links) using a free Firebase Hosting site. It also shows a "Get the app on TestFlight" page for parents who don't have it yet. (Firebase Dynamic Links, the old way to do this, was shut down in 2025.)

### App layout

- **Tabs:** `Scores` (everyone) and `Sideline` (only if you're an admin of the selected team).
- **Team switcher** at the top when you belong to more than one team. A single-team user never sees it.
- On the Sideline tab, the live game screen is the same scoreboard fans see, with the controls added around it. That way the admin always sees exactly what parents see.

---

## 2. Backend recommendation

### Pick: Firebase (Firestore + Auth + Hosting + one Cloud Function)

| Need | How Firebase covers it |
|---|---|
| Live updates in the app | Firestore snapshot listeners push changes to every open app in well under a second. No polling. |
| Spotty cell signal at the field | Firestore's offline cache queues admin writes and sends them when signal returns. This matters more than anything else at a park. |
| Accounts | Anonymous auth for fans, Sign in with Apple for admins. Anonymous fans can be upgraded later without losing their teams. |
| Who can read and write | Security rules check the user's membership doc: fans read, admins write games, owners manage the team. |
| Invite links | Firebase Hosting (free) serves the Universal Link file and a small join page. |
| Lock Screen updates when the app is closed | One Cloud Function fires on each game update and sends a Live Activity push through APNs. |
| Cost | Free tier: 50k reads, 20k writes per day, 2M function calls per month. A game for 30 parents is about 2k reads. |

The one catch: Cloud Functions need the **Blaze (pay-as-you-go) plan**, which needs a card on file. The free allowances still apply on Blaze. Set a **$1 budget alert** on day one. Realistic bill: $0, at worst a few cents a month for function image storage.

### Why not the others

- **CloudKit (Apple's own):** free, no card, no extra account. The weak spot is live updates: its change notifications are throttled and can take seconds to minutes, which kills the "live" feel. Sharing a team with anonymous parents is also awkward.
- **Supabase:** nice Postgres + realtime, but free projects pause after a week of inactivity. Games are weekly, so you'd hit that.
- **Cloudflare Workers + Durable Objects:** cheap and fast, but you'd build auth, offline sync and realtime yourself.
- **A small always-on server:** costs money every month and needs upkeep. No benefit here.

### The design choice that keeps it cheap: don't stream the clock

The admin's phone never sends ticks. It writes the clock as a **state** only when something changes:

```
clock = { running: true, startedAt: <server timestamp>, elapsedBeforeStart: 0 }
```

Every phone computes the displayed time locally from that. A whole game is maybe 30 to 60 writes (kickoff, pauses, goals, halftime, final), no matter how many parents watch. It also gives a perfectly smooth clock, and iOS can draw a live-ticking timer in a Live Activity from one start date (`Text(timerInterval:)`) with no updates at all.

---

## 3. Architecture

```
 Admin phone (Sideline tab)         Firebase                    Fan phones (Scores tab)
 ──────────────────────────    ────────────────────          ──────────────────────────
 Clock + goal buttons ──────►  Firestore: game doc  ──────►  Live game screen
 Offline write queue           + event log                   (snapshot listener)
 Admin Live Activity           │
 (buttons on Lock Screen)      └► Cloud Function ──► APNs ──► Live Activity / Dynamic Island
                                  (on game update)            (Lock Screen, app closed)
```

### Code layout (one repo, one app)

- `SoccerKit` (local Swift package):
  - `SoccerModels`: Team, Membership/Role, Game, GameEvent, ClockState, invite codes, and the "what time is it now" logic. Pure Swift, fully unit tested.
  - `ScoreboardUI`: score bug, clock view, event row, team crest.
  - `Backend` (later): a thin Firestore wrapper behind a protocol, so a fake can drive previews and tests.
- `App/`: the single SwiftUI app (onboarding, Scores tab, Sideline tab).
- `Widgets/` (later): the Live Activity extension, with a fan layout and an admin layout with buttons.
- `functions/` (later, TypeScript): the Live Activity push function.
- `firebase/` (later): security rules and the Hosting site for invite links.
- The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), so it stays readable in git.

Minimum iOS: **18**. It brings broadcast push for Live Activities (one push reaches every subscribed phone) and current SwiftUI animation APIs.

### Live Activities

- **Fans:** "Follow on Lock Screen" on a live game. The activity subscribes to the game's broadcast channel; the function pushes on score, period or pause changes. Between those, the clock ticks on its own.
- **Admins:** a Live Activity with interactive buttons (App Intents) for **Goal Us / Goal Them / Pause**, so the game can be run from the Lock Screen without unlocking.

### Push notifications

Regular alerts for fans who aren't watching the Lock Screen: **kickoff**, **every goal**, **halftime** and **full time**, for example "⚽ Goal, Lightning! 2–1 (31')". The same Cloud Function that updates Live Activities sends these through Firebase Cloud Messaging (free). Each person picks which alerts they want per team, and nothing is sent for games they've muted. Admins get no alerts for games they're running.

### Getting the app to parents

TestFlight with a public link is simplest. Builds expire after 90 days and the first external build goes through a short Apple review. An unlisted App Store listing is the step up later.

---

## 4. Data model (single team now, many teams later)

```
users/{uid}
  displayName?, createdAt, isAnonymous

teams/{teamId}
  name, shortName, colors { primary, secondary }, crestURL?
  ownerId
  fanCode              // current reusable fan code, e.g. "K7QX2M"
  defaults { periodCount: 2, periodMinutes: 25 }

teams/{teamId}/members/{uid}      // one doc per person per team; rules read this
  role: owner | admin | fan
  displayName?, joinedAt, joinedVia: "fanCode" | "adminInvite" | "created"

joinCodes/{code}                  // lookup only: get by exact code, never list
  teamId, role: fan, active

adminInvites/{token}              // single use
  teamId, createdBy, expiresAt, usedBy?

games/{gameId}                    // top level, so "all live games" works across teams later
  teamId, opponent { name, shortName, colors }
  homeAway, venue?, scheduledAt
  status: scheduled | live | halftime | final
  period, periodCount, periodMinutes
  clock { running, startedAt?, elapsedBeforeStart }
  score { us, them }
  updatedAt, updatedBy

games/{gameId}/events/{eventId}   // append-only log
  type: kickoff | goal | pause | resume | periodEnd | final | correction
  side?: us | them, scorer?, matchSecond, createdAt, createdBy
  correctsEventId?
```

- **Membership is a document per person**, not a list on the team. Rules can check one doc cheaply, and a team with 40 fans never hits document-size or contention issues.
- **Joining is checked by rules:** a fan can create their own membership only with `role: fan` and a `joinCode` that points at that team and is active. Admin membership needs a valid, unexpired, unused admin invite.
- **Score and clock live on the game doc**, so a fan's screen needs one listener. Events are the log behind them and drive the timeline.
- **Corrections are events**, so an accidental tap never silently rewrites history, and the admin gets a real Undo.
- **Kids' privacy:** scorers as first name or jersey number only, never full names or photos. Every read requires a membership, so nothing is on the open internet.

---

## 5. Polish list

- Big, glanceable score bug with team colors, `contentTransition(.numericText())` on score changes, and a short goal celebration (crest pulse, haptic).
- Clock in monospaced digits that never jitters, with clear states: LIVE, HT, FT, PAUSED.
- Event timeline with minute markers ("12' Goal, #7").
- Sideline built for one thumb in sunlight: huge targets, high contrast, a confirm-free Goal button with a 5-second Undo toast.
- Pre-game card ("Saturday 9:00 vs. Hornets, Field 3") and a final-score card parents can share.
- Join flow that feels like magic: tap link, see the scoreboard. No forms.

## 6. Foldable layouts ("Duo support", confirmed)

Every screen uses SwiftUI size classes instead of fixed iPhone frames. The Sideline game screen goes two-pane when wide (clock and controls on one side, event log on the other) and single column when narrow. That covers a foldable iPhone, iPad split view and landscape.

---

## 7. Build order

1. **Shared package:** models, roles, invite codes, clock math, with tests. *(First PR.)*
2. App shell: onboarding (two doors), tabs, team switcher, all against a local fake backend.
3. Scoreboard UI and the Sideline game screen, running a full game on the fake backend.
4. Firebase project, security rules, anonymous auth plus Sign in with Apple, invite links.
5. Live Activities and push notifications: the admin Live Activity first (no server needed), then the fan Live Activity, goal and kickoff alerts, and the push function that sends both.
6. Polish pass, then TestFlight to a few parents for a real Saturday game.
7. **Later: Sentry** for crash reporting and error tracking (Aiden's pick). Sentry's free tier fits this size. The app will start it once at launch in `SoccerLiveApp`, report backend errors from the one place they're caught, and upload debug symbols from CI. To keep that easy, errors stay typed (`BackendError`, `GameActionError`) and no personal data, such as kids' names, goes into error messages.

## 8. What I need from you

- **Accounts:** an Apple Developer membership and a Firebase/Google account when we reach step 4. Nothing needed before then.
- **Building:** I can't compile iOS code in my environment, so each PR needs a build in Xcode on your Mac.

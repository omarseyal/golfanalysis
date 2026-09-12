# Rough estimates

A small Rails app around the TrackMan tooling in `../lib` and `../script`:
sign up, paste in TrackMan dynamic-report links, and get the raw shot data,
a summary (like `../output/summary.md`), and per-club progress charts (like
`../output/progress.html`) — all scoped to your account, plus a token-
authenticated JSON API so an agent can do the same things on your behalf.

## Setup

```
bundle install
bin/rails db:create db:migrate
bin/rails server
```

Ruby 3.2.2 (see `.ruby-version`), SQLite locally / Postgres in production, no
Node/JS build step (plain forms, no JS framework).

`lib/trackman_report` is a **vendored copy** of `../lib/trackman_report` (see
the `require_relative` in `config/application.rb`) — not a symlink or a
require of the sibling directory — so this app is self-contained and
deployable on its own (Heroku's `git subtree push` only ships this
directory, not its siblings). If you change the fetch/parse/stats logic in
`../lib`, copy it over here too:

```
rm -rf lib/trackman_report lib/trackman_report.rb
cp -r ../lib/trackman_report.rb ../lib/trackman_report lib/
```

## Web UI

- `/signup`, `/login` — email + password.
- `/` — your sessions; paste a TrackMan link to add one.
- `/trackman_sessions/:id` — per-shot data for one session, + a "Download
  raw CSV" link (every TrackMan field, not just the ones charted).
- `/summary` — per-club averages & dispersion, one section per session.
- `/progress` — per-club P25/P50/P75 charts across all your sessions.
- `/account` — your API key (for the API below) and TrackMan player-name
  filter (set this if your bay is shared with someone else).

## JSON API (for agents/scripts)

Every endpoint needs `Authorization: Bearer <api_key>` (find your key on
`/account`). `GET /api/v1` returns a machine-readable list of endpoints.

```
GET    /api/v1/me
GET    /api/v1/sessions
POST   /api/v1/sessions          {"url": "<trackman dynamic-report link>"}
GET    /api/v1/sessions/:id
GET    /api/v1/sessions/:id.csv
DELETE /api/v1/sessions/:id
GET    /api/v1/summary
GET    /api/v1/progress
```

`POST /api/v1/sessions` is idempotent by report id — safe for an agent to
call again on a link it's already added (e.g. re-processing an inbox).

## Tests

```
bin/rails test
```

Covers the User/TrackmanIngestor/ClubSummary/ClubProgress models & services,
the signup/login/logout flow, and the JSON API (auth, ingest, summary,
progress, CSV) — network calls are stubbed with the sample fixture at
`test/fixtures/files/sample_report.json` (copied from `../test/fixtures`).

# Play Console publish automation (ego-browser scripts)

Battle-tested on batches 1–3 (apps 001–017). All scripts run via
`ego-browser nodejs < script.mjs` on the logged-in ego-lite browser
(Play Console MUST be ajijuttam2006@gmail.com, authuser=1).

Placeholders to sed before running: `__APPID__` (Play app id), `__TRACK__`
(closed-track id, printed by the driver), `__NAME__` (slug for logs),
`__CATEGORY__`, `__MDIR__` (abs marketing dir), `__AAB__` (abs bundle path),
`__NOTES__`, `__NSHOTS__`, `__SHORT__`, `__FULL__` (from listing.md),
`__VIOLENCE__` (false fleet-wide), and `taskSpace(N)` → current space id.

Per-app order (what publish-chain.sh does):
1. play-driver-template.mjs — declarations, listing + assets, .aab, track
2. iarc.mjs — content rating (Everyone / PEGI 3, all-No)
3. ds-full.mjs — data safety
4. track-fix.mjs — countries (178) + testers + release save
5. finish-app.mjs — contact details fix + release save + submit (also the
   standalone submit2-template.mjs). First submit button may read
   "Send app for review".

Known gotchas live in the memory file and docs/play-console.md (local).
Queue for the Nov-3 weekly window: bazaar-defense, meme-reset, then 018–032
(up to ~15/window; remainder the following week). After approval: email all
testers the opt-in links (standing rule).

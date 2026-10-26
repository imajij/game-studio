# Google Play policy notes

Working notes — always verify current rules before a release; Google changes
these yearly. Primary sources:
- Target API requirement: https://developer.android.com/google/play/requirements/target-sdk
- Policy center: https://play.google/developer-content-policy/
- Families: https://support.google.com/googleplay/android-developer/answer/9893335

## Target API level
Google requires new apps and updates to target a recent Android API level,
raised every August (API 35 became mandatory Aug 2025; expect API 36 from
Aug 2026 — **verify before each release**, this file may be stale).
Godot's gradle export sets a default; override `gradle_build/target_sdk`
in the Android preset if it's behind the requirement.

## Ads (AdMob)
- Data safety form: AdMob collects device identifiers (AAID) and ad-performance
  data ⇒ declare "Device or other IDs", shared with third parties, for advertising.
- "Contains ads" label is mandatory.
- Ad placement policy: no ads that interfere with gameplay, no accidental-click
  layouts, no ads on app open before any interaction, interstitials only at
  natural breaks. AdsManager's frequency cap exists to keep us inside this.
- Never click/tap real ads on own devices — invalid traffic bans the AdMob account.

## Families policy
If a game could appeal to under-13s (bright simple visuals often do), either
declare a mixed/kids audience and comply (certified ad SDKs, child-directed ad
requests, no AAID collection for kids) or make the content/listing clearly
not child-directed. **Never misdeclare the target audience** — this is a
common ban reason.

## Privacy policy
Required for every app because ads collect identifiers. Needs a stable URL
(GitHub Pages works). Must name the data collected (device IDs via AdMob),
purpose, third parties (Google AdMob), and a contact address.

## Spam / repetitive content
Each game needs a distinct core mechanic, art set, and listing text. Don't
mass-publish near-identical games from the template — that's an account-level
strike. The template shares code, not gameplay.

## Account & misc
- No login in our games ⇒ no account-deletion requirement.
- Store listing: no misleading screenshots, no competitor names or trending IP
  names in title/keywords ("parody the vibe, not the IP").

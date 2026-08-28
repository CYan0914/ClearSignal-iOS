# Resolution Center 回复文案 — Guideline 4.3(b) Spam(网页回复用)

> 用法：把下面 "===" 之后的内容复制到 App Store Connect → Resolution Center。
> 不改语气、不删数字、不加 "this is wrong" 之类对抗性措辞。

===

Hello App Review,

Thank you for the second review. We would like to address Guideline 4.3(b) directly with the specific, defensible differentiators that make SignalVeil not a member of the generic "AI health coach" category:

1. Anti-noise design, not an AI dashboard.
   Every other app in the "wearable insights" category (Bevel, OakWell, PeakWatch, StressWatch, PulseBuddy, Boddy AI, Well AI, Simple, etc.) shows MORE data: more scores, more charts, more notifications. SignalVeil shows LESS. We curate 5-8 core metrics, label each one as either SIGNAL (worth watching) or NOISE (safe to ignore), and let the user actively mute entire anxiety sources with one tap — e.g. "Oura Anxiety Kit", "Apple Watch Pressure", "Fitness Score Overload". This is a categorically different product philosophy, not a styling difference.

2. Deterministic rule engine — no AI in the judgment loop.
   All health-data judgment is done by a pure rule engine in `Services/RuleEngine.swift`. The AI service (`Services/AIService.swift`) only takes the rule engine's structured output and translates it into natural language. The AI never sees raw HealthKit data, and never makes the verdict. This is a documented architectural decision with code comments, not marketing language.

3. Conflict Arbitrator — "who to trust" when the watch disagrees with the user.
   When the device scores say "recover" but the user feels fine — or vice versa — SignalVeil runs a three-state `ConflictVerdict` (`Models/ConflictVerdict.swift`):
   - `trust_feeling` (default)
   - `trust_trend` (3+ day anomaly exception)
   - `flag_for_tracking` (user feels bad but data is normal — track it)
   No other health app in the store performs this arbitration; they either show the score or show the chart, never the resolution. It is visible to all users on the Today screen as the "Feel vs Score" card, and on the Weekly screen as the "Conflict Stats" card.

4. Quick Declutter Bundles (industry-unique).
   `Models/IgnoreListItem.swift` defines three pre-built bundles that mute entire categories of anxiety-inducing wearable signals: Oura Readiness/Stress/Resilience scores, Apple Watch stand/move/exercise reminders, Whoop strain and Athlytic recovery scores. No competitor in the wearable-insights category offers a one-tap "mute the whole category of noise" feature. The three bundles are now FREE for every user in build 27 so reviewers and users can verify the feature directly.

5. Goal-based metric filtering (the rest is noise by default).
   Users pick a goal (Running, Weight Loss, Stress Management, General Health) during onboarding and only see the 3-4 metrics relevant to that goal. The other 5-6 metrics are hidden by design. Other apps show all 8-12 metrics by default and let the user filter (if at all). The default-state difference is observable in the first session.

6. Original backend and codebase, as previously stated.
   Self-hosted AI proxy at `signalveil.taomindapp.com`, our own FastAPI implementation, our own domain, native SwiftUI app, no template, no white-label, no shared binary. Build 27 contains no changes to the backend, no changes to the HealthKit authorization flow, no changes to the AI citation source list, and no changes to the iPad layout — only a metadata rewrite, a one-tap free tier change to the Ignore Bundles, and small UI hierarchy changes that make the differentiators visible in screenshots.

Build 27 is ready for review. We are happy to provide additional code, build archives, or backend documentation if the review team wants to verify the rule engine architecture directly.

Thank you for your time.

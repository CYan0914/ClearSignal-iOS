# SignalVeil App Store Listing (ASO Metadata)

> Target: US App Store (美区)
> App Name: SignalVeil
> SKU: com.cyan0914.clearsignal
> Bundle ID: com.cyan0914.clearsignal
> Version for next submission: 1.0.0 (build 27)

---

## App Store 信息

| 字段 | 值 |
|------|-----|
| App Name | SignalVeil |
| Subtitle | Trust Your Body, Not Your Watch |
| Category | Health & Fitness |
| Subcategory | Medical (备用) |
| Promotional Text | Not another AI health coach. SignalVeil uses a deterministic rule engine to tell you which of your metrics are signal — and which to ignore today. When your watch says "recover" but you feel fine, we trust you. |

## Keywords (100 字符限制)

```
health,wearable,anxiety,oura,whoop,hrv,sleep,trend,quiet,ignore,noise,calm,simple,body,feeling,checkin,goal,weekly,daily,trust
```

> 注：保留 oura/whoop 是为了拦截竞品用户搜索流量（"Oura alternative"、"Whoop without anxiety"），三个 Declutter Bundles 在描述里直接提到这两家产品。

## Description（英文）

**Your Apple Watch tells you too much. SignalVeil tells you what to ignore.**

We don't add another dashboard. We subtract. Every metric is judged by a deterministic rule engine — never by AI — and labeled either SIGNAL (worth watching) or NOISE (safe to mute). When your device says "recover" but you feel fine, we trust you, not the watch.

**What SignalVeil does**

- 🔇 **Tells you what to ignore.** Most wearable scores are single-day noise. SignalVeil marks them as such so you can stop worrying about them.
- ⚖️ **Resolves device-vs-feeling conflicts.** When your watch says one thing and you feel another, you see which one we trusted — and why.
- 🎯 **Goal-aware metric filtering.** Pick a goal (Running, Weight Loss, Stress Management, or General Health) and only see the 3-4 metrics that actually matter. The rest are hidden by design.
- 🧹 **Quick Declutter Bundles.** One-tap presets to mute "Oura Anxiety Kit", "Apple Watch Pressure", and "Fitness Score Overload" — entire categories of anxiety-inducing wearable signals.
- 📊 **ONE clear daily brief.** A short, plain-English summary of your trends. The rule engine decides the verdict; the AI only rephrases it.

**Why we are not an AI health coach**

Every other wearable app shows MORE data: more scores, more charts, more notifications, more "insights". That's exactly what creates health anxiety. SignalVeil does the opposite. Our rule engine is deterministic, not learned. It will give the same verdict tomorrow that it gives today, with the same input. AI is only used, optionally, to translate an already-decided verdict into a friendly sentence. The AI never reads your raw health data, and never makes a judgment.

**The conflict arbitrator**

Most apps either show the score or show the chart. SignalVeil shows the resolution:

- You feel good but your watch says "recover" → we trust you. Single-day scores are noise.
- Your watch flags a 3+ day trend anomaly → we surface it, even if you feel fine.
- You feel off but the data is normal → we track it quietly and watch for patterns.

No other health app in the store does this. It's the heart of the product.

**Quiet Mode — the first thing you'll see in the app**

Three pre-built Declutter Bundles are free for every user:

1. **Oura Anxiety Kit** — mutes Readiness, Stress, and Resilience score notifications.
2. **Apple Watch Pressure** — mutes stand, move, and exercise ring reminders.
3. **Fitness Score Overload** — mutes Whoop strain, Athlytic recovery, and similar scores.

Add custom ignores (unlimited) and access 30-day ignore history with Premium.

**Premium Features**

- Daily AI Morning Brief (natural-language summary of today's rule-engine verdict)
- Conversational Q&A (ask "Is this drop real or single-day noise?" and get a real answer)
- Unlimited custom Ignore items
- 30-day ignore history
- Weekly summary with conflict stats ("we trusted your feeling X times this week; the watch Y times")

**Privacy by Design**

We read 5-8 core metrics from Apple Health. All judgment happens on-device. We NEVER upload raw health data. The AI service receives only the pre-digested, structured verdict — never your numbers.

**Pricing**

- Free: trends, signal/noise labels, the 3 Declutter Bundles, 3 active ignores, 1 weekly brief
- Premium: $4.99/month or $39.99/year — daily AI brief, Q&A, unlimited ignores, 30-day history

===

## 审核备注（Review Notes）

```
Review Notes for Apple:

1. HealthKit Usage:
   - This app reads HealthKit data (sleep, heart rate, HRV, respiratory rate, activity, weight, blood oxygen)
   - All judgment happens on-device via a deterministic rule engine
   - No raw health data is ever uploaded to external servers

2. Subscription testing (Sandbox):
   - The app uses RevenueCat for subscription management
   - Premium features: AI daily brief, conversational Q&A, unlimited ignore items, 30-day history
   - Free tier: trends, signal/noise labels, 3 Declutter Bundles, 3 active ignores, 1 weekly brief
   - To test: use a Sandbox Apple ID, go to Settings > tap to upgrade

3. Why SignalVeil is not a Guideline 4.3(b) case:
   - The product philosophy is subtraction, not addition (we tell users what to ignore, not what to track)
   - All judgment is a deterministic rule engine (Services/RuleEngine.swift) — AI is translation-only
   - The "conflict arbitrator" (Models/ConflictVerdict.swift) is a unique product feature with no equivalent in the wearable-insights category
   - The "Declutter Bundles" (Models/IgnoreListItem.swift) let users one-tap mute entire categories of wearable noise

4. Core functionality to test:
   - Onboarding: select health goal, connect HealthKit, view "How it works" explainer
   - Today tab: view morning brief, "Feel vs Score" conflict card, signal/noise labels
   - Feel Log: daily check-in (3 options: good/okay/not great)
   - Quiet tab: review 3 free Declutter Bundles, add up to 3 free ignores
   - Ask tab: AI chat about health data (premium feature)

5. No login/account creation required.

6. AI-generated content is for informational purposes only. The app does not provide medical diagnosis or treatment recommendations.

7. Push notifications: 1 daily morning brief at 8:00 AM (can be disabled in Settings).
```

---

## 截图计划（程序化生成）

| 序 | 设备 | 拍什么 | 关键文案 overlay |
|---|---|---|---|
| 1 | iPhone 6.7" 1290×2796 | Quiet Mode 主页：3 个 Declutter Bundles 全可见 | "Mute the noise. One tap." |
| 2 | iPhone 6.7" 1290×2796 | Feel vs Score 冲突卡片 + ConflictVerdict 浮层 | "When the watch disagrees with you, we side with you." |
| 3 | iPhone 6.7" 1290×2796 | Today 主页 + 红色 "🔇 NOISE" 徽章显眼 | "Single-day is noise. Only trends are signal." |
| 4 | iPhone 6.7" 1290×2796 | TrendDetail Signal vs Noise 判定卡 | "Verdict: NOISE. Skip it." |
| 5 | iPhone 6.7" 1290×2796 | Onboarding Goal 选择 | "Pick a goal. The rest is noise." |
| 6 | iPhone 6.7" 1290×2796 | Weekly Summary 的 Conflict Stats | "This week: we trusted you 5 times. The watch 2." |
| 7-10 | iPad Pro 13" 竖 4 张 | 1/2/3/6 同图重排版 | 同上 |

实现方式：Playwright (Chromium headless) 渲染 1290×2796 设备框 HTML + SwiftUI 风格组件 + marketing text overlay，导出 PNG。

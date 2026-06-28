# AIAvatarProfilePics

Generated from niche `ai-avatar` (AI Image, tier A, score 80).

**Utility:** Stylized AI avatars from selfies
**Primary ASO keyword:** `ai avatar`
**Also target:** `ai profile picture`, `avatar maker`, `ai selfie`, `cartoon avatar`
**Paywall hook:** More packs/styles, HD, no watermark

> Lensa wave. Trend-sensitive; lean on a fresh style (anime, yearbook, LinkedIn).

## Build it

```bash
brew install xcodegen        # once
cd AIAvatarProfilePics
xcodegen generate
open AIAvatarProfilePics.xcodeproj
```

The app runs immediately on a MockPurchaseProvider (real paywall UI, fake
purchases). To go live:

1. Replace `revenueCatKey` in `Sources/App.swift` with your RevenueCat key.
2. In App Store Connect create products `ai-avatar_yearly` and `ai-avatar_weekly`,
   map them into a RevenueCat offering, entitlement id `premium`.
3. Build the real feature in `Sources/ContentView.swift`.
4. **Guideline 4.3:** make the function, UI, screenshots and keywords genuinely
   distinct from any sibling app. Re-niche, never reskin.

Bundle id: `com.zubeid.aiavatar`

## Ship to TestFlight

This app ships with a Fastlane lane + GitHub Actions workflow. One-time account
setup (API key, signing) is documented in the kit's `Tools/appgen/DEPLOYMENT.md`.
Once your GitHub secrets are set, trigger the **TestFlight** workflow (or push a
`v*` tag), or run locally:

```bash
bundle install
bundle exec fastlane beta
```

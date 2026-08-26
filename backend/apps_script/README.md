# TiB AI Personal Styling — Apps Script backend

The Flutter app calls the existing Google Apps Script Web App configured in `lib/config/google_drive_config.dart`.

## Access mode

The backend is currently in **pre-launch/testing mode**.

- All authenticated users can use AI Styling.
- All authenticated users can use Today's Recommendation.
- All authenticated users can use Virtual Try-On.
- Premium entitlement is **not required during testing**.
- The Firebase ID token is still verified server-side before AI requests are accepted.

The single switch is in `Code.gs`:

```javascript
const PRE_LAUNCH_MODE = true;
```

Keep it `true` while the app is being tested. When the app officially launches and Premium should be enforced, change it to:

```javascript
const PRE_LAUNCH_MODE = false;
```

The Premium verification helper is intentionally kept in the backend so the launch transition does not require another major code rewrite.

## Gemini Virtual Try-On

In Apps Script: **Project Settings → Script Properties → Add script property**

- Property: `GEMINI_API_KEY`
- Value: your Google Gemini API key

Do not put the key in Flutter or commit it to GitHub.

The backend uses `gemini-3.1-flash-image` for image editing/generation. It sends the user's TiB Model image and selected wardrobe images as references, then stores the generated result in a `virtual_try_on` folder under the existing profile Drive folder.

## Anthropic AI Styling

Add the Anthropic key in Apps Script **Project Settings → Script Properties**:

- Property: `ANTHROPIC_API_KEY`
- Value: your Anthropic API key

Do not put this key in Flutter or commit it to GitHub.

## Deploy

After saving the Apps Script:

**Deploy → Manage deployments → Edit → New version → Deploy**

Keep the same Web App URL so the Flutter configuration does not need to change.

## Test

The Flutter request actions are:

- `aiStyling`
- `todayRecommendation`
- `virtualTryOn`

During pre-launch, all three require a valid Firebase ID token but do not require Premium entitlement.

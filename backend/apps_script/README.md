# TiB Virtual Try-On backend

The Flutter app calls the existing Google Apps Script Web App configured in `lib/config/google_drive_config.dart`.

## 1. Add the backend patch

Open the existing Apps Script project and add the contents of `virtual_try_on_patch.gs` to the existing `Code.gs`.

Inside `doPost(e)`, immediately after the existing `aiStyling` block, add:

```javascript
if (body.action === "virtualTryOn") {
  return handleVirtualTryOn(body);
}
```

## 2. Add the Gemini API key

In Apps Script: **Project Settings → Script Properties → Add script property**

- Property: `GEMINI_API_KEY`
- Value: your Google Gemini API key

Do not put the key in Flutter or commit it to GitHub.

The backend uses `gemini-3.1-flash-image` for image editing/generation. It sends the user's model image and selected wardrobe images as image references, then stores the generated result in a `virtual_try_on` folder under the existing profile Drive folder.

## 3. Deploy a new Web App version

After saving the Apps Script:

**Deploy → Manage deployments → Edit → New version → Deploy**

Keep the same Web App URL so the Flutter configuration does not need to change.

## 4. Test

The Flutter request action is `virtualTryOn`. The backend verifies the Firebase ID token and Premium entitlement before calling Gemini.

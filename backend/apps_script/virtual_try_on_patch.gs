// TiB AI Personal Styling — Virtual Try-On backend patch
//
// STATUS: SUPERSEDED BY backend/apps_script/Code.gs
//
// The complete Apps Script backend is now tracked in Code.gs.
// Use Code.gs as the source of truth instead of copying this patch into
// another Apps Script project.
//
// PRE-LAUNCH ACCESS:
//   const PRE_LAUNCH_MODE = true;
//
// In pre-launch mode, Virtual Try-On is available to every authenticated
// Firebase user. The server still verifies the Firebase ID token.
//
// OFFICIAL LAUNCH:
//   const PRE_LAUNCH_MODE = false;
//
// When PRE_LAUNCH_MODE is false, the shared hasAiAccess() helper switches
// the AI endpoints back to server-side Premium entitlement checking.
//
// Gemini setup remains in Project Settings -> Script Properties:
//   GEMINI_API_KEY
//
// Keep API keys out of Flutter and out of source control.

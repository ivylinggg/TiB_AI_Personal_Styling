const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

function cleanString(value, fallback = "") {
  if (typeof value !== "string") return fallback;
  const result = value.trim();
  return result || fallback;
}

function assertAdmin(context) {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  return db.collection("users").doc(context.auth.uid).get().then((snapshot) => {
    if (!snapshot.exists || snapshot.data().role !== "admin" || snapshot.data().isActive === false) {
      throw new HttpsError("permission-denied", "Administrator access is required.");
    }
  });
}

exports.createStaffAccount = onCall({
  region: "asia-southeast1",
  enforceAppCheck: false,
}, async (request) => {
  await assertAdmin(request);

  const data = request.data || {};
  const staffId = cleanString(data.staffId);
  const name = cleanString(data.name);
  const email = cleanString(data.email).toLowerCase();
  const trainerName = cleanString(data.trainerName);
  const photoUrl = cleanString(data.photoUrl);
  const password = cleanString(data.password);
  const role = data.role === "admin" ? "admin" : "consultant";
  const groomingCompleted = data.groomingCompleted === true;
  const groomingScore = data.groomingScore;
  const groomingNotes = cleanString(data.groomingNotes);

  if (!staffId || !name || !email || !password) {
    throw new HttpsError("invalid-argument", "Staff ID, name, email and password are required.");
  }

  if (password.length < 8) {
    throw new HttpsError("invalid-argument", "Password must contain at least 8 characters.");
  }

  if (!email.includes("@")) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }

  const duplicateStaff = await db.collection("users")
      .where("staffId", "==", staffId)
      .limit(1)
      .get();

  if (!duplicateStaff.empty) {
    throw new HttpsError("already-exists", "This Staff ID is already registered.");
  }

  const duplicateEmail = await db.collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();

  if (!duplicateEmail.empty) {
    throw new HttpsError("already-exists", "This email is already linked to an account.");
  }

  let userRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
      photoURL: photoUrl || undefined,
      disabled: false,
      emailVerified: false,
    });
  } catch (error) {
    logger.error("Unable to create Firebase Authentication user", error);
    if (error && error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "A Firebase account already exists for this email.");
    }
    throw new HttpsError("internal", "Unable to create the staff authentication account.");
  }

  try {
    await db.collection("users").doc(userRecord.uid).set({
      uid: userRecord.uid,
      staffId,
      name,
      email,
      trainerName,
      photoUrl,
      role,
      isActive: true,
      isPremium: false,
      onboardingComplete: true,
      groomingCompleted,
      groomingScore: groomingScore === null || groomingScore === undefined ? null : groomingScore,
      groomingNotes,
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      groomingCompletedAt: groomingCompleted ? admin.firestore.FieldValue.serverTimestamp() : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error("Unable to create staff Firestore profile", error);
    await auth.deleteUser(userRecord.uid).catch((deleteError) => {
      logger.error("Rollback of Authentication user failed", deleteError);
    });
    throw new HttpsError("internal", "Unable to create the staff profile.");
  }

  try {
    await auth.generateEmailVerificationLink(email);
  } catch (error) {
    logger.warn("Staff profile created but verification link generation failed", error);
  }

  return {
    uid: userRecord.uid,
    email,
    staffId,
    role,
  };
});

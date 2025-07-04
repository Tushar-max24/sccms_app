const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendReportNotification = functions.firestore
  .document('reports/{reportId}')
  .onWrite(async (change, context) => {
    const newData = change.after.exists ? change.after.data() : null;

    if (!newData) {
      console.log("🛑 Report deleted. No notification needed.");
      return null;
    }

    const userId = newData.userId;

    if (!userId) {
      console.error("⚠️ No user ID found in report.");
      return null;
    }

    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const fcmToken = userDoc.data().fcmToken;

    if (!fcmToken) {
      console.error("⚠️ No FCM token found for user:", userId);
      return null;
    }

    const payload = {
      notification: {
        title: "📢 Report Update",
        body: `Your report '${newData.title || "Cleanliness Issue"}' has been updated.`,
      },
      token: fcmToken,
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("✅ Notification sent:", response);
    } catch (error) {
      console.error("❌ Error sending notification:", error);
    }

    return null;
  });

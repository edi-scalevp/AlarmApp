import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================================
// CONTACT MATCHING
// ============================================================================

/**
 * Find registered users from a list of phone number hashes
 * Used for contact-based friend discovery
 */
export const findFriendsFromContacts = functions.https.onCall(
  async (data, context) => {
    // Ensure user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { phoneHashes } = data as { phoneHashes: string[] };
    const userId = context.auth.uid;

    if (!phoneHashes || !Array.isArray(phoneHashes)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "phoneHashes must be an array"
      );
    }

    // Firestore 'in' query limited to 10 items, so batch if needed
    const batches: string[][] = [];
    for (let i = 0; i < phoneHashes.length; i += 10) {
      batches.push(phoneHashes.slice(i, i + 10));
    }

    const matchedUsers: Array<{
      id: string;
      displayName: string;
      profileImageURL?: string;
      phoneNumberHash: string;
    }> = [];

    for (const batch of batches) {
      if (batch.length === 0) continue;

      const snapshot = await db
        .collection("users")
        .where("phoneNumberHash", "in", batch)
        .get();

      snapshot.docs.forEach((doc) => {
        // Exclude self
        if (doc.id !== userId) {
          const userData = doc.data();
          matchedUsers.push({
            id: doc.id,
            displayName: userData.displayName || "Unknown",
            profileImageURL: userData.profileImageURL,
            phoneNumberHash: userData.phoneNumberHash,
          });
        }
      });
    }

    return { users: matchedUsers };
  }
);

// ============================================================================
// ALARM ESCALATION
// ============================================================================

interface EscalationEvent {
  id: string;
  alarmId: string;
  userId: string;
  triggerTime: FirebaseFirestore.Timestamp;
  escalationTime: FirebaseFirestore.Timestamp;
  friendIds: string[];
  status: "pending" | "dismissed" | "escalated" | "expired";
  message?: string;
  dismissedAt?: FirebaseFirestore.Timestamp;
  escalatedAt?: FirebaseFirestore.Timestamp;
}

/**
 * Called when an alarm fires on a user's device
 * Creates an escalation event and schedules the notification
 */
export const onAlarmTriggered = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const {
      alarmId,
      triggerTime,
      escalationDelayMinutes,
      friendIds,
      message,
    } = data as {
      alarmId: string;
      triggerTime: string;
      escalationDelayMinutes: number;
      friendIds: string[];
      message?: string;
    };

    const userId = context.auth.uid;

    // Parse trigger time
    const triggerDate = new Date(triggerTime);
    const escalationDate = new Date(
      triggerDate.getTime() + escalationDelayMinutes * 60 * 1000
    );

    // Create escalation event
    const eventId = db.collection("escalations").doc().id;
    const event: EscalationEvent = {
      id: eventId,
      alarmId,
      userId,
      triggerTime: admin.firestore.Timestamp.fromDate(triggerDate),
      escalationTime: admin.firestore.Timestamp.fromDate(escalationDate),
      friendIds,
      status: "pending",
      message,
    };

    await db.collection("escalations").doc(eventId).set(event);

    // Schedule a Cloud Task to process escalation after delay
    // For simplicity, we'll use a scheduled function that checks pending escalations
    // In production, you'd use Cloud Tasks for precise timing

    return { success: true, eventId };
  }
);

/**
 * Called when user dismisses their alarm
 * Marks the escalation as dismissed to prevent friend notification
 */
export const onAlarmDismissed = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { eventId } = data as { eventId: string };

    if (!eventId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "eventId is required"
      );
    }

    // Update escalation status
    await db.collection("escalations").doc(eventId).update({
      status: "dismissed",
      dismissedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);

/**
 * Called when user snoozes their alarm
 * Extends the escalation deadline
 */
export const onAlarmSnoozed = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { eventId, additionalMinutes } = data as {
    eventId: string;
    additionalMinutes: number;
  };

  if (!eventId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "eventId is required"
    );
  }

  // Get current escalation
  const eventDoc = await db.collection("escalations").doc(eventId).get();
  if (!eventDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Escalation not found");
  }

  const event = eventDoc.data() as EscalationEvent;

  // Calculate new escalation time
  const currentEscalationTime = event.escalationTime.toDate();
  const newEscalationTime = new Date(
    currentEscalationTime.getTime() + additionalMinutes * 60 * 1000
  );

  // Update escalation time
  await db.collection("escalations").doc(eventId).update({
    escalationTime: admin.firestore.Timestamp.fromDate(newEscalationTime),
  });

  return { success: true };
});

/**
 * Scheduled function that processes pending escalations
 * Runs every minute to check for escalations that need to be triggered
 */
export const processEscalations = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    // Find pending escalations where escalation time has passed
    const snapshot = await db
      .collection("escalations")
      .where("status", "==", "pending")
      .where("escalationTime", "<=", now)
      .get();

    const batch = db.batch();
    const notifications: Promise<string>[] = [];

    for (const doc of snapshot.docs) {
      const event = doc.data() as EscalationEvent;

      // Get user info for notification
      const userDoc = await db.collection("users").doc(event.userId).get();
      const userData = userDoc.data();
      const userName = userData?.displayName || "Someone";

      // Calculate minutes elapsed
      const triggerTime = event.triggerTime.toDate();
      const minutesElapsed = Math.round(
        (now.toDate().getTime() - triggerTime.getTime()) / 60000
      );

      // Send push notification to each friend
      for (const friendId of event.friendIds) {
        const friendDoc = await db.collection("users").doc(friendId).get();
        const friendData = friendDoc.data();
        const fcmToken = friendData?.fcmToken;

        if (fcmToken) {
          const message: admin.messaging.Message = {
            token: fcmToken,
            notification: {
              title: `${userName} needs help waking up!`,
              body: `Their alarm has been going off for ${minutesElapsed} minutes.`,
            },
            data: {
              type: "friend_alarm",
              userId: event.userId,
              eventId: event.id,
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                },
              },
            },
          };

          notifications.push(messaging.send(message));
        }
      }

      // Mark as escalated
      batch.update(doc.ref, {
        status: "escalated",
        escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Execute all operations
    await Promise.all([batch.commit(), ...notifications]);

    console.log(`Processed ${snapshot.docs.length} escalations`);
    return null;
  });

// ============================================================================
// FRIEND REQUESTS
// ============================================================================

/**
 * Send push notification when a friend request is received
 */
export const onFriendRequestCreated = functions.firestore
  .document("friendRequests/{requestId}")
  .onCreate(async (snap) => {
    const request = snap.data();
    const toUserId = request.toUserId;

    // Get recipient's FCM token
    const userDoc = await db.collection("users").doc(toUserId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      console.log("No FCM token for user:", toUserId);
      return;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "New Friend Request",
        body: `${request.fromDisplayName} wants to be your accountability partner!`,
      },
      data: {
        type: "friend_request",
        requestId: snap.id,
        fromUserId: request.fromUserId,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await messaging.send(message);
  });

/**
 * Send push notification when a friend request is accepted
 */
export const onFriendRequestAccepted = functions.firestore
  .document("friendRequests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only process if status changed to accepted
    if (before.status === "pending" && after.status === "accepted") {
      const fromUserId = after.fromUserId;

      // Get sender's FCM token
      const userDoc = await db.collection("users").doc(fromUserId).get();
      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        console.log("No FCM token for user:", fromUserId);
        return;
      }

      // Get accepter's name
      const accepterDoc = await db.collection("users").doc(after.toUserId).get();
      const accepterData = accepterDoc.data();
      const accepterName = accepterData?.displayName || "Someone";

      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title: "Friend Request Accepted",
          body: `${accepterName} is now your accountability partner!`,
        },
        data: {
          type: "friend_accepted",
          friendId: after.toUserId,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      await messaging.send(message);
    }
  });

// ============================================================================
// STATISTICS
// ============================================================================

/**
 * Get wake-up statistics for a user
 */
export const getWakeUpStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const userId = context.auth.uid;

  // Get all escalation events for user
  const snapshot = await db
    .collection("escalations")
    .where("userId", "==", userId)
    .get();

  let totalAlarms = 0;
  let dismissedOnTime = 0;
  let escalated = 0;

  snapshot.docs.forEach((doc) => {
    const event = doc.data() as EscalationEvent;
    totalAlarms++;

    if (event.status === "dismissed") {
      dismissedOnTime++;
    } else if (event.status === "escalated") {
      escalated++;
    }
  });

  // Calculate streaks (simplified - in production, track per-day)
  const currentStreak = calculateCurrentStreak(snapshot.docs);
  const bestStreak = calculateBestStreak(snapshot.docs);

  return {
    totalAlarms,
    dismissedOnTime,
    escalated,
    currentStreak,
    bestStreak,
  };
});

function calculateCurrentStreak(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): number {
  // Simplified streak calculation
  // In production, you'd track alarm dismissals by day
  let streak = 0;
  const sortedDocs = docs
    .filter((doc) => doc.data().status === "dismissed")
    .sort((a, b) => {
      const aTime = a.data().triggerTime.toDate().getTime();
      const bTime = b.data().triggerTime.toDate().getTime();
      return bTime - aTime; // Most recent first
    });

  if (sortedDocs.length === 0) return 0;

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  for (const doc of sortedDocs) {
    const eventDate = doc.data().triggerTime.toDate();
    eventDate.setHours(0, 0, 0, 0);

    const daysDiff = Math.floor(
      (today.getTime() - eventDate.getTime()) / (1000 * 60 * 60 * 24)
    );

    if (daysDiff === streak) {
      streak++;
    } else {
      break;
    }
  }

  return streak;
}

function calculateBestStreak(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): number {
  // Simplified - return current streak or a placeholder
  // In production, you'd track historical streaks
  return Math.max(calculateCurrentStreak(docs), 7);
}

/**
 * Get escalation history for a user
 */
export const getEscalationHistory = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { userId, limit = 20 } = data as { userId: string; limit?: number };

    // Only allow users to see their own history
    if (userId !== context.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Cannot view other user's history"
      );
    }

    const snapshot = await db
      .collection("escalations")
      .where("userId", "==", userId)
      .orderBy("triggerTime", "desc")
      .limit(limit)
      .get();

    const history = snapshot.docs.map((doc) => {
      const event = doc.data() as EscalationEvent;
      return {
        id: event.id,
        alarmLabel: "Alarm", // In production, fetch from alarm data
        triggerTime: event.triggerTime.toDate().toISOString(),
        status: event.status,
        friendName: null, // In production, fetch friend name
      };
    });

    return { history };
  }
);

/**
 * Check if a friend can be notified (rate limiting)
 */
export const canNotifyFriend = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const { friendId } = data as { friendId: string };

  // Check recent notifications to this friend (rate limit: max 3 per hour)
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  const snapshot = await db
    .collection("escalations")
    .where("friendIds", "array-contains", friendId)
    .where("status", "==", "escalated")
    .where("escalatedAt", ">=", admin.firestore.Timestamp.fromDate(oneHourAgo))
    .get();

  const canNotify = snapshot.docs.length < 3;

  return { canNotify };
});

// ============================================================================
// USER MANAGEMENT
// ============================================================================

/**
 * Clean up user data when account is deleted
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  const batch = db.batch();

  // Delete user document
  batch.delete(db.collection("users").doc(userId));

  // Delete user's friends subcollection
  const friendsSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("friends")
    .get();
  friendsSnapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  // Delete friend requests
  const sentRequests = await db
    .collection("friendRequests")
    .where("fromUserId", "==", userId)
    .get();
  sentRequests.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  const receivedRequests = await db
    .collection("friendRequests")
    .where("toUserId", "==", userId)
    .get();
  receivedRequests.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  // Delete escalation events
  const escalations = await db
    .collection("escalations")
    .where("userId", "==", userId)
    .get();
  escalations.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  console.log(`Cleaned up data for deleted user: ${userId}`);
});

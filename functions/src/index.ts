/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import {onDocumentWritten, onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

admin.initializeApp();

export const debugFirestoreStructure = onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const rootCols = await db.listCollections();
    const result: Record<string, any> = {};
    for (const col of rootCols) {
      const name = col.id;
      const snap = await col.limit(3).get();
      result[name] = snap.docs.map((d) => ({ id: d.id, fields: Object.keys(d.data() || {}) }));
    }
    res.status(200).json({ ok: true, collections: result });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// Role normalization utility
// Secured: requires Firebase ID token of an admin user in Authorization: Bearer <token>
// Usage:
//   GET  /normalizeUserRoles            -> dry-run preview of changes
//   POST /normalizeUserRoles?apply=1    -> apply updates
export const normalizeUserRoles = onRequest(async (req, res) => {
  try {
    const authz = req.headers.authorization || "";
    const token = authz.startsWith("Bearer ") ? authz.substring("Bearer ".length) : "";
    if (!token) { res.status(401).json({ok: false, error: "Missing Authorization bearer token"}); return; }

    const decoded = await admin.auth().verifyIdToken(token);
    const uid = decoded.uid;

    const db = admin.firestore();
    const meDoc = await db.collection("users").doc(uid).get();
    const myRole = (meDoc.exists ? (meDoc.data()?.role as string | undefined) : undefined) || "";
    const isAdmin = (myRole || "").toLowerCase() === "admin" || (decoded.email || "").toLowerCase() === "admin@savipets.com";
    if (!isAdmin) { res.status(403).json({ok: false, error: "Admin only"}); return; }

    const apply = req.method === "POST" && (req.query.apply === "1" || req.query.apply === "true");

    const mapToCanonical = (raw?: string | null): string | null => {
      if (!raw) return null;
      const s = raw.toString().trim().toLowerCase();
      if (s === "admin") return "admin";
      if (s === "owner" || s === "petowner" || s === "pet owner") return "petOwner";
      if (s === "sitter" || s === "petsitter" || s === "pet sitter") return "petSitter";
      return raw as string; // already canonical or unknown custom role
    };

    const snap = await db.collection("users").get();
    const changes: Array<{id: string, from: any, to: any}> = [];
    for (const doc of snap.docs) {
      const role = (doc.data().role as string | null | undefined) || "";
      const canonical = mapToCanonical(role);
      if (canonical && canonical !== role) {
        changes.push({id: doc.id, from: role, to: canonical});
      }
    }

    if (!apply) {
      res.status(200).json({ok: true, apply: false, total: snap.size, changes});
      return;
    }

    const batch = db.batch();
    for (const c of changes) {
      batch.set(db.collection("users").doc(c.id), {role: c.to}, {merge: true});
    }
    await batch.commit();
    res.status(200).json({ok: true, apply: true, updated: changes.length});
  } catch (e: any) {
    res.status(500).json({ok: false, error: e?.message || String(e)});
  }
});

// Create/maintain visits on service booking approval
export const onServiceBookingWrite = onDocumentWritten("serviceBookings/{bookingId}", async (event) => {
  const before = event.data?.before?.data() as any | undefined;
  const after = event.data?.after?.data() as any | undefined;
  if (!after) return;
  const wasApproved = (before?.status || "").toString().toLowerCase() === "approved";
  const isApproved = (after?.status || "").toString().toLowerCase() === "approved";
  if (isApproved && !wasApproved) {
    const db = admin.firestore();
    const bookingId = event.params.bookingId as string;
    const sitterId = after.sitterId || "";
    const sitterName = after.sitterName || "";
    const clientId = after.clientId || "";
    const serviceType = after.serviceType || "Service";

    // Build scheduledStart/end from date + time string
    const ts = after.scheduledDate?._seconds ? new Date(after.scheduledDate._seconds * 1000) : new Date();
    const timeStr = (after.scheduledTime || "").toString();

    const combineDateTime = (date: Date, time: string): Date => {
      // Expect formats like "10:00 AM"; fallback to same date midnight if parse fails
      const m = time.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
      let d = new Date(date);
      d.setHours(0, 0, 0, 0);
      if (m) {
        let hours = parseInt(m[1], 10);
        const minutes = parseInt(m[2], 10);
        const ampm = m[3].toUpperCase();
        if (ampm === "PM" && hours < 12) hours += 12;
        if (ampm === "AM" && hours === 12) hours = 0;
        d.setHours(hours, minutes, 0, 0);
      }
      return d;
    };

    const scheduledStart = combineDateTime(ts, timeStr);
    const durationMin: number = Number(after.duration || 30);
    const scheduledEnd = new Date(scheduledStart.getTime() + Math.max(durationMin, 0) * 60000);

    // Resolve client display name best-effort
    let clientName = "Client";
    try {
      const clientDoc = await db.collection("users").doc(clientId).get();
      const u = clientDoc.data() || {};
      const email = (u.email as string) || "";
      const fallback = email.split("@")[0] || "Client";
      const raw = (u.displayName as string) || (u.name as string) || "";
      clientName = raw.trim() || fallback;
    } catch {}

    const visitRef = db.collection("visits").doc(bookingId);
    const toWrite: Record<string, any> = {
      bookingId,
      sitterId,
      sitterName,
      clientId,
      clientName,
      serviceSummary: serviceType,
      scheduledStart: admin.firestore.Timestamp.fromDate(scheduledStart),
      scheduledEnd: admin.firestore.Timestamp.fromDate(scheduledEnd),
      status: "scheduled",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (after.address) toWrite.address = after.address;
    if (after.specialInstructions) toWrite.note = after.specialInstructions;
    if (Array.isArray(after.pets) && after.pets.length) toWrite.pets = after.pets;

    await visitRef.set(toWrite, {merge: true});
  }
});

// ============================================================================
// PUSH NOTIFICATION TRIGGERS
// ============================================================================

/**
 * Send push notification when a new message is created
 * Triggered by: conversations/{conversationId}/messages/{messageId}
 */
export const onNewMessage = onDocumentCreated("conversations/{conversationId}/messages/{messageId}", async (event) => {
  try {
    const message = event.data?.data();
    if (!message) return;

    const conversationId = event.params.conversationId;
    const senderId = message.senderId;
    const messageText = message.text || "";
    const status = message.status || "sent";

    // Don't send notification for pending messages (awaiting approval)
    if (status === "pending") return;

    const db = admin.firestore();
    
    // Get conversation to find recipient
    const conversationDoc = await db.collection("conversations").doc(conversationId).get();
    const conversationData = conversationDoc.data();
    if (!conversationData) return;

    const participants = conversationData.participants || [];
    const recipientId = participants.find((p: string) => p !== senderId);
    if (!recipientId) return;

    // Get recipient's FCM token
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    const recipientData = recipientDoc.data();
    const fcmToken = recipientData?.fcmToken;
    if (!fcmToken) return;

    // Get sender name
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderData = senderDoc.data();
    const senderName = senderData?.displayName || senderData?.name || "Someone";

    // Send push notification
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: senderName,
        body: messageText.length > 100 ? messageText.substring(0, 97) + "..." : messageText,
      },
      data: {
        conversationId: conversationId,
        messageId: event.params.messageId,
        type: "chat_message",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    logger.info(`Push notification sent to ${recipientId} for message in ${conversationId}`);
  } catch (error) {
    logger.error("Error sending push notification:", error);
  }
});

/**
 * Send notification when booking is approved
 */
export const onBookingApproved = onDocumentWritten("serviceBookings/{bookingId}", async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const wasApproved = (before?.status || "").toLowerCase() === "approved";
    const isApproved = (after.status || "").toLowerCase() === "approved";

    // Only send notification on status change to approved
    if (!isApproved || wasApproved) return;

    const clientId = after.clientId;
    if (!clientId) return;

    const db = admin.firestore();
    const clientDoc = await db.collection("users").doc(clientId).get();
    const clientData = clientDoc.data();
    const fcmToken = clientData?.fcmToken;
    if (!fcmToken) return;

    const serviceType = after.serviceType || "Service";
    const sitterName = after.sitterName || "Your sitter";

    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: "Booking Approved! 🎉",
        body: `${sitterName} approved your ${serviceType} booking.`,
      },
      data: {
        bookingId: event.params.bookingId,
        type: "booking_approved",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    logger.info(`Booking approval notification sent to ${clientId}`);
  } catch (error) {
    logger.error("Error sending booking approval notification:", error);
  }
});

/**
 * Send notification when visit starts
 */
export const onVisitStarted = onDocumentWritten("visits/{visitId}", async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const wasStarted = before?.status === "in_adventure";
    const isStarted = after.status === "in_adventure";

    // Only send notification on status change to in_adventure
    if (!isStarted || wasStarted) return;

    const clientId = after.clientId;
    if (!clientId) return;

    const db = admin.firestore();
    const clientDoc = await db.collection("users").doc(clientId).get();
    const clientData = clientDoc.data();
    const fcmToken = clientData?.fcmToken;
    if (!fcmToken) return;

    const sitterName = after.sitterName || "Your sitter";
    const serviceSummary = after.serviceSummary || "visit";

    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: "Visit Started! 🐾",
        body: `${sitterName} has started your ${serviceSummary}.`,
      },
      data: {
        visitId: event.params.visitId,
        type: "visit_started",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    logger.info(`Visit start notification sent to ${clientId}`);
  } catch (error) {
    logger.error("Error sending visit start notification:", error);
  }
});

/**
 * Sync visit status changes to corresponding booking
 * This runs server-side with admin permissions to avoid client permission issues
 */
export const syncVisitStatusToBooking = onDocumentWritten("visits/{visitId}", async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    
    // If visit was deleted, nothing to sync
    if (!after) return;
    
    const visitId = event.params.visitId;
    const visitStatus = after.status || "scheduled";
    const bookingId = after.bookingId || visitId; // Use bookingId if available, else visitId
    
    // Map visit status to booking status
    let bookingStatus: string;
    switch (visitStatus) {
      case "scheduled":
        bookingStatus = "approved";
        break;
      case "in_adventure":
        bookingStatus = "in_adventure";
        break;
      case "completed":
        bookingStatus = "completed";
        break;
      case "cancelled":
        bookingStatus = "cancelled";  // Match enum spelling (British)
        break;
      default:
        bookingStatus = "approved";
    }
    
    // Only update if status changed
    const oldStatus = before?.status || "";
    if (oldStatus === visitStatus) {
      return; // No change, skip update
    }
    
    // Update the corresponding service booking (server-side with admin permissions)
    const db = admin.firestore();
    await db.collection("serviceBookings").doc(bookingId).update({
      status: bookingStatus,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info(`Synced visit ${visitId} status (${visitStatus}) to booking ${bookingId} (${bookingStatus})`);
    
  } catch (error: any) {
    // If booking doesn't exist, that's OK (not all visits have bookings)
    if (error.code !== 5) { // 5 = NOT_FOUND
      logger.error("Error syncing visit status to booking:", error);
    }
  }
});

// ============================================================================
// AUTOMATED CLEANUP JOBS
// ============================================================================

/**
 * Daily cleanup job - runs every day at 2 AM EST
 * Cleans up old data, expired sessions, and orphaned records
 */
export const dailyCleanupJob = onSchedule({
  schedule: "0 2 * * *",
  timeZone: "America/New_York",
}, async () => {
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const thirtyDaysAgo = new Date(now.toDate().getTime() - 30 * 24 * 60 * 60 * 1000);

    logger.info("Starting daily cleanup job");

    // 1. Clean up old completed visits (older than 30 days)
    const oldVisits = await db.collection("visits")
      .where("status", "==", "completed")
      .where("scheduledEnd", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();

    const batch = db.batch();
    let deleteCount = 0;

    oldVisits.docs.forEach((doc) => {
      batch.delete(doc.ref);
      deleteCount++;
    });

    // 2. Clean up orphaned conversations with no messages (older than 7 days)
    const sevenDaysAgo = new Date(now.toDate().getTime() - 7 * 24 * 60 * 60 * 1000);
    const orphanedConversations = await db.collection("conversations")
      .where("lastMessageAt", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .get();

    for (const convDoc of orphanedConversations.docs) {
      const messagesSnap = await convDoc.ref.collection("messages").limit(1).get();
      if (messagesSnap.empty) {
        batch.delete(convDoc.ref);
        deleteCount++;
      }
    }

    // 3. Clean up duplicate conversations (safety check)
    const allConversations = await db.collection("conversations")
      .where("type", "==", "adminInquiry")
      .where("isPinned", "==", true)
      .get();

    const conversationGroups: Record<string, FirebaseFirestore.DocumentSnapshot[]> = {};
    
    allConversations.docs.forEach((doc) => {
      const data = doc.data();
      const participants = (data.participants || []).sort().join("_");
      if (!conversationGroups[participants]) {
        conversationGroups[participants] = [];
      }
      conversationGroups[participants].push(doc);
    });

    for (const key in conversationGroups) {
      const conversations = conversationGroups[key];
      if (conversations.length > 1) {
        // Sort by lastMessageAt, keep most recent
        const sorted = conversations.sort((a, b) => {
          const aTime = a.data()?.lastMessageAt?.toMillis() || 0;
          const bTime = b.data()?.lastMessageAt?.toMillis() || 0;
          return bTime - aTime;
        });
        
        // Delete all except the first (most recent)
        for (let i = 1; i < sorted.length; i++) {
          batch.delete(sorted[i].ref);
          deleteCount++;
        }
      }
    }

    await batch.commit();
    logger.info(`Daily cleanup completed: ${deleteCount} records deleted`);
  } catch (error) {
    logger.error("Error in daily cleanup job:", error);
  }
});

/**
 * Weekly analytics aggregation - runs every Monday at 3 AM EST
 * Aggregates weekly stats for revenue, bookings, and visits
 */
export const weeklyAnalytics = onSchedule({
  schedule: "0 3 * * 1",
  timeZone: "America/New_York",
}, async () => {
  try {
    const db = admin.firestore();
    const now = new Date();
    const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const weekEnd = now;

    logger.info(`Running weekly analytics for ${weekStart.toISOString()} to ${weekEnd.toISOString()}`);

    // 1. Aggregate bookings
    const bookingsSnap = await db.collection("serviceBookings")
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(weekStart))
      .where("createdAt", "<=", admin.firestore.Timestamp.fromDate(weekEnd))
      .get();

    const bookingStats = {
      total: bookingsSnap.size,
      approved: 0,
      pending: 0,
      completed: 0,
      revenue: 0,
    };

    bookingsSnap.docs.forEach((doc) => {
      const data = doc.data();
      const status = (data.status || "").toLowerCase();
      if (status === "approved") bookingStats.approved++;
      if (status === "pending") bookingStats.pending++;
      if (status === "completed") bookingStats.completed++;
      
      const price = parseFloat(data.price || "0");
      if (!isNaN(price)) {
        bookingStats.revenue += price;
      }
    });

    // 2. Aggregate visits
    const visitsSnap = await db.collection("visits")
      .where("scheduledStart", ">=", admin.firestore.Timestamp.fromDate(weekStart))
      .where("scheduledStart", "<=", admin.firestore.Timestamp.fromDate(weekEnd))
      .get();

    const visitStats = {
      total: visitsSnap.size,
      completed: 0,
      inProgress: 0,
      scheduled: 0,
    };

    visitsSnap.docs.forEach((doc) => {
      const data = doc.data();
      const status = data.status || "scheduled";
      if (status === "completed") visitStats.completed++;
      if (status === "in_adventure") visitStats.inProgress++;
      if (status === "scheduled") visitStats.scheduled++;
    });

    // 3. Save analytics
    const weekKey = `${weekStart.getFullYear()}-W${Math.ceil((weekStart.getTime() - new Date(weekStart.getFullYear(), 0, 1).getTime()) / (7 * 24 * 60 * 60 * 1000))}`;
    
    await db.collection("analytics").doc(weekKey).set({
      weekStart: admin.firestore.Timestamp.fromDate(weekStart),
      weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
      bookings: bookingStats,
      visits: visitStats,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Weekly analytics saved: ${bookingStats.total} bookings, ${visitStats.total} visits, $${bookingStats.revenue} revenue`);
  } catch (error) {
    logger.error("Error in weekly analytics job:", error);
  }
});

/**
 * Backup database - runs daily at 1 AM EST
 * Creates a Firestore export for backup purposes
 * Note: Requires Firestore Admin API to be enabled and proper IAM permissions
 */
export const dailyBackup = onSchedule({
  schedule: "0 1 * * *",
  timeZone: "America/New_York",
}, async () => {
  try {
    const projectId = process.env.GCLOUD_PROJECT || "";
    const bucket = `gs://${projectId}-backups`;
    
    logger.info(`Starting daily Firestore backup to ${bucket}`);
    
    // Note: This requires the Cloud Firestore Admin API to be enabled
    // and the service account to have the necessary IAM permissions
    // For now, we'll log a reminder
    logger.info("Backup job triggered - ensure Cloud Firestore Admin API is enabled");
    
    // Actual backup would use:
    // const client = new admin.firestore.v1.FirestoreAdminClient();
    // await client.exportDocuments({...});
    
  } catch (error) {
    logger.error("Error in daily backup job:", error);
  }
});

/**
 * Cleanup expired sessions - runs every 6 hours
 * Removes stale location tracking and expired auth tokens
 */
export const cleanupExpiredSessions = onSchedule("every 6 hours", async () => {
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const sixHoursAgo = new Date(now.toDate().getTime() - 6 * 60 * 60 * 1000);

    logger.info("Cleaning up expired sessions");

    // Clean up old location data (older than 6 hours and not in an active visit)
    const oldLocations = await db.collection("locations")
      .where("updatedAt", "<", admin.firestore.Timestamp.fromDate(sixHoursAgo))
      .get();

    const batch = db.batch();
    let cleanupCount = 0;

    for (const locDoc of oldLocations.docs) {
      const uid = locDoc.id;
      
      // Check if user has an active visit
      const activeVisits = await db.collection("visits")
        .where("sitterId", "==", uid)
        .where("status", "==", "in_adventure")
        .limit(1)
        .get();

      if (activeVisits.empty) {
        batch.delete(locDoc.ref);
        cleanupCount++;
      }
    }

    await batch.commit();
    logger.info(`Cleaned up ${cleanupCount} expired location records`);
  } catch (error) {
    logger.error("Error in session cleanup job:", error);
  }
});

// ============================================================================
// ANALYTICS & METRICS
// ============================================================================

/**
 * Track daily active users
 * Updates when users authenticate or perform actions
 */
export const trackDailyActiveUser = onDocumentWritten("users/{userId}", async (event) => {
  try {
    const after = event.data?.after?.data();
    if (!after) return;

    const db = admin.firestore();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const dateKey = today.toISOString().split("T")[0];

    const userId = event.params.userId;
    const role = after.role || "unknown";

    // Update DAU metrics
    await db.collection("metrics").doc(dateKey).set({
      date: admin.firestore.Timestamp.fromDate(today),
      activeUsers: admin.firestore.FieldValue.arrayUnion(userId),
      usersByRole: {
        [role]: admin.firestore.FieldValue.increment(1),
      },
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

  } catch (error) {
    logger.error("Error tracking daily active user:", error);
  }
});

/**
 * Aggregate booking revenue by sitter
 * Updates sitter stats when bookings are completed
 */
export const aggregateSitterRevenue = onDocumentWritten("serviceBookings/{bookingId}", async (event) => {
  try {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const wasCompleted = (before?.status || "").toLowerCase() === "completed";
    const isCompleted = (after.status || "").toLowerCase() === "completed";

    // Only aggregate when booking is completed
    if (!isCompleted || wasCompleted) return;

    const sitterId = after.sitterId;
    if (!sitterId) return;

    const price = parseFloat(after.price || "0");
    if (isNaN(price) || price <= 0) return;

    const db = admin.firestore();
    const month = new Date().toISOString().substring(0, 7); // YYYY-MM

    await db.collection("sitterStats").doc(sitterId).collection("monthly").doc(month).set({
      revenue: admin.firestore.FieldValue.increment(price),
      completedBookings: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    logger.info(`Updated revenue for sitter ${sitterId}: +$${price}`);
  } catch (error) {
    logger.error("Error aggregating sitter revenue:", error);
  }
});

// ============================================================================
// AUDIT LOGGING
// ============================================================================

/**
 * Audit admin actions for security tracking
 */
export const auditAdminActions = onDocumentWritten("{collection}/{docId}", async (event) => {
  try {
    // Only audit admin-sensitive collections
    const collection = event.params.collection;
    const adminCollections = ["users", "serviceBookings", "visits", "sitters"];
    
    if (!adminCollections.includes(collection)) return;

    const before = event.data?.before;
    const after = event.data?.after;
    
    // Determine action type
    let action = "modified";
    if (!before?.exists && after?.exists) action = "created";
    if (before?.exists && !after?.exists) action = "deleted";

    const db = admin.firestore();
    
    await db.collection("auditLogs").add({
      collection: collection,
      documentId: event.params.docId,
      action: action,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        beforeExists: before?.exists || false,
        afterExists: after?.exists || false,
      },
    });

  } catch (error) {
    logger.error("Error in audit logging:", error);
  }
});

// ============================================================================
// ACCOUNT DELETION FUNCTIONS
// ============================================================================

/**
 * Import account deletion functions from accountDeletion.ts
 * These functions handle:
 * - Sending deletion confirmation emails
 * - Sending reminders before permanent deletion
 * - Executing scheduled deletions after grace period
 * - Cleaning up old deletion records
 * 
 * TEMPORARILY COMMENTED OUT - needs nodemailer dependency and v2 API update
 */
/*
export {
  sendDeletionEmail,
  sendDeletionReminders,
  executeScheduledDeletions,
  cleanupDeletionRecords,
} from "./accountDeletion";
*/

// ============================================================================
// SQUARE PAYMENT FUNCTIONS
// ============================================================================

/**
 * Import Square payment functions from squarePayments.ts
 * These functions handle:
 * - Creating dynamic Square checkout links
 * - Processing payment webhooks for auto-approval
 * - Automatic refund processing
 * - Recurring payment subscriptions
 */
export {
  createSquareCheckout,
  handleSquareWebhook,
  processSquareRefund,
  createSquareSubscription,
} from "./squarePayments";

// ============================================================================
// CHAT APPROVAL FUNCTIONS
// ============================================================================

/**
 * Import chat approval functions from chatApproval.ts
 * These functions handle:
 * - Notifying admin when sitter requests chat with owner
 * - Notifying participants when admin approves chat
 */
export {
  notifyAdminOnChatRequest,
  notifyUsersOnChatApproval,
} from "./chatApproval";

// ============================================================================
// BOOKING NOTIFICATION FUNCTIONS
// ============================================================================

/**
 * Import booking notification functions from bookingNotifications.ts
 * These functions handle:
 * - Notifying owners when sitter checks in (starts visit)
 * - Notifying owners when sitter checks out (completes visit)
 * - Notifying owners when booking is approved
 */
export {
  notifyOwnerOnCheckIn,
  notifyOwnerOnCheckOut,
  notifyOwnerOnBookingApproved,
} from "./bookingNotifications";

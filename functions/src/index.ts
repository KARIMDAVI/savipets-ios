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
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

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

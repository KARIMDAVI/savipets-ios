/**
 * Booking Status Notification Functions
 * 
 * Sends push notifications to owners when:
 * 1. Sitter checks in (status → in_adventure)
 * 2. Sitter checks out (status → completed)
 */

import {onDocumentUpdated} from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

/**
 * Notify owner when sitter starts a visit (check-in)
 */
export const notifyOwnerOnCheckIn = onDocumentUpdated(
  'serviceBookings/{bookingId}',
  async (event) => {
    try {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();
      
      if (!before || !after) return;
      
      // Check if status changed to "in_adventure" (On an Adventure)
      const statusChanged = before.status !== 'in_adventure' && after.status === 'in_adventure';
      
      if (!statusChanged) return;
      
      const bookingId = event.params.bookingId;
      const ownerId = after.clientId;
      const petNames = after.pets?.join(', ') || 'your pet';
      const sitterName = after.sitterName || 'Your sitter';
      
      logger.info(`Check-in detected for booking ${bookingId} - Notifying owner ${ownerId}`);
      
      // Send push notification to owner
      await sendPushNotification(ownerId, {
        title: '🐾 On an Adventure!',
        body: `${sitterName} just started a visit with ${petNames}.`,
        data: {
          type: 'booking_started',
          bookingId: bookingId,
        },
      });
      
      // Create in-app notification
      await createInAppNotification(ownerId, {
        type: 'booking_started',
        title: '🐾 On an Adventure!',
        message: `${sitterName} just started a visit with ${petNames}.`,
        bookingId: bookingId,
      });
      
      logger.info(`✅ Check-in notification sent to owner ${ownerId}`);
      
    } catch (error) {
      logger.error('Error in notifyOwnerOnCheckIn:', error);
    }
  }
);

/**
 * Notify owner when sitter completes a visit (check-out)
 */
export const notifyOwnerOnCheckOut = onDocumentUpdated(
  'serviceBookings/{bookingId}',
  async (event) => {
    try {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();
      
      if (!before || !after) return;
      
      // Check if status changed to "completed"
      const statusChanged = before.status !== 'completed' && after.status === 'completed';
      
      if (!statusChanged) return;
      
      const bookingId = event.params.bookingId;
      const ownerId = after.clientId;
      const petNames = after.pets?.join(', ') || 'your pet';
      
      logger.info(`Check-out detected for booking ${bookingId} - Notifying owner ${ownerId}`);
      
      // Send push notification to owner
      await sendPushNotification(ownerId, {
        title: '✅ Visit Complete!',
        body: `${petNames}'s visit is complete! Check out your visit summary.`,
        data: {
          type: 'booking_completed',
          bookingId: bookingId,
        },
      });
      
      // Create in-app notification
      await createInAppNotification(ownerId, {
        type: 'booking_completed',
        title: '✅ Visit Complete!',
        message: `${petNames}'s visit is complete! Check out your visit summary.`,
        bookingId: bookingId,
      });
      
      logger.info(`✅ Check-out notification sent to owner ${ownerId}`);
      
    } catch (error) {
      logger.error('Error in notifyOwnerOnCheckOut:', error);
    }
  }
);

/**
 * Send push notification via FCM
 */
async function sendPushNotification(
  userId: string,
  payload: {
    title: string;
    body: string;
    data?: Record<string, string>;
  }
) {
  try {
    const db = admin.firestore();
    
    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    
    if (!fcmToken) {
      logger.warn(`No FCM token found for user ${userId}`);
      return;
    }
    
    // Send FCM notification
    const message = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      token: fcmToken,
    };
    
    await admin.messaging().send(message);
    logger.info(`Push notification sent to ${userId}`);
    
  } catch (error) {
    logger.error(`Failed to send push notification to ${userId}:`, error);
    // Don't throw - notification failure shouldn't break the flow
  }
}

/**
 * Create in-app notification document
 */
async function createInAppNotification(
  userId: string,
  notification: {
    type: string;
    title: string;
    message: string;
    bookingId: string;
  }
) {
  try {
    const db = admin.firestore();
    
    await db.collection('notifications').add({
      recipientId: userId,
      type: notification.type,
      title: notification.title,
      message: notification.message,
      bookingId: notification.bookingId,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info(`In-app notification created for user ${userId}`);
    
  } catch (error) {
    logger.error(`Failed to create in-app notification for ${userId}:`, error);
  }
}

/**
 * Notify owner when booking is approved (after payment)
 */
export const notifyOwnerOnBookingApproved = onDocumentUpdated(
  'serviceBookings/{bookingId}',
  async (event) => {
    try {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();
      
      if (!before || !after) return;
      
      // Check if status changed to "approved"
      const statusChanged = before.status !== 'approved' && after.status === 'approved';
      
      if (!statusChanged) return;
      
      const bookingId = event.params.bookingId;
      const ownerId = after.clientId;
      const serviceType = after.serviceType || 'Service';
      const scheduledDate = after.scheduledDate?.toDate();
      
      logger.info(`Booking approved: ${bookingId} - Notifying owner ${ownerId}`);
      
      // Format date
      const dateStr = scheduledDate 
        ? scheduledDate.toLocaleDateString('en-US', { 
            weekday: 'short', 
            month: 'short', 
            day: 'numeric' 
          })
        : 'soon';
      
      // Send push notification to owner
      await sendPushNotification(ownerId, {
        title: '✅ Booking Confirmed!',
        body: `Your ${serviceType} booking for ${dateStr} has been confirmed.`,
        data: {
          type: 'booking_approved',
          bookingId: bookingId,
        },
      });
      
      // Create in-app notification
      await createInAppNotification(ownerId, {
        type: 'booking_approved',
        title: '✅ Booking Confirmed!',
        message: `Your ${serviceType} booking for ${dateStr} has been confirmed.`,
        bookingId: bookingId,
      });
      
      logger.info(`✅ Approval notification sent to owner ${ownerId}`);
      
    } catch (error) {
      logger.error('Error in notifyOwnerOnBookingApproved:', error);
    }
  }
);



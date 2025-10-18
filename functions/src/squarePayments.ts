/**
 * Square Payments Integration
 * 
 * This file handles:
 * 1. Creating dynamic Square checkout links
 * 2. Processing webhooks for auto-approval
 * 3. Automatic refunds
 * 4. Subscription/recurring payments
 */

import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onRequest} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

// Square SDK types (install with: npm install square)
// For now, using fetch API directly to avoid dependency issues

// Square API configuration
const getSquareConfig = () => {
  const env = process.env.SQUARE_ENVIRONMENT || 'sandbox';
  
  return {
    accessToken: env === 'production' 
      ? process.env.SQUARE_PRODUCTION_TOKEN 
      : process.env.SQUARE_SANDBOX_TOKEN,
    environment: env,
    locationId: process.env.SQUARE_LOCATION_ID,
    applicationId: env === 'production'
      ? process.env.SQUARE_APPLICATION_ID
      : process.env.SQUARE_SANDBOX_APPLICATION_ID,
  };
};

const SQUARE_API_BASE = (env: string) => 
  env === 'production' 
    ? 'https://connect.squareup.com' 
    : 'https://connect.squareupsandbox.com';

/**
 * Create Square checkout link for a booking
 * Callable from iOS app
 */
export const createSquareCheckout = onCall(async (request) => {
  // 1. Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in');
  }
  
  const userId = request.auth.uid;
  const userEmail = request.auth.token.email || '';
  
  const { 
    bookingId, 
    serviceType, 
    price, 
    numberOfVisits = 1,
    isRecurring = false,
    frequency = 'once',
    pets = [],
    scheduledDate = '',
  } = request.data;
  
  // 2. Validate booking ownership
  const db = admin.firestore();
  logger.info(`Looking for booking document: ${bookingId}`);
  const bookingDoc = await db.collection('serviceBookings').doc(bookingId).get();
  
  if (!bookingDoc.exists) {
    logger.error(`Booking document not found: ${bookingId}`);
    throw new HttpsError('not-found', 'Booking not found');
  }
  
  const bookingData = bookingDoc.data();
  logger.info(`Booking found, clientId: ${bookingData?.clientId}, userId: ${userId}`);
  
  if (bookingData?.clientId !== userId) {
    logger.error(`Booking ownership mismatch: booking.clientId=${bookingData?.clientId}, userId=${userId}`);
    throw new HttpsError('permission-denied', 'Not your booking');
  }
  
  try {
    const config = getSquareConfig();
    const apiBase = SQUARE_API_BASE(config.environment);
    
    // 3. Build order for Square
    const orderData = {
      idempotency_key: `${bookingId}_${Date.now()}`,
      order: {
        location_id: config.locationId,
        line_items: [{
          name: serviceType,
          quantity: numberOfVisits.toString(),
          base_price_money: {
            amount: Math.round(price * 100), // Convert to cents
            currency: 'USD',
          },
          note: pets.length > 0 ? `Pets: ${pets.join(', ')}` : undefined,
        }],
        metadata: {
          bookingId: bookingId,
          userId: userId,
          isRecurring: isRecurring.toString(),
          frequency: frequency,
          scheduledDate: scheduledDate,
        },
      },
      checkout_options: {
        redirect_url: `savipets://booking/${bookingId}/success`,
        ask_for_shipping_address: false,
        accepted_payment_methods: {
          apple_pay: true,
          google_pay: true,
          cash_app_pay: true,
          afterpay_clearpay: true,
        },
      },
      pre_populated_data: {
        buyer_email: userEmail,
      },
    };
    
    // 4. Create payment link via Square API
    const response = await fetch(`${apiBase}/v2/online-checkout/payment-links`, {
      method: 'POST',
      headers: {
        'Square-Version': '2024-12-18',
        'Authorization': `Bearer ${config.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(orderData),
    });
    
    if (!response.ok) {
      const error = await response.json();
      logger.error('Square API error:', error);
      throw new Error(`Square API error: ${JSON.stringify(error)}`);
    }
    
    const result = await response.json();
    const paymentLink = result.payment_link;
    
    // 5. Store Square data in Firestore
    await bookingDoc.ref.update({
      squareOrderId: paymentLink.order_id,
      squarePaymentLinkId: paymentLink.id,
      squareCheckoutUrl: paymentLink.url,
      paymentStatus: 'pending',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info(`Square checkout created for booking ${bookingId}: ${paymentLink.url}`);
    
    // 6. Return checkout URL to app
    return {
      success: true,
      checkoutUrl: paymentLink.url,
      orderId: paymentLink.order_id,
    };
    
  } catch (error: any) {
    logger.error('Error creating Square checkout:', error);
    throw new HttpsError('internal', `Failed to create checkout: ${error.message}`);
  }
});

/**
 * Handle Square webhook events
 * Auto-approve bookings when payment succeeds
 */
export const handleSquareWebhook = onRequest(async (req, res) => {
  try {
    const event = req.body;
    
    logger.info(`Square webhook received: ${event.type}`);
    
    // Handle different event types
    switch (event.type) {
      case 'payment.created':
      case 'payment.updated':
        await handlePaymentEvent(event.data?.object?.payment);
        break;
      
      case 'refund.created':
      case 'refund.updated':
        await handleRefundEvent(event.data?.object?.refund);
        break;
      
      default:
        logger.info(`Unhandled webhook event: ${event.type}`);
    }
    
    res.status(200).send('OK');
    
  } catch (error) {
    logger.error('Webhook processing error:', error);
    res.status(500).send('Error');
  }
});

/**
 * Handle payment events - Auto-approve bookings
 */
async function handlePaymentEvent(payment: any) {
  if (!payment) return;
  
  const orderId = payment.order_id;
  const paymentId = payment.id;
  const status = payment.status;
  
  logger.info(`Processing payment ${paymentId}, status: ${status}`);
  
  // Only process completed payments
  if (status !== 'COMPLETED') {
    logger.info(`Payment not completed yet: ${status}`);
    return;
  }
  
  try {
    const config = getSquareConfig();
    const apiBase = SQUARE_API_BASE(config.environment);
    
    // Get order to find booking ID
    const orderResponse = await fetch(`${apiBase}/v2/orders/${orderId}`, {
      headers: {
        'Square-Version': '2024-12-18',
        'Authorization': `Bearer ${config.accessToken}`,
      },
    });
    
    if (!orderResponse.ok) {
      logger.error('Failed to fetch order');
      return;
    }
    
    const orderData = await orderResponse.json();
    const bookingId = orderData.order?.metadata?.bookingId;
    
    if (!bookingId) {
      logger.error('No bookingId in order metadata');
      return;
    }
    
    const db = admin.firestore();
    
    // ✅ AUTO-APPROVE BOOKING!
    await db.collection('serviceBookings').doc(bookingId).update({
      status: 'approved',
      paymentStatus: 'completed',
      squarePaymentId: paymentId,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: 'system_auto',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info(`✅ Booking ${bookingId} auto-approved after payment`);
    
    // Send confirmation notification
    await sendBookingConfirmationNotification(bookingId);
    
  } catch (error) {
    logger.error('Error processing payment:', error);
  }
}

/**
 * Handle refund events
 */
async function handleRefundEvent(refund: any) {
  if (!refund) return;
  
  const paymentId = refund.payment_id;
  const refundId = refund.id;
  const status = refund.status;
  
  logger.info(`Processing refund ${refundId}, status: ${status}`);
  
  if (status !== 'COMPLETED' && status !== 'PENDING') return;
  
  try {
    const db = admin.firestore();
    
    // Find booking by payment ID
    const bookingsSnapshot = await db.collection('serviceBookings')
      .where('squarePaymentId', '==', paymentId)
      .get();
    
    if (bookingsSnapshot.empty) {
      logger.warn(`No booking found for payment ${paymentId}`);
      return;
    }
    
    const bookingDoc = bookingsSnapshot.docs[0];
    
    // Mark refund as processed
    await bookingDoc.ref.update({
      refundProcessed: true,
      refundProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
      refundMethod: 'square_api',
      squareRefundId: refundId,
      paymentStatus: 'refunded',
    });
    
    logger.info(`✅ Refund processed for booking ${bookingDoc.id}`);
    
  } catch (error) {
    logger.error('Error processing refund:', error);
  }
}

/**
 * Send booking confirmation notification
 */
async function sendBookingConfirmationNotification(bookingId: string) {
  const db = admin.firestore();
  
  try {
    const bookingDoc = await db.collection('serviceBookings').doc(bookingId).get();
    const booking = bookingDoc.data();
    
    if (!booking) return;
    
    // Create notification for Cloud Function to send
    await db.collection('notifications').add({
      type: 'booking_confirmed',
      recipientId: booking.clientId,
      bookingId: bookingId,
      serviceType: booking.serviceType,
      scheduledDate: booking.scheduledDate,
      scheduledTime: booking.scheduledTime,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
    });
    
    logger.info(`Confirmation notification queued for booking ${bookingId}`);
    
  } catch (error) {
    logger.error('Error sending confirmation:', error);
  }
}

/**
 * Process Square refund
 * Callable from iOS app when booking is canceled
 */
export const processSquareRefund = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in');
  }
  
  const { bookingId, refundAmount, reason } = request.data;
  
  try {
    const db = admin.firestore();
    const bookingDoc = await db.collection('serviceBookings').doc(bookingId).get();
    
    if (!bookingDoc.exists) {
      throw new HttpsError('not-found', 'Booking not found');
    }
    
    const booking = bookingDoc.data();
    
    // Verify ownership
    if (booking?.clientId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Not your booking');
    }
    
    const paymentId = booking?.squarePaymentId;
    if (!paymentId) {
      throw new HttpsError('failed-precondition', 'No payment to refund');
    }
    
    // Create refund via Square API
    const config = getSquareConfig();
    const apiBase = SQUARE_API_BASE(config.environment);
    
    const refundData = {
      idempotency_key: `refund_${bookingId}_${Date.now()}`,
      amount_money: {
        amount: Math.round(refundAmount * 100), // Convert to cents
        currency: 'USD',
      },
      payment_id: paymentId,
      reason: reason || 'Booking canceled by customer',
    };
    
    const response = await fetch(`${apiBase}/v2/refunds`, {
      method: 'POST',
      headers: {
        'Square-Version': '2024-12-18',
        'Authorization': `Bearer ${config.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(refundData),
    });
    
    if (!response.ok) {
      const error = await response.json();
      logger.error('Square refund error:', error);
      throw new Error('Refund failed');
    }
    
    const result = await response.json();
    
    logger.info(`✅ Refund created: ${result.refund?.id}`);
    
    return {
      success: true,
      refundId: result.refund?.id,
      status: result.refund?.status,
    };
    
  } catch (error: any) {
    logger.error('Error processing refund:', error);
    throw new HttpsError('internal', error.message);
  }
});

/**
 * Create Square subscription for recurring bookings
 */
export const createSquareSubscription = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in');
  }
  
  const { seriesId, planId, customerId } = request.data;
  
  try {
    const config = getSquareConfig();
    const apiBase = SQUARE_API_BASE(config.environment);
    
    // Create subscription
    const subscriptionData = {
      idempotency_key: `sub_${seriesId}_${Date.now()}`,
      location_id: config.locationId,
      plan_id: planId,
      customer_id: customerId,
      card_id: request.data.cardId, // Saved card from previous payment
      start_date: request.data.startDate,
    };
    
    const response = await fetch(`${apiBase}/v2/subscriptions`, {
      method: 'POST',
      headers: {
        'Square-Version': '2024-12-18',
        'Authorization': `Bearer ${config.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(subscriptionData),
    });
    
    if (!response.ok) {
      const error = await response.json();
      logger.error('Square subscription error:', error);
      throw new Error('Subscription creation failed');
    }
    
    const result = await response.json();
    
    // Store subscription info
    await admin.firestore().collection('recurringSeries').doc(seriesId).update({
      squareSubscriptionId: result.subscription?.id,
      subscriptionStatus: result.subscription?.status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info(`✅ Subscription created: ${result.subscription?.id}`);
    
    return {
      success: true,
      subscriptionId: result.subscription?.id,
    };
    
  } catch (error: any) {
    logger.error('Error creating subscription:', error);
    throw new HttpsError('internal', error.message);
  }
});



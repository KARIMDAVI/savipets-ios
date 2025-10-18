/**
 * Chat Approval System - Cloud Functions
 * 
 * Handles admin approval workflow for sitter-owner conversations:
 * 1. notifyAdminOnChatRequest - Alerts admin when sitter requests to chat with owner
 * 2. notifyUsersOnChatApproval - Notifies both participants when admin approves chat
 */

import {onDocumentCreated, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

/**
 * Notify admin when a new chat request is created
 * Triggers when: New conversation with status = "pending"
 */
export const notifyAdminOnChatRequest = onDocumentCreated(
  'conversations/{conversationId}',
  async (event) => {
    try {
      const conversation = event.data?.data();
      
      if (!conversation) return;
      
      const conversationId = event.params.conversationId;
      const status = conversation.status || 'active';
      const type = conversation.type || '';
      
      // Only process pending chat requests for sitter-owner conversations
      if (status !== 'pending') {
        logger.info(`Conversation ${conversationId} is not pending (status: ${status}), skipping notification`);
        return;
      }
      
      if (type !== 'sitter-to-client' && type !== 'client-sitter') {
        logger.info(`Conversation ${conversationId} is not sitter-owner type (type: ${type}), skipping notification`);
        return;
      }
      
      logger.info(`New chat request detected: ${conversationId}`);
      
      const participants = conversation.participants || [];
      const participantRoles = conversation.participantRoles || [];
      
      // Find sitter and owner names
      const db = admin.firestore();
      let sitterName = 'A sitter';
      let ownerName = 'an owner';
      
      for (let i = 0; i < participants.length; i++) {
        const userId = participants[i];
        const role = participantRoles[i];
        
        try {
          const userDoc = await db.collection('users').doc(userId).get();
          const userName = userDoc.data()?.displayName || userDoc.data()?.name || 'User';
          
          if (role === 'petSitter') {
            sitterName = userName;
          } else if (role === 'petOwner') {
            ownerName = userName;
          }
        } catch (error) {
          logger.warn(`Could not fetch user ${userId}:`, error);
        }
      }
      
      // Find all admins and notify them
      const adminsSnapshot = await db.collection('users')
        .where('role', '==', 'admin')
        .get();
      
      if (adminsSnapshot.empty) {
        logger.warn('No admin users found to notify');
        return;
      }
      
      const notificationPromises = adminsSnapshot.docs.map(async (adminDoc) => {
        const adminId = adminDoc.id;
        const fcmToken = adminDoc.data().fcmToken;
        
        // Create in-app notification
        await db.collection('notifications').add({
          recipientId: adminId,
          type: 'chat_request',
          title: '💬 New Chat Request',
          message: `${sitterName} requested to start a conversation with ${ownerName}.`,
          conversationId: conversationId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Send push notification if FCM token available
        if (fcmToken) {
          try {
            await admin.messaging().send({
              notification: {
                title: '💬 New Chat Request',
                body: `${sitterName} wants to chat with ${ownerName}. Review and approve.`,
              },
              data: {
                type: 'chat_request',
                conversationId: conversationId,
              },
              token: fcmToken,
            });
            
            logger.info(`Push notification sent to admin ${adminId}`);
          } catch (error) {
            logger.warn(`Failed to send push to admin ${adminId}:`, error);
          }
        }
      });
      
      await Promise.all(notificationPromises);
      
      logger.info(`✅ Chat request notification sent for conversation ${conversationId}`);
      
    } catch (error) {
      logger.error('Error in notifyAdminOnChatRequest:', error);
    }
  }
);

/**
 * Notify participants when admin approves a chat
 * Triggers when: Conversation status changes from "pending" to "active"
 */
export const notifyUsersOnChatApproval = onDocumentUpdated(
  'conversations/{conversationId}',
  async (event) => {
    try {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();
      
      if (!before || !after) return;
      
      const conversationId = event.params.conversationId;
      
      // Check if status changed from pending to active
      const statusChanged = before.status === 'pending' && after.status === 'active';
      
      if (!statusChanged) {
        return;
      }
      
      logger.info(`Chat approved: ${conversationId} - Notifying participants`);
      
      const participants = after.participants || [];
      const db = admin.firestore();
      
      // Notify each participant
      const notificationPromises = participants.map(async (userId: string) => {
        try {
          // Get user info
          const userDoc = await db.collection('users').doc(userId).get();
          const fcmToken = userDoc.data()?.fcmToken;
          
          // Create in-app notification
          await db.collection('notifications').add({
            recipientId: userId,
            type: 'chat_approved',
            title: '✅ Chat Approved',
            message: 'Your chat has been approved by Admin. You can now send messages.',
            conversationId: conversationId,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          // Send push notification
          if (fcmToken) {
            try {
              await admin.messaging().send({
                notification: {
                  title: '✅ Chat Approved',
                  body: 'Your chat request has been approved. Start messaging now!',
                },
                data: {
                  type: 'chat_approved',
                  conversationId: conversationId,
                },
                token: fcmToken,
              });
              
              logger.info(`Push notification sent to user ${userId}`);
            } catch (error) {
              logger.warn(`Failed to send push to ${userId}:`, error);
            }
          }
        } catch (error) {
          logger.warn(`Error notifying user ${userId}:`, error);
        }
      });
      
      await Promise.all(notificationPromises);
      
      logger.info(`✅ Chat approval notifications sent for conversation ${conversationId}`);
      
    } catch (error) {
      logger.error('Error in notifyUsersOnChatApproval:', error);
    }
  }
);


import { Request, Response } from 'express';
import { SubscriptionSyncService } from '../services/subscriptionSyncService';

const syncService = new SubscriptionSyncService();

/**
 * Controller handling Google Cloud Pub/Sub push messages for Google Play RTDN
 */
export const handleGooglePlayRtdnWebhook = async (req: Request, res: Response): Promise<void> => {
  try {
    const pubsubMessage = req.body?.message;

    if (!pubsubMessage || !pubsubMessage.data) {
      console.warn('[WebhookController] Received malformed Pub/Sub payload');
      res.status(400).json({ error: 'Invalid Pub/Sub message structure' });
      return;
    }

    const messageId = pubsubMessage.messageId || `msg_${Date.now()}`;
    const rawData = Buffer.from(pubsubMessage.data, 'base64').toString('utf-8');
    const developerNotification = JSON.parse(rawData);

    console.log(`[WebhookController] Ingesting RTDN Notification ID: ${messageId}`);

    // Process notification asynchronously or synchronously
    await syncService.handleRtdnNotification(developerNotification, messageId);

    // Google Cloud Pub/Sub requires HTTP 200/204 to acknowledge delivery
    res.status(200).json({ status: 'acknowledged', messageId });
  } catch (err: any) {
    console.error('[WebhookController] Error processing RTDN Webhook:', err);
    // Return 200 on non-retryable format errors to avoid infinite Pub/Sub retry storms
    res.status(200).json({ status: 'failed_logged', error: err.message });
  }
};

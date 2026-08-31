import { google } from 'googleapis';
import dotenv from 'dotenv';

dotenv.config();

export interface VerifiedSubscriptionDetails {
  subscriptionState: string;
  expiryTime: Date;
  startTime: Date;
  autoRenewing: boolean;
  orderId?: string;
  productId: string;
  linkedPurchaseToken?: string;
}

export class GooglePlayService {
  private androidPublisher;
  private packageName: string;

  constructor() {
    this.packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.asiverticals.ledgify';

    const serviceAccountJson = process.env.GOOGLE_SERVICE_ACCOUNT_KEY_JSON;
    let authClient;

    if (serviceAccountJson) {
      try {
        const credentials = JSON.parse(serviceAccountJson);
        authClient = new google.auth.JWT({
          email: credentials.client_email,
          key: credentials.private_key,
          scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });
      } catch (err) {
        console.error('[GooglePlayService] Failed to parse GOOGLE_SERVICE_ACCOUNT_KEY_JSON:', err);
        authClient = new google.auth.GoogleAuth({
          scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });
      }
    } else {
      authClient = new google.auth.GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
      });
    }

    this.androidPublisher = google.androidpublisher({
      version: 'v3',
      auth: authClient,
    });
  }

  /**
   * Verifies an active subscription purchase token using Google Play Developer API (v3)
   */
  async verifySubscriptionPurchase(
    subscriptionId: string,
    purchaseToken: string,
    packageName?: string
  ): Promise<VerifiedSubscriptionDetails> {
    const pkg = packageName || this.packageName;

    try {
      // Use Subscriptions v2 get endpoint
      const response = await this.androidPublisher.purchases.subscriptionsv2.get({
        packageName: pkg,
        token: purchaseToken,
      });

      const data = response.data;
      const lineItem = data.lineItems?.[0];
      const expiryMillis = lineItem?.expiryTime
        ? parseInt(lineItem.expiryTime, 10)
        : Date.now() + 30 * 24 * 60 * 60 * 1000;
      const startMillis = data.startTime ? parseInt(data.startTime, 10) : Date.now();

      return {
        subscriptionState: data.subscriptionState || 'SUBSCRIPTION_STATE_ACTIVE',
        expiryTime: new Date(expiryMillis),
        startTime: new Date(startMillis),
        autoRenewing: lineItem?.autoRenewingPlan?.autoRenewEnabled ?? true,
        orderId: data.latestOrderId || undefined,
        productId: lineItem?.productId || subscriptionId,
        linkedPurchaseToken: data.linkedPurchaseToken || undefined,
      };
    } catch (err: any) {
      console.error(`[GooglePlayService] Verification failed for token ${purchaseToken.substring(0, 10)}...:`, err.message);
      throw err;
    }
  }

  /**
   * Acknowledges a subscription purchase to prevent automatic refund
   */
  async acknowledgeSubscriptionPurchase(
    subscriptionId: string,
    purchaseToken: string,
    packageName?: string
  ): Promise<void> {
    const pkg = packageName || this.packageName;

    try {
      await this.androidPublisher.purchases.subscriptions.acknowledge({
        packageName: pkg,
        subscriptionId,
        token: purchaseToken,
      });
      console.log(`[GooglePlayService] Successfully acknowledged subscription: ${subscriptionId}`);
    } catch (err: any) {
      // 400 with 'already acknowledged' is non-fatal
      if (err.message?.includes('already acknowledged') || err.status === 400) {
        console.warn(`[GooglePlayService] Purchase token already acknowledged: ${subscriptionId}`);
        return;
      }
      console.error(`[GooglePlayService] Acknowledge error:`, err.message);
      throw err;
    }
  }
}

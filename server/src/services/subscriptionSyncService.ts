import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { GooglePlayService, VerifiedSubscriptionDetails } from './googlePlayService';

dotenv.config();

export interface RTDNSubscriptionNotification {
  version: string;
  notificationType: number;
  purchaseToken: string;
  subscriptionId: string;
}

export interface RTDNDeveloperNotification {
  version: string;
  packageName: string;
  eventTimeMillis: string;
  subscriptionNotification?: RTDNSubscriptionNotification;
  testNotification?: {
    version: string;
  };
}

export class SubscriptionSyncService {
  private supabase: SupabaseClient;
  private googlePlayService: GooglePlayService;

  constructor(googlePlayService?: GooglePlayService) {
    const supabaseUrl = process.env.SUPABASE_URL || 'https://supabase.local';
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'service-role-key';

    this.supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });
    this.googlePlayService = googlePlayService || new GooglePlayService();
  }

  /**
   * Processes Google Cloud Pub/Sub RTDN developer notification
   */
  async handleRtdnNotification(
    notification: RTDNDeveloperNotification,
    eventId: string
  ): Promise<void> {
    const subNotif = notification.subscriptionNotification;

    if (!subNotif) {
      if (notification.testNotification) {
        console.log('[SubscriptionSyncService] Received RTDN Test Notification');
        await this.logWebhook(eventId, 'TEST_NOTIFICATION', 'N/A', notification, 'PROCESSED');
      }
      return;
    }

    const { subscriptionId, purchaseToken, notificationType } = subNotif;
    const status = this.mapNotificationTypeToStatus(notificationType);
    const eventTypeName = this.getNotificationTypeName(notificationType);

    try {
      // 1. Verify with Google Play Developer API
      const verified = await this.googlePlayService.verifySubscriptionPurchase(
        subscriptionId,
        purchaseToken,
        notification.packageName
      );

      // 2. Map Product ID to Subscription Tier
      const tier = this.mapProductIdToTier(verified.productId || subscriptionId);

      // 3. Upsert user_subscriptions row via Supabase service_role
      await this.upsertSubscriptionRecord(purchaseToken, tier, status, verified);

      // 4. Log successful audit trail
      await this.logWebhook(
        eventId,
        eventTypeName,
        purchaseToken,
        { notification, verified },
        'PROCESSED'
      );

      console.log(`[SubscriptionSyncService] Processed ${eventTypeName} for token: ${purchaseToken.substring(0, 10)}... (Status: ${status}, Tier: ${tier})`);
    } catch (err: any) {
      console.error(`[SubscriptionSyncService] Error processing RTDN notification:`, err);
      await this.logWebhook(
        eventId,
        eventTypeName,
        purchaseToken,
        { notification, error: err.message },
        'FAILED'
      );
      throw err;
    }
  }

  /**
   * Directly verifies and registers client purchase from mobile Flutter client
   */
  async handleClientPurchaseVerification(
    userId: string,
    productId: string,
    purchaseToken: string,
    orderId?: string
  ): Promise<any> {
    // 1. Verify token with Google Play
    const verified = await this.googlePlayService.verifySubscriptionPurchase(productId, purchaseToken);

    // 2. Acknowledge subscription
    await this.googlePlayService.acknowledgeSubscriptionPurchase(productId, purchaseToken);

    // 3. Determine tier
    const tier = this.mapProductIdToTier(verified.productId || productId);

    // 4. Upsert user_subscriptions
    const { data, error } = await this.supabase
      .from('user_subscriptions')
      .upsert(
        {
          user_id: userId,
          product_id: verified.productId || productId,
          purchase_token: purchaseToken,
          order_id: verified.orderId || orderId || `GPA.${Date.now()}`,
          tier: tier,
          status: 'ACTIVE',
          current_period_start: verified.startTime.toISOString(),
          current_period_end: verified.expiryTime.toISOString(),
          expiry_time: verified.expiryTime.toISOString(),
          auto_renewing: verified.autoRenewing,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'purchase_token' }
      )
      .select()
      .single();

    if (error) {
      console.error('[SubscriptionSyncService] Database upsert error:', error);
      throw error;
    }

    // 5. Fetch updated entitlement
    const { data: entitlement, error: entError } = await this.supabase.rpc(
      'get_user_entitlement',
      { p_user_id: userId }
    );

    if (entError) throw entError;
    return entitlement;
  }

  private mapNotificationTypeToStatus(type: number): string {
    switch (type) {
      case 1: // SUBSCRIPTION_RECOVERED
      case 2: // SUBSCRIPTION_RENEWED
      case 4: // SUBSCRIPTION_PURCHASED
      case 7: // SUBSCRIPTION_RESTARTED
        return 'ACTIVE';
      case 6: // SUBSCRIPTION_IN_GRACE_PERIOD
        return 'IN_GRACE_PERIOD';
      case 5: // SUBSCRIPTION_ON_HOLD
        return 'ON_HOLD';
      case 10: // SUBSCRIPTION_PAUSED
        return 'PAUSED';
      case 3: // SUBSCRIPTION_CANCELED
        return 'CANCELED';
      case 12: // SUBSCRIPTION_REVOKED
      case 13: // SUBSCRIPTION_EXPIRED
        return 'EXPIRED';
      default:
        return 'ACTIVE';
    }
  }

  private getNotificationTypeName(type: number): string {
    const types: Record<number, string> = {
      1: 'SUBSCRIPTION_RECOVERED',
      2: 'SUBSCRIPTION_RENEWED',
      3: 'SUBSCRIPTION_CANCELED',
      4: 'SUBSCRIPTION_PURCHASED',
      5: 'SUBSCRIPTION_ON_HOLD',
      6: 'SUBSCRIPTION_IN_GRACE_PERIOD',
      7: 'SUBSCRIPTION_RESTARTED',
      8: 'SUBSCRIPTION_PRICE_CHANGE_CONFIRMED',
      9: 'SUBSCRIPTION_DEFERRED',
      10: 'SUBSCRIPTION_PAUSED',
      11: 'SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED',
      12: 'SUBSCRIPTION_REVOKED',
      13: 'SUBSCRIPTION_EXPIRED',
    };
    return types[type] || `UNKNOWN_NOTIFICATION_${type}`;
  }

  private mapProductIdToTier(productId: string): string {
    if (productId.toLowerCase().includes('enterprise')) {
      return 'ENTERPRISE';
    }
    if (productId.toLowerCase().includes('pro')) {
      return 'PRO';
    }
    return 'FREE';
  }

  private async upsertSubscriptionRecord(
    purchaseToken: string,
    tier: string,
    status: string,
    verified: VerifiedSubscriptionDetails
  ): Promise<void> {
    const { error } = await this.supabase
      .from('user_subscriptions')
      .update({
        tier: status === 'EXPIRED' ? 'FREE' : tier,
        status: status,
        current_period_end: verified.expiryTime.toISOString(),
        expiry_time: verified.expiryTime.toISOString(),
        auto_renewing: verified.autoRenewing,
        updated_at: new Date().toISOString(),
      })
      .eq('purchase_token', purchaseToken);

    if (error) {
      console.error('[SubscriptionSyncService] Update subscription record error:', error);
      throw error;
    }
  }

  private async logWebhook(
    eventId: string,
    eventType: string,
    purchaseToken: string,
    payload: any,
    status: string
  ): Promise<void> {
    try {
      await this.supabase.from('billing_webhook_logs').insert({
        event_id: eventId,
        event_type: eventType,
        purchase_token: purchaseToken,
        payload: payload,
        processed_status: status,
      });
    } catch (err: any) {
      console.error('[SubscriptionSyncService] Failed to write webhook log:', err.message);
    }
  }
}

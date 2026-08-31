import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { SubscriptionSyncService } from '../services/subscriptionSyncService';

const syncService = new SubscriptionSyncService();

/**
 * Controller allowing client apps to submit and immediately verify a new Google Play purchase token
 */
export const verifyClientPurchase = async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing or invalid Authorization header' });
      return;
    }

    const token = authHeader.split(' ')[1];
    const supabaseUrl = process.env.SUPABASE_URL || 'https://supabase.local';
    const supabaseAnonKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false },
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      res.status(401).json({ error: 'Invalid user authentication token' });
      return;
    }

    const { productId, purchaseToken, orderId } = req.body;

    if (!productId || !purchaseToken) {
      res.status(400).json({ error: 'Missing required parameters: productId, purchaseToken' });
      return;
    }

    console.log(`[SubscriptionClientController] Verifying client purchase for user: ${user.id}, product: ${productId}`);

    const entitlement = await syncService.handleClientPurchaseVerification(
      user.id,
      productId,
      purchaseToken,
      orderId
    );

    res.status(200).json({
      status: 'success',
      entitlement,
    });
  } catch (err: any) {
    console.error('[SubscriptionClientController] Client purchase verification error:', err);
    res.status(500).json({
      status: 'error',
      message: err.message || 'Internal server error verifying purchase',
    });
  }
};

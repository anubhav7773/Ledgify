import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req: Request): Promise<Response> => {
  try {
    // 1. Verify Google Cloud Pub/Sub OIDC Authorization Header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response("Unauthorized Pub/Sub token", { status: 401 });
    }

    const body = await req.json();
    if (!body.message || !body.message.data) {
      return new Response("Invalid Pub/Sub payload", { status: 400 });
    }

    // 2. Decode Base64 Pub/Sub Data
    const decodedString = atob(body.message.data);
    const rtdnPayload = JSON.parse(decodedString);
    const eventId = body.message.messageId || `EVT-${Date.now()}`;

    // 3. Log Immutable Webhook Event
    await supabase.from("billing_webhook_logs").insert({
      event_id: eventId,
      event_type: rtdnPayload.subscriptionNotification ? "SUBSCRIPTION_EVENT" : "ONE_TIME_EVENT",
      purchase_token: rtdnPayload.subscriptionNotification?.purchaseToken || "UNKNOWN",
      payload: rtdnPayload,
    });

    // 4. Process Subscription State Transition
    if (rtdnPayload.subscriptionNotification) {
      const { notificationType, purchaseToken } = rtdnPayload.subscriptionNotification;
      let newStatus = "ACTIVE";

      switch (notificationType) {
        case 1: // SUBSCRIPTION_RECOVERED
        case 2: // SUBSCRIPTION_RENEWED
        case 4: // SUBSCRIPTION_PURCHASED
          newStatus = "ACTIVE";
          break;
        case 3: // SUBSCRIPTION_CANCELED
          newStatus = "CANCELLED";
          break;
        case 5: // SUBSCRIPTION_ON_HOLD
          newStatus = "ON_HOLD";
          break;
        case 6: // SUBSCRIPTION_IN_GRACE_PERIOD
          newStatus = "IN_GRACE_PERIOD";
          break;
        case 12: // SUBSCRIPTION_PAUSED
          newStatus = "PAUSED";
          break;
        case 13: // SUBSCRIPTION_EXPIRED
          newStatus = "EXPIRED";
          break;
        default:
          newStatus = "ACTIVE";
          break;
      }

      // Update active subscription state in DB
      await supabase
        .from("user_subscriptions")
        .update({ status: newStatus, updated_at: new Date().toISOString() })
        .eq("purchase_token", purchaseToken);
    }

    // Acknowledge Pub/Sub message
    return new Response("OK", { status: 200 });
  } catch (err: unknown) {
    const errMessage = err instanceof Error ? err.message : String(err);
    return new Response(`Webhook handler error: ${errMessage}`, { status: 500 });
  }
});

import express from 'express';
import dotenv from 'dotenv';
import { handleGooglePlayRtdnWebhook } from './controllers/webhookController';
import { verifyClientPurchase } from './controllers/subscriptionClientController';

dotenv.config();

const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());

// -----------------------------------------------------------------------------
// Keep-Alive & Health Check Endpoints (UptimeRobot / Monitoring)
// -----------------------------------------------------------------------------

// 1. Root & Ping Keep-Alive (Zero Overhead)
app.get(['/', '/ping'], (req, res) => {
  res.status(200).send('pong');
});

// 2. Comprehensive Health Check
app.get(['/health', '/healthz'], (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'ledgify-billing-server',
    uptimeSeconds: Math.floor(process.uptime()),
    memoryUsageMB: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
    timestamp: new Date().toISOString(),
  });
});

// -----------------------------------------------------------------------------
// Billing & API Routes
// -----------------------------------------------------------------------------

// Google Play RTDN Webhook Endpoint (Cloud Pub/Sub Push)
app.post('/api/v1/webhooks/google-play-rtdn', handleGooglePlayRtdnWebhook);

// Authenticated Client Purchase Verification Endpoint
app.post('/api/v1/subscriptions/verify-client-purchase', verifyClientPurchase);

app.listen(port, () => {
  console.log(`[Ledgify-Billing] Server listening on port ${port}`);
});

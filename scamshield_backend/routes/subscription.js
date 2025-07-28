/**
 * Subscription Routes
 * Handles subscription management operations
 */

const express = require('express');
const { log } = require('../utils/helpers');

function createSubscriptionRoutes(postgresService) {
  const router = express.Router();

  /**
   * Get user subscription status
   * GET /api/subscription/status
   */
  router.get('/status', async (req, res) => {
    try {
      const userId = req.user?.phoneNumber;
      if (!userId) {
        return res.status(401).json({ error: 'User not authenticated' });
      }

      const subscription = await postgresService.getSubscription(userId);
      
      if (!subscription) {
        return res.json({
          status: 'none',
          hasPremium: false,
          trialDaysRemaining: 0
        });
      }

      // Check if trial is expired
      let status = subscription.status;
      let hasPremium = status === 'active';
      let trialDaysRemaining = 0;

      if (status === 'trial' && subscription.trial_end_date) {
        const now = new Date();
        const trialEnd = new Date(subscription.trial_end_date);
        const daysRemaining = Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24));
        
        if (daysRemaining <= 0) {
          // Trial expired, update status
          await postgresService.createOrUpdateSubscription({
            userId,
            status: 'expired'
          });
          status = 'expired';
          trialDaysRemaining = 0;
        } else {
          trialDaysRemaining = daysRemaining;
        }
      }

      res.json({
        status,
        hasPremium,
        trialDaysRemaining,
        subscription: {
          planCode: subscription.plan_code,
          paymentReference: subscription.payment_reference,
          trialStartDate: subscription.trial_start_date,
          trialEndDate: subscription.trial_end_date,
          subscriptionStartDate: subscription.subscription_start_date,
          subscriptionEndDate: subscription.subscription_end_date,
          amountPaid: subscription.amount_paid,
          currency: subscription.currency,
          autoRenew: subscription.auto_renew
        }
      });

    } catch (error) {
      log('error', 'Error getting subscription status:', error.message);
      res.status(500).json({ error: 'Failed to get subscription status' });
    }
  });

  /**
   * Start free trial
   * POST /api/subscription/trial
   */
  router.post('/trial', async (req, res) => {
    try {
      const userId = req.user?.phoneNumber;
      if (!userId) {
        return res.status(401).json({ error: 'User not authenticated' });
      }

      // Check if user already has a subscription
      const existingSubscription = await postgresService.getSubscription(userId);
      if (existingSubscription && existingSubscription.status !== 'none') {
        return res.status(400).json({ error: 'User already has an active subscription or trial' });
      }

      const subscription = await postgresService.startFreeTrial(userId);
      
      log('info', `Started free trial for user ${userId}`);
      
      res.json({
        success: true,
        message: 'Free trial started successfully',
        subscription: {
          status: subscription.status,
          trialStartDate: subscription.trial_start_date,
          trialEndDate: subscription.trial_end_date
        }
      });

    } catch (error) {
      log('error', 'Error starting free trial:', error.message);
      res.status(500).json({ error: 'Failed to start free trial' });
    }
  });

  /**
   * Activate paid subscription
   * POST /api/subscription/activate
   */
  router.post('/activate', async (req, res) => {
    try {
      const userId = req.user?.phoneNumber;
      const { paymentReference, amountPaid } = req.body;

      if (!userId) {
        return res.status(401).json({ error: 'User not authenticated' });
      }

      if (!paymentReference || !amountPaid) {
        return res.status(400).json({ error: 'Payment reference and amount are required' });
      }

      const subscription = await postgresService.activateSubscription(userId, paymentReference, amountPaid);
      
      log('info', `Activated subscription for user ${userId} with payment ${paymentReference}`);
      
      res.json({
        success: true,
        message: 'Subscription activated successfully',
        subscription: {
          status: subscription.status,
          paymentReference: subscription.payment_reference,
          subscriptionStartDate: subscription.subscription_start_date,
          subscriptionEndDate: subscription.subscription_end_date,
          amountPaid: subscription.amount_paid
        }
      });

    } catch (error) {
      log('error', 'Error activating subscription:', error.message);
      res.status(500).json({ error: 'Failed to activate subscription' });
    }
  });

  /**
   * Cancel subscription
   * POST /api/subscription/cancel
   */
  router.post('/cancel', async (req, res) => {
    try {
      const userId = req.user?.phoneNumber;
      if (!userId) {
        return res.status(401).json({ error: 'User not authenticated' });
      }

      const subscription = await postgresService.cancelSubscription(userId);
      
      log('info', `Cancelled subscription for user ${userId}`);
      
      res.json({
        success: true,
        message: 'Subscription cancelled successfully',
        subscription: {
          status: subscription.status,
          autoRenew: subscription.auto_renew
        }
      });

    } catch (error) {
      log('error', 'Error cancelling subscription:', error.message);
      res.status(500).json({ error: 'Failed to cancel subscription' });
    }
  });

  /**
   * Sync subscription from frontend
   * POST /api/subscription/sync
   */
  router.post('/sync', async (req, res) => {
    try {
      const userId = req.user?.phoneNumber;
      const { status, paymentReference, amountPaid } = req.body;

      if (!userId) {
        return res.status(401).json({ error: 'User not authenticated' });
      }

      if (!status) {
        return res.status(400).json({ error: 'Status is required' });
      }

      // Ensure user exists in the database before creating subscription
      const userExistsQuery = 'SELECT phone_number FROM users WHERE phone_number = $1';
      const userResult = await postgresService.query(userExistsQuery, [userId]);
      
      if (userResult.rows.length === 0) {
        // Create user record if it doesn't exist
        const createUserQuery = `
          INSERT INTO users (phone_number, is_premium, subscription_status, created_at, updated_at)
          VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ON CONFLICT (phone_number) DO NOTHING
        `;
        await postgresService.query(createUserQuery, [userId, status === 'active', status]);
        log('info', `Created user record for ${userId}`);
      }

      let subscription;
      
      if (status === 'active' && paymentReference) {
        subscription = await postgresService.activateSubscription(userId, paymentReference, amountPaid || 3500);
      } else if (status === 'trial') {
        subscription = await postgresService.startFreeTrial(userId);
      } else if (status === 'cancelled') {
        subscription = await postgresService.cancelSubscription(userId);
      } else {
        // Handle other status cases with proper default values
        subscription = await postgresService.createOrUpdateSubscription({
          userId,
          status,
          planCode: null,
          paymentReference: paymentReference || null,
          trialStartDate: null,
          trialEndDate: null,
          subscriptionStartDate: null,
          subscriptionEndDate: null,
          amountPaid: amountPaid || null,
          currency: 'ZAR',
          paymentProvider: 'paystack',
          autoRenew: status !== 'cancelled'
        });
      }
      
      log('info', `Synced subscription for user ${userId} with status ${status}`);
      
      res.json({
        success: true,
        message: 'Subscription synced successfully',
        subscription: {
          status: subscription.status,
          paymentReference: subscription.payment_reference
        }
      });

    } catch (error) {
      log('error', 'Error syncing subscription:', error.message);
      res.status(500).json({ error: 'Failed to sync subscription' });
    }
  });

  return router;
}

module.exports = createSubscriptionRoutes;

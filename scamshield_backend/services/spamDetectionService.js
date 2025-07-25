/**
 * Multi-API Spam Detection Service
 * Abstracts multiple spam detection APIs with fallback and aggregation logic
 */

const { log } = require('../utils/helpers');

class SpamDetectionService {
  constructor() {
    this.providers = new Map();
    this.config = {
      timeout: 5000, // 5 second timeout per API
      maxConcurrentRequests: 3,
      fallbackEnabled: true,
      aggregationStrategy: 'highest_risk' // 'highest_risk', 'majority_vote', 'weighted_average'
    };
  }

  /**
   * Register a spam detection provider
   * @param {string} name - Provider name (e.g., 'hiya', 'truecaller')
   * @param {Object} provider - Provider instance
   * @param {Object} config - Provider-specific configuration
   */
  registerProvider(name, provider, config = {}) {
    this.providers.set(name, {
      instance: provider,
      config: {
        enabled: true,
        weight: 1.0, // Weight for aggregation (0.0 - 1.0)
        priority: 1, // Priority order (1 = highest)
        timeout: config.timeout || this.config.timeout,
        ...config
      },
      stats: {
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        avgResponseTime: 0,
        lastUsed: null
      }
    });

    log('success', `📡 Registered spam detection provider: ${name}`);
  }

  /**
   * Check phone number against all enabled providers
   * @param {string} phoneNumber - Phone number to check
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Aggregated spam detection result
   */
  async checkNumber(phoneNumber, options = {}) {
    const startTime = Date.now();
    
    try {
      log('info', `🔍 Checking ${phoneNumber} against ${this.providers.size} providers`);

      // Get enabled providers sorted by priority
      const enabledProviders = Array.from(this.providers.entries())
        .filter(([name, provider]) => provider.config.enabled)
        .sort((a, b) => a[1].config.priority - b[1].config.priority);

      if (enabledProviders.length === 0) {
        throw new Error('No spam detection providers enabled');
      }

      // Execute API calls concurrently with timeout
      const providerPromises = enabledProviders.map(([name, provider]) => 
        this.callProvider(name, provider, phoneNumber, options)
      );

      // Wait for all providers or timeout
      const results = await Promise.allSettled(providerPromises);
      
      // Process results
      const successfulResults = [];
      const failedResults = [];

      results.forEach((result, index) => {
        const [providerName] = enabledProviders[index];
        
        if (result.status === 'fulfilled' && result.value) {
          successfulResults.push({
            provider: providerName,
            ...result.value
          });
        } else {
          failedResults.push({
            provider: providerName,
            error: result.reason?.message || 'Unknown error'
          });
        }
      });

      // Log results
      log('info', `✅ ${successfulResults.length} providers succeeded, ${failedResults.length} failed`);
      
      if (failedResults.length > 0) {
        log('warn', `Failed providers: ${failedResults.map(f => f.provider).join(', ')}`);
      }

      // Aggregate results
      const aggregatedResult = this.aggregateResults(successfulResults, phoneNumber);
      
      // Add metadata
      aggregatedResult.metadata = {
        totalProviders: enabledProviders.length,
        successfulProviders: successfulResults.length,
        failedProviders: failedResults.length,
        responseTime: Date.now() - startTime,
        aggregationStrategy: this.config.aggregationStrategy,
        timestamp: new Date().toISOString()
      };

      log('success', `📊 Aggregated result for ${phoneNumber}: ${aggregatedResult.riskLevel} risk`);
      
      return aggregatedResult;

    } catch (error) {
      log('error', `❌ Error checking ${phoneNumber}:`, error);
      
      // Return safe default
      return {
        phoneNumber,
        riskLevel: 'LOW',
        confidence: 'UNKNOWN',
        action: 'allow',
        autoReject: false,
        category: 'unknown',
        sources: [],
        error: error.message,
        metadata: {
          totalProviders: 0,
          successfulProviders: 0,
          failedProviders: this.providers.size,
          responseTime: Date.now() - startTime,
          timestamp: new Date().toISOString()
        }
      };
    }
  }

  /**
   * Call a specific provider with timeout and error handling
   * @param {string} name - Provider name
   * @param {Object} provider - Provider configuration
   * @param {string} phoneNumber - Phone number to check
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Provider result
   */
  async callProvider(name, provider, phoneNumber, options) {
    const startTime = Date.now();
    
    try {
      // Update stats
      provider.stats.totalRequests++;
      provider.stats.lastUsed = new Date().toISOString();

      // Call provider with timeout
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error(`${name} API timeout`)), provider.config.timeout);
      });

      const apiPromise = provider.instance.checkSpamNumber(phoneNumber, options);
      const result = await Promise.race([apiPromise, timeoutPromise]);

      // Update success stats
      provider.stats.successfulRequests++;
      const responseTime = Date.now() - startTime;
      provider.stats.avgResponseTime = 
        (provider.stats.avgResponseTime * (provider.stats.successfulRequests - 1) + responseTime) / 
        provider.stats.successfulRequests;

      log('info', `✅ ${name} API responded in ${responseTime}ms`);
      
      return {
        ...result,
        responseTime,
        weight: provider.config.weight
      };

    } catch (error) {
      // Update failure stats
      provider.stats.failedRequests++;
      
      log('warn', `⚠️ ${name} API failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * Aggregate results from multiple providers
   * @param {Array} results - Array of provider results
   * @param {string} phoneNumber - Phone number being checked
   * @returns {Object} Aggregated result
   */
  aggregateResults(results, phoneNumber) {
    if (results.length === 0) {
      return {
        phoneNumber,
        riskLevel: 'LOW',
        confidence: 'UNKNOWN',
        action: 'allow',
        autoReject: false,
        category: 'unknown',
        sources: []
      };
    }

    // If only one result, return it
    if (results.length === 1) {
      const result = results[0];
      return {
        phoneNumber,
        riskLevel: result.riskLevel || 'LOW',
        confidence: result.confidence || 'UNKNOWN',
        action: result.action || 'allow',
        autoReject: result.autoReject || false,
        category: result.category || 'unknown',
        sources: [result.provider],
        providerData: results
      };
    }

    // Multiple results - apply aggregation strategy
    switch (this.config.aggregationStrategy) {
      case 'highest_risk':
        return this.aggregateByHighestRisk(results, phoneNumber);
      
      case 'majority_vote':
        return this.aggregateByMajorityVote(results, phoneNumber);
      
      case 'weighted_average':
        return this.aggregateByWeightedAverage(results, phoneNumber);
      
      default:
        return this.aggregateByHighestRisk(results, phoneNumber);
    }
  }

  /**
   * Aggregate by highest risk level
   */
  aggregateByHighestRisk(results, phoneNumber) {
    const riskOrder = { 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1, 'UNKNOWN': 0 };
    
    // Find highest risk result
    const highestRiskResult = results.reduce((highest, current) => {
      const currentRisk = riskOrder[current.riskLevel] || 0;
      const highestRisk = riskOrder[highest.riskLevel] || 0;
      return currentRisk > highestRisk ? current : highest;
    });

    return {
      phoneNumber,
      riskLevel: highestRiskResult.riskLevel || 'LOW',
      confidence: highestRiskResult.confidence || 'UNKNOWN',
      action: highestRiskResult.action || 'allow',
      autoReject: highestRiskResult.autoReject || false,
      category: highestRiskResult.category || 'unknown',
      sources: results.map(r => r.provider),
      primarySource: highestRiskResult.provider,
      providerData: results,
      aggregationMethod: 'highest_risk'
    };
  }

  /**
   * Aggregate by majority vote
   */
  aggregateByMajorityVote(results, phoneNumber) {
    const riskCounts = { 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0 };
    const actionCounts = { 'block': 0, 'allow': 0 };

    results.forEach(result => {
      riskCounts[result.riskLevel] = (riskCounts[result.riskLevel] || 0) + 1;
      actionCounts[result.action] = (actionCounts[result.action] || 0) + 1;
    });

    // Find majority risk level
    const majorityRisk = Object.keys(riskCounts).reduce((a, b) => 
      riskCounts[a] > riskCounts[b] ? a : b
    );

    // Find majority action
    const majorityAction = Object.keys(actionCounts).reduce((a, b) => 
      actionCounts[a] > actionCounts[b] ? a : b
    );

    return {
      phoneNumber,
      riskLevel: majorityRisk,
      confidence: 'MEDIUM', // Majority vote gives medium confidence
      action: majorityAction,
      autoReject: majorityAction === 'block',
      category: majorityAction === 'block' ? 'suspicious' : 'unknown',
      sources: results.map(r => r.provider),
      providerData: results,
      aggregationMethod: 'majority_vote',
      voteCounts: { riskCounts, actionCounts }
    };
  }

  /**
   * Aggregate by weighted average
   */
  aggregateByWeightedAverage(results, phoneNumber) {
    const riskScores = { 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1, 'UNKNOWN': 0 };
    
    let totalWeight = 0;
    let weightedScore = 0;

    results.forEach(result => {
      const weight = result.weight || 1.0;
      const score = riskScores[result.riskLevel] || 0;
      
      weightedScore += score * weight;
      totalWeight += weight;
    });

    const averageScore = totalWeight > 0 ? weightedScore / totalWeight : 0;
    
    // Convert back to risk level
    let finalRisk = 'LOW';
    let finalAction = 'allow';
    
    if (averageScore >= 2.5) {
      finalRisk = 'HIGH';
      finalAction = 'block';
    } else if (averageScore >= 1.5) {
      finalRisk = 'MEDIUM';
      finalAction = 'allow';
    }

    return {
      phoneNumber,
      riskLevel: finalRisk,
      confidence: 'MEDIUM',
      action: finalAction,
      autoReject: finalAction === 'block',
      category: finalAction === 'block' ? 'suspicious' : 'unknown',
      sources: results.map(r => r.provider),
      providerData: results,
      aggregationMethod: 'weighted_average',
      averageScore: Math.round(averageScore * 100) / 100
    };
  }

  /**
   * Get provider statistics
   */
  getProviderStats() {
    const stats = {};
    
    for (const [name, provider] of this.providers.entries()) {
      stats[name] = {
        ...provider.stats,
        config: provider.config,
        successRate: provider.stats.totalRequests > 0 ? 
          (provider.stats.successfulRequests / provider.stats.totalRequests * 100).toFixed(2) + '%' : 
          '0%'
      };
    }
    
    return stats;
  }

  /**
   * Update provider configuration
   */
  updateProviderConfig(name, config) {
    if (this.providers.has(name)) {
      Object.assign(this.providers.get(name).config, config);
      log('info', `📝 Updated ${name} provider configuration`);
    }
  }

  /**
   * Enable/disable provider
   */
  setProviderEnabled(name, enabled) {
    if (this.providers.has(name)) {
      this.providers.get(name).config.enabled = enabled;
      log('info', `${enabled ? '✅' : '❌'} ${enabled ? 'Enabled' : 'Disabled'} ${name} provider`);
    }
  }
}

module.exports = SpamDetectionService;

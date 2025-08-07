const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

class Config {
  constructor() {
    this.nodeEnv = process.env.NODE_ENV || 'development';
    this.port = parseInt(process.env.PORT) || 8080;
    this.projectId = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCP_PROJECT_ID;
    this.environment = process.env.ENVIRONMENT || 'dev';
    
    // CORS configuration
    this.corsOrigins = process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : '*';
    
    // Rate limiting
    this.rateLimitMax = parseInt(process.env.RATE_LIMIT_MAX) || 100;
    
    // JWT configuration
    this.jwtSecret = process.env.JWT_SECRET || 'fallback-secret-change-in-production';
    this.jwtExpiresIn = process.env.JWT_EXPIRES_IN || '24h';
    
    // Form.io configuration
    this.formioBaseUrl = process.env.FORMIO_BASE_URL || '';
    this.formioApiKey = process.env.FORMIO_API_KEY || '';
    
    // Pub/Sub configuration
    this.pubsub = {
      topicPrefix: process.env.PUBSUB_TOPIC_PREFIX || 'formio',
      topics: {
        formEvents: `${process.env.PUBSUB_TOPIC_PREFIX || 'formio'}-form-events-${this.environment}`,
        formSubmissions: `${process.env.PUBSUB_TOPIC_PREFIX || 'formio'}-form-submissions-${this.environment}`,
        formUpdates: `${process.env.PUBSUB_TOPIC_PREFIX || 'formio'}-form-updates-${this.environment}`,
        webhookEvents: `${process.env.PUBSUB_TOPIC_PREFIX || 'formio'}-webhook-events-${this.environment}`
      }
    };
    
    // Database configuration
    this.database = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT) || 5432,
      database: process.env.DB_NAME || 'formio',
      user: process.env.DB_USER || 'formio_user',
      password: process.env.DB_PASSWORD || '',
      ssl: process.env.DB_SSL === 'true',
      max: parseInt(process.env.DB_POOL_MAX) || 20,
      min: parseInt(process.env.DB_POOL_MIN) || 2,
      acquireTimeoutMillis: parseInt(process.env.DB_ACQUIRE_TIMEOUT) || 60000,
      createTimeoutMillis: parseInt(process.env.DB_CREATE_TIMEOUT) || 3000,
      destroyTimeoutMillis: parseInt(process.env.DB_DESTROY_TIMEOUT) || 5000,
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 300000,
      reapIntervalMillis: parseInt(process.env.DB_REAP_INTERVAL) || 1000,
      createRetryIntervalMillis: parseInt(process.env.DB_CREATE_RETRY_INTERVAL) || 200
    };
    
    // Secret Manager configuration
    this.secrets = {
      connectionString: process.env.CONNECTION_STRING_SECRET_ID || '',
      jwtSecret: process.env.JWT_SECRET_SECRET_ID || '',
      formioApiKey: process.env.FORMIO_API_KEY_SECRET_ID || ''
    };
    
    // Logging configuration
    this.logging = {
      level: process.env.LOG_LEVEL || 'info',
      format: process.env.LOG_FORMAT || 'json',
      enableGoogleCloud: process.env.ENABLE_GOOGLE_CLOUD_LOGGING === 'true'
    };
    
    // Cache configuration
    this.cache = {
      ttl: parseInt(process.env.CACHE_TTL) || 300, // 5 minutes
      maxItems: parseInt(process.env.CACHE_MAX_ITEMS) || 1000
    };
    
    // Feature flags
    this.features = {
      analyticsEnabled: process.env.ANALYTICS_ENABLED !== 'false',
      cachingEnabled: process.env.CACHING_ENABLED !== 'false',
      auditLoggingEnabled: process.env.AUDIT_LOGGING_ENABLED !== 'false',
      pubsubEnabled: process.env.PUBSUB_ENABLED !== 'false'
    };
    
    this.secretManagerClient = null;
  }
  
  // Initialize Secret Manager client
  async initializeSecretManager() {
    if (!this.projectId) {
      throw new Error('Google Cloud Project ID is required');
    }
    
    this.secretManagerClient = new SecretManagerServiceClient();
  }
  
  // Get secret from Secret Manager
  async getSecret(secretId) {
    if (!this.secretManagerClient) {
      await this.initializeSecretManager();
    }
    
    try {
      const name = `projects/${this.projectId}/secrets/${secretId}/versions/latest`;
      const [version] = await this.secretManagerClient.accessSecretVersion({ name });
      return version.payload.data.toString();
    } catch (error) {
      console.error(`Failed to get secret ${secretId}:`, error.message);
      return null;
    }
  }
  
  // Load configuration from Secret Manager
  async loadSecrets() {
    try {
      // Load database connection string
      if (this.secrets.connectionString) {
        const connectionData = await this.getSecret(this.secrets.connectionString);
        if (connectionData) {
          const connections = JSON.parse(connectionData);
          const mainConnection = new URL(connections.main);
          
          this.database = {
            ...this.database,
            host: mainConnection.hostname,
            port: parseInt(mainConnection.port) || 5432,
            database: mainConnection.pathname.slice(1),
            user: mainConnection.username,
            password: mainConnection.password,
            ssl: mainConnection.searchParams.get('sslmode') === 'require'
          };
        }
      }
      
      // Load JWT secret
      if (this.secrets.jwtSecret) {
        const jwtSecret = await this.getSecret(this.secrets.jwtSecret);
        if (jwtSecret) {
          this.jwtSecret = jwtSecret;
        }
      }
      
      // Load Form.io API key
      if (this.secrets.formioApiKey) {
        const apiKey = await this.getSecret(this.secrets.formioApiKey);
        if (apiKey) {
          this.formioApiKey = apiKey;
        }
      }
      
    } catch (error) {
      console.error('Failed to load secrets:', error);
      // Continue with environment variables/defaults
    }
  }
  
  // Validate required configuration
  validate() {
    const required = [];
    
    if (!this.projectId && this.nodeEnv === 'production') {
      required.push('GOOGLE_CLOUD_PROJECT');
    }
    
    if (!this.database.host) {
      required.push('DB_HOST');
    }
    
    if (!this.database.user) {
      required.push('DB_USER');
    }
    
    if (!this.database.password && !this.secrets.connectionString) {
      required.push('DB_PASSWORD or CONNECTION_STRING_SECRET_ID');
    }
    
    if (required.length > 0) {
      throw new Error(`Missing required configuration: ${required.join(', ')}`);
    }
  }
  
  // Get database connection string
  getDatabaseUrl() {
    const { host, port, database, user, password, ssl } = this.database;
    const sslMode = ssl ? 'require' : 'disable';
    return `postgresql://${user}:${password}@${host}:${port}/${database}?sslmode=${sslMode}`;
  }
}

// Singleton instance
const config = new Config();

module.exports = config;
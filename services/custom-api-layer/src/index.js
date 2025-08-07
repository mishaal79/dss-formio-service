const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const logger = require('./utils/logger');
const config = require('./config');
const errorHandler = require('./middleware/errorHandler');
const authMiddleware = require('./middleware/auth');
const database = require('./database');

// Route imports
const formRoutes = require('./routes/forms');
const submissionRoutes = require('./routes/submissions');
const analyticsRoutes = require('./routes/analytics');
const templateRoutes = require('./routes/templates');
const healthRoutes = require('./routes/health');

const app = express();

// Trust proxy (required for Cloud Run)
app.set('trust proxy', true);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: config.rateLimitMax || 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// General middleware
app.use(compression());
app.use(cors({
  origin: config.corsOrigins || '*',
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}));

// Health check route (no auth required)
app.use('/health', healthRoutes);

// API versioning
const v1Router = express.Router();

// Authentication middleware for API routes
v1Router.use(authMiddleware);

// API routes
v1Router.use('/forms', formRoutes);
v1Router.use('/submissions', submissionRoutes);
v1Router.use('/analytics', analyticsRoutes);
v1Router.use('/templates', templateRoutes);

// Mount v1 routes
app.use('/api/v1', v1Router);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'Form.io PostgreSQL API Layer',
    version: '1.0.0',
    status: 'running',
    timestamp: new Date().toISOString(),
    docs: '/api/v1/docs',
    health: '/health'
  });
});

// API documentation endpoint
app.get('/api/v1/docs', (req, res) => {
  res.json({
    title: 'Form.io PostgreSQL API Layer',
    version: '1.0.0',
    description: 'Custom API layer for integrating Form.io with PostgreSQL',
    endpoints: {
      forms: {
        'GET /api/v1/forms': 'List all forms',
        'GET /api/v1/forms/:id': 'Get form by ID',
        'POST /api/v1/forms': 'Create new form',
        'PUT /api/v1/forms/:id': 'Update form',
        'DELETE /api/v1/forms/:id': 'Delete form',
        'POST /api/v1/forms/:id/sync': 'Sync form with Form.io'
      },
      submissions: {
        'GET /api/v1/submissions': 'List submissions with filtering',
        'GET /api/v1/submissions/:id': 'Get submission by ID',
        'POST /api/v1/submissions': 'Create new submission',
        'PUT /api/v1/submissions/:id': 'Update submission',
        'DELETE /api/v1/submissions/:id': 'Delete submission',
        'GET /api/v1/forms/:formId/submissions': 'Get submissions for form'
      },
      analytics: {
        'GET /api/v1/analytics/forms/:id/summary': 'Get form analytics',
        'GET /api/v1/analytics/submissions/trends': 'Get submission trends',
        'GET /api/v1/analytics/forms/popular': 'Get popular forms'
      },
      templates: {
        'GET /api/v1/templates': 'List form templates',
        'GET /api/v1/templates/:id': 'Get template by ID',
        'POST /api/v1/templates': 'Create new template',
        'POST /api/v1/templates/:id/instantiate': 'Create form from template'
      }
    },
    authentication: 'Bearer token required for all API endpoints except /health'
  });
});

// Error handling middleware
app.use(errorHandler);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.originalUrl} not found`,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown handler
const gracefulShutdown = async (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`);
  
  try {
    // Close database connections
    await database.close();
    logger.info('Database connections closed');
    
    // Close server
    server.close(() => {
      logger.info('HTTP server closed');
      process.exit(0);
    });
    
    // Force exit after timeout
    setTimeout(() => {
      logger.error('Forced exit due to timeout');
      process.exit(1);
    }, 10000);
    
  } catch (error) {
    logger.error('Error during graceful shutdown:', error);
    process.exit(1);
  }
};

// Initialize database and start server
const startServer = async () => {
  try {
    // Initialize database connection
    await database.initialize();
    logger.info('Database initialized successfully');
    
    // Start server
    const port = config.port || 8080;
    const server = app.listen(port, '0.0.0.0', () => {
      logger.info(`Server running on port ${port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
      logger.info(`Database: ${config.database.host}:${config.database.port}/${config.database.database}`);
    });
    
    // Setup graceful shutdown
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    
    return server;
    
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Start the server if this file is run directly
if (require.main === module) {
  startServer();
}

module.exports = app;
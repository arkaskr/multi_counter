const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');

// Check root .env first, then server/.env
const rootEnvPath = path.resolve(__dirname, '../../.env');
const localEnvPath = path.resolve(__dirname, '../.env');

if (fs.existsSync(rootEnvPath)) {
  dotenv.config({ path: rootEnvPath });
} else if (fs.existsSync(localEnvPath)) {
  dotenv.config({ path: localEnvPath });
} else {
  dotenv.config();
}

const config = {
  port: parseInt(process.env.PORT || '5000', 10),
  mongodbUri: process.env.MONGODB_URI || 'mongodb+srv://arkaskr24_db_user:wVvVLeD9fGrnMnBO@counter.v7ndlkx.mongodb.net/daily_counter?retryWrites=true&w=majority',
  jwtSecret: process.env.JWT_SECRET || 'daily_counter_jwt_secret_dev_key_2026',
  smtp: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || 'dummy_user@gmail.com',
    pass: process.env.SMTP_PASS || 'dummy_app_password',
    from: process.env.SMTP_FROM || '"Daily Counter" <dummy_user@gmail.com>',
  },
};

module.exports = config;


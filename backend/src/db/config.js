require("dotenv").config();

module.exports = {
  development: {
    url: process.env.DATABASE_URL,
    dialect: "postgres",
    logging: false,
  },
  staging: {
    url: process.env.TEST_DATABASE_URL || process.env.DATABASE_URL,
    dialect: "postgres",
    logging: false,
  },
  production: {
    url: process.env.DATABASE_URL,
    dialect: "postgres",
    logging: false,
    dialectOptions: {
      ssl: { require: true, rejectUnauthorized: false },
    },
  },
};

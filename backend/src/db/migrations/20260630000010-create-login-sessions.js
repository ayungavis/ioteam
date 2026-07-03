'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('login_sessions', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'users', key: 'id' },
        onDelete: 'CASCADE',
      },
      token_hash: {
        type: Sequelize.STRING,
        allowNull: false,
        unique: true,
      },
      device_name: {
        type: Sequelize.STRING,
        allowNull: true,
      },
      ip_address: {
        type: Sequelize.STRING,
        allowNull: true,
      },
      last_active_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      revoked_at: {
        type: Sequelize.DATE,
        allowNull: true,
      },
    });

    await queryInterface.addIndex('login_sessions', ['user_id', 'revoked_at']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('login_sessions');
  },
};

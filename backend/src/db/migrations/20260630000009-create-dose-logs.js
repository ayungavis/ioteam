'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('dose_logs', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      dose_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'doses', key: 'id' },
        onDelete: 'CASCADE',
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: true,
        references: { model: 'users', key: 'id' },
        onDelete: 'SET NULL',
      },
      event_type: {
        type: Sequelize.ENUM('taken', 'missed', 'skipped', 'confirmed', 'rejected'),
        allowNull: false,
      },
      source: {
        type: Sequelize.ENUM('device_event', 'manual', 'system'),
        allowNull: false,
      },
      metadata: {
        type: Sequelize.JSONB,
        allowNull: true,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.addIndex('dose_logs', ['dose_id']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('dose_logs');
  },
};

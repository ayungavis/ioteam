'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('device_events', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      device_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'devices', key: 'id' },
        onDelete: 'CASCADE',
      },
      event_type: {
        type: Sequelize.ENUM('open', 'close'),
        allowNull: false,
      },
      device_timestamp: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      server_received_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      firmware_version: {
        type: Sequelize.STRING,
        allowNull: true,
      },
      raw_payload: {
        type: Sequelize.JSONB,
        allowNull: true,
      },
    });

    await queryInterface.addIndex('device_events', ['device_id', 'device_timestamp']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('device_events');
  },
};

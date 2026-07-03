'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('devices', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      family_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'families', key: 'id' },
        onDelete: 'CASCADE',
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      hardware_id: {
        type: Sequelize.STRING,
        allowNull: false,
        unique: true,
      },
      connection_type: {
        type: Sequelize.ENUM('bluetooth', 'matter', 'homekit'),
        allowNull: false,
        defaultValue: 'bluetooth',
      },
      status: {
        type: Sequelize.ENUM('active', 'disabled', 'deleted'),
        allowNull: false,
        defaultValue: 'active',
      },
      firmware_version: {
        type: Sequelize.STRING,
        allowNull: true,
      },
      last_seen_at: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('devices');
  },
};

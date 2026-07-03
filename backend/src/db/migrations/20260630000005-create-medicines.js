'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('medicines', {
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
      device_id: {
        type: Sequelize.UUID,
        allowNull: true,
        references: { model: 'devices', key: 'id' },
        onDelete: 'SET NULL',
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      total_quantity: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      pill_per_dose: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      remaining_quantity: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('active', 'disabled', 'deleted'),
        allowNull: false,
        defaultValue: 'active',
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
    await queryInterface.dropTable('medicines');
  },
};

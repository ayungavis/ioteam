'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('schedules', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      medicine_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'medicines', key: 'id' },
        onDelete: 'CASCADE',
      },
      frequency_type: {
        type: Sequelize.ENUM('daily', 'weekly', 'hourly'),
        allowNull: false,
      },
      // Stores times_of_day, weekdays, interval_hours depending on frequency_type
      schedule_config: {
        type: Sequelize.JSONB,
        allowNull: false,
      },
      grace_before_minutes: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0,
      },
      grace_after_minutes: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 30,
      },
      start_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      end_at: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      status: {
        type: Sequelize.ENUM('active', 'superseded'),
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
    await queryInterface.dropTable('schedules');
  },
};

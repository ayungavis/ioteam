'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('doses', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      schedule_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'schedules', key: 'id' },
        onDelete: 'CASCADE',
      },
      medicine_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'medicines', key: 'id' },
        onDelete: 'CASCADE',
      },
      scheduled_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      window_start_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      window_end_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      dose_amount: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      status: {
        type: Sequelize.ENUM(
          'pending', //default
          'due', // before grace minutes
          'taken', // if already confirm by user = final status
          'missed', // after grace minutes
          'skipped', // todo: nice to have, no need for now
          'needs_confirmation', // if within before-after grace minutes box is opened (record exist in device_event table)
          'disabled' // deprecated
        ),
        allowNull: false,
        defaultValue: 'pending',
      },
      actual_taken_at: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      taken_source: {
        type: Sequelize.ENUM('device_event', 'manual'),
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

    await queryInterface.addIndex('doses', ['medicine_id', 'scheduled_at']);
    await queryInterface.addIndex('doses', ['status', 'window_start_at', 'window_end_at']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('doses');
  },
};

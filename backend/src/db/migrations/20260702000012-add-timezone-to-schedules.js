'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // IANA timezone (e.g. "Asia/Singapore") the schedule's times-of-day are
    // interpreted in. Default "UTC" for any pre-existing rows.
    await queryInterface.addColumn('schedules', 'timezone', {
      type: Sequelize.STRING,
      allowNull: false,
      defaultValue: 'UTC',
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('schedules', 'timezone');
  },
};

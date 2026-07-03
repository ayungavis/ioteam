'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.changeColumn('users', 'date_of_birth', {
      type: Sequelize.DATEONLY,
      allowNull: true,
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.changeColumn('users', 'date_of_birth', {
      type: Sequelize.DATEONLY,
      allowNull: false,
    });
  },
};

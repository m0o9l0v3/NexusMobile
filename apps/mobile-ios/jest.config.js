/** @type {import('jest').Config} */
module.exports = {
  preset: 'jest-expo/ios',
  testMatch: ['<rootDir>/__tests__/**/*.test.[jt]s?(x)'],
  clearMocks: true,
  restoreMocks: true,
};

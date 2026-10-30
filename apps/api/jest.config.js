/** @type {import("jest").Config} */
const shared = {
  moduleFileExtensions: ["js", "json", "ts"],
  rootDir: ".",
  testEnvironment: "node",
  moduleNameMapper: {
    "^@softxu/contracts$": "<rootDir>/../../packages/contracts/dist/index.js",
  },
  // jose is ESM-only. Compile that package to CommonJS for Jest.
  transformIgnorePatterns: ["/node_modules/(?!(\\.pnpm/jose@|jose/))"],
  transform: {
    "^.+\\.ts$": ["ts-jest", { tsconfig: "<rootDir>/tsconfig.json" }],
    "^.+/jose/.+\\.js$": [
      "ts-jest",
      {
        tsconfig: {
          allowJs: true,
          esModuleInterop: true,
          module: "commonjs",
          target: "ES2022",
        },
      },
    ],
  },
};

module.exports = {
  testTimeout: 30000,
  projects: [
    {
      ...shared,
      displayName: "unit",
      testMatch: ["<rootDir>/test/unit/**/*.spec.ts"],
      setupFiles: ["<rootDir>/test/setup-unit.ts"],
    },
    {
      ...shared,
      displayName: "integration",
      testMatch: ["<rootDir>/test/integration/**/*.spec.ts"],
      setupFiles: ["<rootDir>/test/setup-integration.ts"],
    },
  ],
};

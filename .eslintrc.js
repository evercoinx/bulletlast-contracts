module.exports = {
    parser: "@typescript-eslint/parser",
    parserOptions: {
        tsconfigRootDir: __dirname,
        project: "tsconfig.json",
        sourceType: "module",
    },
    root: true,
    plugins: ["@typescript-eslint"],
    extends: [
        "eslint:recommended",
        "plugin:prettier/recommended",
        "plugin:@typescript-eslint/recommended",
    ],
    env: {
        mocha: true,
        node: true,
    },
    rules: {},
};

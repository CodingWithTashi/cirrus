// @ts-check
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {ignores: ['lib/**', 'node_modules/**', 'coverage/**']},
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        // Config files live outside tsconfig's include, so the type-aware
        // parser needs them named explicitly.
        projectService: {
          allowDefaultProject: [
            'eslint.config.mjs',
            'vitest.config.ts',
            'vitest.rules.config.ts',
          ],
        },
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        {argsIgnorePattern: '^_', varsIgnorePattern: '^_'},
      ],
      // Firestore hands back `any`; the codec layer is where it gets narrowed,
      // so unsafe access is an error everywhere except there (see overrides).
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
      'no-console': 'error', // use the structured logger — console breaks log levels
      eqeqeq: ['error', 'always', {null: 'ignore'}],
    },
  },
  {
    // The codec is the one place raw wire `unknown` gets narrowed by hand.
    files: ['src/domain/journeyCodec.ts'],
    rules: {'@typescript-eslint/no-unsafe-member-access': 'off'},
  },
  {
    // Fixtures deliberately mimic untrusted wire payloads, including the
    // malformed ones — typing them strictly would defeat what they test.
    files: ['test/**/*.ts'],
    rules: {
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
);

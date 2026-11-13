# Testing the current release

Use the [single development workflow](BETA-DEVELOPMENT.md) for automated macOS checks and the single current package. Follow [hardware acceptance](HARDWARE-ACCEPTANCE.md) for the actual A2141 test matrix and Issue #2 protocol gate.

Open the packaged Setup app, choose a language and use the GUI actions. Source users have one starter: `Start.command`. The old language-specific launchers live in `legacy/`.

Do not run multiple keyboard-light controllers together. The standard app identity preserves existing preferences. No Linux testing is required.

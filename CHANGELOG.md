# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- refactor: split execution context struct items into dynamic and static parts, to lower gas consumption of updates
- opcodes: add 0x16-AND opcode
- opcodes: add 0x18-XOR opcode
- opcodes: add 0x0B-SIGNEXTEND opcode
- opcodes: add 0x07-SMOD opcode
- math: u256_signed_div now enforces div to be NonZero
- fix: ADDMOD opcode
- opcodes: add 0x09-MULMOD opcode
- ci: add `CHANGELOG.md` and enforce it is edited for each PR on `main`

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- tooling(23/08/2023): delete stale and label CI actions
- opcode(22/08/2023): add 0x1A-BYTE opcode
- tooling: CI now generates gas snapshots artifacts. pre-push hook to compare
  gas snapshots changes
- refactor(22/08/2023): add result-based error management in execution context
  run method.
- refactor(21/08/2023): wrap StaticExecutionContext and DynamicExecutionContext
  in boxes
- tooling: added scripts for gas snapshots generation/comparison. bumped scarb
  version to use nightlies.
- refactor(21/08/2023): add result-based error management in stack methods and
  related opcodes
- refactor: split execution context struct items into dynamic and static parts,

  to lower gas consumption of updates

- opcodes: add 0x80-DUP1 to 0x8F-DUP16 opcode
- opcodes: add 0x19-NOT opcode
- opcodes: add 0x16-AND opcode
- opcodes: add 0x18-XOR opcode
- opcodes: add 0x0B-SIGNEXTEND opcode
- opcodes: add 0x07-SMOD opcode
- math: u256_signed_div now enforces div to be NonZero
- fix: ADDMOD opcode
- opcodes: add 0x09-MULMOD opcode
- ci: add `CHANGELOG.md` and enforce it is edited for each PR on `main`

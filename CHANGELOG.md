# Changelog

All notable changes to this project will be documented in this file.

## [0.2.2] - 2025-07-22

### 🐛 Bug Fixes

- Remove duplicate instruction counting in executeInstruction
- Improve MEMCPY bounds checking and handle overlapping memory regions
- Prevent integer underflow in STORE/LOAD_MEM bounds checking
- Prevent integer underflow in jump instructions for target address 0

### ⚙️ Miscellaneous Tasks

- *(repo)* Add git-cliff for changelog generation

## [0.1.0] - 2025-02-15

### 🚀 Features

- *(core)* Initial Ziglet Virtual Machine Implementation
- Enhance Ziglet VM with Advanced Features

### 🐛 Bug Fixes

- Instructions would always produce a result of 0

### 💼 Other

- Initial Commit
- Initial Project Structure
- Error Handling System
- Reexport VM modules, test excercise to public API
- Fixed errors when returning an Error Enum and not an acutal error member of the global scope
- Refactored structure, decode, set and type have their own seperated module under src/instruction
- Added examples (simple and calculator) + build step for examples
- Added re-export for new modules

<!-- generated by git-cliff -->

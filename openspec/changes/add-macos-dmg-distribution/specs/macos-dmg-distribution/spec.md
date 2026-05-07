## ADDED Requirements

### Requirement: Release command produces a DMG
The system SHALL provide a repeatable release packaging command that produces a distributable Snapper DMG from the native macOS app bundle.

#### Scenario: Package Snapper for distribution
- **WHEN** the release packaging command completes successfully on macOS
- **THEN** a `.dmg` file containing Snapper SHALL exist in the configured distribution output directory
- **AND** the command SHALL not require launching Snapper from a terminal after packaging

#### Scenario: Package from a clean checkout
- **WHEN** the release packaging command is run after required build tools are available
- **THEN** it SHALL build or prepare `Snapper.app` before creating the DMG
- **AND** it SHALL fail with a clear error if the app bundle cannot be produced

### Requirement: DMG provides a Mac-style install layout
The DMG SHALL present Snapper as a normal macOS application install artifact for a single-app distribution.

#### Scenario: Open DMG contents
- **WHEN** a user opens the generated DMG in Finder
- **THEN** the volume SHALL contain `Snapper.app`
- **AND** the volume SHALL provide an Applications shortcut or equivalent guidance for moving Snapper into `/Applications`

#### Scenario: Install without terminal
- **WHEN** a user copies `Snapper.app` from the DMG into `/Applications`
- **THEN** Snapper SHALL be installable without running repository scripts from the terminal

### Requirement: Free distribution path avoids paid Apple credentials
The default DMG packaging flow SHALL work without Apple Developer Program membership, Developer ID certificates, notarization credentials, or App Store Connect access.

#### Scenario: Package without Developer ID certificate
- **WHEN** the release packaging command runs on a machine without a Developer ID Application certificate
- **THEN** the command SHALL still be able to produce a DMG using the free local signing behavior
- **AND** it SHALL not attempt notarization by default

#### Scenario: Preserve future signing path
- **WHEN** a future implementation adds Developer ID signing or notarization
- **THEN** the free DMG packaging behavior SHALL remain available as a separate or default local path

### Requirement: App metadata remains stable for installation
The packaged app SHALL preserve Snapper's expected macOS bundle metadata so the installed application is identifiable and permission prompts are understandable.

#### Scenario: Inspect packaged app metadata
- **WHEN** the generated DMG's `Snapper.app` is inspected
- **THEN** the app SHALL use the Snapper bundle name and executable name
- **AND** the app SHALL use the existing Snapper bundle identifier unless explicitly changed by a future proposal
- **AND** the app SHALL retain the Accessibility usage description

### Requirement: Unsigned distribution limitations are documented
The project documentation SHALL explain the behavior and limitations of the free unsigned or ad-hoc-signed DMG distribution path.

#### Scenario: User reads installation docs
- **WHEN** a user reads the installation or release documentation
- **THEN** the documentation SHALL explain that the free DMG is not Developer ID notarized
- **AND** it SHALL describe likely Gatekeeper first-launch warnings and approval steps at a high level
- **AND** it SHALL mention that Snapper still requires Accessibility permission to move and resize windows

#### Scenario: User compares free and certified distribution
- **WHEN** a maintainer reads the distribution documentation
- **THEN** the documentation SHALL distinguish the free DMG path from the paid Developer ID notarization path
- **AND** it SHALL identify Developer ID signing and notarization as the path for smoother public distribution

# Project Overview — Chimera

## What This Is

Chimera is a multilingual, cross-platform developer toolbox that brings common
conversion, encoding, formatting, comparison, analysis, and test-data generation
utilities into one application. It is delivered as a browser application, a
Windows and Linux desktop application, and a command-line interface.

## The Problem

Developers regularly switch among unrelated websites, scripts, and small utilities
for routine transformations and test-data preparation. That fragmentation wastes
time, creates inconsistent results, and can expose sensitive input to online
services. Chimera provides one consistent toolbox whose utilities process data
locally and remain usable offline.

## Who It's For

- Developers using an interactive browser or desktop interface.
- Developers using the command-line interface directly in Windows or Linux
  terminals.
- Local scripts and automation that invoke the command-line interface.

## What It Does

- Parses cron expressions and converts dates.
- Converts JSON arrays to tables and CSV, and converts JSON to YAML.
- Converts numbers among bases.
- Escapes, unescapes, compares, and analyzes text and lists.
- Encodes and decodes Base64 content, certificates, GZIP content, HTML, JWTs,
  QR codes, and URLs.
- Formats JSON, SQL, and XML.
- Generates hashes, checksums, Lorem Ipsum, passwords, UUIDs, and GUIDs.
- Generates synthetic credit-card, identity-document, and person data for US and
  Brazilian locales.
- Encodes and decodes common ciphers and alphabets.
- Stores only the user's theme and interface-language preferences locally.
- Checks for desktop and CLI updates and, with user confirmation, applies them
  without requiring a manual download.

## What It Doesn't Do

- Cloud synchronization or remote storage of user data.
- User accounts, authentication, or authorization.
- A plugin or extension ecosystem.
- Mobile applications.
- Collaborative or multi-user workflows.
- Server-side processing of utility inputs.

## How Success Is Measured

- Every capability listed in the brainstorm is implemented and usable through
  the browser, desktop application, and CLI where an interactive visual surface
  is not intrinsically required.
- Every utility is covered by appropriate unit and functional tests, and those
  tests pass on its supported targets.
- Utility operations work offline and keep input data on the user's device.
- The web application works in Chromium, Firefox, and Safari.
- Desktop and CLI artifacts are available for Windows and Linux as portable
  downloads or installers, and installed copies can prompt for and apply updates.
- Both English and Brazilian Portuguese interfaces are usable, with English as
  the default.
- The interactive applications provide a clear, responsive, and consistent user
  experience across supported platforms.

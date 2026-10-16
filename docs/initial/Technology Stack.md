# Technology Stack — Chimera

## Platform & Language

Chimera uses Flutter and Dart. Technologies and packages are selected from their
latest stable releases at implementation time rather than being pinned in this
informal document. Exact selections belong in the formal
[Technology Stack Document](../requirements/Technology%20Stack%20Document.md).

## Application Type

- A Flutter web application for Chromium, Firefox, and Safari.
- A Flutter desktop application for Windows and Linux.
- A Dart command-line application for Windows and Linux terminals and local
  automation.

The interfaces share utility logic so that the same operation produces consistent
results across browser, desktop, and CLI surfaces.

## Data Storage

Utility operations are stateless. Chimera has no database and stores no input,
output, or operation history. Only two user preferences persist locally:

- Theme: light or dark.
- Interface language: English or Brazilian Portuguese, with English as default.

## Data Access

No ORM, query builder, database driver, or remote data-access layer is required.
A platform-appropriate local preference store provides access to the theme and
language settings.

## Authentication

Chimera has no authentication or authorization. It has no user accounts and all
locally available utilities are accessible to the person running the application.

## Testing

Unit and functional testing are required for every utility and supported surface.
The baseline is Flutter and Dart's official testing tooling, including
`flutter_test`, `integration_test`, and `test`. Additional stable test packages
may be selected when they provide a better fit for a specific target or behavior.

## External Dependencies

Utility execution depends on no external service and must work offline. Inputs
and outputs remain on the user's device. Network access is limited to delivery
concerns:

- Loading the web application from the self-managed server.
- Checking GitHub Releases for desktop and CLI updates.
- Downloading an update only after the user accepts the prompt.

Third-party Flutter and Dart packages may be used when they are the best fit for
an operation, provided the utility remains local and offline.

## Deployment

The web build is deployed in Docker to a self-managed Ubuntu VPS and exposed
through Traefik. Deployment is managed by
[Yggdrasil](https://github.com/artur-rios/yggdrasil), using its application
catalog, root `Jenkinsfile`, self-hosted Jenkins pipeline, environment-specific
Docker Compose deployment, health checks, and rollback behavior. It targets
Chromium, Firefox, and Safari.

Windows and Linux desktop and CLI builds are published through GitHub Releases.
Each is offered as a portable download or an installer. Installed desktop and
CLI distributions check for updates, prompt the user, and apply an accepted
update without requiring the user to download a package manually. GitHub Actions
owns build and test checks; Yggdrasil owns environment deployment and the release
promotion flow.

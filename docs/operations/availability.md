# Production Availability Objective

Chimera's production web application has a monthly availability objective of
99.5%, measured as successful `/healthz` probes divided by scheduled probes while
the production environment is expected to run.

Yggdrasil's status API performs the health probes and exposes their current state
to its console and monitoring stack. Prometheus records probe results; Grafana is
the operational review surface. Planned maintenance is recorded explicitly and is
not silently removed from measurements. Utility input and output never enter these
signals.

The objective is reviewed after each production incident and before each release.
Failure to meet it does not cause automated data collection inside Chimera; it
triggers an operational review of container, host, routing, and deployment events.


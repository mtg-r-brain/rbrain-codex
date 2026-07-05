# deployment-stack-distroless-health — Design

One decision: keep distroless runtime images and adapt the probe strategy, rather than fattening images to host a probe.

Alternatives considered:

- **Add a static probe binary to each Rust image** (e.g. a `grpc_health_probe`-style helper or busybox layer): six sibling Dockerfile changes and a permanent image-size/attack-surface tax, to satisfy a local-stack convenience. Rejected.
- **Bind-mount a host `curl` into containers**: depends on host binary compatibility (macOS vs linux/amd64/arm64), fragile. Rejected.
- **Exempt distroless services from in-container probes** (chosen): infra healthchecks (`pg_isready`, NATS `/healthz`) still gate startup ordering — which is what actually prevents boot-time migration races. Service liveness is asserted by the host-side `GET /health` sweep that already defines "stack settled". Kubernetes `httpGet` probes restore per-container health properly in the Helm story (v2), where the kubelet probes from outside the container.

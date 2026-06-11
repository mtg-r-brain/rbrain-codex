# Build stage
FROM rust:1.83-slim AS builder
WORKDIR /build

# Cache deps separately from source
COPY Cargo.toml Cargo.lock* ./
RUN mkdir src && \
    echo "fn main(){}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

COPY src ./src
RUN touch src/main.rs && cargo build --release && \
    strip target/release/rbrain-chronicle

# Runtime stage
FROM gcr.io/distroless/cc-debian12
COPY --from=builder /build/target/release/rbrain-chronicle /app/rbrain-chronicle
EXPOSE 8080
USER nonroot
ENTRYPOINT ["/app/rbrain-chronicle"]

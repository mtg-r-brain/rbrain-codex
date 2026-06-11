# Build stage
FROM node:22-alpine AS builder
WORKDIR /build

RUN corepack enable && corepack prepare pnpm@9.12.0 --activate

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

# Runtime stage
FROM node:22-alpine
WORKDIR /app

ENV NODE_ENV=production \
    PORT=8080 \
    HOSTNAME=0.0.0.0

RUN addgroup -S rbrain && adduser -S -G rbrain rbrain

COPY --from=builder --chown=rbrain:rbrain /build/.next/standalone ./
COPY --from=builder --chown=rbrain:rbrain /build/.next/static ./.next/static
COPY --from=builder --chown=rbrain:rbrain /build/public ./public 2>/dev/null || true

USER rbrain
EXPOSE 8080
CMD ["node", "server.js"]

## syntax=docker/dockerfile:1.6
ARG TARGETPLATFORM
ARG BUILDPLATFORM

FROM --platform=$BUILDPLATFORM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
# Cache npm dependencies between builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

FROM --platform=$BUILDPLATFORM node:20-alpine AS builder
WORKDIR /app
# Some Next.js native deps (e.g., sharp) may require libc6-compat on Alpine
RUN apk add --no-cache libc6-compat
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
RUN --mount=type=cache,target=/root/.npm \
    npm run build

FROM --platform=$TARGETPLATFORM gcr.io/distroless/nodejs20-debian12:nonroot AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copy only the standalone output and public assets
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
ENV PORT=3000

# distroless/nodejs has node as entrypoint; run the Next.js server
CMD ["server.js"]
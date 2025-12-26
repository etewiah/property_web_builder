# syntax=docker/dockerfile:1
# PropertyWebBuilder Production Dockerfile
# Multi-stage build for optimized production image size

# =============================================================================
# Stage 1: Node.js Builder - Compile Tailwind CSS and other assets
# =============================================================================
FROM node:22-bookworm-slim AS node_builder

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install Node.js dependencies
# Note: We need all dependencies because Tailwind CLI is not in devDependencies
RUN npm ci

# Copy source files needed for Tailwind CSS compilation
# Tailwind 4 uses @import "tailwindcss" with inline @theme configuration
COPY app/assets/stylesheets/ ./app/assets/stylesheets/
COPY app/themes/ ./app/themes/
COPY app/views/ ./app/views/
COPY app/helpers/ ./app/helpers/
COPY app/javascript/ ./app/javascript/

# Build Tailwind CSS for all themes (production minified)
RUN npm run tailwind:build:prod

# =============================================================================
# Stage 2: Ruby Builder - Install gems with native extensions
# =============================================================================
FROM ruby:3.4-slim-bookworm AS ruby_builder

# Install build dependencies for native gem extensions
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libvips-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /app

# Set production environment for gem installation
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

# Copy Gemfiles and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    # Remove unnecessary files from bundle
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # Compile bootsnap cache for faster boot
    bundle exec bootsnap precompile --gemfile

# =============================================================================
# Stage 3: Production Image - Minimal runtime environment
# =============================================================================
FROM ruby:3.4-slim-bookworm AS production

# Install runtime dependencies only (no build tools)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libpq5 \
    libvips42 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Create non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

WORKDIR /app

# Set production environment variables
ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Copy installed gems from builder
COPY --from=ruby_builder /usr/local/bundle /usr/local/bundle

# Copy compiled Tailwind CSS from Node builder
COPY --from=node_builder /app/app/assets/builds/ ./app/assets/builds/

# Copy application code
COPY . .

# Precompile bootsnap cache for application code
RUN bundle exec bootsnap precompile app/ lib/

# Precompile Rails assets (Sprockets manifest, fingerprinting, etc.)
# SECRET_KEY_BASE is required for asset precompilation but not used
RUN SECRET_KEY_BASE=dummy_key_for_precompilation \
    bundle exec rake assets:precompile

# Create required directories
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log storage && \
    chown -R rails:rails tmp log storage db

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh

# Switch to non-root user
USER rails

# Expose Puma port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/up || exit 1

# Entrypoint handles database migrations and startup
ENTRYPOINT ["docker-entrypoint.sh"]

# Default command: start Puma web server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

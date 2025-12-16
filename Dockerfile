# Multi-stage build for Jekyll portfolio
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./

# Install Node dependencies with Yarn (already included in node:20)
RUN yarn install

# Copy source files
COPY . .

# Build assets with gulp
RUN yarn prod


FROM ruby:3.3-alpine AS jekyll-builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Copy Gemfile
COPY Gemfile* ./

# Install Ruby gems
RUN bundle install

# Copy everything from node builder
COPY --from=node-builder /app .

# Build Jekyll site
RUN bundle exec jekyll build


# Final stage - nginx to serve static files
FROM nginx:alpine

# Copy built site from jekyll-builder
COPY --from=jekyll-builder /app/_site /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

# Builds the Angular app and serves it with nginx, proxying /api to the backend.
# Used by the "full" docker compose profile.

FROM node:22-alpine AS build
WORKDIR /build
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npx ng build --configuration production

FROM nginx:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /build/dist/frontend/browser/ /usr/share/nginx/html/
EXPOSE 80

# --- build stage: bundle the client-side Firebase SDK with esbuild ---
FROM node:20-slim AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY public/login.js public/account.js public/admin.js ./public/
RUN npm run build

# --- runtime stage: production deps + server only ---
FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./server.js
COPY public/login.html public/login.css public/account.html public/account.css public/admin.html public/admin.css ./public/
COPY --from=build /app/public/dist ./public/dist
COPY gated-content ./gated-content

EXPOSE 8080
CMD ["node", "server.js"]

# Étape 1 : dépendances de production uniquement
FROM node:25-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Étape 2 : image finale
FROM node:25-alpine
ENV NODE_ENV=production
WORKDIR /app

# Mise à jour de npm
RUN npm install -g npm@latest

COPY --from=deps /app/node_modules ./node_modules
COPY server.js ./

USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "server.js"]

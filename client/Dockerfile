FROM node:20-alpine

WORKDIR /app

# Railway builds this Dockerfile with the repository root as context.
COPY client/package*.json ./
RUN npm install

COPY client/ ./

RUN npm run build

ENV NODE_ENV=production

CMD ["sh", "-c", "npm run preview -- --host 0.0.0.0 --port ${PORT:-4173}"]

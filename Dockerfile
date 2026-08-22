FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY server/package.json ./package.json
RUN npm install --omit=dev
COPY server/src ./src
EXPOSE 4000
CMD ["node","src/index.js"]

FROM node:20-alpine

WORKDIR /app

COPY client/package*.json ./
RUN npm install

COPY client/ ./
RUN npm run build

FROM nginx:alpine

COPY --from=0 /app/dist /usr/share/nginx/html
COPY client/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

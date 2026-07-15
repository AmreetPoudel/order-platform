FROM node:20-alpine AS build

WORKDIR /app
COPY package.json .
RUN npm install

COPY . .
# API URL baked in at build time - points to the api container via the
# browser, so use localhost since the browser runs on the host machine
ARG VITE_API_URL=http://localhost:4000
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

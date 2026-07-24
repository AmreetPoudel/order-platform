## on resact after installing dependencies, we get static content in the dist folder, which we can serve using nginx.
##nothing other than that, we don't need node to run the frontend, so we can use nginx to serve the static content.


## multi stage build for frontend 

FROM node:20-alpine AS build


WORKDIR /app
COPY package.json .
RUN npm install

COPY . .
# API URL baked in at build time - points to the api container via the
# browser, so use localhost since the browser runs on the host machine
ARG VITE_API_URL=http://localhost:4000
# arg is build time variable, it is not available at runtime, so we need to set it as an environment variable in the container.
#we can get arg from this dockerfile or CI .
ENV VITE_API_URL=$VITE_API_URL
# vite api url is set as an environment variable in the container, so we can access it in the frontend code using 
#import.meta.env.VITE_API_URL  
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

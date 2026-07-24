FROM node:20-alpine

WORKDIR /app

COPY package.json .
#dependencies for production only because we don't need dev dependencies in the container 
# dependencies — packages your app actually needs while running (e.g., express to serve HTTP requests).
# devDependencies — packages only needed while developing (testing frameworks like jest, linters like eslint, build tools)
 # your running application never calls these at runtime, they're tools you use while writing code. 
 # {
#   "dependencies": {
#     "express": "^4.18.0"
#   },
#   "devDependencies": {
#     "jest": "^29.0.0",
#     "eslint": "^8.0.0"
#   }
# }
RUN npm install --production

COPY . .

EXPOSE 4000

CMD ["node", "index.js"]
# this is graceful shutdown, it will listen for the SIGTERM signal and close the server gracefully before exiting the 
#process.
#if it is cmd then it will not be able to listen for the signal and will exit immediately, which can cause issues with 
#open connections and data loss.

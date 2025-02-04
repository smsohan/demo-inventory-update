
FROM node:23-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

# Expose the port your app listens on
EXPOSE 8080

# Define the command to run when the container starts
CMD ["npx", "nodemon"]
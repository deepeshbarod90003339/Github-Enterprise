# Stage 1: Build the React app
FROM node:20.13.1 AS build
 
WORKDIR /usr/src/app
 
# Copy package.json and package-lock.json first for caching
COPY package*.json ./
 
# Remove existing node_modules & package-lock.json (to avoid corruption)
RUN rm -rf node_modules package-lock.json
 
# Install dependencies
RUN npm install --force
 
# Copy the rest of the app files
COPY . .
 
# Build the React app
RUN npm run build
 
# Stage 2: Serve the React app with Nginx
FROM nginx:latest
 
# Remove the default Nginx website files
RUN rm -rf /usr/share/nginx/html/*
 
# Create the custom directory structure
RUN mkdir -p /usr/share/nginx/html/eda/ui/dataplatform/datascience
 
# Copy the built React app from the build stage
COPY --from=build /usr/src/app/apps/web-app/dist/ /usr/share/nginx/html/eda/ui/dataplatform/datascience/
 
# Set proper permissions for the content
RUN chmod -R 755 /usr/share/nginx/html/eda/ui/dataplatform/datascience
# Set proper permissions for the content
#RUN chmod -R 755 /usr/share/nginx/html && \
    #chown -R nginx:nginx /usr/share/nginx/html
 
EXPOSE 80
 
CMD ["nginx", "-g", "daemon off;"]

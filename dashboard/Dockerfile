FROM nginx:alpine

# Copy dashboard files
COPY index.html /usr/share/nginx/html/

# Create health check endpoint
RUN echo '<!DOCTYPE html><html><body>OK</body></html>' > /usr/share/nginx/html/health

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

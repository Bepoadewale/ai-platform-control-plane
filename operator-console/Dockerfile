FROM nginx:1.27-alpine

COPY operator-console/index.html operator-console/styles.css operator-console/app.js /usr/share/nginx/html/
COPY operator-console/runtime-config.js /usr/share/nginx/html/runtime-config.js
COPY operator-console/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

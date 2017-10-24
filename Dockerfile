# Building on top of Ubuntu 14.04. The best distro around.
FROM nginx
COPY html /usr/share/nginx/html

EXPOSE 80
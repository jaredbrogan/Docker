FROM nginx:alpine

RUN apt update && apt upgrade -y && apt install iputils-ping -y
RUN rm -fv /etc/nginx/conf.d/default.conf

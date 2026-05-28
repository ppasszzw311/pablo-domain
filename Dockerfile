FROM nginx:1.27-alpine

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.d/15-set-nginx-resolver.envsh /docker-entrypoint.d/15-set-nginx-resolver.envsh

CMD ["nginx", "-g", "daemon off;"]

FROM nginx:1.27-alpine
LABEL org.opencontainers.image.title="E-Waste Collection and Recycling Portal"
LABEL org.opencontainers.image.description="Sample city e-waste collection portal"
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1

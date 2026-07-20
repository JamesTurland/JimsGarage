## Traefik with seperate socket-proxy
The benefit of using a Docker Socket Proxy with Traefik is to enhance security by restricting access to the Docker API. Instead of allowing Traefik full access to the Docker socket, the proxy enables the proxying of only the necessary API calls, thus reducing the exposure of the Docker socket to the public and potential security risks.

## Use this Socket Proxy with othter Stacks / docker-compose Services
The idear is, to create a internal Traefik Socket Proxy (with only the Permission to read Container Information with the API).
If you would use this socket proxy, for other Stacks, see the example below.

### Adjustment with the docker-compose.yml from Uptime-Kuma
example: Uptime-Kuma

``` docker-compose-uptime.yml
services:
  uptime-kuma:
    image: louislam/uptime-kuma
    volumes:
      - /opt/dockerdata/uptime-kuma:/app/data
      # - /var/run/docker.sock:/var/run/docker.sock:ro  # not necessarry - use the socket-proxy
#   ...
    networks:
      - proxy
      - socket-proxy

networks:
  socket-proxy:
    name: socket-proxy-traefik    # use the socket proxy from the Traefik stack
    external: true

```

### Adjust the Docker Host Deamon Uptime-Kuma Web-GUI:

1. Uptime-Kuma Settings > Docker Hosts > Setup Docker Host
2. Docker Daemon: change to `tcp://socket-proxy-traefik:2375`
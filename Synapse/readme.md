1) Create a config file

sudo docker run -it --rm \
   --mount type=volume,src=synapse-data,dst=/data \
   -e SYNAPSE_SERVER_NAME=matrix.jimsgarage.co.uk \
   -e SYNAPSE_REPORT_STATS=no \
   matrixdotorg/synapse:latest generate

2) become root and access the file

sudo -i

3) copy config file to your docker volume mount

4) become non-root user

5) change owner and permissions of configs so that we can edit them

su username

sudo chown ubuntu:ubuntu * (or whatever your user is)

6) edit config

change database section

 name: psycopg2
 args:
   user: <user>
   password: <pass>
   database: <db>
   host: <host>
   cp_min: 5
   cp_max: 10

copy over the credentials from the docker compose

7) create admin user

docker exec -it synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml --help #remove help once ready

8) add record to dns server (remember needs to be external as well!)

9) check page to see it's up

10) element and profit

11) Add emails, recaptcha if you want to (recommended!)

# Nethermind - Docker - Client

 Folder contains the Docker Compose files to run the Nethermind node for Fuse or Spark networks.


## Usage

 Was used the simple approach with Nethermind configuration based on `docker-compose.[node_role].yaml` file and environment variables file `.[node_role].env`.

 To run the specific Nethermind configuration depending on the node role:

 ```bash
 docker-compose -f docker-compose.[node_role].yaml --env-file .[node_role].env up -d
 ```

 or

 ```bash
 docker compose -f docker-compose.[node_role].yaml --env-file .[node_role].env up -d
 ```

 depending on Docker Compose version.

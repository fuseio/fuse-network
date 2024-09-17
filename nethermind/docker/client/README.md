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


## How-To

 How-To tutorials used to provide detailed info for Docker Compose setup usage.

### Update Docker image version

 There are the next steps to update Docker image version:

 1. Go to the `[node_role].env` file;
 
 2. Find the needed section `[APP]_DOCKER_IMAGE_TAG`;

 3. Update the Docker image tag;

 4. Run the command provided in `README.md` file, `Usage` section.

# Nethermind - Docker - Monitoring

 Folder contains the Docker Compose files to run the monitoring stack to monitor Nethermind client health and performance. Monitoring stack contains the next applications running near with the Nethermind client:

 - Prometheus - collect the metrics from Nethermind client exposed port (by default :9091/tcp);

 - Grafana - visualize Nethermind metrics;

 - Seq - collect Nethermind client logs.

 There is a table with exposed endpoints:

 | Application  | Endpoint              |
 | ------------ | --------------------- |
 | Prometheus   | http://localhost:9090 |
 | Grafana      | http://localhost:3000 |
 | Seq          | http://localhost:5341 |


 > **Note**: if you want to expose it in public please take care about HTTPS connection and proper service authentication.

 
## Usage

 Was used the simple approach with initial `docker-compose.yaml` file and environment variables file `.monitoring.env`.

 To run the specific Nethermind configuration depending on the node role:

 ```bash
 docker-compose --env-file .monitoring.env up -d
 ```

 or

 ```bash
 docker compose -f docker-compose.[node_role].yaml --env-file .[node_role].env up -d
 ```

 depending on Docker Compose version.

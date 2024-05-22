# Starkflare Indexer

This repository contains the indexer for the Starkflare, a tool that monitors the resource usage of rollups in the StarkNet ecosystem, starting with StarkNet Mainnet. The main repository for Starkflare can be found at https://github.com/walnuthq/starkflare.

## Installation

To set up the indexer locally, follow these steps:

1. Install the Apibara CLI by following the instructions in the [Apibara Getting Started guide](https://www.apibara.com/docs/getting-started).

2. Obtain an Apibara DNA Key. The [Apibara Getting Started guide](https://www.apibara.com/docs/getting-started) provides instructions on how to get the key.

3. Set up your editor by following the instructions in the [Apibara documentation](https://www.apibara.com/docs/indexers/editor-setup).

## API Implementation

We are using PostgREST to create a RESTful API directly from our PostgreSQL database. PostgREST automatically generates API endpoints based on the database schema, allowing us to quickly expose the indexed data through a web API without the need for custom server-side code. This approach simplifies the development process and enables us to focus on the indexing logic and database design.

## Database Migrations

This repository includes database migrations to set up the necessary tables for the indexer. The migration scripts are named using a numbered prefix followed by a descriptive name, such as 001_init.up.sql. The number represents the order in which the migrations should be applied.

## Running the Indexer and API

To run the database and API locally, you can use the provided Docker Compose configuration. Docker Compose will set up a PostgreSQL database and PostgREST for you. The included Swagger UI can be used to explore and test the API endpoints. The indexer needs to be run separately. 

1. From the root folder of the repository, navigate to the database folder.

2. Run the following command to start the PostgreSQL database and PostgREST:
   
   ```docker-compose up -d```

3. Return to the root folder and start the indexer by running the following command with your Apibara DNA Key:
   
   ```apibara run --allow-env=.env.dev indexer/src/account-calls.ts -A <APIBARA_DNA_KEY>```
   

Once the indexer is running and the Docker Compose services are up, you can:

- Access the API at `http://localhost:3000/rpc/` to retrieve the indexed data.
- Connect to the PostgreSQL database at `postgresql://postgres:password@localhost:5432/postgres`.
- Explore and test the API endpoints using Swagger at `http://localhost:8080`.

To stop the database and API and remove the volumes:

```docker-compose down --volumes```

## Contributing

If you'd like to contribute to Starkflare and add more data to the app, please follow these guidelines:

- Most of the tiles on the Starkflare app use a single get_common_data endpoint. If you want to add more data, create a separate function and call it within the get_common_data function to include the results.

- For example, we already have a get_user_stats function to retrieve data for the users tile.

By following this approach, you can easily extend the functionality of Starkflare and provide additional insights into the resource usage of rollup in the StarkNet ecosystem.
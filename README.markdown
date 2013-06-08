# Redis Object

#### Seabright Studios

It maps arbitrary objects to a Redis (http://redis.io) store, using sorted sets as indices and hashes as object storage, with some regular old sets mixed in for fun.

## Running the specs

Choose a system redis db you're not using and set it in the environment:

	TEST_DB=14 rake spec


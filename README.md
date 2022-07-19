# Running local umee

- This repo is meant to facilitate the use of umee blockchain, starting 2 process:
  - Umee blockchain with single node
  - Price-feeder with mock data

## Run the docker-compose

> remind to clear your docker volumes first

```shell
$~ docker-compose up --build
```

## Changing the config

- It is also possible for the user to modify the [price-feeder config](./price-feeder.config.toml), or even the [umee init script](./single-node.sh) to build with different [parameters](https://umeeversity.umee.cc/developers/)

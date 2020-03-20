import Config

config :nostrum,
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: 1

config :logger,
  level: :warn

import_config "#{Mix.env()}.exs"

import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :nostrum,
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: 1

config :broker, Broker.Report.Scheduler,
  timezone: "America/New_York",
  jobs: [
    market_open_report: [
      # just before 9:30am ET, M-F
      schedule: "29 9 * * 1-5",
      task: fn ->
        Broker.Portfolio.OrderProcessor.open()
        Broker.Report.Scheduler.report("Market Open Leaderboard")
      end
    ],
    market_close_report: [
      # just after 4pm ET, M-F
      schedule: "1 16 * * 1-5",
      task: fn ->
        Broker.Portfolio.OrderProcessor.close()
        Broker.Report.Scheduler.report("Market Close Leaderboard")
      end
    ]
  ]

import_config "#{Mix.env()}.exs"

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
        Broker.Report.Scheduler.report("Market Open Leaderboard")
      end
    ],
    market_open_allow_trades: [
      # just after 9:30am ET, M-F
      schedule: "31 9 * * 1-5",
      task: fn ->
        Broker.Portfolio.OrderProcessor.open()
      end
    ],
    market_close_report: [
      # just after 4pm ET, M-F
      schedule: "1 16 * * 1-5",
      task: fn ->
        Broker.Report.Scheduler.report("Market Close Leaderboard")
      end
    ],
    market_close_allow_trades: [
      # just before 4pm ET, M-F
      schedule: "59 15 * * 1-5",
      task: fn ->
        Broker.Portfolio.OrderProcessor.close()
      end
    ]
  ]

import_config "#{Mix.env()}.exs"

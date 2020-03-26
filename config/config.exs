import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :nostrum,
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: 1

config :broker, Broker.Report.Scheduler,
  timezone: "America/New_York",
  jobs: [
    market_open_report: [
      # 9:30am ET, M-F
      schedule: "30 9 * * 1-5",
      task: fn ->
        Nostrum.Api.create_message(
          686_660_042_208_182_397,
          "```\n#{Broker.Bot.Command.report_message("Market Open Leaderboard")}\n```"
        )
      end
    ]
    market_close_report: [
      # 4pm ET, M-F
      schedule: "0 16 * * 1-5",
      timezone: "America/New_York",
      task: fn ->
        Nostrum.Api.create_message(
          686_660_042_208_182_397,
          "```\n#{Broker.Bot.Command.report_message("Market Close Leaderboard")}\n```"
        )
      end
    ]
  ]

import_config "#{Mix.env()}.exs"

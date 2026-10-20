import Config

# The only place the OS environment is read. Everything else asks `Campfire.Env`, which reads the
# map set here, so a module never depends on the process environment and tests can override a
# value with `Campfire.Env.put/2` instead of mutating the environment.
environment = %{
  "APP_VERSION" => System.get_env("APP_VERSION", "dev"),
  "GIT_REVISION" => System.get_env("GIT_REVISION", "dev"),
  "APP_URL" => System.get_env("APP_URL", "http://example.org"),
  "RAILS_ENV" => System.get_env("RAILS_ENV", "production"),
  "FORCE_SSL" => System.get_env("FORCE_SSL", ""),
  "PORT" => System.get_env("PORT", "7070"),
  "CAMPFIRE_BIND" => System.get_env("CAMPFIRE_BIND"),
  "CAMPFIRE_NO_SERVER" => System.get_env("CAMPFIRE_NO_SERVER"),
  "CAMPFIRE_WORKER" => System.get_env("CAMPFIRE_WORKER"),
  "CAMPFIRE_JOBS_ADAPTER" => System.get_env("CAMPFIRE_JOBS_ADAPTER"),
  "CAMPFIRE_CLOCK" => System.get_env("CAMPFIRE_CLOCK"),
  "CAMPFIRE_CLOCK_TICK" => System.get_env("CAMPFIRE_CLOCK_TICK"),
  "CAMPFIRE_RESPONSE_CACHE_MB" => System.get_env("CAMPFIRE_RESPONSE_CACHE_MB", "64"),
  "CAMPFIRE_FRAGMENT_CACHE_MB" => System.get_env("CAMPFIRE_FRAGMENT_CACHE_MB", "32"),
  "CAMPFIRE_CABLE_REDIS_BRIDGE" => System.get_env("CAMPFIRE_CABLE_REDIS_BRIDGE"),
  "REDIS_URL" => System.get_env("REDIS_URL"),
  "DATABASE_PATH" => System.get_env("DATABASE_PATH", "var/production.sqlite3"),
  "STORAGE_PATH" => System.get_env("STORAGE_PATH", "var/files"),
  "BACKUP_PATH" => System.get_env("BACKUP_PATH"),
  "SSL_CERT_FILE" => System.get_env("SSL_CERT_FILE"),
  "SECRET_KEY_BASE" => System.get_env("SECRET_KEY_BASE"),
  "VAPID_PUBLIC_KEY" => System.get_env("VAPID_PUBLIC_KEY", ""),
  "VAPID_PRIVATE_KEY" => System.get_env("VAPID_PRIVATE_KEY"),
  "PATH" => System.get_env("PATH", "")
}

# The test environment signs with the captured reference key; the vectors are the source of truth
# for it, and config is evaluated before the suite runs.
environment =
  if config_env() == :test do
    secret = Path.join(__DIR__, "../vectors/rails_compat.json") |> File.read!() |> Jason.decode!()

    Map.put(environment, "SECRET_KEY_BASE", secret["secret_key_base"])
  else
    environment
  end

config :campfire, :env, environment

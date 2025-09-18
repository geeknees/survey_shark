# Processes count, allows better CPU utilization when executing Ruby code.
workers(ENV.fetch("WEB_CONCURRENCY") { 2 })

# Thread per process count allows context switching on IO-bound tasks for better CPU utilization.
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 3 }
threads(threads_count, threads_count)

# Reduce memory usage on copy-on-write (CoW) systems.
preload_app!

# Ruby buildpack sets RAILS_ENV and RACK_ENV in production.
run_env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
environment(run_env)

# Support IPv6 by binding to host `::` in production instead of `0.0.0.0` and `::1` instead of `127.0.0.1` in development.
host = run_env == "production" ? "::" : "::1"

# PORT environment variable is set by Heroku in production.
port(ENV.fetch("PORT") { 3000 }, host)

# Allow Puma to be restarted by the `rails restart` command locally.
plugin(:tmp_restart)

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

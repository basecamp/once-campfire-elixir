#!/usr/bin/env ruby
# Runs the shared verification load generator against an implementation started by hand on this
# host.
#
# The upstream harness starts each implementation as a production container on Linux with pinned
# CPUs. This keeps its load generator, its seed-derived route contracts and its write audits, but
# points them at a native process and a native build, which is how this repository measures on
# macOS. Contracts are validated against the seed's SQL, so nothing is taken on trust from the app.
#
#   ruby bench/native-http.rb --app elixir --base http://127.0.0.1:4000 --out tmp/native/elixir
#
# Requires the shared checkout (VERIFICATION_ROOT, default ../once-campfire-verification), its
# built load generator and a generated seed (its bin/seed).
require "fileutils"
require "json"
require "optparse"

VERIFICATION = File.expand_path(
  ENV.fetch("VERIFICATION_ROOT") { File.expand_path("../../once-campfire-verification", __dir__) }
)

$LOAD_PATH.unshift(File.join(VERIFICATION, "bench"))
require "comparison_support"
require "contracts"

options = {
  app: "app",
  base: nil,
  seed: File.join(VERIFICATION, "fixtures/default"),
  routes: "room_show,messages_page,sidebar,search,post_message",
  concs: "1,16,64",
  duration: 8,
  rounds: 3,
  out: nil
}

OptionParser.new do |parser|
  parser.on("--app NAME") { |value| options[:app] = value }
  parser.on("--base URL") { |value| options[:base] = value }
  parser.on("--seed PATH") { |value| options[:seed] = File.expand_path(value) }
  parser.on("--routes LIST") { |value| options[:routes] = value }
  parser.on("--concs LIST") { |value| options[:concs] = value }
  parser.on("--duration SECONDS", Integer) { |value| options[:duration] = value }
  parser.on("--rounds N", Integer) { |value| options[:rounds] = value }
  parser.on("--out DIR") { |value| options[:out] = File.expand_path(value) }
  parser.on("--help") { puts parser; exit }
end.parse!

abort "--base is required" unless options[:base]
abort "--out is required" unless options[:out]

include BenchmarkSupport

loadgen = File.join(VERIFICATION, "loadgen/target/release/loadgen")
abort "build the shared load generator first: cargo build --release --locked --manifest-path loadgen/Cargo.toml" unless File.executable?(loadgen)

labels = JSON.parse(File.read(File.join(options[:seed], "labels.json")))
database = File.join(options[:seed], "db/production.sqlite3")
room = Integer(labels.fetch("rooms.watercooler"))
write_room = Integer(labels.fetch("rooms.hq"))

routes = {
  "room_show" => "/rooms/#{room}",
  "messages_page" => "/rooms/#{room}/messages?before=#{labels.fetch('messages.busy_060')}",
  "sidebar" => "/users/me/sidebar",
  "search" => "/searches?q=coffee",
  "post_message" => nil
}

lg = ->(*args) { JSON.parse(run(loadgen, *args)) }

FileUtils.mkdir_p(options[:out])
samples = []

options[:rounds].times do |round|
  cookie = lg.call(
    "login", "--base", options[:base],
    "--email", labels.fetch("emails.david"), "--password", labels.fetch("passwords.all")
  ).fetch("cookie")

  scrape = lg.call("scrape", "--base", options[:base], "--cookie", cookie, "--room", room.to_s)
  csrf = scrape.fetch("csrf").to_s

  # Only the routes this run measures are prepared and validated: an implementation under test can
  # differ elsewhere without blocking the measurement of the route the run is about.
  prepared = BenchmarkContracts.prepare(
    options[:base], cookie, database, labels, scrape.fetch("css"),
    File.join(options[:out], "contracts"),
    only: options[:routes].split(",")
  )
  contracts = prepared.fetch(:contracts)

  options[:routes].split(",").each do |name|
    path = routes.fetch(name)

    audit = File.join(options[:out], "post-#{name}-round-#{round + 1}.jsonl")
    args = path ? ["--path", path] : ["--post-room", write_room.to_s, "--csrf", csrf]

    options[:concs].split(",").each do |conc|
      audit_args = path ? [] : ["--audit-writes", audit]

      sample = lg.call(
        "http", "--base", options[:base], "--cookie", cookie, *args,
        "--validate", contracts.fetch(name), *audit_args,
        "--conc", conc, "--duration", options[:duration].to_s
      )

      if sample.fetch("errors") != 0 || sample.fetch("invalid_responses") != 0 || sample.fetch("validation") != "route-contract-v1"
        raise "#{name} at #{conc}: rejected sample #{sample.slice('errors', 'invalid_responses', 'validation', 'statuses')}"
      end

      rate = sample.fetch("ok") / options[:duration].to_f
      sample = sample.merge("route" => name, "concurrency" => conc.to_i, "round" => round + 1, "requests_per_second" => rate)
      samples << sample
      printf("%-13s round %d conc %-3s %8.1f req/s  ok=%d\n", name, round + 1, conc, rate, sample.fetch("ok"))
    end
  end
end

summary = {}
samples.group_by { |sample| [sample.fetch("route"), sample.fetch("concurrency")] }.each do |(route, concurrency), group|
  summary["#{route}@#{concurrency}"] = {
    "route" => route,
    "concurrency" => concurrency,
    "requests_per_second" => median(group.map { |sample| sample.fetch("requests_per_second") }),
    "samples" => group.map { |sample| sample.fetch("requests_per_second") }
  }
end

write_json(File.join(options[:out], "summary-#{options[:app]}.json"),
           "app" => options[:app], "base" => options[:base], "seed" => options[:seed],
           "routes" => options[:routes].split(","), "concurrencies" => options[:concs].split(",").map(&:to_i),
           "rounds" => options[:rounds], "duration" => options[:duration],
           "loadgen" => loadgen, "host" => `uname -srm`.strip, "cpus" => `sysctl -n hw.ncpu`.strip,
           "samples" => samples, "results" => summary)

puts
summary.each { |key, value| printf("%-22s %10.1f req/s  (%s)\n", key, value.fetch("requests_per_second"), value.fetch("samples").join(", ")) }
puts "written to #{options[:out]}"

#!/usr/bin/env ruby
# Builds the shared verification seed natively, on this host.
#
# The upstream bin/seed runs the pinned Rails app in a container. This runs the same seeder through
# this repository's pinned reference checkout instead, so a macOS host can produce the fixture the
# shared load generator and its contracts expect without Docker.
#
#   ruby bench/native-seed.rb [--output DIR]
#
# The reference checkout stays untouched: the app is materialised with `git archive` into a
# temporary tree whose storage/db and storage/files are symlinks into the output directory.
require "digest"
require "fileutils"
require "json"
require "open3"
require "openssl"
require "securerandom"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
REFERENCE = File.expand_path("reference", ROOT)
VERIFICATION = File.expand_path(
  ENV.fetch("VERIFICATION_ROOT") { File.expand_path("../../once-campfire-verification", __dir__) }
)
BUNDLE_PATH = ENV.fetch("REFERENCE_BUNDLE_PATH", File.expand_path("var/reference-bundle", ROOT))
RUBY_VERSION = File.read(File.expand_path(".ruby-version", REFERENCE)).strip

output =
  if (index = ARGV.index("--output"))
    File.expand_path(ARGV[index + 1])
  else
    File.join(VERIFICATION, "fixtures/default")
  end
abort "output already exists: #{output}" if File.exist?(output)

# Kernel#system for the steps whose output does not matter; BenchmarkSupport#run (which returns
# captured output and raises) is used for the two steps that read something back.
def shell(*command)
  system(*command) || abort("failed: #{command.join(" ")}")
end

def capture(*command, **options)
  output, errors, status = Open3.capture3(*command, **options)
  abort "#{command.join(" ")} failed: #{errors}" unless status.success?
  output
end

unless `ruby -e 'print RUBY_VERSION'`.strip == RUBY_VERSION
  abort "seeding natively needs Ruby #{RUBY_VERSION} (see the repository README)"
end

revision = `git -C #{REFERENCE} rev-parse HEAD`.strip
FileUtils.mkdir_p(File.dirname(output))
FileUtils.mkdir_p(File.join(BUNDLE_PATH))

Dir.mktmpdir("native-seed-") do |data|
  Dir.mkdir(File.join(data, "db"))
  Dir.mkdir(File.join(data, "storage"))

  key = OpenSSL::PKey::EC.generate("prime256v1")
  credentials = {
    "SECRET_KEY_BASE" => SecureRandom.hex(64),
    "VAPID_PUBLIC_KEY" => [key.public_key.to_octet_string(:uncompressed)].pack("m0").tr("+/", "-_"),
    "VAPID_PRIVATE_KEY" => [key.private_key.to_s(2).rjust(32, "\0")].pack("m0").tr("+/", "-_"),
    "VERIFICATION_PASSWORD" => SecureRandom.hex(16),
    "VERIFICATION_BENDER_TOKEN" => SecureRandom.hex(16),
    "VERIFICATION_DEPLOY_TOKEN" => SecureRandom.hex(16),
    "VERIFICATION_OLD_TOKEN" => SecureRandom.hex(16)
  }
  env_file = File.join(data, "reference.env")
  File.write(env_file, File.read(File.join(VERIFICATION, "fixtures/reference.env"))
    .sub(/\AWEB_CONCURRENCY=.*\n/, "")
    .sub(/\ARAILS_MAX_THREADS=.*\n/, "")
    .sub(/\AJOB_CONCURRENCY=.*\n/, "")
    .sub(/\ARAILS_LOG_LEVEL=.*\n/, "")
    .sub(/^GIT_REVISION=.*\n/, "GIT_REVISION=#{revision}\n") + credentials.map { |name, value| "#{name}=#{value}\n" }.join)
  File.chmod(0o600, env_file)

  app = File.join(data, "app")
  FileUtils.mkdir_p(app)
  shell("git", "-C", REFERENCE, "archive", revision, "-o", File.join(data, "reference.tar"))
  shell("tar", "-xf", File.join(data, "reference.tar"), "-C", app)

  # The seeder writes the database and its labels next to the app's storage.
  FileUtils.rm_rf(File.join(app, "storage"))
  FileUtils.mkdir_p(File.join(app, "storage"))
  FileUtils.ln_s(File.join(data, "db"), File.join(app, "storage/db"))
  FileUtils.ln_s(File.join(data, "storage"), File.join(app, "storage/files"))

  redis = spawn("redis-server", "--port", "6380", "--save", "", "--appendonly", "no",
                "--logfile", "/dev/null", "--daemonize", "yes", out: File::NULL, err: File::NULL)
  Process.wait(redis)

  bundle_env = { "BUNDLE_PATH" => BUNDLE_PATH, "BUNDLE_FROZEN" => "true", "BUNDLE_WITHOUT" => "development",
                 "BUNDLE_IGNORE_CONFIG" => "1", "RAILS_ENV" => "production" }
  # The seeder signs cookies and logs in as fixture users, so it runs with the credentials it
  # writes into the fixture environment file.
  rails_env = bundle_env.merge(credentials).merge("REDIS_URL" => "redis://127.0.0.1:6380/0",
                                                  "RAILS_LOG_LEVEL" => "warn")

  puts "seeding through #{REFERENCE} at #{revision} (bundle #{BUNDLE_PATH})"
  shell(bundle_env, "bundle", "install", chdir: app)
  shell(rails_env, "bin/rails", "db:prepare", chdir: app)

  database = capture(rails_env, "bin/rails", "runner",
                 "print ActiveRecord::Base.connection_db_config.database", chdir: app).to_s.strip
  puts "Rails database: #{database} (exists: #{File.exist?(database)})"
  puts "seed db dir: #{Dir.children(File.join(data, "db")).inspect}"
  shell(rails_env, "bin/rails", "runner", File.join(VERIFICATION, "fixtures/seeds/build.rb"), "default", chdir: app)

  system("redis-cli", "-p", "6380", "shutdown", "nosave", out: File::NULL, err: File::NULL)

  FileUtils.mv(File.join(data, "db/labels.json"), File.join(data, "labels.json"))

  fixture_db = File.join(data, "db/production.sqlite3")
  puts "after seeding: db dir #{Dir.children(File.join(data, "db")).inspect}, " \
       "database exists: #{File.exist?(fixture_db)} (#{File.size(fixture_db) rescue "no size"}), " \
       "storage #{Dir.children(File.join(data, "storage")).length} files"

  # The seeder leaves a WAL behind; the check opens the database read-write so it can recover it.
  integrity = capture("sqlite3", File.expand_path(fixture_db), "PRAGMA integrity_check;").strip
  abort "invalid fixture: #{integrity}" unless integrity == "ok"

  # Only the fixture itself is published: the materialised app used to build it stays in the
  # temporary directory.
  FileUtils.mkdir_p(output)
  FileUtils.cp_r(File.join(data, "db"), output)
  FileUtils.cp_r(File.join(data, "storage"), output)
  FileUtils.cp(env_file, File.join(output, "reference.env"))
  FileUtils.cp(File.join(data, "labels.json"), File.join(output, "labels.json"))
  File.write(File.join(output, "source.json"), JSON.pretty_generate(
    repository: "https://github.com/basecamp/once-campfire", revision: revision,
    seed_sha256: Digest::SHA256.file(File.join(output, "db/production.sqlite3")).hexdigest,
    built_natively: true
  ) + "\n")
end

puts output

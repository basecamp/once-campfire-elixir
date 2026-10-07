# Shared benchmarks reject invalid responses and audit every acknowledged write.
require "rbconfig"
verification = File.expand_path(ENV.fetch("VERIFICATION_ROOT") { File.expand_path("../../once-campfire-verification", __dir__) })
command = File.join(verification, "bin/benchmark")
abort "Clone https://github.com/basecamp/once-campfire-verification alongside this repo, or set VERIFICATION_ROOT" unless File.file?(command)
exec RbConfig.ruby, command, "--apps", "elixir,rust", *ARGV

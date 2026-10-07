# Shared correctness gates live in the standalone verification repository.
module CampfireVerification
  ROOT = File.expand_path(ENV.fetch("VERIFICATION_ROOT") { File.expand_path("../../once-campfire-verification", __dir__) })

  def self.load(name, caller_file)
    file = File.join(ROOT, "bench", name)
    abort "Clone https://github.com/basecamp/once-campfire-verification alongside this repo, or set VERIFICATION_ROOT" unless File.file?(file)
    if File.expand_path($PROGRAM_NAME) == File.expand_path(caller_file)
      require "rbconfig"
      exec RbConfig.ruby, file, *ARGV
    else
      require file
    end
  end
end

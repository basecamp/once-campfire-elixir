require "fileutils"
require "json"
require "open3"
require "optparse"

module BenchmarkSupport
  ROOT = File.expand_path("..", __dir__)
  WORK = File.join(ROOT, "tmp/bench")

  def run(*command, input: nil)
    output, errors, status = Open3.capture3(*command, stdin_data: input, binmode: true)
    raise "#{command.first} failed (#{status.exitstatus}): #{errors}" unless status.success?
    output
  end

  def remove_container(name)
    Open3.capture3("docker", "rm", "-f", name)
  end

  def prepare_storage(seed, destination)
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
    FileUtils.cp_r(File.join(seed, "db"), File.join(destination, "db"))
    FileUtils.cp_r(File.join(seed, "storage"), File.join(destination, "files"))
  end

  def mounts(paths)
    paths.flat_map { |host, target| [ "-v", "#{host}:#{target}" ] }
  end

  def environment(values)
    values.flat_map { |name, value| [ "-e", "#{name}=#{value}" ] }
  end

  def write_json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def median(values)
    values = values.sort
    middle = values.length / 2
    values.length.odd? ? values[middle] : (values[middle - 1] + values[middle]) / 2.0
  end

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

"""Drain real fixture queues, waiting for an active job and any jobs it enqueues."""
import subprocess
WAIT="""wait = fn wait ->
  case Redix.command(Campfire.Redis, [\"LLEN\", \"resque:queue:default\"]) do
    {:ok, 0} ->
      :sys.get_state(Campfire.Worker, 30_000)
      if Redix.command(Campfire.Redis, [\"LLEN\", \"resque:queue:default\"]) != {:ok, 0}, do: wait.(wait)
    _ -> Process.sleep(50); wait.(wait)
  end
end
wait.(wait)
"""
def drain(side):
 if side=='reference':cmd=['docker','exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1','campfire-elixir-rails','bin/rails','runner',"n=0; while job=Resque.reserve('default'); job.perform; n+=1; end; puts n"]
 else:cmd=['docker','exec','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_WORKER=1','campfire-elixir-candidate','mix','run','-e',WAIT]
 return subprocess.run(cmd,check=True,capture_output=True,text=True,timeout=90)

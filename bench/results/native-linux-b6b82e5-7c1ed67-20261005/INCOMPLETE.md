# Incomplete native Linux attempt — do not use as a comparison

The first attempt aborted during baseline round 1 at the unchanged default
1,000-client Cable workload. No complete round or comparison table was produced.

- Baseline: `b6b82e50a653c4060136bb04e805eb78fd76ba10`.
- Candidate: `7c1ed67d062f5e241d37e3eb0e9a3d97a2324636` (not reached).
- All 24 HTTP samples reported successful 200 responses and zero errors.
- Cable 100/500 subscribed all clients and completed all broadcasts.
- Cable 1,000: ready 430, failed 27, connect wait 120.29 seconds;
  zero complete paced or saturated broadcasts. The harness assertion failed.
- The host/loadgen shell and default Docker containers both had a soft open-file
  limit of 1,024 (hard limit 1,048,576), discovered after the abort. Thruster needs
  client and upstream descriptors, in addition to listener and other descriptors.
  The low limit is an environmental constraint, not an application optimization.

`raw-run.log` preserves the command output and failing Cable result. `env.txt`,
preflight response evidence, phase logs, and process-memory samples are retained.
The benchmark container was removed by the harness exit trap.

A subsequent attempt must raise and record descriptor limits equally for both
server images and the load generator, then restart all four balanced rounds.
Do not combine the partial samples here with a later run or lower client counts
to manufacture a successful result.

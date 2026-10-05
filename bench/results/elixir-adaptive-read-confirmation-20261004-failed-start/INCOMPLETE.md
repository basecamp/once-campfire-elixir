# Excluded failed start

No workload ran. The parity release fixture still owned the Erlang node name when
the baseline container started, so the release rejected startup. Fixture services
were stopped and the confirmation was rerun in the sibling directory. This record
is retained for auditability and excluded from all reports.

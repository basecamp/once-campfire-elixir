# Token-free browser protection

The current app deliberately replaces Rails CSRF tokens with the Rust Fetch Metadata policy.
The shared HTML comparison removes legacy CSRF meta tags and hidden inputs only. Request
helpers send same-origin metadata; legacy token extraction accepts its absence. Golden Rails
fixtures and cryptographic vectors remain unchanged.

Historical token-rejection assertions and scripts that extract a token together with a form
URL describe the old pinned protocol and are not current security evidence. Current native
`fetch_metadata_test.exs`, `sessions_test.exs`, and `tokenless_upload_test.exs` cover the new
policy, cookie continuity and signed upload boundaries. The public shared verification harness
checks actual current browser behavior independently. The historical 65-gate receipts precede
this deliberate protocol change; no complete rerun of that historical inventory is claimed.

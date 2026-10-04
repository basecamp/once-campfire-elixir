# Rich-text comparison rules

The corpus contains 1,058 stored-content cases: hand-written examples, seeded
malformed HTML, and seeded mutations. The Rails oracle runs against the pinned
source. Expected output is never rewritten. The native comparison preserves both
raw differences and remaining differences after the following explicit rules.

- HTML attribute values escape `<` and `>`; automatic links are never inserted
  inside an attribute. This is the deliberate stored-XSS protection in the Rust
  port's `crates/richtext/tests/corpus.rs`, adapted without its removal of `name`.
  Text and links outside attribute values remain exact comparisons.
- Equivalent failures are compared by category: invalid Base64, invalid JSON,
  invalid attachment attribute objects, invalid envelopes, and invalid Open Graph
  URLs. Ruby and Elixir exception class names and diagnostic wording differ.
  Every unclassified error remains an exact mismatch.
- Rails' rescue logger raises a second exception when a JSON parser error contains
  invalid UTF-8. Native presentation returns the intended empty string. Full
  message rendering catches malformed plain text and emits the pinned Rails
  failed-message partial. This is a deliberate error-handling difference.

The implementation reproduces Rails' order-sensitive attribute sanitizer. Its
URI escaping occurs after each surviving attribute, and can change a later URI
before that URI is checked. The native parser uses unmodified Gumbo sources from
the same Nokogiri gem as Rails, including its parser-time limits and template
contents. Provenance and licensing are in `native/vendor/gumbo/`.

`parity/results/richtext-corpus-raw-differences.json` retains all unequal raw
outcomes. `richtext-corpus-differences.json` retains unresolved outcomes. Passing
this corpus does not establish attachment upload/embedding or full application
parity; those require independent HTTP, browser, storage, and mutation evidence.

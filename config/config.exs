import Config

# `gumbo` is a NIF whose C sources are the pinned parser plus a patch series. elixir_make skips
# a build when the shared library is already in place, and Mix cannot see `c_src/patches` as an
# input, so a dependency that only gained or renamed a patch would otherwise keep the previous
# parser in place — silently, until someone removed priv/obj by hand. This is the knob
# elixir_make documents for that ("Users of a library can also force build by setting the
# following application configuration"): with it, every compile of that dependency runs make,
# whose own stamp decides whether there is work to do.
config :elixir_make, :force_build, gumbo: true

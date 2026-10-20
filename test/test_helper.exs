ExUnit.start()

# Byte-for-byte image gates only hold on the pinned libvips; another version resamples and encodes
# differently (8.18 already diverges inside thumbnail_image), so run them in the toolchain:
#   bin/mix test
pinned_libvips = Jason.decode!(File.read!("plans/provenance.json"))["media_runtime"]["libvips"]

if Vix.Vips.version() != pinned_libvips do
  ExUnit.configure(exclude: [:pinned_libvips])

  IO.puts(
    "skipping :pinned_libvips gates: libvips #{Vix.Vips.version()} != #{pinned_libvips}; " <>
      "run them with bin/mix test"
  )
end

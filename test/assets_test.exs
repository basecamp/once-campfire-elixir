defmodule Campfire.AssetsTest do
  use ExUnit.Case, async: false

  setup do
    tmp = Path.join(System.tmp_dir!(), "campfire-assets-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(tmp) end)
    project = Path.join(tmp, "project")
    assets = Path.join(project, "priv/static/assets")
    File.mkdir_p!(assets)
    File.mkdir_p!(Path.join(project, "bin"))
    File.cp!("bin/export-assets", Path.join(project, "bin/export-assets"))
    File.cp!("bin/apply-asset-overrides", Path.join(project, "bin/apply-asset-overrides"))
    File.ln_s!(Path.expand("reference"), Path.join(project, "reference"))
    {revision, 0} = System.cmd("git", ["-C", "reference", "rev-parse", "HEAD"])
    revision = String.trim(revision)

    for args <- [
          ["init", "-q"],
          ["update-index", "--add", "--cacheinfo", "160000,#{revision},reference"],
          [
            "-c",
            "user.name=Test",
            "-c",
            "user.email=test@example.test",
            "-c",
            "commit.gpgsign=false",
            "-c",
            "core.hooksPath=/dev/null",
            "commit",
            "-qm",
            "Fixture"
          ]
        ] do
      {output, status} = System.cmd("git", ["-C", project | args], stderr_to_stdout: true)
      assert status == 0, output
    end

    {:ok, tmp: tmp, assets: assets, revision: revision}
  end

  test "exported assets include real files and the captured Rails frontend" do
    manifest = Campfire.Assets.read("static/assets/.manifest.json") |> Jason.decode!()

    for {_logical, %{"digested_path" => path}} <- manifest do
      assert File.regular?(Campfire.Assets.file("static/assets/" <> path)), path
    end

    # Captured Rails URLs, not expectations computed from the generated manifest.
    assert Campfire.Assets.path("application.js") == "/assets/application-a54c74a7.js"
    assert Campfire.Assets.path("lexxy.js") == "/assets/lexxy-a21f41d4.js"
    assert Campfire.Assets.path("turbo.js") == "/assets/turbo-a1e3a50a.js"

    assert Campfire.Assets.read("static/assets/application-a54c74a7.js") ==
             File.read!("reference/app/javascript/application.js")
  end

  test "missing Docker image is not reported as a revision mismatch", %{tmp: tmp} do
    File.write!(Path.join(tmp, "docker"), "#!/bin/sh\necho 'No such image' >&2\nexit 1\n")
    File.chmod!(Path.join(tmp, "docker"), 0o755)

    {output, status} = export_with_path(tmp)
    assert status == 1
    assert output =~ "Cannot inspect campfire-reference:app"
    assert output =~ "bin/export-assets --local"
    refute output =~ "Reference image revision differs"
  end

  test "an existing image with the wrong revision is still rejected", %{tmp: tmp} do
    File.write!(Path.join(tmp, "docker"), "#!/bin/sh\necho GIT_REVISION=wrong-revision\n")
    File.chmod!(Path.join(tmp, "docker"), 0o755)

    {output, status} = export_with_path(tmp)
    assert status == 1
    assert output =~ "Reference image revision differs from pinned source"
    refute output =~ "Cannot inspect"
  end

  test "a complete export replaces obsolete digests", %{
    tmp: tmp,
    assets: assets,
    revision: revision
  } do
    File.write!(Path.join(assets, "obsolete-digest.js"), "stale")

    write_executable(
      Path.join(tmp, "docker"),
      """
      #!/bin/sh
      case "$1" in
        image) echo GIT_REVISION=#{revision} ;;
        create) echo fixture-container ;;
        cp)
          case "$2" in
            *:/rails/public/assets/.)
              printf '{}' > "$3/.manifest.json"
              printf 'fresh' > "$3/current-digest.js"
              ;;
            *:/rails/public/robots.txt|*:/rails/public/*.html) printf 'public fixture' > "$3" ;;
            *) exit 99 ;;
          esac
          ;;
        rm) test "$2" = fixture-container && touch '#{tmp}/container-removed' ;;
        *) exit 99 ;;
      esac
      """
    )

    {output, status} = export_with_path(tmp)
    assert status == 0, output
    assert File.read!(Path.join(assets, "current-digest.js")) == "fresh"
    refute File.exists?(Path.join(assets, "obsolete-digest.js"))
    assert File.stat!(assets).mode |> Bitwise.band(0o777) == 0o755
    assert File.exists?(Path.join(tmp, "container-removed"))
    assert Path.wildcard(assets <> ".*") == []
  end

  test "port-owned controller overrides get new digests and replace stale bodies", %{
    tmp: tmp,
    assets: assets
  } do
    logical = "controllers/rooms_list_controller.js"
    previous = "controllers/rooms_list_controller-original.js"
    override = Path.join(tmp, "project/assets/overrides/" <> logical)
    File.mkdir_p!(Path.dirname(override))
    File.cp!("assets/overrides/" <> logical, override)
    File.mkdir_p!(Path.join(assets, "controllers"))
    File.write!(Path.join(assets, previous), "original")
    File.write!(Path.join(assets, previous <> ".gz"), "obsolete compressed body")

    File.write!(
      Path.join(assets, ".manifest.json"),
      Jason.encode!(%{logical => %{"digested_path" => previous, "integrity" => nil}})
    )

    script = Path.join(tmp, "project/bin/apply-asset-overrides")
    {output, status} = System.cmd("python3", [script, assets], stderr_to_stdout: true)
    assert status == 0, output
    manifest = File.read!(Path.join(assets, ".manifest.json")) |> Jason.decode!()
    digested = manifest[logical]["digested_path"]
    assert digested == "controllers/rooms_list_controller-8fe7485c.js"
    assert File.read!(Path.join(assets, digested)) == File.read!(override)
    refute File.exists?(Path.join(assets, previous))
    refute File.exists?(Path.join(assets, previous <> ".gz"))

    {output, status} = System.cmd("python3", [script, assets], stderr_to_stdout: true)
    assert status == 0, output
    assert File.read!(Path.join(assets, digested)) == File.read!(override)
  end

  test "a failed export preserves the previous asset directory", %{
    tmp: tmp,
    assets: assets,
    revision: revision
  } do
    File.write!(Path.join(assets, "keep-on-failure.js"), "preserved")

    write_executable(
      Path.join(tmp, "docker"),
      """
      #!/bin/sh
      case "$1" in
        image) echo GIT_REVISION=#{revision} ;;
        create) echo fixture-container ;;
        cp) exit 1 ;;
        rm) test "$2" = fixture-container && touch '#{tmp}/container-removed' ;;
        *) exit 99 ;;
      esac
      """
    )

    {_output, status} = export_with_path(tmp)
    assert status == 1
    assert File.read!(Path.join(assets, "keep-on-failure.js")) == "preserved"
    assert File.exists?(Path.join(tmp, "container-removed"))
    assert Path.wildcard(assets <> ".*") == []
  end

  defp export_with_path(path) do
    System.cmd("sh", [Path.join(path, "project/bin/export-assets")],
      env: [{"PATH", path <> ":" <> System.get_env("PATH", "")}],
      stderr_to_stdout: true
    )
  end

  defp write_executable(path, contents) do
    File.write!(path, contents)
    File.chmod!(path, 0o755)
  end
end

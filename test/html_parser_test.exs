defmodule Campfire.HtmlParserTest do
  use ExUnit.Case, async: false

  # The reference adapter is the Rails side's parser: a pool of helper processes running
  # Nokogiri's own gumbo sources, which the parity tests measure against. It is not in the
  # request path — the parser above it is the NIF — so the pool's fault isolation is pinned
  # here, where the tests that used to exercise the pool the port itself ran now live.
  setup do
    for index <- 0..3 do
      case Campfire.HtmlParserReference.start_link(index) do
        {:ok, pid} -> on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
        {:error, {:already_started, _}} -> :ok
      end
    end

    :ok
  end

  defp reference_worker do
    Module.concat(Campfire.HtmlParserReference, "#{:erlang.phash2(self(), 4)}")
  end

  test "parser produces native terms through an isolated worker" do
    html = ~s(<p class="message">Hello<!-- pause --><strong>world</strong></p>)

    expected = [
      {"p", [{"class", "message"}], ["Hello", {:comment, " pause "}, {"strong", [], ["world"]}]}
    ]

    assert Campfire.HtmlParser.parse(html) == expected
  end

  test "large fragments use the public parser path without changing output" do
    text = String.duplicate("abcdefgh", 2_049)
    assert [{"p", [], [^text]}] = Campfire.HtmlParser.parse("<p>#{text}</p>")
  end

  test "valid documents beyond the NIF node budget retain Rails behavior" do
    html = String.duplicate("<p>x</p>", 6_000)

    assert nodes = Campfire.HtmlParser.parse(html)
    assert Enum.count(nodes) == 6_000
    assert Enum.all?(nodes, &(&1 == {"p", [], ["x"]}))
  end

  test "both backends refuse a document past the reference's limits with the same message" do
    deep = String.duplicate("<div>", 405) <> "x"
    wide = "<p " <> Enum.map_join(1..405, fn i -> ~s(a#{i}="x" ) end) <> ">y</p>"

    for {html, message} <- [
          {deep, ~r/Document tree depth limit exceeded/},
          {wide, ~r/Attributes per element limit exceeded/}
        ] do
      assert_raise ArgumentError, message, fn -> Campfire.HtmlParser.parse(html) end
      assert_raise ArgumentError, message, fn -> Campfire.HtmlParserReference.parse(html) end
    end

    assert Campfire.HtmlParser.parse("<p>alive</p>") == [{"p", [], ["alive"]}]
  end

  test "a document that exhausts the reference helper leaves the caller and the VM alive" do
    formatting = Enum.map_join(1..390, &~s(<b a="#{&1}">))
    html = "<p>#{formatting}" <> String.duplicate("<p>x", 3_000)

    # On this machine the reference helper aborts on this document (its own allocation fails and
    # it exits 134) and the caller gets an error; on a larger one it may return a tree. Either
    # way the caller survives and the VM stays up, which is the property being pinned here.
    reference =
      try do
        {:tree, Campfire.HtmlParserReference.parse(html)}
      rescue
        e in ArgumentError -> {:error, Exception.message(e)}
      end

    case reference do
      {:error, message} -> assert message =~ "isolated HTML parser exited with status"
      {:tree, nodes} -> assert is_list(nodes)
    end

    # The port's own path holds the reference's limits as budgets rather than as a process that
    # can be lost, so it returns a tree where the reference cannot finish: the recorded known
    # difference for documents the reference's C cannot allocate.
    assert is_list(Campfire.HtmlParser.parse(html))
    assert Campfire.HtmlParser.parse("<p>alive</p>") == [{"p", [], ["alive"]}]
  end

  test "an idle helper death is replaced without crashing its worker or caller" do
    worker = reference_worker()
    worker_pid = Process.whereis(worker)
    port = :sys.get_state(worker)
    {:os_pid, os_pid} = Port.info(port, :os_pid)

    assert {_, 0} = System.cmd("kill", ["-KILL", Integer.to_string(os_pid)])
    replacement = await_replacement(worker, port, System.monotonic_time(:millisecond) + 5_000)

    assert is_port(replacement)
    assert Port.info(replacement)
    assert Process.whereis(worker) == worker_pid
    assert Campfire.HtmlParserReference.parse("<p>alive</p>") == [{"p", [], ["alive"]}]
  end

  test "a helper is recycled after returning a large result" do
    worker = reference_worker()
    port = :sys.get_state(worker)
    html = String.duplicate("<p>x</p>", 70_000)

    assert nodes = Campfire.HtmlParserReference.parse(html)
    assert Enum.count(nodes) == 70_000
    refute :sys.get_state(worker) == port
    assert Campfire.HtmlParserReference.parse("<p>alive</p>") == [{"p", [], ["alive"]}]
  end

  test "an abnormal linked port exit returns an error and replaces the helper" do
    worker = reference_worker()
    worker_pid = Process.whereis(worker)
    broken_port = open_port_with_closed_input()

    assert_receive {^broken_port, {:data, "ready"}}, 1_000
    assert Port.connect(broken_port, worker_pid)
    Process.unlink(broken_port)

    :sys.replace_state(worker, fn port ->
      Process.link(broken_port)
      Port.close(port)
      broken_port
    end)

    assert_raise ArgumentError, ~r/isolated HTML parser exited/, fn ->
      Campfire.HtmlParserReference.parse("<p>broken pipe</p>")
    end

    replacement =
      await_replacement(worker, broken_port, System.monotonic_time(:millisecond) + 5_000)

    assert is_port(replacement)
    assert Process.whereis(worker) == worker_pid
    assert Campfire.HtmlParserReference.parse("<p>alive</p>") == [{"p", [], ["alive"]}]
  end

  defp open_port_with_closed_input do
    executable = System.find_executable("sh")
    script = ~S(exec 0<&-; printf '\000\000\000\005ready'; sleep 30)

    Port.open({:spawn_executable, String.to_charlist(executable)}, [
      :binary,
      {:packet, 4},
      :exit_status,
      args: [~c"-c", String.to_charlist(script)]
    ])
  end

  defp await_replacement(worker, old_port, deadline) do
    case :sys.get_state(worker) do
      ^old_port ->
        if System.monotonic_time(:millisecond) < deadline do
          await_replacement(worker, old_port, deadline)
        else
          flunk("parser helper was not replaced")
        end

      replacement ->
        replacement
    end
  end
end

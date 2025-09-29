defmodule Membrane.Subtitles.SRT.ParserTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions
  require Membrane.Pad

  alias Membrane.Buffer
  alias Membrane.Testing.{Pipeline, Sink}

  @tag :tmp_dir
  test "parses an SRT file byte by byte through a pipeline", %{tmp_dir: tmp_dir} do
    input_path = "test/data/sample.srt"
    output_path = Path.join(tmp_dir, "reconstructed.srt")

    spec = [
      child(:source, %Membrane.File.Source{
        location: input_path
      })
      |> child(:parser, Membrane.Subtitles.SRT.Parser)
      |> child(:sink, %Membrane.File.Sink{location: output_path})
    ]

    pid = Membrane.Testing.Pipeline.start_link_supervised!(spec: spec)

    assert_end_of_stream(pid, :sink, :input, 5_000)

    reconstructed = File.read!(output_path)
    original = File.read!(input_path)

    original_texts =
      original
      |> String.split(~r/\r?\n\r?\n/)
      |> Enum.map(fn block ->
        block
        |> String.split("\n")
        |> Enum.drop_while(fn line -> line =~ ~r/^\d+$/ or line =~ ~r/-->/ end)
        |> Enum.join("\n")
      end)
      |> Enum.join("")

    assert reconstructed == original_texts
  end

  @tag :tmp_dir
  test "parses an SRT file split in two buffers", %{tmp_dir: _tmp_dir} do
    buffers = [
      %Buffer{
        payload: "1\n00:00:01,000 --> 00:00:03,000\nHello world"
      },
      %Buffer{
        payload: "2\n00:00:04,000 --> 00:00:06,000\nSecond subtitle"
      }
    ]

    spec = [
      child(:source, %Membrane.Testing.Source{output: buffers})
      |> child(:parser, Membrane.Subtitles.SRT.Parser)
      |> child({:sink, :text}, %Sink{})
    ]

    pid = Pipeline.start_link_supervised!(spec: spec)
    assert_end_of_stream(pid, {:sink, :text}, :input, 5_000)

    assert_sink_buffer(
      pid,
      {:sink, :text},
      %Membrane.Buffer{
        payload: "Hello world"
      }
    )

    assert_sink_buffer(
      pid,
      {:sink, :text},
      %Membrane.Buffer{
        payload: "Second subtitle"
      }
    )
  end
end

defmodule Membrane.Subtitles.BuilderTest do
  use ExUnit.Case, async: true
  use Mneme

  import Membrane.ChildrenSpec
  alias Membrane.{Buffer, Testing, Time}
  alias Membrane.Subtitles.Builder

  test "correctly builds and splits subtitles" do
    spec = [
      child(:source, %Membrane.Testing.Source{
        output: create_subtitle_buffers(),
        stream_format: %Membrane.Text{}
      })
      |> child(:builder, %Builder{
        max_length: 50,
        min_duration: Time.seconds(2),
        max_lines: 2
      })
      |> child(:sink, %Membrane.Testing.Sink{})
    ]

    pipeline = Testing.Pipeline.start_link_supervised!(spec: spec)

    buffers =
      Stream.resource(
        fn -> pipeline end,
        fn pid ->
          receive do
            {Membrane.Testing.Pipeline, ^pid,
             {:handle_child_notification, {{:buffer, buffer}, :sink}}} ->
              {[buffer], pid}

            {Membrane.Testing.Pipeline, ^pid,
             {:handle_child_notification, {{:end_of_stream, :input}, :sink}}} ->
              {:halt, pid}
          after
            3_000 ->
              raise "test timeout"
          end
        end,
        fn pid -> Membrane.Testing.Pipeline.terminate(pid, force?: true) end
      )
      |> Enum.to_list()

    # Auto-assert the structure of collected buffers
    auto_assert(
      [
        %{
          duration_ms: 5102,
          pts_ms: 0,
          text: "This is a short subtitle.\nThis is a much longer subtitle that should be",
          to_ms: 5102
        },
        %{
          duration_ms: 2897,
          pts_ms: 5103,
          text: "split because it exceeds\nthe maximum length constraint.",
          to_ms: 8000
        },
        %{
          duration_ms: 4464,
          pts_ms: 8000,
          text: "Another short one.\nHere we introduce a slightly longer subtitle,",
          to_ms: 12464
        },
        %{
          duration_ms: 2535,
          pts_ms: 12465,
          text: "still readable in one go.\nYes!",
          to_ms: 15000
        },
        %{
          duration_ms: 2213,
          pts_ms: 15001,
          text:
            "This line overlaps with the previous one slightly.\nIn some cases, subtitles can run extremely long,",
          to_ms: 17214
        },
        %{
          duration_ms: 2011,
          pts_ms: 17215,
          text:
            "containing multiple sentences, commas, and\nconjunctions that make them difficult to display",
          to_ms: 19226
        },
        %{
          duration_ms: 2049,
          pts_ms: 19227,
          text:
            "in a single frame without overwhelming the viewer,\nwhich means they should definitely be split across",
          to_ms: 21276
        },
        %{duration_ms: 2000, pts_ms: 21277, text: "multiple lines or time ranges.", to_ms: 23277}
      ] <-
        buffers
        |> Enum.map(fn buf ->
          %{
            text: buf.payload,
            pts_ms: Time.as_milliseconds(buf.pts, :round),
            to_ms: Time.as_milliseconds(buf.metadata.to, :round),
            duration_ms: Time.as_milliseconds(buf.metadata.to - buf.pts, :round)
          }
        end)
    )

    buffers
    |> Enum.reduce(fn buf, prev_buf ->
      assert buf.pts >= prev_buf.metadata.to,
             "Current buffer pts (#{buf.pts}) should be >= previous buffer end time (#{prev_buf.metadata.to})"

      assert buf.metadata.to >= buf.pts,
             "Buffer end time should be after start time #{inspect(buf)}"

      buf
    end)

    for buffer <- buffers do
      lines = String.split(buffer.payload, "\n")
      duration = buffer.metadata.to - buffer.pts
      line_count = length(lines)

      for {line, idx} <- Enum.with_index(lines, 1) do
        line_length = String.length(line)

        assert line_length <= 50,
               "Line #{idx} length #{line_length} exceeds max_length of 50: #{inspect(line)}"
      end

      assert duration >= Time.seconds(2),
             "Duration #{Time.as_milliseconds(duration, :round)}ms is less than min_duration of 2000ms"

      assert line_count <= 2,
             "Line count #{line_count} exceeds max_lines of 2"
    end
  end

  defp create_subtitle_buffers do
    [
      %Buffer{
        payload: "This is a short subtitle.",
        pts: Time.seconds(0),
        metadata: %{to: Time.seconds(3)}
      },
      %Buffer{
        payload:
          "This is a much longer subtitle that should be split because it exceeds the maximum length constraint.",
        pts: Time.seconds(3),
        metadata: %{to: Time.seconds(8)}
      },
      %Buffer{
        payload: "Another short one.",
        pts: Time.seconds(8),
        metadata: %{to: Time.seconds(10)}
      },
      %Buffer{
        payload: "Here we introduce a slightly longer subtitle, still readable in one go.",
        pts: Time.seconds(10),
        metadata: %{to: Time.seconds(14)}
      },
      %Buffer{
        payload: "Yes!",
        pts: Time.seconds(14),
        metadata: %{to: Time.seconds(15)}
      },
      %Buffer{
        payload: "This line overlaps with the previous one slightly.",
        pts: Time.seconds(14),
        metadata: %{to: Time.seconds(16)}
      },
      %Buffer{
        payload:
          "In some cases, subtitles can run extremely long, containing multiple sentences, commas, and conjunctions that make them difficult to display in a single frame without overwhelming the viewer, which means they should definitely be split across multiple lines or time ranges.",
        pts: Time.seconds(16),
        metadata: %{to: Time.seconds(22)}
      }
    ]
  end
end

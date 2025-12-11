# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Membrane Framework plugin for subtitle generation and parsing. It provides filters for parsing SRT (SubRip) subtitle files and building subtitles with configurable constraints (max length, min duration, max lines).

**Key dependencies:**
- `membrane_core` ~> 1.1 - Core Membrane Framework functionality
- `membrane_text_format` ~> 1.0 - Text format support for Membrane
- `kim_subtitle` ~> 0.1 - Subtitle parsing and building library

## Common Commands

```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a specific test file
mix test test/subtitles/builder_test.exs
mix test test/subtitles/srt/parser_test.exs

# Run tests with Mneme (snapshot testing)
mix mneme.test
mix mneme.watch

# Format code
mix format

# Generate documentation
mix docs

# Build for production
MIX_ENV=prod mix compile
```

## Architecture

### Core Components

**1. SRT Parser (`Membrane.Subtitles.SRT.Parser`)**
- Location: `lib/membrane/subtitles/srt/parser.ex`
- Membrane Filter that parses SRT subtitle files
- Accepts `Membrane.RemoteStream` input, outputs `Membrane.Text`
- Handles partial buffers for streaming parsing
- Converts SRT cues to Membrane buffers with PTS (Presentation Time Stamp) and metadata

**2. Subtitle Builder (`Membrane.Subtitles.Builder`)**
- Location: `lib/membrane/subtitles/builder.ex`
- Membrane Filter that builds and splits subtitles based on constraints
- Accepts and outputs `Membrane.Text` format
- Configurable options:
  - `max_length`: Maximum character length per line
  - `min_duration`: Minimum duration for a subtitle cue (in Membrane.Time units)
  - `max_lines`: Maximum number of lines per subtitle
- Uses the `kim_subtitle` library's `Subtitle.Cue.Builder` internally
- Handles subtitle timing, splitting long text, and flushing on end of stream

### Data Flow

1. **Parser Flow**: Raw SRT bytes → Parser → Membrane.Text buffers with timing metadata
2. **Builder Flow**: Membrane.Text buffers → Builder → Optimized subtitle buffers (split/merged based on constraints)

### Key Concepts

**Membrane Buffers and Timing:**
- Buffers carry `pts` (presentation timestamp) in nanoseconds
- Metadata includes `to` (end time) and `duration`
- Conversion helpers: `Membrane.Time.milliseconds()`, `Membrane.Time.seconds()`, `Time.as_milliseconds()`

**Filter Pattern:**
- All components are Membrane Filters (use `use Membrane.Filter`)
- Define input/output pads with `def_input_pad` and `def_output_pad`
- Implement callbacks: `handle_init/2`, `handle_buffer/4`, `handle_end_of_stream/3`
- Return action lists like `[buffer: {:output, buffer}, end_of_stream: :output]`

### Testing

- Tests use `Membrane.Testing.Pipeline` for integration testing
- `Mneme` library used for snapshot testing (see builder_test.exs)
- Test data located in `test/data/` directory
- Builder tests verify timing constraints and text splitting logic
- Parser tests verify SRT parsing with both full files and partial buffers

## Development Notes

- Time units are always in nanoseconds internally; convert using `Membrane.Time` helpers
- The Builder maintains state between buffers to handle merging/splitting across boundaries
- Parser handles partial SRT data for streaming scenarios
- Empty text cues trigger a flush in the Builder

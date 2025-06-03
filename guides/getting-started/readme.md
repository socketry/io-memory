# Getting Started

This guide explains how to use `io-memory` for efficient memory operations and zero-copy data sharing.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add io-memory
~~~

## Core Concepts

`IO::Memory` has several core concepts:

- Cross-platform memory mapping that automatically selects the best implementation (Linux `memfd_create`, POSIX `shm_open`, or generic tempfiles)
- Integration with Ruby's {ruby IO::Buffer} class for efficient memory operations
- Automatic resource management through `with` blocks and explicit cleanup methods
- Support for file descriptor passing between processes (where supported)

## Basic Memory Operations

This example shows how to create and use a memory-mapped buffer:

```ruby
require 'io/memory'

# Create a memory-mapped buffer
IO::Memory.with(1024) do |handle|
  # Get a mapped IO::Buffer
  buffer = handle.map
  
  # Write some data
  message = "Hello, World!"
  buffer.set_string(message, 0)
  
  # Read data back
  result = buffer.get_string(0, message.length)
  puts result # => "Hello, World!"
  
  # Access as IO object for traditional operations
  io = handle.io
  io.seek(0)
  io.write("Additional data")
end # Automatically cleaned up
```

## Working with Large Buffers

`IO::Memory` efficiently handles large memory regions:

```ruby
require 'io/memory'

# Create a 1MB buffer
handle = IO::Memory.new(1024 * 1024)

# Map the entire buffer
buffer = handle.map

# Write data at different offsets
buffer.set_string("Start", 0)
buffer.set_string("Middle", 512 * 1024)
buffer.set_string("End", 1024 * 1024 - 3)

# Read back the data
puts buffer.get_string(0, 5)           # => "Start"
puts buffer.get_string(512 * 1024, 6) # => "Middle"
puts buffer.get_string(1024 * 1024 - 3, 3) # => "End"

# Clean up
handle.close
```

## Partial Buffer Mapping

You can map only portions of a memory region:

```ruby
require 'io/memory'

# Create a large buffer
handle = IO::Memory.new(4096)

# Map only the first 1KB
partial_buffer = handle.map(1024)
puts partial_buffer.size # => 1024

# Use the partial buffer
partial_buffer.set_string("Only first KB", 0)

handle.close
```

## Platform Information

Check which implementation is being used on your platform:

```ruby
require 'io/memory'

info = IO::Memory.info
puts "Implementation: #{info[:implementation]}"
puts "Platform: #{info[:platform]}"
puts "Features: #{info[:features].join(', ')}"

# Example outputs:
# Linux: "Implementation: Linux memfd_create"
# macOS: "Implementation: POSIX shm_open"  
# Windows: "Implementation: Generic tempfile"
```

## Error Handling

Handle platform-specific limitations gracefully:

```ruby
require 'io/memory'

begin
  # Some platforms may not support zero-size buffers
  handle = IO::Memory.new(0)
  buffer = handle.map
  handle.close
rescue Errno::EINVAL => e
  puts "Zero-size buffers not supported: #{e.message}"
end
```

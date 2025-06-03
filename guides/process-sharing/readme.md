# Process Memory Sharing

This guide demonstrates how to share memory between processes using `io-memory` for high-performance inter-process communication (IPC).

## Overview

`IO::Memory` enables true zero-copy memory sharing between processes by:

- Creating memory-mapped regions that persist beyond the creating process
- Passing file descriptors through Unix domain sockets
- Allowing multiple processes to map the same physical memory
- Providing automatic cleanup when all references are closed

This is significantly faster than traditional IPC methods like pipes or message queues since no data copying occurs.

## Basic Process Sharing

Here's a simple example of sharing memory between a parent and child process:

```ruby
require 'io/memory'

# Create shared memory buffer
handle = IO::Memory.new(1024)
buffer = handle.map

# Write data in parent process
message = "Hello from parent!"
buffer.set_string(message, 0)

pid = fork do
  # Child process automatically inherits the file descriptor
  child_buffer = handle.map
  
  # Read parent's data
  received = child_buffer.get_string(0, message.length)
  puts "Child received: #{received}"
  
  # Write response
  response = "Hello from child!"
  child_buffer.set_string(response, 100)
end

Process.wait(pid)

# Parent can see child's response
child_response = buffer.get_string(100, 17)
puts "Parent received: #{child_response}"

handle.close
```

## Unix Domain Socket File Descriptor Passing

For more flexible process communication, you can pass file descriptors through Unix sockets:

```ruby
require 'io/memory'
require 'socket'

def parent_process
  # Create shared memory
  handle = IO::Memory.new(2048)
  buffer = handle.map
  
  # Write initial data
  buffer.set_string("Shared data from parent", 0)
  
  # Create socket pair for communication
  parent_socket, child_socket = UNIXSocket.socketpair
  
  pid = fork do
    parent_socket.close
    child_process(child_socket)
  end
  
  child_socket.close
  
  # Send file descriptor to child
  parent_socket.send_io(handle.io)
  
  # Wait for child to process
  response = parent_socket.read(100)
  puts "Parent received: #{response}"
  
  # Check if child modified the buffer
  child_data = buffer.get_string(1000, 20)
  puts "Child wrote: #{child_data}"
  
  Process.wait(pid)
  parent_socket.close
  handle.close
end

def child_process(socket)
  # Receive file descriptor from parent
  received_io = socket.recv_io
  
  # Map the shared memory
  buffer = ::IO::Buffer.map(received_io, 2048)
  
  # Read parent's data
  parent_data = buffer.get_string(0, 23)
  puts "Child read: #{parent_data}"
  
  # Write data back
  buffer.set_string("Data from child proc", 1000)
  
  # Send confirmation
  socket.write("Child processing complete")
  
  received_io.close
  socket.close
end

parent_process
```

## Multi-Process Worker Pool

Here's a more advanced example showing a worker pool sharing memory:

```ruby
require 'io/memory'
require 'socket'

class SharedMemoryWorkerPool
  def initialize(worker_count: 4, buffer_size: 1024 * 1024)
    @worker_count = worker_count
    @buffer_size = buffer_size
    @workers = []
    @sockets = []
    
    setup_shared_memory
    spawn_workers
  end
  
  def submit_work(data, offset = 0)
    # Write work data to shared memory
    @buffer.set_string(data, offset)
    
    # Signal a worker
    worker_socket = @sockets.sample
    worker_socket.write("WORK:#{offset}:#{data.length}\n")
    
    # Read result
    response = worker_socket.readline.chomp
    response
  end
  
  def shutdown
    @sockets.each { |socket| socket.write("QUIT\n") }
    @workers.each { |pid| Process.wait(pid) }
    @sockets.each(&:close)
    @handle.close
  end
  
  private
  
  def setup_shared_memory
    @handle = IO::Memory.new(@buffer_size)
    @buffer = @handle.map
  end
  
  def spawn_workers
    @worker_count.times do |i|
      parent_socket, child_socket = UNIXSocket.socketpair
      
      pid = fork do
        parent_socket.close
        worker_process(child_socket, i)
      end
      
      child_socket.close
      @workers << pid
      @sockets << parent_socket
      
      # Send shared memory to worker
      parent_socket.send_io(@handle.io)
    end
  end
  
  def worker_process(socket, worker_id)
    # Receive shared memory
    shared_io = socket.recv_io
    buffer = ::IO::Buffer.map(shared_io, @buffer_size)
    
    puts "Worker #{worker_id} started"
    
    loop do
      command = socket.readline.chomp
      break if command == "QUIT"
      
      if command.start_with?("WORK:")
        _, offset, length = command.split(":")
        offset = offset.to_i
        length = length.to_i
        
        # Read work data from shared memory
        data = buffer.get_string(offset, length)
        
        # Process data (example: reverse it)
        result = data.reverse
        
        # Write result back to shared memory at a different offset
        result_offset = offset + 10000
        buffer.set_string(result, result_offset)
        
        socket.write("DONE:#{result_offset}:#{result.length}\n")
      end
    end
    
    shared_io.close
    socket.close
    puts "Worker #{worker_id} finished"
  end
end

# Usage example
pool = SharedMemoryWorkerPool.new(worker_count: 3)

# Submit work
result1 = pool.submit_work("Hello World", 0)
result2 = pool.submit_work("Shared Memory", 100)
result3 = pool.submit_work("Zero Copy IPC", 200)

puts "Results: #{result1}, #{result2}, #{result3}"

pool.shutdown
```

## Performance Considerations

### Memory Alignment

For best performance, align your data to cache line boundaries:

```ruby
# Align data to 64-byte boundaries (typical cache line size)
CACHE_LINE_SIZE = 64

def aligned_offset(offset)
  (offset + CACHE_LINE_SIZE - 1) & ~(CACHE_LINE_SIZE - 1)
end

handle = IO::Memory.new(4096)
buffer = handle.map

# Write data at aligned offsets
buffer.set_string("Data 1", aligned_offset(0))    # offset 0
buffer.set_string("Data 2", aligned_offset(100))  # offset 128
buffer.set_string("Data 3", aligned_offset(200))  # offset 256
```

### Batch Operations

Group operations to minimize system call overhead:

```ruby
handle = IO::Memory.new(1024)
buffer = handle.map

# Instead of multiple small writes:
# buffer.set_string("A", 0)
# buffer.set_string("B", 1)
# buffer.set_string("C", 2)

# Use a single larger write:
data = "ABC"
buffer.set_string(data, 0)
```

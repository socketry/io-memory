# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

require "sus"
require "io/memory"
require "io/memory/a_memory_buffer"
require "socket"

# Try to require all implementations for testing.
begin
	require "io/memory/linux"
rescue LoadError
	# Linux not available on this platform
end

begin  
	require "io/memory/posix"
rescue LoadError
	# POSIX not available on this platform
end

begin
	require "io/memory/generic"  
rescue LoadError
	# Generic should always be available
end

describe IO::Memory do
	it_behaves_like IO::Memory::AMemoryBuffer
		
	# Additional tests specific to the main interface
	with "automatic implementation selection" do				
		it "provides consistent interface across implementations" do
			handle = IO::Memory.new(512)
						
			# Should work regardless of which implementation is selected
			expect(handle).to respond_to(:io)
			expect(handle).to respond_to(:map)
			expect(handle).to respond_to(:close)
						
			handle.close
		end
	end
end

# Test specific implementations if they're available and supported
if defined?(IO::Memory::POSIX) && IO::Memory::POSIX.supported?
	describe IO::Memory::POSIX do
		it_behaves_like IO::Memory::AMemoryBuffer
				
		with "POSIX-specific features" do
			it "creates POSIX handles" do
				handle = IO::Memory::POSIX.new(1024)
				expect(handle.class.to_s).to be(:include?, "POSIX")
				handle.close
			end
		end
	end
end

if defined?(IO::Memory::Linux) && IO::Memory::Linux.supported?
	describe IO::Memory::Linux do
		it_behaves_like IO::Memory::AMemoryBuffer
				
		with "Linux-specific features" do
			it "creates Linux handles" do
				handle = IO::Memory::Linux.new(1024)
				expect(handle.class.to_s).to be(:include?, "Linux")
				handle.close
			end
		end
	end
end

if defined?(IO::Memory::Generic) && IO::Memory::Generic.supported?
	describe IO::Memory::Generic do
		it_behaves_like IO::Memory::AMemoryBuffer
				
		with "Generic implementation features" do
			it "creates generic handles" do
				handle = IO::Memory::Generic.new(1024)
				expect(handle.class.to_s).to be(:include?, "Generic")
				handle.close
			end
		end
	end
end

# Test Unix domain socket file descriptor passing for shared memory
describe IO::Memory do
	with "Unix domain socket file descriptor passing" do
		it "can share memory buffers across process boundaries via socket" do
			skip "Fork not supported" unless Process.respond_to?(:fork)
			
			# Create a Unix domain socket pair
			parent_socket, child_socket = UNIXSocket.socketpair
			
			# Create shared memory buffer
			handle = IO::Memory.new(1024)
			buffer = handle.map
			
			# Write test data from parent
			test_message = "Hello from parent process!"
			buffer.set_string(test_message, 0)
			
			pid = fork do
				# Child process
				parent_socket.close
				
				begin
					# Receive file descriptor from parent
					received_io = child_socket.recv_io
					
					# Map the received memory
					child_buffer = ::IO::Buffer.map(received_io, 1024)
					
					# Read what parent wrote
					received_message = child_buffer.get_string(0, test_message.length)
					expect(received_message).to be == test_message
					
					# Write response that parent can see
					response = "Hello from child process!"
					child_buffer.set_string(response, 100)
					
					# Signal completion
					child_socket.write("OK")
					
					received_io.close
					child_socket.close
				rescue => error
					child_socket.write("ERROR: #{error}")
					exit 1
				end
				
				exit 0
			end
			
			# Parent process
			child_socket.close
			
			# Send file descriptor to child
			parent_socket.send_io(handle.io)
			
			# Wait for child response
			response = parent_socket.read(100) # Read more to get full error message
			if response.start_with?("ERROR:")
				raise "Child process error: #{response}"
			end
			expect(response[0, 2]).to be == "OK"
			
			# Verify child's write is visible to parent
			child_response = buffer.get_string(100, 25)
			expect(child_response).to be == "Hello from child process!"
			
			# Clean up
			Process.wait(pid)
			parent_socket.close
			handle.close
		end
		
		it "can share memory between threads using file descriptor duplication" do
			# Create shared memory buffer
			handle = IO::Memory.new(512)
			buffer = handle.map
			
			# Write initial data
			initial_data = "Thread communication test"
			buffer.set_string(initial_data, 0)
			
			# Share file descriptor with another thread
			shared_fd = handle.io.dup
			
			# Data to be written by the other thread
			thread_message = "Updated by thread"
			
			thread = Thread.new do
				# Map the same memory in the thread
				thread_io = IO.for_fd(shared_fd.fileno, autoclose: false)
				thread_buffer = ::IO::Buffer.map(thread_io, 512)
				
				# Verify initial data is visible
				read_data = thread_buffer.get_string(0, initial_data.length)
				expect(read_data).to be == initial_data
				
				# Write new data
				thread_buffer.set_string(thread_message, 100)
				
				thread_io = nil # Don't close, let the dup handle it
			end
			
			thread.join
			
			# Verify thread's write is visible in main thread
			result = buffer.get_string(100, thread_message.length)
			expect(result).to be == thread_message
			
			# Clean up
			shared_fd.close
			handle.close
		end
	end
end 

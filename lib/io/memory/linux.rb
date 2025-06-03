# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

require "fiddle"
require "fiddle/import"

module IO::Memory
	# Linux-specific implementation of memory-mapped IO using memfd_create.
	# This implementation provides the most efficient memory mapping on Linux
	# by using the memfd_create system call to create anonymous memory objects
	# that exist only in memory without being backed by any filesystem.
	module Linux
		extend self
				
		# Check if the Linux implementation is supported on this platform.
		# This implementation requires Linux with memfd_create system call support.
		# @returns [Boolean] true if running on Linux, false otherwise
		def self.supported?
			RUBY_PLATFORM.match?(/linux/i)
		end
				
		if supported?
			module Implementation
				extend Fiddle::Importer
								
				# Import libc functions
				dlload Fiddle.dlopen(nil)
								
				# memfd_create system call constants
				MFD_CLOEXEC = 0x01
				MFD_ALLOW_SEALING = 0x02
								
				# Import memfd_create function
				begin
					extern "int memfd_create(const char*, unsigned int)"
				rescue Fiddle::DLError
					# Fall back to syscall if memfd_create is not available in libc
					begin
						extern "long syscall(long, ...)"
												
						# memfd_create syscall number for Linux x86_64
						SYS_MEMFD_CREATE = 319
												
						def self.memfd_create(name, flags)
							syscall(SYS_MEMFD_CREATE, name, flags)
						end
					rescue Fiddle::DLError => e
						raise LoadError, "memfd_create system call not available: #{e.message}"
					end
				end
								
				# Import ftruncate for resizing the memory file
				begin
					extern "int ftruncate(int, long)"
				rescue Fiddle::DLError => e
					raise LoadError, "ftruncate function not available: #{e.message}"
				end

				# Handle class that wraps the IO
				class Handle
					def initialize(io, size)
						@io = io
						@size = size
					end
										
					def io
						@io
					end
										
					def map(size = nil)
						size ||= @size
						::IO::Buffer.map(@io, size)
					end
										
					def close
						@io.close unless @io.closed?
					end
										
					def closed?
						@io.closed?
					end
				end

				def self.create_handle(size)
					# Create the memory file descriptor
					fd = memfd_create("io_memory", MFD_CLOEXEC)
										
					if fd == -1
						raise IO::Memory::MemoryError, "Failed to create memfd: #{Fiddle.last_error}"
					end
										
					# Set the size
					if ftruncate(fd, size) == -1
						# Clean up on error
						begin
							::IO.for_fd(fd).close
						rescue
							# Ignore cleanup errors
						end
						raise IO::Memory::MemoryError, "Failed to set memfd size: #{Fiddle.last_error}"
					end
										
					# Convert to IO object and wrap in Handle
					io = ::IO.for_fd(fd, autoclose: true)
					Handle.new(io, size)
				rescue => e
					# Clean up on any error
					if defined?(fd) && fd && fd != -1
						begin
							::IO.for_fd(fd).close
						rescue
							# Ignore cleanup errors
						end
					end
					raise
				end
			end
						
			private_constant :Implementation

			# Create a new memory-mapped buffer using Linux memfd_create.
			# This creates an anonymous memory object that exists only in memory
			# without being backed by any filesystem.
			# @parameter size [Integer] size of the memory buffer in bytes
			# @returns [Object] a handle object that provides access to the memory buffer
			def new(size)
				Implementation.create_handle(size)
			end

			# Create a memory-mapped buffer and yield it to a block.
			# The buffer is automatically cleaned up when the block exits,
			# regardless of whether an exception is raised.
			# @parameter size [Integer] size of the memory buffer in bytes
			# @yields {|handle| ...}
			# 	@parameter handle [Object] the handle to the memory buffer with access to IO and mapping operations
			# @returns [Object] the result of the block execution
			def with(size, &block)
				handle = new(size)
				begin
					yield handle
				ensure
					handle.close
				end
			end
						
			# Get information about the Linux implementation.
			# @returns [Hash] implementation details including platform and features
			def info
				{
										implementation: "Linux memfd_create",
										platform: RUBY_PLATFORM,
										features: ["file_descriptor_passing", "zero_copy", "anonymous_memory"]
								}
			end
		end
	end
end 

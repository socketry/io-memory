# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

require "fiddle"
require "securerandom"

module IO::Memory
	# POSIX implementation of memory-mapped IO using shm_open.
	# This implementation provides efficient memory mapping on POSIX-compliant
	# systems (macOS, BSD, etc.) by using the shm_open system call to create
	# shared memory objects. These objects can be shared between processes
	# and provide zero-copy memory operations.
	module POSIX
		extend self
				
		# Check if the POSIX implementation is supported on this platform.
		# This implementation works on Unix-like systems that support POSIX
		# shared memory, excluding Linux (which has its own implementation)
		# and Windows platforms.
		# @returns [Boolean] true if POSIX shared memory is supported, false otherwise
		def self.supported?
			# POSIX shared memory is available on Unix-like systems (not Linux since we have a dedicated implementation, not Windows)
			!RUBY_PLATFORM.match?(/linux|mingw|mswin/i)
		end
				
		if supported?
			module Implementation
				# POSIX shared memory constants
				O_CREAT = 0x0200
				O_EXCL = 0x0800  
				O_RDWR = 0x0002
								
				# Load system functions
				LIBC = Fiddle.dlopen(nil)
								
				begin
					SHM_OPEN = Fiddle::Function.new(
						LIBC["shm_open"],
						[Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_INT],
						Fiddle::TYPE_INT
					)
					
					SHM_UNLINK = Fiddle::Function.new(
						LIBC["shm_unlink"], 
						[Fiddle::TYPE_VOIDP],
						Fiddle::TYPE_INT
					)
					
					FTRUNCATE = Fiddle::Function.new(
						LIBC["ftruncate"],
						[Fiddle::TYPE_INT, Fiddle::TYPE_LONG],
						Fiddle::TYPE_INT
					)
				rescue Fiddle::DLError => error
					raise LoadError, "POSIX shared memory functions not available!"
				end

				class MemoryError < StandardError; end
								
				# Handle class that wraps the IO and manages shared memory cleanup
				class Handle
					def initialize(io, shm_name, size)
						@io = io
						@shm_name = shm_name
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
					ensure
						# Unlink the shared memory object
						if @shm_name
							Implementation::SHM_UNLINK.call(@shm_name)
							@shm_name = nil
						end
					end
										
					def closed?
						@io.closed?
					end
				end

				def self.create_handle(size)
					# Try multiple times with different names to avoid conflicts
					attempts = 0
					max_attempts = 10
										
					while attempts < max_attempts
						# Generate simpler name that works with POSIX shared memory
						shm_name = "/iomem#{Process.pid}#{attempts}"
												
						# Create shared memory object
						shm_fd = SHM_OPEN.call(shm_name, O_CREAT | O_EXCL | O_RDWR, 0600)
												
						if shm_fd >= 0
							# Success! Set the size of the shared memory object
							if FTRUNCATE.call(shm_fd, size) == 0
								# Create IO object from file descriptor
								io = ::IO.for_fd(shm_fd, autoclose: true)
								# Return Handle that manages both IO and cleanup
								return Handle.new(io, shm_name, size)
							else
								# ftruncate failed, clean up
								SHM_UNLINK.call(shm_name)
								raise IO::Memory::MemoryError, "Failed to set shared memory size to #{size}!"
							end
						else
							# shm_open failed, try again with different name
							attempts += 1
							if attempts >= max_attempts
								raise IO::Memory::MemoryError, "Failed to create shared memory object after #{max_attempts} attempts!"
							end
						end
					end
				end
			end
						
			private_constant :Implementation

			# Create a new memory-mapped buffer using POSIX shared memory.
			# This creates a shared memory object using shm_open that can be
			# shared between processes and provides zero-copy operations.
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
						
			# Get information about the POSIX implementation.
			# @returns [Hash] implementation details including platform and features
			def info
				{
					implementation: "POSIX shared memory (shm_open)",
					platform: RUBY_PLATFORM,
					features: ["file_descriptor_passing", "zero_copy", "posix_shared_memory"]
				}
			end
		end
	end
end 

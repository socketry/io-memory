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

		module Implementation
			def self.supported?
				@supported
			end
			
			# Use Ruby's File constants instead of hardcoded values for cross-platform compatibility
			O_CREAT = IO::CREAT
			O_EXCL = IO::EXCL
			O_RDWR = IO::RDWR
							
			# Load system functions
			LIBC = Fiddle.dlopen(nil)
			
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
				# Generate a unique name using multiple entropy sources to avoid collisions
				# in high-concurrency situations
				max_attempts = 8
				last_error = nil
				
				max_attempts.times do
					# The most portable maximum length for a POSIX shared memory name is 14 characters:
					shm_name = "/#{SecureRandom.hex(7)}"
					
					# Create shared memory object with O_EXCL to ensure uniqueness
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
						# Store the error for potential debugging
						last_error = Fiddle.last_error
					end
					# If we get here, shm_open failed (likely name collision), try again with new name
				end
				
				# If we've exhausted all attempts:
				if last_error
					cause = SystemCallError.new(last_error)
				end
				
				raise IO::Memory::MemoryError, "Failed to create shared memory object after #{max_attempts} attempts!", cause: cause
			end

			@supported = true
		rescue
			@supported = false
		end
					
		private_constant :Implementation

		# Check if the POSIX shared memory implementation is supported on this system.
		# This implementation uses shm_open() and is available on POSIX-compliant systems
		# like macOS, BSD, and some Linux configurations with shared memory support.
		# @returns [Boolean] true if POSIX shared memory is available, false otherwise
		def self.supported?
			Implementation.supported?
		end

		if supported?
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
		end
	end
end 

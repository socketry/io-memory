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

		module Implementation
			extend Fiddle::Importer
			
			def self.supported?
				@supported
			end
							
			# memfd_create system call constants
			MFD_CLOEXEC = 0x01
			
			# Load system functions
			LIBC = Fiddle.dlopen(nil)
			
			# Load memfd_create function
			MEMFD_CREATE = Fiddle::Function.new(
				LIBC["memfd_create"],
				[Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
				Fiddle::TYPE_INT
			)
			
			# Load ftruncate function
			FTRUNCATE = Fiddle::Function.new(
				LIBC["ftruncate"],
				[Fiddle::TYPE_INT, Fiddle::TYPE_LONG],
				Fiddle::TYPE_INT
			)

			CLOSE = Fiddle::Function.new(
				LIBC["close"],
				[Fiddle::TYPE_INT],
				Fiddle::TYPE_INT
			)

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
				file_descriptor = MEMFD_CREATE.call("io_memory", MFD_CLOEXEC)
									
				if file_descriptor == -1
					raise IO::Memory::MemoryError, "Failed to create memfd!"
				end
									
				# Set the size
				if FTRUNCATE.call(file_descriptor, size) == -1
					# Clean up on error
					begin
						CLOSE.call(file_descriptor)
					rescue
						# Ignore cleanup errors
					end
					raise IO::Memory::MemoryError, "Failed to set memfd size!"
				end
									
				# Convert to IO object and wrap in Handle
				io = ::IO.for_fd(file_descriptor, autoclose: true)
				
				return Handle.new(io, size)
			rescue => error
				# Clean up on any error
				if file_descriptor and file_descriptor != -1
					begin
						CLOSE.call(file_descriptor)
					rescue
						# Ignore cleanup errors
					end
				end
				raise
			end

			@supported = true
		rescue
			@supported = false
		end

		private_constant :Implementation

		# Check if the Linux memfd_create implementation is supported on this system.
		# This implementation uses the memfd_create() system call available on Linux 3.17+
		# and provides the most efficient memory mapping by creating anonymous memory objects.
		# @returns [Boolean] true if memfd_create is available, false otherwise
		def self.supported?
			Implementation.supported?
		end

		if supported?
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
		end
	end
end

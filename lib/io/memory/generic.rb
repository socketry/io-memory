# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

require "tempfile"

module IO::Memory
	# Generic implementation of memory-mapped IO using temporary files.
	# This implementation provides maximum compatibility across platforms
	# by using Ruby's built-in Tempfile class and file descriptor mapping.
	# The temporary files are unlinked immediately after creation to behave
	# like anonymous memory objects.
	module Generic
		extend self
				
		# Check if the generic implementation is supported on this platform.
		# The generic implementation should work on all platforms that support
		# Ruby's Tempfile and IO::Buffer classes.
		# @returns [Boolean] always true, as generic implementation is universally supported
		def self.supported?
			true # Generic implementation should work on all platforms
		end
				
		if supported?
			module Implementation
				# Handle class that wraps the IO and manages tempfile cleanup
				class Handle
					def initialize(io, tempfile, size)
						@io = io
						@tempfile = tempfile
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
						# Clean up tempfile
						if @tempfile && !@tempfile.closed?
							@tempfile.close
							@tempfile = nil
						end
					end
										
					def closed?
						@io.closed?
					end
				end

				def self.create_handle(size)
					# Create a temporary file
					tempfile = Tempfile.new(["io_memory", ".tmp"])
										
					begin
						# Set the size
						tempfile.truncate(size) if tempfile.respond_to?(:truncate)
												
						# Immediately unlink the file so it's deleted when closed
						# This makes it behave more like memfd - it exists only in memory/cache
						File.unlink(tempfile.path)
												
						# Create IO from file descriptor and wrap in Handle
						io = ::IO.for_fd(tempfile.fileno, autoclose: false)
						Handle.new(io, tempfile, size)
					rescue => error
						# Clean up on error
						tempfile.close
						tempfile.unlink if File.exist?(tempfile.path)
						raise IO::Memory::MemoryError, "Failed to create temporary file buffer!"
					end
				end
			end
						
			private_constant :Implementation

			# Create a new memory-mapped buffer using a temporary file.
			# The temporary file is immediately unlinked to behave like
			# anonymous memory, existing only in the filesystem cache.
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
						
			# Get information about the generic implementation.
			# @returns [Hash] implementation details including platform and features
			def info
				{
					implementation: "Generic temporary file",
					platform: RUBY_PLATFORM,
					features: ["file_descriptor_passing"]
				}
			end
		end
	end
end 

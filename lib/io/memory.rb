# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

# Provides memory-mapped IO objects for zero-copy data sharing with cross-platform support.
# This module automatically selects the best available implementation based on the platform:
# - Linux: Uses memfd_create() for anonymous memory objects
# - POSIX: Uses shm_open() for shared memory objects  
# - Generic: Uses temporary files for maximum compatibility
module IO::Memory
	# Exception raised when memory operations fail.
	# This includes errors during memory buffer creation, mapping, or cleanup operations.
	class MemoryError < StandardError; end
		
	# Try to load implementations and extend the best available one
	# Priority: Linux (memfd_create) > POSIX (shm_open) > Generic (tempfile)
		
	# Try Linux first
	begin
		require_relative "memory/linux"
		if Linux.supported?
			extend Linux
		else
			raise LoadError, "Linux not supported"
		end
	rescue LoadError
		# Try POSIX next
		begin
			require_relative "memory/posix"
			if POSIX.supported?
				extend POSIX
			else
				raise LoadError, "POSIX not supported"
			end
		rescue LoadError
			# Fall back to Generic
			require_relative "memory/generic"
			if Generic.supported?
				extend Generic
			else
				raise LoadError, "No supported implementation available"
			end
		end
	end
end 

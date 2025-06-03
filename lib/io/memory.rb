# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

require_relative "memory/version"

require_relative "memory/linux"
require_relative "memory/posix"
require_relative "memory/generic"

# Provides memory-mapped IO objects for zero-copy data sharing with cross-platform support.
# This module automatically selects the best available implementation based on the platform:
# - Linux: Uses memfd_create() for anonymous memory objects
# - POSIX: Uses shm_open() for shared memory objects  
# - Generic: Uses temporary files for maximum compatibility
module IO::Memory
	# Exception raised when memory operations fail.
	# This includes errors during memory buffer creation, mapping, or cleanup operations.
	class MemoryError < StandardError; end
	
	# Select the best available implementation
	# Priority: Linux (memfd_create) > POSIX (shm_open) > Generic (tempfile)
	if Linux.supported?
		extend Linux
	elsif POSIX.supported?
		extend POSIX
	else
		extend Generic
	end
end 

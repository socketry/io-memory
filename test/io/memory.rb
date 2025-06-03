# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

require "sus"
require "io/memory"
require "io/memory/a_memory_buffer"

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

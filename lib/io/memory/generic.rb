require 'tempfile'

module IO::Memory
  module Generic
    extend self
    
    def self.supported?
      true  # Generic implementation should work on all platforms
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
          tempfile = Tempfile.new(['io_memory', '.tmp'])
          
          begin
            # Set the size
            tempfile.truncate(size) if tempfile.respond_to?(:truncate)
            
            # Immediately unlink the file so it's deleted when closed
            # This makes it behave more like memfd - it exists only in memory/cache
            File.unlink(tempfile.path)
            
            # Create IO from file descriptor and wrap in Handle
            io = ::IO.for_fd(tempfile.fileno, autoclose: false)
            Handle.new(io, tempfile, size)
          rescue => e
            # Clean up on error
            tempfile.close
            tempfile.unlink if File.exist?(tempfile.path)
            raise IO::Memory::MemoryError, "Failed to create temporary file buffer: #{e.message}"
          end
        end
      end
      
      private_constant :Implementation

      def new(size)
        Implementation.create_handle(size)
      end

      def with(size, &block)
        handle = new(size)
        begin
          yield handle
        ensure
          handle.close
        end
      end
      
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
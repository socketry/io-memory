require 'sus'

module IO::Memory
  AMemoryBuffer = Sus::Shared("a memory buffer") do
    it "can create a memory handle" do
      handle = subject.new(1024)
      
      expect(handle).to respond_to(:io)
      expect(handle).to respond_to(:map)
      expect(handle).to respond_to(:close)
      expect(handle).to respond_to(:closed?)
      expect(handle.closed?).to be == false
      
      handle.close
    end
    
    it "provides a working IO handle" do
      handle = subject.new(512)
      
      expect(handle.io).to respond_to(:read)
      expect(handle.io).to respond_to(:write)
      expect(handle.io).to respond_to(:close)
      expect(handle.closed?).to be == false
      
      handle.close
      expect(handle.closed?).to be == true
    end
    
    it "can map to IO::Buffer" do
      handle = subject.new(256)
      
      buffer = handle.map
      expect(buffer).to be_a(::IO::Buffer)
      expect(buffer.size).to be == 256
      
      handle.close
    end
    
    it "can map with explicit size" do
      handle = subject.new(1024)
      
      buffer = handle.map(512)
      expect(buffer).to be_a(::IO::Buffer)
      expect(buffer.size).to be == 512
      
      handle.close
    end
    
    it "can read and write data through buffer" do
      handle = subject.new(1024)
      
      buffer = handle.map
      test_string = "Hello, memory buffer!"
      buffer.set_string(test_string)
      
      result = buffer.get_string(0, test_string.length)
      expect(result).to be == test_string
      
      handle.close
    end
    
    it "supports with method for automatic cleanup" do
      handle_ref = nil
      
      result = subject.with(128) do |handle|
        handle_ref = handle
        expect(handle.closed?).to be == false
        
        buffer = handle.map
        buffer.set_string("test")
        
        "test_result"
      end
      
      expect(result).to be == "test_result"
      expect(handle_ref.closed?).to be == true
    end
    
    it "provides implementation information" do
      info = subject.info
      
      expect(info).to be_a(Hash)
      expect(info[:implementation]).to be_a(String)
      expect(info[:platform]).to be_a(String)
      expect(info[:features]).to be_a(Array)
    end
    
    it "handles zero-sized buffers" do
      begin
        handle = subject.new(0)
        
        buffer = handle.map
        expect(buffer).to be_a(::IO::Buffer)
        expect(buffer.size).to be == 0
        
        handle.close
      rescue Errno::EINVAL
        # Zero-size buffers may not be supported on all platforms
        # This is acceptable behavior
        skip "Zero-size buffers not supported on this platform/implementation"
      end
    end
    
    it "handles large buffers" do
      large_size = 1024 * 1024  # 1MB
      handle = subject.new(large_size)
      
      buffer = handle.map
      expect(buffer).to be_a(::IO::Buffer)
      expect(buffer.size).to be == large_size
      
      # Test writing at different offsets
      buffer.set_string("start", 0)
      buffer.set_string("end", large_size - 3)
      
      expect(buffer.get_string(0, 5)).to be == "start"
      expect(buffer.get_string(large_size - 3, 3)).to be == "end"
      
      handle.close
    end
  end
end 
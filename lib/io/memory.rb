module IO::Memory
  class MemoryError < StandardError; end
  
  # Try to load implementations and extend the best available one
  # Priority: Linux (memfd_create) > POSIX (shm_open) > Generic (tempfile)
  
  # Try Linux first
  begin
    require_relative 'memory/linux'
    if Linux.supported?
      extend Linux
    else
      raise LoadError, "Linux not supported"
    end
  rescue LoadError
    # Try POSIX next
    begin
      require_relative 'memory/posix'
      if POSIX.supported?
        extend POSIX
      else
        raise LoadError, "POSIX not supported"
      end
    rescue LoadError
      # Fall back to Generic
      require_relative 'memory/generic'
      if Generic.supported?
        extend Generic
      else
        raise LoadError, "No supported implementation available"
      end
    end
  end
end 
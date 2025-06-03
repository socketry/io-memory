# Releases

## Unreleased

  - Initial implementation with cross-platform memory mapping support
  - Linux `memfd_create()` implementation for anonymous memory objects
  - POSIX `shm_open()` implementation for shared memory
  - Generic temporary file fallback for maximum compatibility
  - Integration with Ruby's `IO::Buffer` class
  - Automatic resource cleanup with `with` blocks

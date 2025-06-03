# `IO::Memory`

Memory-mapped IO objects for zero-copy data sharing with cross-platform support for Linux (`memfd_create`), POSIX (`shm_open`), and generic implementations.

[![Development Status](https://github.com/socketry/io-memory/workflows/Test/badge.svg)](https://github.com/socketry/io-memory/actions?workflow=Test)

## Motivation

Modern applications increasingly require efficient memory sharing and zero-copy operations, especially in high-performance scenarios like web servers, data processing pipelines, and inter-process communication. `IO::Memory` provides a cross-platform abstraction over memory-mapped files that automatically selects the best available implementation based on your platform:

  - **Linux**: Uses `memfd_create()` for anonymous memory objects with file descriptor passing
  - **POSIX**: Uses `shm_open()` for POSIX shared memory objects
  - **Generic**: Falls back to temporary files for maximum compatibility

This gem is designed to work seamlessly with Ruby's `IO::Buffer` class, providing efficient memory mapping capabilities that integrate well with modern Ruby's IO subsystem.

## Features

  - **Cross-platform**: Automatically selects the best memory implementation for your platform
  - **Zero-copy**: Direct memory mapping without data copying
  - **IO::Buffer integration**: Works seamlessly with Ruby's built-in buffer objects
  - **File descriptor passing**: Share memory between processes (where supported)
  - **Automatic cleanup**: Built-in resource management with `with` blocks
  - **Multiple sizes**: Support for buffers from zero bytes to multiple gigabytes

## Usage

Please see the [project documentation](https://socketry.github.io/io-memory/) for more details.

  - [Getting Started](https://socketry.github.io/io-memory/guides/getting-started/index) - This guide explains how to use `io-memory` for efficient memory operations.

## Platform Support

| Platform | Implementation | Features |
|----------|----------------|----------|
| Linux | `memfd_create()` | Anonymous memory, file descriptor passing |
| macOS/BSD | `shm_open()` | POSIX shared memory, file descriptor passing |  
| Windows/Other | Temporary files | File descriptor passing, maximum compatibility |

## Performance

`IO::Memory` provides significant performance benefits for memory-intensive operations:

  - **Zero-copy**: No data copying when mapping memory
  - **OS-optimized**: Uses the most efficient memory primitives available
  - **Large buffer support**: Handles multi-gigabyte buffers efficiently
  - **Shared memory**: Enable inter-process communication without serialization

## Releases

Please see the [project releases](releases.md) for all releases.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.

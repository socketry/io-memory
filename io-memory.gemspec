# frozen_string_literal: true

require_relative "lib/io/memory/version"

Gem::Specification.new do |spec|
	spec.name = "io-memory"
	spec.version = IO::Memory::VERSION
	
	spec.summary = "Memory-mapped IO objects for zero-copy data sharing."
	spec.authors = ["Shopify Inc."]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/io-memory"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/io-memory/",
		"source_code_uri" => "https://github.com/socketry/io-memory.git",
	}
	
	spec.files = Dir["{lib}/**/*", "*.md", base: __dir__]
	
	spec.required_ruby_version = ">= 3.2"
end

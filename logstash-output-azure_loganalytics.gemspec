Gem::Specification.new do |s|
  s.name = 'logstash-output-azure_loganalytics'
  s.version    =  File.read("VERSION").strip
  s.authors = ["Yoichi Kawasaki"]
  s.email = "yoichi.kawasaki@outlook.com"
  s.summary = %q{logstash output plugin to store events into Azure Log Analytics}
  s.description = s.summary
  s.homepage = "http://github.com/yokawasa/logstash-output-azure_loganalytics"
  s.licenses = ["Apache License (2.0)"]
  s.require_paths = ["lib"]

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT', 'VERSION']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "rest-client", ">= 1.8.0"
  s.add_runtime_dependency "azure-loganalytics-datacollector-api", ">= 0.1.5"
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency "logstash-codec-plain"
  s.add_development_dependency "logstash-devutils"
end

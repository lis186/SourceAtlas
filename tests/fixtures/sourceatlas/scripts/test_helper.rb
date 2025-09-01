#!/usr/bin/env ruby

require 'json'
require 'fileutils'

module TestHelper
  class Runner
    attr_reader :results
    
    def initialize(config_path)
      @config = load_config(config_path)
      @results = []
    end
    
    def run_tests
      @config['tests'].each do |test|
        result = execute_test(test)
        @results << result
      end
    end
    
    private
    
    def load_config(path)
      JSON.parse(File.read(path))
    end
    
    def execute_test(test)
      puts "Running test: #{test['name']}"
      { name: test['name'], passed: true }
    end
  end
  
  module Utils
    def self.create_temp_dir
      Dir.mktmpdir('test-')
    end
  end
end

if __FILE__ == $0
  runner = TestHelper::Runner.new(ARGV[0])
  runner.run_tests
end
require "open3"
require "tmpdir"
require "fileutils"
require "file_spec/version"

# A set of RSpec utilities for testing files
#
# @example
#   RSpec.configure do |config|
#     config.include FileSpec
#   end
module FileSpec
  # Include everything in the top-level by default
  def self.included(base)
    base.include FileSpec::Setup
    base.include FileSpec::Helpers
    base.include FileSpec::Matchers
  end

  # Include this module to automatically switch to a temporary
  # directory before each test.
  #
  # @example
  #   RSpec.configure do |config|
  #     config.include FileSpec::Setup
  #   end
  module Setup
    def self.included(base)
      base.around :each do |example|
        Dir.mktmpdir do |tmp|
          Dir.chdir tmp do
            example.run
          end
        end
      end
    end
  end

  # A set of helper methods for interacting with files
  #
  # @example
  #   RSpec.configure do |config|
  #     config.include FileSpec::Helpers
  #   end
  module Helpers
    IGNORE = %w[.git .svn .venv .DS_Store node_modules *.o *.pyc *.class *.lock *.log]

    # Create a directories if they do not exist.
    # @param path [String,Pathname]
    def mkdir(path)
      FileUtils.mkdir_p(path)
    end

    # Write a file. This will automatically create directories if necessary.
    # @param path [String,Pathname]
    # @param content [String]
    def write(path, content = "")
      mkdir(File.dirname(path))
      File.write(path, content)
    end

    # Read a file.
    # @param path [String,Pathname]
    def read(path)
      File.read(path)
    end

    # Get the diff between two files or directories
    # @param before [String,Pathname] file path of inital file or files
    # @param after [String,Pathname] file path of changed file or files
    # @param exclude [Array<String>] list of paths to ignore
    def diff(before, after, exclude: [], **opts)
      cmd = %w[diff --unified --new-file --recursive]
      cmd += (exclude + IGNORE).flat_map { |path| ["--exclude", path] }
      cmd += [before.to_s, after.to_s]

      diff, _status = Open3.capture2e(*cmd, **opts)
      diff = diff.gsub(/^diff --unified.*\n/, "")
      diff.gsub(/^([+-]{3})\s(.*)\t\d{4}-.*$/, "\\1 \\2")
    end

    # Record changes to a file or directory over time
    # @param path [String,Pathname] the path to observe
    # @param opts [Hash] additional options passed to {#diff}
    def record_changes(path, **opts)
      basename = File.basename(path)
      tmp_path = Dir.mktmpdir("file_spec")
      before_path = File.join(tmp_path, "before", basename)
      after_path = File.join(tmp_path, "after", basename)

      unless File.directory?(path)
        mkdir File.dirname(before_path)
        mkdir File.dirname(after_path)
      end

      FileUtils.cp_r(path, before_path)
      yield
      FileUtils.cp_r(path, after_path)

      diff("before", "after", chdir: tmp_path, **opts)
    ensure
      FileUtils.rm_rf(tmp_path)
    end
  end

  # A collection of RSpec matchers for making file assertions
  #
  # @example
  #   RSpec.configure do |config|
  #     config.include FileSpec::Matchers
  #   end
  module Matchers
    extend ::RSpec::Matchers::DSL

    # @!method have_content
    # Determine if a file has matching content
    #
    # @example
    #   expect("foo.txt").to have_content("bar")
    #   expect("foo.txt").to have_content(/ba/)
    matcher :have_content do |expected|
      match do |actual|
        @actual = File.read(actual)
        values_match?(expected, @actual)
      end

      diffable if expected.is_a?(String)
      description { "have content: #{description_of(expected)}" }
    end

    # @!method be_a_file
    # Determine if a file exists
    #
    # @example
    #   expect("foo.txt").to be_a_file
    #   expect("bar.txt").not_to be_a_file
    matcher :be_a_file do
      match { |actual| File.file?(actual) }
    end

    # @!method be_a_directory
    # Determine if a directory exists
    #
    # @example
    #   expect("foo").to be_a_directory
    #   expect("bar").not_to be_a_directory
    matcher :be_a_directory do
      match { |actual| File.directory?(actual) }
    end

    # @!method be_executable
    # Test if a file is executable
    #
    # @example
    #   expect("bin/rails").to be_executable
    #   expect("Gemfile").not_to be_executable
    matcher :be_executable do
      match { |actual| File.executable?(actual) }
    end

    # @!method have_entries
    # Find the files in a directory
    #
    # @example
    #   expect("foo").to have_entries(%w[foo.txt bar.txt])
    matcher :have_entries do |expected|
      match do |actual|
        root = Pathname.new(actual)

        @expected = expected.sort
        @actual = root.glob("**/*", File::FNM_DOTMATCH)
          .select(&:file?)
          .map { |path| path.relative_path_from(root).to_s }
          .sort

        values_match?(@expected, @actual)
      end

      description { "contain files: #{description_of(@expected)}" }
    end
  end
end

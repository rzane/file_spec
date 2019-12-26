require "open3"
require "tmpdir"
require "fileutils"
require "file_spec/version"

module FileSpec
  extend ::RSpec::Matchers::DSL

  IGNORE = %w[.git .svn .venv .DS_Store node_modules *.o *.pyc *.class *.lock *.log]

  def self.included(base)
    base.around :each do |example|
      Dir.mktmpdir do |tmp|
        Dir.chdir tmp do
          example.run
        end
      end
    end
  end

  # Create a directory
  # @param path [String]
  def mkdir(path)
    FileUtils.mkdir_p(path)
  end

  # Write a file
  # @param path [String]
  # @param content [String]
  def write(path, content = "")
    mkdir(File.dirname(path))
    File.write(path, content)
  end

  # Read a file
  # @param path [String]
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
  # @param options [Hash] additional options passed to {#diff}
  def record_changes(path, **opts)
    basename = File.basename(path)

    Dir.mktmpdir do |tmp_path|
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
    end
  end

  # Determine if a file has matching content
  matcher :have_content do |expected|
    match do |actual|
      @actual = File.read(actual)
      values_match?(expected, @actual)
    end

    diffable if expected.is_a?(String)
    description { "have content: #{description_of(expected)}" }
  end

  # Determine if a filename is an existing file
  matcher :be_a_file do
    match { |actual| File.file?(actual) }
  end

  # Determine if a filename is an existing directory
  matcher :be_a_directory do
    match { |actual| File.directory?(actual) }
  end

  # Find the files in a directory
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

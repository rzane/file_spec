RSpec.describe FileSpec do
  include FileSpec

  it "has a version number" do
    expect(FileSpec::VERSION).not_to be nil
  end

  describe "#diff" do
    it "generates a diff based on two files" do
      write "before.txt", "hello"
      write "after.txt", "goodbye"

      expect(diff("before.txt", "after.txt")).to eq(<<~DIFF)
        --- before.txt
        +++ after.txt
        @@ -1 +1 @@
        -hello
        \\ No newline at end of file
        +goodbye
        \\ No newline at end of file
      DIFF
    end

    it "generates a diff based on two directories" do
      write "before/hello.txt", "hello"
      write "after/hello.txt", "goodbye"

      expect(diff("before", "after")).to eq(<<~DIFF)
        --- before/hello.txt
        +++ after/hello.txt
        @@ -1 +1 @@
        -hello
        \\ No newline at end of file
        +goodbye
        \\ No newline at end of file
      DIFF
    end
  end

  describe "#record_changes" do
    it "records changes to a file" do
      write "example/file.txt", "hello"

      diff = record_changes "example/file.txt" do
        write "example/file.txt", "goodbye"
      end

      expect(diff).to eq(<<~DIFF)
        --- a/file.txt
        +++ b/file.txt
        @@ -1 +1 @@
        -hello
        \\ No newline at end of file
        +goodbye
        \\ No newline at end of file
      DIFF
    end

    it "records changes to a directory" do
      write "example/file.txt", "hello"

      diff = record_changes "example" do
        write "example/file.txt", "goodbye"
      end

      expect(diff).to eq(<<~DIFF)
        --- a/file.txt
        +++ b/file.txt
        @@ -1 +1 @@
        -hello
        \\ No newline at end of file
        +goodbye
        \\ No newline at end of file
      DIFF
    end
  end

  describe "#have_content" do
    it "matches when file has equal content" do
      write "foo.txt", "hello"
      expect("foo.txt").to have_content("hello")
    end

    it "matches when file has matching content" do
      write "foo.txt", "hello"
      expect("foo.txt").to have_content(/he/)
    end

    it "does not match when file does not have matching content" do
      write "foo.txt", "hello"

      expect { expect("foo.txt").to have_content("goodbye") }.to raise_error(
        RSpec::Expectations::ExpectationNotMetError,
        %(expected "hello" to have content: "goodbye")
      )
    end
  end

  describe "#be_a_file" do
    it "matches files" do
      write "foo"
      expect("foo").to be_a_file
    end

    it "does not match directories" do
      mkdir "foo"
      expect("foo").not_to be_a_file
    end

    it "does not match missing" do
      expect("foo").not_to be_a_file
    end
  end

  describe "#be_a_directory" do
    it "matches directories" do
      mkdir "foo"
      expect("foo").to be_a_directory
    end

    it "does not match files" do
      write "foo"
      expect("foo").not_to be_a_directory
    end

    it "does not match missing" do
      expect("foo").not_to be_a_directory
    end
  end

  describe "#have_entries" do
    it "finds all files in a directory" do
      write "foo/bar.txt"
      write "foo/bar/buzz.txt"
      write "foo/.gitignore"
      expect("foo").to have_entries(%w[bar.txt bar/buzz.txt .gitignore])
    end
  end

  describe "#be_executable" do
    it "matches an executable" do
      write "foo"
      FileUtils.chmod "+x", "foo"
      expect("foo").to be_executable
    end

    it "does not match a regular file" do
      write "foo"
      expect("foo").not_to be_executable
    end
  end
end

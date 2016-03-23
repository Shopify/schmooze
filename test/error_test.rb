require 'test_helper'
require 'fileutils'

class ErrorTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, 'fixtures')

  class ErrorSchmoozer < Schmooze::Base
    dependencies nonexistant: 'this-package-is-not-here'
    method :bogus, 'bogus'
  end

  class UninstalledSchmoozer < Schmooze::Base
    dependencies less: 'less'
    method :bogus, 'bogus'
  end

  class CoffeeSchmoozer < Schmooze::Base
    dependencies coffee: 'coffee-script'
    method :compile, 'coffee.compile'
  end

  class UnknownErrorSchmoozer < Schmooze::Base
    method :throw_string, 'function() { throw decodeURIComponent("%C2%AF%5C_%28%E3%83%84%29_%2F%C2%AF") }'
  end

  class LateArrivingDependency < Schmooze::Base
    dependencies empty: 'empty'
    method :test, 'function() { return 1; }'
  end

  def test_import_error
    dir = File.join(FIXTURES_DIR, 'uninstalled_package')
    error = assert_raises Schmooze::DependencyError do
      ErrorSchmoozer.new(dir).bogus
    end
    assert_equal "Cannot find module 'this-package-is-not-here'. You need to add it to '#{File.join(dir, 'package.json')}' and run 'npm install'", error.message
  end

  def test_import_error_no_package_json
    dir = File.join(FIXTURES_DIR, 'no_package_json')
    error = assert_raises Schmooze::DependencyError do
      ErrorSchmoozer.new(dir).bogus
    end
    assert_equal "Cannot find module 'this-package-is-not-here'. You need to add it to '#{File.join(dir, 'package.json')}' and run 'npm install'", error.message
  end

  def test_import_error_but_in_package_json
    dir = File.join(FIXTURES_DIR, 'uninstalled_package')
    error = assert_raises Schmooze::DependencyError do
      UninstalledSchmoozer.new(dir).bogus
    end
    assert_equal "Cannot find module 'less'. The module was found in '#{File.join(dir, 'package.json')}' however, please run 'npm install' from '#{dir}'", error.message
  end

  def test_javascript_error
    dir = File.join(FIXTURES_DIR, 'coffee')
    error = assert_raises Schmooze::JavaScript::SyntaxError do
      CoffeeSchmoozer.new(dir).compile('<=> 1')
    end

    assert_equal <<-ERROR.strip, error.message
[stdin]:1:1: error: unexpected <=
<=> 1
^^
ERROR
  end

  def test_late_arriving_dependency
    dir = File.join(FIXTURES_DIR, 'late-dep')
    late = LateArrivingDependency.new(dir, {"NODE_PATH" => dir})

    assert_raises Schmooze::DependencyError do
      late.test
    end

    assert_raises Schmooze::DependencyError do
      late.test
    end

    File.write(File.join(dir, 'empty.js'), 'module.exports = null;')

    assert_equal late.test, 1
  ensure
    FileUtils.rm(File.join(dir, 'empty.js'), force: true)
  end

  def test_unknown_error
    dir = File.join(FIXTURES_DIR, 'coffee')
    error = assert_raises Schmooze::JavaScript::UnknownError do
      UnknownErrorSchmoozer.new(dir).throw_string
    end
    assert_equal '¯\_(ツ)_/¯', error.message
  end
end

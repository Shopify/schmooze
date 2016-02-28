require 'test_helper'

FIXTURES_DIR = File.join(__dir__, 'fixtures')

class SchmoozeTest < Minitest::Test
  class ErrorSchmoozer < Schmooze::Base
    dependencies nonexistant: 'this-package-is-not-here'
  end

  class UninstalledSchmoozer < Schmooze::Base
    dependencies less: 'less'
  end

  def test_import_error
    dir = File.join(FIXTURES_DIR, 'uninstalled_package')
    error = assert_raises Schmooze::DependencyError do
      ErrorSchmoozer.new(dir)
    end
    assert_equal "Cannot find module 'this-package-is-not-here'. You need to add it to '#{File.join(dir, 'package.json')}' and run 'npm install'", error.message
  end

  def test_import_error_no_package_json
    dir = File.join(FIXTURES_DIR, 'no_package_json')
    error = assert_raises Schmooze::DependencyError do
      ErrorSchmoozer.new(dir)
    end
    assert_equal "Cannot find module 'this-package-is-not-here'. You need to add it to '#{File.join(dir, 'package.json')}' and run 'npm install'", error.message
  end

  def test_import_error_but_in_package_json
    dir = File.join(FIXTURES_DIR, 'uninstalled_package')
    error = assert_raises Schmooze::DependencyError do
      UninstalledSchmoozer.new(dir)
    end
    assert_equal "Cannot find module 'less'. The module was found in '#{File.join(dir, 'package.json')}' however, please run 'npm install' from '#{dir}'", error.message
  end
end

require 'test_helper'

class SchmoozeTest < Minitest::Test
  class CoffeeSchmoozer < Schmooze::Base
    dependencies coffee: 'coffee-script', compile: 'coffee-script.compile'

    method :compile, 'compile'
    method :version, 'function() { return [process.version, coffee.VERSION]; }'
  end

  def setup
    @schmoozer = CoffeeSchmoozer.new(File.join(__dir__, 'fixtures'))
  end

  def test_that_it_has_a_version_number
    refute_nil ::Schmooze::VERSION
  end

  def test_it_generates_code
    assert_equal <<-JS.strip, @schmoozer.instance_variable_get(:@code).strip
var coffee = require("coffee-script");
var compile = require("coffee-script").compile;

var __methods__ = {};
__methods__["compile"] = (compile);
__methods__["version"] = (function() { return [process.version, coffee.VERSION]; });

require('readline').createInterface({
  input: process.stdin,
  terminal: false,
}).on('line', function(line) {
  var input = JSON.parse(line);
  var output;
  try {
    output = ['ok', __methods__[input[0]].apply(null, input[1])];
  } catch (e) {
    output = ['err', e.toString()];
  }
  process.stdout.write(JSON.stringify(output));
  process.stdout.write("\\n");
});
JS
  end

  def test_usage
    assert_equal [%x[node -v].strip, '1.10.0'], @schmoozer.version
  end

  def test_compile
    result = @schmoozer.compile('a = 1')
    assert_equal <<-JS.strip, result.strip
(function() {
  var a;

  a = 1;

}).call(this);
JS
  end

  def test_compile_args
    result = @schmoozer.compile('a = 1', bare: true)
    assert_equal <<-JS.strip, result.strip
var a;

a = 1;
JS
  end
end

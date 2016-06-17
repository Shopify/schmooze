require 'test_helper'

class SchmoozeTest < Minitest::Test
  class CoffeeSchmoozer < Schmooze::Base
    dependencies coffee: 'coffee-script', compile: 'coffee-script.compile'

    method :compile, 'compile'
    method :error, %{function() {
  throw new Error("failed hard");
}}
    method :version, 'function() { return [process.version, coffee.VERSION]; }'
    method :async_version, %{function() {
  return new Promise(function(resolve) {
    setTimeout(function() {
      resolve([process.version, coffee.VERSION]);
    }, 100);
  });
}}
    method :async_error, %{function() {
  return new Promise(function() {
    throw new Error("asynchronously failed so hard");
  });
}}
  end

  def setup
    @schmoozer = CoffeeSchmoozer.new(File.join(__dir__, 'fixtures', 'coffee'))
  end

  def test_that_it_has_a_version_number
    refute_nil ::Schmooze::VERSION
  end

  def test_it_generates_code
    assert_equal <<-JS.strip, @schmoozer.instance_variable_get(:@_schmooze_bridge).code.strip
try {
  var coffee = require("coffee-script");
  var compile = require("coffee-script").compile;
} catch (e) {
  process.stdout.write(JSON.stringify(['err', e.toString()]));
  process.stdout.write("\\n");
  process.exit(1);
}
process.stdout.write("[\\"ok\\"]\\n");
var __methods__ = {};
__methods__["compile"] = (compile);
__methods__["error"] = (function() {
  throw new Error("failed hard");
});
__methods__["version"] = (function() { return [process.version, coffee.VERSION]; });
__methods__["async_version"] = (function() {
  return new Promise(function(resolve) {
    setTimeout(function() {
      resolve([process.version, coffee.VERSION]);
    }, 100);
  });
});
__methods__["async_error"] = (function() {
  return new Promise(function() {
    throw new Error("asynchronously failed so hard");
  });
});

function __handle_error__(error) {
  if (error instanceof Error) {
    process.stdout.write(JSON.stringify(['err', error.toString().replace(new RegExp('^' + error.name + ': '), ''), error.name]));
  } else {
    process.stdout.write(JSON.stringify(['err', error.toString()]));
  }
  process.stdout.write("\\n");
}
require('readline').createInterface({
  input: process.stdin,
  terminal: false,
}).on('line', function(line) {
  var input = JSON.parse(line);
  try {
    Promise.resolve(__methods__[input[0]].apply(null, input[1])
    ).then(function (result) {
      process.stdout.write(JSON.stringify(['ok', result]));
      process.stdout.write("\\n");
    }).catch(__handle_error__);
  } catch(error) {
    __handle_error__(error);
  }
});
JS
  end

  def test_usage
    assert_equal [%x[node -v].strip, '1.10.0'], @schmoozer.version
  end

  def test_error
    error = assert_raises Schmooze::JavaScript::Error do
      @schmoozer.error
    end
    assert_match /failed hard/, error.message
  end

  def test_async
    assert_equal [%x[node -v].strip, '1.10.0'], @schmoozer.async_version
  end

  def test_async_error
    error = assert_raises Schmooze::JavaScript::Error do
      @schmoozer.async_error
    end
    assert_match /asynchronously failed so hard/, error.message
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

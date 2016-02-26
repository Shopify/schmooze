require 'json'

module Schmooze
  class ProcessorGenerator
    class << self
      def generate(imports, methods)
%{#{imports.map {|import| generate_import(import)}.join}
var __methods__ = {};
#{methods.map{ |method| generate_method(method[:name], method[:code]) }.join}
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
}
      end

      def generate_method(name, code)
        "__methods__[#{name.to_json}] = (#{code});\n"
      end

      def generate_import(import)
        package, mid, path = import[:package].partition('.')
        "var #{import[:identifier]} = require(#{package.to_json})#{mid}#{path};\n"
      end
    end
  end
end

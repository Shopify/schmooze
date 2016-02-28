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
  try {
    Promise.resolve(__methods__[input[0]].apply(null, input[1])
    ).then(function (result) {
      process.stdout.write(JSON.stringify(['ok', result]));
      process.stdout.write("\\n");
    }).catch(function (error) {
      process.stdout.write(JSON.stringify(['err', error.toString()]));
      process.stdout.write("\\n");
    });
  } catch(error) {
    process.stdout.write(JSON.stringify(['err', error.toString()]));
    process.stdout.write("\\n");
  }
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

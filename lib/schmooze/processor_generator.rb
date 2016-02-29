require 'json'

module Schmooze
  class ProcessorGenerator
    class << self
      def generate(imports, methods)
%{try {
#{imports.map {|import| generate_import(import)}.join}} catch (e) {
  process.stdout.write(JSON.stringify(['err', e.toString()]));
  process.stdout.write("\\n");
  process.exit(1);
}
process.stdout.write("[\\"ok\\"]\\n");
var __methods__ = {};
#{methods.map{ |method| generate_method(method[:name], method[:code]) }.join}
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
}
      end

      def generate_method(name, code)
        "__methods__[#{name.to_json}] = (#{code});\n"
      end

      def generate_import(import)
        package, mid, path = import[:package].partition('.')
        "  var #{import[:identifier]} = require(#{package.to_json})#{mid}#{path};\n"
      end
    end
  end
end

# Schmooze

Schmooze lets Ruby and Node.js work together intimately. It has a DSL that allows you to define what methods you need, and it executes code by spawning a Node.js process and sending messages back and forth.

## Requirements

Schmooze requires that you have [nodejs](https://nodejs.org/en/) installed and in the `$PATH`.

## Gem Installation

Add this line to your application's Gemfile:

```ruby
gem 'schmooze'
```

And then execute:

    $ bundle

## Usage

To use Schmooze, you first need to create a sublcass of `Schmooze::Base`. Your subclass needs to list all of the package dependencies, and methods that you want to have available. For example, here is a Schmooze class that interfaces with [Babel](https://babeljs.io/):

```ruby
require 'schmooze'

class BabelSchmoozer < Schmooze::Base
  dependencies babel: 'babel-core'

  method :transform, 'babel.transform'
  method :version, 'function() { return [process.version, babel.version]; }'
end
```

Note that the `babel-core` package is available under the name `babel`, because that's how we requested it.

To define a method, you simply give it a name and pass in a JavaScript string that should resolve to a function. Let's put this class to use!

First we need to make sure we install any needed packages.

`$ npm install babel-core babel-preset-es2015`

All we need to do next is to instantiate the class with a path to where the node modules are installed, and then we can call the methods! (Note that we need to pass in `ast: false` because of a [caveat](#caveats)).

```ruby
$ pry
Ruby 2.2.2
pry> load './babel_schmoozer.rb'
pry> babel = BabelSchmoozer.new(__dir__)
pry> babel.version
=> ["v5.5.0", "6.5.2"]
pry> puts babel.transform('a = () => 1', ast: false, presets: ['es2015'])['code']
"use strict";

a = function a() {
  return 1;
};
```

This could easily be turned into a Sprockets plugin.

## Error handling

Errors happen, and Schmooze tries to make them as painless as possible to handle. If there is a dependency missing, Schmooze will throw a helpful Error when you try to initialize the class. Here is an example from the tests:

```ruby
class ErrorSchmoozer < Schmooze::Base
  dependencies nonexistant: 'this-package-is-not-here'
end
ErrorSchmoozer.new(__dir__)
```

This will raise

```
Schmooze::DependencyError: Cannot find module 'this-package-is-not-here'.
You need to add it to '/Users/bouke/code/schmooze/test/fixtures/uninstalled_package/package.json' and run 'npm install'
```

Any JavaScript errors that happen get converted to Ruby errors under the `Schmooze::Javascript` namespace. For example (once again, from the tests):

```ruby
class CoffeeSchmoozer < Schmooze::Base
  dependencies coffee: 'coffee-script'
  method :compile, 'coffee.compile'
end

CoffeeSchmoozer.new(dir).compile('<=> 1')
```

This will raise

```
Schmooze::JavaScript::SyntaxError: [stdin]:1:1: error: unexpected <=
 <=> 1
 ^^
```

## Caveats

* Because we serialize the return values from JavaScript to JSON, you can't return circular data structures (like the Babel AST).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/schmooze.

### Make sure the tests pass

Run the setup script

```
$ ./script/setup
```

Run the tests

```
$ ./script/test
```

maestro-ruby-plugin
===================

Library For Creating Ruby Based Maestro Plugins
=======
# Introduction

Maestro 4 provides support for plugins written in Java and Ruby.  They are both permitted to have dependent libraries.
Ruby based plugins provide the worker source file (.rb) and any dependencies (.gem) are loaded using the Rubygems (gem)
executable. Both plugin types provide a manifest file (manifest.json) that details the contents and attributes of the
plugin.


## Installation

Add this line to your application's Gemfile:

    gem 'maestro_plugin'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install maestro_plugin

## Usage

### Directory Layout

Your plugin source directory should contain the following subdirectories:

* src - contains the plugin source code.
* spec - contains the plugin RSpec testing code.

### The POM

TBD

### The manifest

TBD

### The worker class

Simply extend the Maestro::MaestroWorker class. Then set it in the *class* parameter of your manifest.  Make sure the
command parameter for each task defined in the manifest has a matching method in your worker.


### Unit Testing Your Plugins

In order to unit test your plugins, you should make sure to set the MaestroWorker class to "mock" mode so that it doesn't
attempt to post messages on the response queue. You can do this by calling the *Maestro::MaestroWorker.mock!* method.


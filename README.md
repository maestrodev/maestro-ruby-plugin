Maestro Ruby Plugin Gem
=======================
[![Gem Version](https://badge.fury.io/rb/maestro_plugin.png)](http://badge.fury.io/rb/maestro_plugin)
[![Code Climate](https://codeclimate.com/github/maestrodev/maestro-ruby-plugin.png)](https://codeclimate.com/github/maestrodev/maestro-ruby-plugin)

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
* images - contains the plugin images displayed in the task list and composition bar.

### The Manifest

TBD

### The Worker Class

The logic for your plugin is implemented by a worker class. This class should extend the Maestro::MaestroWorker class.
Set it in the *class* parameter of your manifest. The command parameter for each task defined in the manifest must have
a matching method in your worker.

### Unit Testing Your Plugin

You can use RSpec to perform unit testing. If your plugin invokes any of the utility methods in the MaestroWorker class,
you should make sure to set the MaestroWorker class to "mock" mode so that it doesn't attempt to post messages on the
response queue. You can do this by calling the *Maestro::MaestroWorker.mock!* method.

### Packaging Your Plugin

You must package your plugin into a zip file. It must contain the following files and directory:

* src - the source directory
* images - the directory containing the image displayed on the Maestro UI in the task list and composition bar.
* vendor - the directory containing all the gem dependencies.
* manifest.json - the manifest.
* README.md - the README file (optional)
* LICENSE - the license file (optional)

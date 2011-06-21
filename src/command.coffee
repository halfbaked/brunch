# External dependencies.
nomnom      = require 'nomnom'
path        = require 'path'
brunch      = require './brunch'
helpers     = require './helpers'
colors      = require('../vendor/termcolors').colors
yaml        = require 'yaml'
fs          = require 'fs'
_           = require 'underscore'

# The list of all the valid option flags that 'brunch' knows how to handle.
NOMNOM_CONFIG_OLD = [
    name  : 'expressPort'
    string: '-ep <port>, --expressPort=<port>'
    help  : 'set the express server port'
  ,
    name  : 'projectTemplate'
    string: '-p <template>, --projectTemplate=<template>'
    help  : 'set which kind of project template should be used'
  ,
    name  : 'version'
    string: '-v, --version'
    help  : 'display brunch version'
  ,
    name  : 'help'
    string: '-h, --help'
    help  : 'display brunch help'
  ,
    name  : 'output'
    string: '-o, --output'
    help  : 'set build path'
  ,
    name  : 'minify'
    string: '-m, --minify'
    help  : 'minify the app.js output via UglifyJS'
]

NOMNOM_CONFIG = {
  version: {
    string: '-v, --version'
    help: 'Returns labBuilder version'
    callback: ->
      return "version 0.1";            
  }
}


options = {}
argParser = {}

buildClient = (options) ->
  console.log 'Building the client'
  brunch.buildClient()

buildServer = (options) ->
  console.log 'Building the server'

# Run 'brunch' by parsing passed options and determining what action to take.
# This also includes checking for a config file. Options in commandline arguments
# overwrite options from the config file. In this case you are able to have
# reasonable defaults and changed only the options you need to change in this particular case.
exports.run = ->

  exports.buildConfig = {
    clientBuildPath: 'build/client',
    clientSrcPath: 'src/client'
  }

  nomnom.command('create-app')
    .opts({
      app: {
        position: 1,
        help: 'Name of app you wish to create'
      }
    })
    .help('Create a new app')
    .callback( (options) ->
      console.log 'Creating new app')

  nomnom.command('build-server')
    .help('Build the server')
    .callback( (options) ->
      brunch.buildServer())

  nomnom.command('build-client')
    .help('Build the client')
    .callback( (options) ->
      buildClient(options))

  nomnom.command('watch-server')
    .help('Watch for changes on the server and rebuild')
    .callback( (options) ->
      console.log 'Watching for changes on server')

  nomnom.command('watch-client')
    .help('Watch for changes on client, and rebuild')
    .callback( (options) ->
      console.log 'Watching for changes on client')

  nomnom.command('build')
    .help('Build client and server')
    .callback( (options) ->
      buildClient(options)
      buildServer(options))
      
  nomnom.command('watch') 
    .help('Watch for changes on client or server and rebuild')
    .callback( (options) ->
      console.log 'Watching for changes on client or server and rebuilding')

  nomnom.command('clean-client')
    .help('Deletes client build directory')
    .callback( (options) ->
      brunch.cleanClient(options))

  nomnom.command('clean-server')
    .help('Deletes server build directory')
    .callback( (options) ->
      console.log 'Cleaning server build directory')

  nomnom.command('start-server')
    .help('Starts Express server')
    .callback( (options) ->
      brunch.startServer())

  opts = nomnom.opts(NOMNOM_CONFIG).parseArgs()
  
# Load default options
exports.loadDefaultArguments = ->
  # buildPath is created in loadOptionsFromArguments
  options =
    templateExtension: 'eco'
    projectTemplate: 'base'
    expressPort: '8080'
    brunchPath: 'brunch'
    dependencies: []
    minify: false
  options

# Load options from config file
exports.loadConfigFile = (configPath) ->
  try
    options = yaml.eval fs.readFileSync(configPath, 'utf8')
    return options
  catch e
    helpers.log colors.lred("brunch:   Couldn't find config.yaml file\n", true)
    process.exit 0

# Load options from arguments
exports.loadOptionsFromArguments = (opts, options) ->
  options.templateExtension = opts.templateExtension if opts.templateExtension?
  options.projectTemplate = opts.projectTemplate if opts.projectTemplate?
  options.expressPort = opts.expressPort if opts.expressPort?
  options.brunchPath = opts[1] if opts[1]?
  options.minify = opts.minify if opts.minify?
  if opts.buildPath?
    options.buildPath = opts.buildPath
  else unless options.buildPath?
    options.buildPath = path.join options.brunchPath, 'build'
  options

# Run nomnom to parse the arguments
parseOptions = ->
  nomnom.parseArgs NOMNOM_CONFIG, { printHelp: false }

# Print the '--help' usage message and exit.
usage = ->
  process.stdout.write BANNER
  process.stdout.write helpers.optionsInfo(NOMNOM_CONFIG)
  process.exit 0

# Print the '--version' message and exit.
version = ->
  process.stdout.write "brunch version #{brunch.VERSION}\n"
  process.exit 0



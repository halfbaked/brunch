# brunch can be used via command-line tool or manually by calling run(options).

root = __dirname + "/../"
# External dependencies.
fs        = require 'fs'
path      = require 'path'
spawn     = require('child_process').spawn
helpers   = require './helpers'
fileUtil  = require 'file'
colors    = require('../vendor/termcolors').colors
stitch    = require 'stitch'
_         = require 'underscore'

# the current brunch version number
exports.VERSION = '0.7.1'

# server process storred as global for stop method
expressProcess = {}

# stitch package
package = {}
fakeServerPackage = {}

# are used as workaround to not call compile to often
# TODO in future this issues should be handled by a clean dir/file watcher
timeouts = {}

# project skeleton generator
exports.new = (options, callback) ->
  exports.options = options

  projectTemplatePath = path.join(module.id, "/../../template", exports.options.projectTemplate)

  path.exists exports.options.brunchPath, (exists) ->
    if exists
      helpers.log colors.lred("brunch:   directory already exists - can't create a project in there\n", true)
      process.exit 0

    fileUtil.mkdirsSync exports.options.brunchPath, 0755
    fileUtil.mkdirsSync exports.options.buildPath, 0755

    helpers.recursiveCopy projectTemplatePath, exports.options.brunchPath, ->
      helpers.recursiveCopy path.join(projectTemplatePath, 'build/'), exports.options.buildPath, ->
        callback()
        helpers.log "brunch:   #{colors.green('created', true)} brunch directory layout\n"

# file watcher
exports.watch  = (options) ->
  exports.options = options
  exports.createBuildDirectories(exports.options.buildPath)
  exports.initializePackage(exports.options.brunchPath)

  # run node server if server file exists
  path.exists path.join(exports.options.brunchPath, 'server/main.js'), (exists) ->
    if exists
      helpers.log "express:  application started on port #{colors.blue(exports.options.expressPort, true)}: http://0.0.0.0:#{exports.options.expressPort}\n"
      expressProcess = spawn('node', [
        path.join(exports.options.brunchPath, 'server/main.js'),
        exports.options.expressPort,
        exports.options.brunchPath
      ])
      expressProcess.stderr.on 'data', (data) ->
        helpers.log colors.lred('express err: ' + data)

   # run node server if server file exists
  path.exists path.join(exports.options.brunchPath, 'build/fake_server/main.js'), (exists) ->
    if exists
      helpers.log "express fake server:  application started on port #{colors.blue(exports.options.expressPort, true)}: http://0.0.0.0:#{exports.options.expressPort}\n"
      expressProcess = spawn('node', [
        path.join(exports.options.buildPath, 'fake_server/main.js'),
        exports.options.expressPort,
        path.join exports.options.brunchPath, 'build/spa' 
      ])
      expressProcess.stderr.on 'data', (data) ->
        helpers.log colors.lred('express err: ' + data)
      expressProcess.stdout.on 'data', (data) ->
        helpers.log colors.blue('test_server:' + data)


  # let's watch
  helpers.watchDirectory(path: path.join(exports.options.brunchPath, 'src'), callOnAdd: true, (file) ->
    exports.dispatch(file)
  )

# building all files
exports.build = (options) ->
  exports.options = options
  exports.createBuildDirectories(exports.options.buildPath)
  exports.initializePackage(exports.options.brunchPath)
  
  exports.compilePackage()
  exports.spawnStylus()
  exports.initializeFakeServerPackage(exports.options.brunchPath)
  exports.buildFakeServer()

exports.stop = ->
  expressProcess.kill 'SIGHUP' unless expressProcess is {}

exports.createBuildDirectories = (buildPath) ->
  fileUtil.mkdirsSync path.join(buildPath, 'spa/js'), 0755
  fileUtil.mkdirsSync path.join(buildPath, 'spa/css'), 0755

# generate list of dependencies and preserve order of brunch libaries
# like defined in options.dependencies
exports.collectDependencies = (sourcePath, orderedDependencies) ->
  filenames = fs.readdirSync sourcePath
  filenames = helpers.filterFiles filenames, sourcePath

  args = orderedDependencies.slice()
  args.unshift filenames
  additionalLibaries = _.without.apply @, args
  dependencies = orderedDependencies.concat additionalLibaries
  dependencyPaths = _.map dependencies, (filename) ->
    path.join(sourcePath, filename)

# creates a stitch package for app directory and include vendor as dependencies
exports.initializePackage = (brunchPath) ->
  vendorPath = path.join brunchPath, 'src/vendor/js'
  dependencyPaths = exports.collectDependencies(vendorPath, exports.options.dependencies)

  package = stitch.createPackage(
    dependencies: dependencyPaths
    paths: [path.join(brunchPath, 'src/spa/')]
  )
  package

# create a stitch package of all fakeserver related files
exports.initializeFakeServerPackage = (brunchPath) ->   
  fakeServerPackage = stitch.createPackage(
    paths: [path.join brunchPath, 'src/fake_server']
  )
  fakeServerPackage

# dispatcher for file watching which determines which action needs to be done
# according to the file that was changed/created/removed
exports.dispatch = (file, options) ->

  queueCoffee = (func) ->
    clearTimeout(timeouts.coffee)
    timeouts.coffee = setTimeout(func, 100)

  # update package dependencies in case a dependency was added or removed
  vendorPath = path.join(exports.options.brunchPath, 'src/vendor/js')
  package.dependencies = exports.collectDependencies vendorPath, exports.options.dependencies if file.match(/src\/vendor\//)

  # handle coffee changes
  if file.match(/\.coffee$/)
    queueCoffee ->
      exports.compilePackage()

  # handle template changes
  templateExtensionRegex = new RegExp("#{exports.options.templateExtension}$")
  if file.match(templateExtensionRegex)
    exports.compilePackage()

  if file.match(/src\/.*\.js$/)
    exports.compilePackage()

  if file.match(/\.styl$/)
    exports.spawnStylus()

# compile app files
#
# uses stitch compile method to merge all application files (including templates)
# and the defined dependencies to one single file
# each file will be saved into a module
exports.compilePackage = ->
  package.compile( (err, source) ->
    if err?
      helpers.log "brunch:   #{colors.lred('There was a problem during compilation.', true)}\n"
      helpers.log "#{colors.lgray(err, true)}\n"
    else
      fs.writeFile(path.join(exports.options.buildPath, 'spa/js/app.js'), source, (err) ->
        if err?
          helpers.log "brunch:   #{colors.lred('Couldn\'t write compiled file.', true)}\n"
          helpers.log "#{colors.lgray(err, true)}\n"
        else
          helpers.log "stitch:   #{colors.green('compiled', true)} application\n"
      )
  )


exports.buildFakeServer = ->
 executeCoffee = spawn('coffee', [
    '-o'
    path.join exports.options.buildPath, 'fake_server'
    '-c'
    path.join exports.options.brunchPath, 'src/fake_server'
  ])
  executeCoffee.stdout.on 'data', (data) ->
    helpers.log 'stylus: ' + data
  executeCoffee.stderr.on 'data', (data) ->
    helpers.log colors.lred('stylus err: ' + data)

# spawn a new stylus process which compiles main.styl
exports.spawnStylus = ->

  path.join(exports.options.brunchPath, 'src')
  executeStylus = spawn('stylus', [
    '-I'
    path.join(exports.options.brunchPath, 'src/vendor/styles')
    '--compress'
    '--out'
    path.join(exports.options.buildPath, 'spa/css'),
    path.join(exports.options.brunchPath, 'src/spa/styles/main.styl')
    path.join(exports.options.brunchPath, 'src/vendor/styles/')
  ])
  executeStylus.stdout.on 'data', (data) ->
    helpers.log 'stylus: ' + data
  executeStylus.stderr.on 'data', (data) ->
    helpers.log colors.lred('stylus err: ' + data)

# brunch can be used via command-line tool or manually by calling run(options).

root = __dirname + "/../"
# External dependencies.
path      = require 'path'
spawn     = require('child_process').spawn
helpers   = require './helpers'
fileUtil  = require 'file'
colors    = require('../vendor/termcolors').colors
stitch    = require 'stitch'
labBuilder = require 'labBuilder'
fs = require 'fs'
rimraf = require("rimraf")
yaml        = require 'yaml'
_ = require 'underscore'
stylus    = require 'stylus'
try
  nib = require('nib')()
catch error
  false

# Strips out all white space from a string
exports.trimString = (str) ->
  str.replace(/\s/g,"")

# the current brunch version number
exports.VERSION = require('./package').version

# server process storred as global for stop method
expressProcess = {}

# available compilers
compilers = []

exports.buildConfig = {
  clientBuildPath: 'build/client',
  clientSrcPath: 'src/client',
  serverBuildPath: 'build/server',
  serverSrcPath: 'src/server',
  clientResourcesPath: 'resources/client'
  vendorStylePath: 'vendor/style'
  indexStyleFile: 'src/client/style/main.styl'
  labJsUrl: 'js/LAB.min.js'
  labBuilderOutputFile: 'js/labBuilder.js'
  dependencies: []
  projectBuildConfigFileName: 'config/client/buildConfig.json'
  mainStylusPath: 'src/client/styles/main.styl'
}

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
  exports.initializeCompilers()

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
  exports.createBuildDirectories(exports.options.buildPath)
  exports.initializeCompilers()

  for compiler in compilers
    compiler.compile(['.'])

exports.stopServer = (options) ->
  expressProcess.kill 'SIGHUP' unless expressProcess is {}

exports.startServer = (options) ->
  serverBuildPath = exports.buildConfig.serverBuildPath
  clientBuildPath = exports.buildConfig.clientBuildPath

  expressProcess = spawn('node', [
        path.join(serverBuildPath, 'main.js'),
        8080,
        clientBuildPath 
      ])
      expressProcess.stderr.on 'data', (data) ->
        helpers.log colors.lred('express err: ' + data)
      expressProcess.stdout.on 'data', (data) ->
        helpers.log colors.blue('server:' + data)

exports.buildServer = (options) ->

  serverBuildPath = exports.buildConfig.serverBuildPath
  serverSrcPath = exports.buildConfig.serverSrcPath
  
  # Create build dirs
  fileUtil.mkdirsSync serverBuildPath, 0755

  # Compile scripts
  executeCoffee = spawn('coffee', [
    '-o'
    serverBuildPath
    '-c'
    serverSrcPath
  ])
  executeCoffee.stdout.on 'data', (data) ->
    helpers.log 'coffee: ' + data
  executeCoffee.stderr.on 'data', (data) ->
    helpers.log colors.lred('coffee err: ' + data)

exports.cleanClient = (options) ->
  clientBuildPath = exports.buildConfig.clientBuildPath
  path.exists clientBuildPath, (exists) ->
    if exists then rimraf clientBuildPath, (err) -> 
      throw err if err 
      console.log "#{clientBuildPath} deleted"
    else console.log "#{clientBuildPath} already deleted"

exports.buildClient = (options) ->

  #include project build config
  projectBuildConfigFile = fs.readFileSync('config/client/buildConfig.json', 'utf8')
  projectBuildConfig = JSON.parse exports.trimString(projectBuildConfigFile)
  exports.buildConfig = _.extend(exports.buildConfig, projectBuildConfig)

  console.log "Build Config:" + exports.buildConfig.dependencies

  clientBuildPath = exports.buildConfig.clientBuildPath
  clientSrcPath = exports.buildConfig.clientSrcPath

  # Create build dirs
  fileUtil.mkdirsSync path.join(clientBuildPath, 'js'), 0755
  fileUtil.mkdirsSync path.join(clientBuildPath, 'css'), 0755

  # Transfer resources
  # Anything can be put in the resources dir and it is simply copied across to the build directory
  clientResourcesPath = exports.buildConfig.clientResourcesPath

  resourceDirContents = fs.readdirSync(clientResourcesPath) 
  console.log "Resources to transfer: #{resourceDirContents}"
  for file in resourceDirContents
    transferResources = spawn('cp', ['-r', path.join(clientResourcesPath, file), clientBuildPath])
    transferResources.stdout.on 'data', (data) ->
      console.log 'transferring resources: ' + data
    transferResources.stderr.on 'data', (data) ->
      console.log colors.lred('transferring resources err: ' + data)

  # Compile scripts
  package = stitch.createPackage(
    paths: [clientSrcPath]
  )
  package.compile( (err, source) ->
    if err?
      helpers.log "brunch:   #{colors.lred('There was a problem during compilation.', true)}\n"
      helpers.log "#{colors.lgray(err, true)}\n"
    else
      source = source + "\nrequire('main');"
      fs.writeFile(path.join(clientBuildPath, 'js/client.js'), source, (err) ->
        if err?
          helpers.log "brunch:   #{colors.lred('Couldn\'t write compiled file.', true)}\n"
          helpers.log "#{colors.lgray(err, true)}\n"
        else
          helpers.log "stitch:   #{colors.green('compiled', true)} application\n"
      )
  )

  
  #console.log "resources transferred: cp -r #{path.join(clientResourcesSrcPath,'*')} #{clientResourcesBuildPath}"

  # build stylus
  vendorStylePath = exports.buildConfig.vendorStylePath
  indexStyleFile = exports.buildConfig.indexStyleFile
  executeStylus = spawn('stylus', [
    '-o'
    path.join clientBuildPath, 'css'
    '-I'
    vendorStylePath
    indexStyleFile
  ])

  # Link dependencies and client app
  dependencies = exports.buildConfig.dependencies
  scripts = dependencies.slice()
  scripts = scripts.concat([{ name: 'clientapp', src:'js/client.js'}])
  
  for script in scripts 
    console.log "name: #{script.name}, src: #{script.src}"

  labJs = exports.buildConfig.labJsUrl
  labBuilderOutputFile = exports.buildConfig.labBuilderOutputFile
  labBuilder.build labJs, scripts, path.join(clientBuildPath, labBuilderOutputFile)
  
  # Compile main stylus file
  stylusMainFilePath = exports.buildConfig.mainStylusPath

  fs.readFile(stylusMainFilePath, 'utf8', (err, data) =>
      if err?
        helpers.log colors.lred('stylus err: ' + err)
      else
        compiler = stylus(data)
          .set('filename', stylusMainFilePath)
          .set('compress', true)
        #  .include(path.join(@options.brunchPath, 'src'))

        if nib
          compiler.use nib

        compiler.render (err, css) =>
          if err?
            helpers.log colors.lred('stylus err: ' + err)
          else
            fs.writeFile(path.join(clientBuildPath, 'css/main.css'), css, 'utf8', (err) =>
              if err?
                helpers.log colors.lred('stylus err: ' + err)
              else
                helpers.log "stylus:   #{colors.green('compiled', true)} main.css\n"
            )
  )

# initializes all avaliable compilers
exports.initializeCompilers = ->
  compilers = (new compiler(exports.options) for name, compiler of require('./compilers'))

exports.stop = ->
  expressProcess.kill 'SIGHUP' unless expressProcess is {}

exports.createBuildDirectories = (buildPath) ->
  fileUtil.mkdirsSync path.join(buildPath, 'spa/js'), 0755
  fileUtil.mkdirsSync path.join(buildPath, 'spa/css'), 0755

# dispatcher for file watching which determines which action needs to be done
# according to the file that was changed/created/removed
exports.dispatch = (file) ->
  for compiler in compilers
    if compiler.matchesFile(file)
      compiler.fileChanged(file)
      break

(function() {
  var colors, compilers, expressProcess, fileUtil, fs, helpers, labBuilder, nib, path, rimraf, root, spawn, stitch, stylus, yaml, _;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  root = __dirname + "/../";
  path = require('path');
  spawn = require('child_process').spawn;
  helpers = require('./helpers');
  fileUtil = require('file');
  colors = require('../vendor/termcolors').colors;
  stitch = require('stitch');
  labBuilder = require('labBuilder');
  fs = require('fs');
  rimraf = require("rimraf");
  yaml = require('yaml');
  _ = require('underscore');
  stylus = require('stylus');
  try {
    nib = require('nib')();
  } catch (error) {
    false;
  }
  exports.trimString = function(str) {
    return str.replace(/\s/g, "");
  };
  exports.VERSION = require('./package').version;
  expressProcess = {};
  compilers = [];
  exports.buildConfig = {
    clientBuildPath: 'build/client',
    clientSrcPath: 'src/client',
    serverBuildPath: 'build/server',
    serverSrcPath: 'src/server',
    clientResourcesPath: 'resources/client',
    vendorStylePath: 'vendor/style',
    indexStyleFile: 'src/client/style/main.styl',
    labJsUrl: 'js/LAB.min.js',
    labBuilderOutputFile: 'js/labBuilder.js',
    dependencies: [],
    projectBuildConfigFileName: 'config/client/buildConfig.json',
    mainStylusPath: 'src/client/styles/main.styl'
  };
  exports["new"] = function(options, callback) {
    var projectTemplatePath;
    exports.options = options;
    projectTemplatePath = path.join(module.id, "/../../template", exports.options.projectTemplate);
    return path.exists(exports.options.brunchPath, function(exists) {
      if (exists) {
        helpers.log(colors.lred("brunch:   directory already exists - can't create a project in there\n", true));
        process.exit(0);
      }
      fileUtil.mkdirsSync(exports.options.brunchPath, 0755);
      fileUtil.mkdirsSync(exports.options.buildPath, 0755);
      return helpers.recursiveCopy(projectTemplatePath, exports.options.brunchPath, function() {
        return helpers.recursiveCopy(path.join(projectTemplatePath, 'build/'), exports.options.buildPath, function() {
          callback();
          return helpers.log("brunch:   " + (colors.green('created', true)) + " brunch directory layout\n");
        });
      });
    });
  };
  exports.watch = function(options) {
    exports.options = options;
    exports.createBuildDirectories(exports.options.buildPath);
    exports.initializeCompilers();
    path.exists(path.join(exports.options.brunchPath, 'server/main.js'), function(exists) {
      if (exists) {
        helpers.log("express:  application started on port " + (colors.blue(exports.options.expressPort, true)) + ": http://0.0.0.0:" + exports.options.expressPort + "\n");
        expressProcess = spawn('node', [path.join(exports.options.brunchPath, 'server/main.js'), exports.options.expressPort, exports.options.brunchPath]);
        return expressProcess.stderr.on('data', function(data) {
          return helpers.log(colors.lred('express err: ' + data));
        });
      }
    });
    path.exists(path.join(exports.options.brunchPath, 'build/fake_server/main.js'), function(exists) {
      if (exists) {
        helpers.log("express fake server:  application started on port " + (colors.blue(exports.options.expressPort, true)) + ": http://0.0.0.0:" + exports.options.expressPort + "\n");
        expressProcess = spawn('node', [path.join(exports.options.buildPath, 'fake_server/main.js'), exports.options.expressPort, path.join(exports.options.brunchPath, 'build/spa')]);
        expressProcess.stderr.on('data', function(data) {
          return helpers.log(colors.lred('express err: ' + data));
        });
        return expressProcess.stdout.on('data', function(data) {
          return helpers.log(colors.blue('test_server:' + data));
        });
      }
    });
    return helpers.watchDirectory({
      path: path.join(exports.options.brunchPath, 'src'),
      callOnAdd: true
    }, function(file) {
      return exports.dispatch(file);
    });
  };
  exports.build = function(options) {
    var compiler, _i, _len, _results;
    exports.createBuildDirectories(exports.options.buildPath);
    exports.initializeCompilers();
    _results = [];
    for (_i = 0, _len = compilers.length; _i < _len; _i++) {
      compiler = compilers[_i];
      _results.push(compiler.compile(['.']));
    }
    return _results;
  };
  exports.stopServer = function(options) {
    if (expressProcess !== {}) {
      return expressProcess.kill('SIGHUP');
    }
  };
  exports.startServer = function(options) {
    var clientBuildPath, serverBuildPath;
    serverBuildPath = exports.buildConfig.serverBuildPath;
    clientBuildPath = exports.buildConfig.clientBuildPath;
    expressProcess = spawn('node', [path.join(serverBuildPath, 'main.js'), 8080, clientBuildPath]);
    expressProcess.stderr.on('data', function(data) {
      return helpers.log(colors.lred('express err: ' + data));
    });
    return expressProcess.stdout.on('data', function(data) {
      return helpers.log(colors.blue('server:' + data));
    });
  };
  exports.buildServer = function(options) {
    var executeCoffee, serverBuildPath, serverSrcPath;
    serverBuildPath = exports.buildConfig.serverBuildPath;
    serverSrcPath = exports.buildConfig.serverSrcPath;
    fileUtil.mkdirsSync(serverBuildPath, 0755);
    executeCoffee = spawn('coffee', ['-o', serverBuildPath, '-c', serverSrcPath]);
    executeCoffee.stdout.on('data', function(data) {
      return helpers.log('coffee: ' + data);
    });
    return executeCoffee.stderr.on('data', function(data) {
      return helpers.log(colors.lred('coffee err: ' + data));
    });
  };
  exports.cleanClient = function(options) {
    var clientBuildPath;
    clientBuildPath = exports.buildConfig.clientBuildPath;
    return path.exists(clientBuildPath, function(exists) {
      if (exists) {
        return rimraf(clientBuildPath, function(err) {
          if (err) {
            throw err;
          }
          return console.log("" + clientBuildPath + " deleted");
        });
      } else {
        return console.log("" + clientBuildPath + " already deleted");
      }
    });
  };
  exports.buildClient = function(options) {
    var clientBuildPath, clientResourcesPath, clientSrcPath, dependencies, executeStylus, file, indexStyleFile, labBuilderOutputFile, labJs, package, projectBuildConfig, projectBuildConfigFile, resourceDirContents, script, scripts, stylusMainFilePath, transferResources, vendorStylePath, _i, _j, _len, _len2;
    projectBuildConfigFile = fs.readFileSync('config/client/buildConfig.json', 'utf8');
    projectBuildConfig = JSON.parse(exports.trimString(projectBuildConfigFile));
    exports.buildConfig = _.extend(exports.buildConfig, projectBuildConfig);
    console.log("Build Config:" + exports.buildConfig.dependencies);
    clientBuildPath = exports.buildConfig.clientBuildPath;
    clientSrcPath = exports.buildConfig.clientSrcPath;
    fileUtil.mkdirsSync(path.join(clientBuildPath, 'js'), 0755);
    fileUtil.mkdirsSync(path.join(clientBuildPath, 'css'), 0755);
    clientResourcesPath = exports.buildConfig.clientResourcesPath;
    resourceDirContents = fs.readdirSync(clientResourcesPath);
    console.log("Resources to transfer: " + resourceDirContents);
    for (_i = 0, _len = resourceDirContents.length; _i < _len; _i++) {
      file = resourceDirContents[_i];
      transferResources = spawn('cp', ['-r', path.join(clientResourcesPath, file), clientBuildPath]);
      transferResources.stdout.on('data', function(data) {
        return console.log('transferring resources: ' + data);
      });
      transferResources.stderr.on('data', function(data) {
        return console.log(colors.lred('transferring resources err: ' + data));
      });
    }
    package = stitch.createPackage({
      paths: [clientSrcPath]
    });
    package.compile(function(err, source) {
      if (err != null) {
        helpers.log("brunch:   " + (colors.lred('There was a problem during compilation.', true)) + "\n");
        return helpers.log("" + (colors.lgray(err, true)) + "\n");
      } else {
        source = source + "\nrequire('main');";
        return fs.writeFile(path.join(clientBuildPath, 'js/client.js'), source, function(err) {
          if (err != null) {
            helpers.log("brunch:   " + (colors.lred('Couldn\'t write compiled file.', true)) + "\n");
            return helpers.log("" + (colors.lgray(err, true)) + "\n");
          } else {
            return helpers.log("stitch:   " + (colors.green('compiled', true)) + " application\n");
          }
        });
      }
    });
    vendorStylePath = exports.buildConfig.vendorStylePath;
    indexStyleFile = exports.buildConfig.indexStyleFile;
    executeStylus = spawn('stylus', ['-o', path.join(clientBuildPath, 'css'), '-I', vendorStylePath, indexStyleFile]);
    dependencies = exports.buildConfig.dependencies;
    scripts = dependencies.slice();
    scripts = scripts.concat([
      {
        name: 'clientapp',
        src: 'js/client.js'
      }
    ]);
    for (_j = 0, _len2 = scripts.length; _j < _len2; _j++) {
      script = scripts[_j];
      console.log("name: " + script.name + ", src: " + script.src);
    }
    labJs = exports.buildConfig.labJsUrl;
    labBuilderOutputFile = exports.buildConfig.labBuilderOutputFile;
    labBuilder.build(labJs, scripts, path.join(clientBuildPath, labBuilderOutputFile));
    stylusMainFilePath = exports.buildConfig.mainStylusPath;
    return fs.readFile(stylusMainFilePath, 'utf8', __bind(function(err, data) {
      var compiler;
      if (err != null) {
        return helpers.log(colors.lred('stylus err: ' + err));
      } else {
        compiler = stylus(data).set('filename', stylusMainFilePath).set('compress', true);
        if (nib) {
          compiler.use(nib);
        }
        return compiler.render(__bind(function(err, css) {
          if (err != null) {
            return helpers.log(colors.lred('stylus err: ' + err));
          } else {
            return fs.writeFile(path.join(clientBuildPath, 'css/main.css'), css, 'utf8', __bind(function(err) {
              if (err != null) {
                return helpers.log(colors.lred('stylus err: ' + err));
              } else {
                return helpers.log("stylus:   " + (colors.green('compiled', true)) + " main.css\n");
              }
            }, this));
          }
        }, this));
      }
    }, this));
  };
  exports.initializeCompilers = function() {
    var compiler, name;
    return compilers = (function() {
      var _ref, _results;
      _ref = require('./compilers');
      _results = [];
      for (name in _ref) {
        compiler = _ref[name];
        _results.push(new compiler(exports.options));
      }
      return _results;
    })();
  };
  exports.stop = function() {
    if (expressProcess !== {}) {
      return expressProcess.kill('SIGHUP');
    }
  };
  exports.createBuildDirectories = function(buildPath) {
    fileUtil.mkdirsSync(path.join(buildPath, 'spa/js'), 0755);
    return fileUtil.mkdirsSync(path.join(buildPath, 'spa/css'), 0755);
  };
  exports.dispatch = function(file) {
    var compiler, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = compilers.length; _i < _len; _i++) {
      compiler = compilers[_i];
      if (compiler.matchesFile(file)) {
        compiler.fileChanged(file);
        break;
      }
    }
    return _results;
  };
}).call(this);

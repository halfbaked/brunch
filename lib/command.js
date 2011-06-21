(function() {
  var NOMNOM_CONFIG, NOMNOM_CONFIG_OLD, argParser, brunch, buildClient, buildServer, colors, fs, helpers, nomnom, options, parseOptions, path, usage, version, yaml, _;
  nomnom = require('nomnom');
  path = require('path');
  brunch = require('./brunch');
  helpers = require('./helpers');
  colors = require('../vendor/termcolors').colors;
  yaml = require('yaml');
  fs = require('fs');
  _ = require('underscore');
  NOMNOM_CONFIG_OLD = [
    {
      name: 'expressPort',
      string: '-ep <port>, --expressPort=<port>',
      help: 'set the express server port'
    }, {
      name: 'projectTemplate',
      string: '-p <template>, --projectTemplate=<template>',
      help: 'set which kind of project template should be used'
    }, {
      name: 'version',
      string: '-v, --version',
      help: 'display brunch version'
    }, {
      name: 'help',
      string: '-h, --help',
      help: 'display brunch help'
    }, {
      name: 'output',
      string: '-o, --output',
      help: 'set build path'
    }, {
      name: 'minify',
      string: '-m, --minify',
      help: 'minify the app.js output via UglifyJS'
    }
  ];
  NOMNOM_CONFIG = {
    version: {
      string: '-v, --version',
      help: 'Returns labBuilder version',
      callback: function() {
        return "version 0.1";
      }
    }
  };
  options = {};
  argParser = {};
  buildClient = function(options) {
    console.log('Building the client');
    return brunch.buildClient();
  };
  buildServer = function(options) {
    return console.log('Building the server');
  };
  exports.run = function() {
    var opts;
    exports.buildConfig = {
      clientBuildPath: 'build/client',
      clientSrcPath: 'src/client'
    };
    nomnom.command('create-app').opts({
      app: {
        position: 1,
        help: 'Name of app you wish to create'
      }
    }).help('Create a new app').callback(function(options) {
      return console.log('Creating new app');
    });
    nomnom.command('build-server').help('Build the server').callback(function(options) {
      return brunch.buildServer();
    });
    nomnom.command('build-client').help('Build the client').callback(function(options) {
      return buildClient(options);
    });
    nomnom.command('watch-server').help('Watch for changes on the server and rebuild').callback(function(options) {
      return console.log('Watching for changes on server');
    });
    nomnom.command('watch-client').help('Watch for changes on client, and rebuild').callback(function(options) {
      return console.log('Watching for changes on client');
    });
    nomnom.command('build').help('Build client and server').callback(function(options) {
      buildClient(options);
      return buildServer(options);
    });
    nomnom.command('watch').help('Watch for changes on client or server and rebuild').callback(function(options) {
      return console.log('Watching for changes on client or server and rebuilding');
    });
    nomnom.command('clean-client').help('Deletes client build directory').callback(function(options) {
      return brunch.cleanClient(options);
    });
    nomnom.command('clean-server').help('Deletes server build directory').callback(function(options) {
      return console.log('Cleaning server build directory');
    });
    nomnom.command('start-server').help('Starts Express server').callback(function(options) {
      return brunch.startServer();
    });
    return opts = nomnom.opts(NOMNOM_CONFIG).parseArgs();
  };
  exports.loadDefaultArguments = function() {
    options = {
      templateExtension: 'eco',
      projectTemplate: 'base',
      expressPort: '8080',
      brunchPath: 'brunch',
      dependencies: [],
      minify: false
    };
    return options;
  };
  exports.loadConfigFile = function(configPath) {
    try {
      options = yaml.eval(fs.readFileSync(configPath, 'utf8'));
      return options;
    } catch (e) {
      helpers.log(colors.lred("brunch:   Couldn't find config.yaml file\n", true));
      return process.exit(0);
    }
  };
  exports.loadOptionsFromArguments = function(opts, options) {
    if (opts.templateExtension != null) {
      options.templateExtension = opts.templateExtension;
    }
    if (opts.projectTemplate != null) {
      options.projectTemplate = opts.projectTemplate;
    }
    if (opts.expressPort != null) {
      options.expressPort = opts.expressPort;
    }
    if (opts[1] != null) {
      options.brunchPath = opts[1];
    }
    if (opts.minify != null) {
      options.minify = opts.minify;
    }
    if (opts.buildPath != null) {
      options.buildPath = opts.buildPath;
    } else if (options.buildPath == null) {
      options.buildPath = path.join(options.brunchPath, 'build');
    }
    return options;
  };
  parseOptions = function() {
    return nomnom.parseArgs(NOMNOM_CONFIG, {
      printHelp: false
    });
  };
  usage = function() {
    process.stdout.write(BANNER);
    process.stdout.write(helpers.optionsInfo(NOMNOM_CONFIG));
    return process.exit(0);
  };
  version = function() {
    process.stdout.write("brunch version " + brunch.VERSION + "\n");
    return process.exit(0);
  };
}).call(this);

path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  signUsingWindowsSDK = (exeToSign, callback) ->
    {WIN_P12_PASS} = process.env
    keyFile = path.resolve(__dirname, '..', 'certs', 'AtomDevTestSign.p12')
    args = ['sign', '/v', '/p', WIN_P12_PASS ? 'password', '/f', keyFile, exeToSign]
    spawn {cmd: 'C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.1A\\bin\\signtool.exe', args: args}, callback

  signUsingJanky = (exeToSign, callback) ->
    spawn {cmd: 'signtool', args: [exeToSign]}, callback

  signWindowsExecutable = if process.env.JANKY_SIGNTOOL then signUsingJanky else signUsingWindowsSDK

  grunt.registerTask 'codesign:exe', 'CodeSign Atom.exe and Update.exe', ->
    done = @async()
    spawn {cmd: 'taskkill', args: ['/F', '/IM', 'atom.exe']}, ->
      atomExePath = path.join(grunt.config.get('atom.shellAppDir'), 'atom.exe')
      signWindowsExecutable atomExePath, (error) ->
        return done(error) if error?

        updateExePath = path.resolve(__dirname, '..', 'node_modules', 'grunt-electron-installer', 'vendor', 'Update.exe')
        signWindowsExecutable updateExePath, (error) -> done(error)

  grunt.registerTask 'codesign:installer', 'CodeSign AtomSetup.exe', ->
    done = @async()
    atomSetupExePath = path.resolve(grunt.config.get('atom.buildDir'), 'installer', 'AtomSetup.exe')
    signWindowsExecutable atomSetupExePath, (error) -> done(error)

  grunt.registerTask 'codesign:app', 'CodeSign Atom.app', ->
    done = @async()

    unlockKeychain (error) ->
      return done(error) if error?

      args = ['--deep', '--force', '--verbose', '--sign', 'Developer ID Application: GitHub', grunt.config.get('atom.shellAppDir')]
      spawn {cmd: 'codesign', args: args}, (error) -> done(error)

  unlockKeychain = (callback) ->
    return callback() unless process.env.XCODE_KEYCHAIN

    {XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN} = process.env
    args = ['unlock-keychain', '-p', XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN]
    spawn {cmd: 'security', args: args}, (error) -> callback(error)

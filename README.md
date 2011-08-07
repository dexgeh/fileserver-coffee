A simple file server written in coffee-script.

Sample usage:

    http = require 'http'
    fileserver = require './fileserver'
    config = fileserver.defaultConfig()
    server = http.createServer (fileserver.getFileServer config)
    server.listen 8080

Enable directory listing:

    config.directoryListing = true

Custom error handling:

    config.errorHandler = (req, res, code, err) ->
        res.writeHead code
        res.end "Error #{code}!!!"

Customize the Server response header:

    config.headers.Server = "'; DROP TABLE SERVER --"

Configure caching:

    # default configuration
    config.cache.enabled = true
    config.cache.fileSizeLimit = 4096
    config.cache.timeLimit = 1000 * 60 * 5

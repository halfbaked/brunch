util = require('util')
path = require('path')
fs = require('fs')
port = process.argv[2]
express = require("express")
app = express.createServer()
#require('./controllers/customer').register(app)
util.log("starting server on port " + port)

spaPath = path.join(process.argv[3])

app.configure( ->
  app.set('views', spaPath)
  app.use(express.static(spaPath))   
  fs.readdir("#{__dirname}/api", (err, files) ->
    throw err if (err)
    files.forEach (file) ->
      require('./api/'+file).register(app)  
  )    
)
util.log "app configured"

app.get('/', (req, res) ->
  res.render('index')
)

util.log("starting server on port " + port)
app.listen(parseInt(port, 10))

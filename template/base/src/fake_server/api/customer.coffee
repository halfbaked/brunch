exports.register = (app) ->
 
  app.get('/api/customer/:id', (req, res) ->
    res.send({id:req.params.id})
  )



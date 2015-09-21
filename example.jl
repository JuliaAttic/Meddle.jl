include("src/Meddle.jl")

import Meddle: @middleware
               LogRequest,
               handler,
               serve,
               with,
               on


# Declare your middleware
@middleware function HelloWorld(req, res)
  println(res)
  write!(res, "<h1>Hello, World!</h1>")  # Write to the response object
  next(req, res)  # Pass along to the next middleware
end

@middleware function JustForKicks(req, res)
  println("This is just for kicks")  # Print this to the console just for kicks
  return next(req, res)  # Pass along the the next middleware
end

# Now start serving the webpage
serve(on(8000),
      with([JustForKicks,
            LogRequest,
            HelloWorld,
            ]))

# or you can use any server implementation that takes
# a function with the signature f(req, res) -> res
using HttpServer
s = Server(with([JustForKicks, LogRequest, HelloWorld]))
run(s, 8000)

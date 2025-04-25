import redis
from redis.exceptions import ConnectionError
import tornado.ioloop
import tornado.web

import os
from sys import exit


try:

    redis_host = os.getenv("REDIS_HOST", "localhost")
    r = redis.Redis(
        host=redis_host,
        port=6379,
        db=0
    )
    r.set("counter", 0)
except ConnectionError:
    print("Redis server isn't running. Exiting...")
    exit()


environment = os.getenv("ENVIRONMENT", "****")  # default to DEV if not passed
port = 8000


class MainHandler(tornado.web.RequestHandler): 
    def get(self):
        self.render(
            "index.html",
             dict={"environment": environment,  "counter":r.incr("counter", 1)},
        )


class Application(tornado.web.Application):
    def __init__(self):
        handlers = [(r"/", MainHandler)]
        settings = {
            "template_path": os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "templates"
            ),
            "static_path": os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "static"
            ),
        }
        tornado.web.Application.__init__(self, handlers, **settings)


if __name__ == "__main__":
    app = Application()
    app.listen(port)
    print("App running: http://localhost:8000")
    tornado.ioloop.IOLoop.current().start()

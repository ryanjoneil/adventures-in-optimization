from StringIO import StringIO
from multiprocessing import Process, Queue
import sys

# Proxy classes that both write to and capture strings
# sent to stdout or stderr, respectively.
class TeeOut(StringIO):
    def write(self, s):
        StringIO.write(self, s)
        sys.__stdout__.write(s)

class TeeErr(StringIO):
    def write(self, s):
        StringIO.write(self, s)
        sys.__stderr__.write(s)

class Parent(object):
    def run(self):
        # Start child process.
        queue = Queue()
        child = Process(target=self.spawn, args=(queue,))
        child.start()
        child.join()

        # Do someting with out and err...
        out = queue.get()
        err = queue.get()

    def spawn(self, queue):
        # Save everything that would otherwise go to stdout.
        out = TeeOut()
        sys.stdout = out

        err = TeeErr()
        sys.stderr = err

        try:
            # Do something...
            print 'out 1'
            print 'out 2'
            sys.stderr.write('error 1\n')
            print 'out 3'
            sys.stderr.write('error 2\n')

        finally:
            # Restore stdout, stderr and send their contents.
            sys.stdout = sys.__stdout__
            sys.stderr = sys.__stderr__
            queue.put(out.getvalue())
            queue.put(err.getvalue())

if __name__ == '__main__':
    Parent().run()

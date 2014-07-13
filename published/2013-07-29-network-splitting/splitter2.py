#!/usr/bin/env python
import json
import sys
import time

class hset(set):
    '''A hashable set. Note that it only hashes by the pointer, and not by the elements.'''
    def __hash__(self):
        return hash(id(self))

    def __cmp__(self, other):
        return cmp(id(self), id(other))

if __name__ == '__main__':
    try:
        inputfile = sys.argv[1]
    except:
        print 'usage: %s network.json' % sys.argv[0]
        sys.exit()

    print time.asctime(), 'parsing json input'
    connections = json.load(open(inputfile))

    edge_to_net = {} # Edge ID -> set([edges that are in the same network])
    nets = set()     # Set of known networks

    print time.asctime(), 'detecting disconnected subgraphs'
    for i, (from_edge, to_set) in enumerate(connections.iteritems()):
        from_edge = int(from_edge)

        try:
            from_net = edge_to_net[from_edge]
        except KeyError:
            from_net = edge_to_net[from_edge] = hset([from_edge])
            nets.add(from_net)

        if not (i+1) % (25 * 1000):
            print time.asctime(), '%d edges processed / %d current subnets' % (i+1, len(nets))
        
        for to in to_set:
            try:
                to_net = edge_to_net[to]

                # If we get here, merge the to_net into the from_net.
                if to_net is not from_net:
                    # Update references to and remove the smaller set for speed.
                    if len(to_net) < len(from_net):
                        smaller, larger = to_net, from_net
                    else:
                        smaller, larger = from_net, to_net

                    larger.update(smaller)
                    for e in smaller:
                        edge_to_net[e] = larger
                    nets.remove(smaller)
                    edge_to_net[to] = larger
                    from_net = larger

            except KeyError:
                from_net.add(to)
                edge_to_net[to] = from_net

    print time.asctime(), len(nets), 'subnets found'
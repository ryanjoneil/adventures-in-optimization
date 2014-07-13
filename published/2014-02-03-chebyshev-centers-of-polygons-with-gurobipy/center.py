#!/usr/bin/env python
from gurobipy import Model, GRB
from math import sqrt

vertices = [(1,1), (2,5), (5,4), (6,2), (4,1)]
edges = zip(vertices, vertices[1:] + [vertices[0]])

m = Model()
r = m.addVar()
x = m.addVar(lb=-GRB.INFINITY)
y = m.addVar(lb=-GRB.INFINITY)
m.update()

for (x1, y1), (x2, y2) in edges:
    dx = x2 - x1
    dy = y2 - y1
    m.addConstr((dx*y - dy*x) + (r * sqrt(dx**2 + dy**2)) <= dx*y1 - dy*x1)

m.setObjective(r, GRB.MAXIMIZE)
m.optimize()

print 'r = %.04f' % r.x
print '(x, y) = (%.04f, %.04f)' % (x.x, y.x)

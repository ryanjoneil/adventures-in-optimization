import random
 
PASSENGERS = 100.0
TRAINS     =   5.0
ITERATIONS = 10000
 
def sim():
    passengers = 0.0
 
    # Determine when the train arrives
    train = random.expovariate(TRAINS)
 
    # Count the number of passenger arrivals before the train
    now = 0.0
    while True:
        now += random.expovariate(PASSENGERS)
        if now >= train:
            break
        passengers += 1.0
 
    return passengers
 
if __name__ == '__main__':        
    output = [sim() for _ in xrange(ITERATIONS)]
 
    total = sum(output)
    mean = total / len(output)
 
    sum_sqrs = sum(x*x for x in output)
    variance = (sum_sqrs - total * mean) / (len(output) - 1)
 
    print 'E[X] = %.02f' % mean
    print 'Var(X) = %.02f' % variance

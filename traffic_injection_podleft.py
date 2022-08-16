import os
import random
import time
import csv
import logging

from concurrent.futures import ThreadPoolExecutor
logging.basicConfig(level=logging.DEBUG, format='%(threadName)s: %(message)s')


def traffic_inj(flow):

    r_pod = 2*int(random.uniform(1,3)) #pods pares 2,4
    r_host = int(random.uniform(1,3)) # host 1,2,3,4

    if r_pod == 2: # pod 2 tiene host 2,3,4,5
        r_host += 1
    else:
        pass

    #r_pod = 2
    #r_host = 2

    os.system('iperf -c 10.0.' + str(r_pod) + '.' + str(r_host) + ' -n ' + str(flow))
    logging.info('Finished Flow {} tx \n'.format(flow))

def main():

    # ***** SACO LA MATRIZ ********
    flow_size = []

    with open('traffic_mtrx.csv', 'r') as file:
        reader = csv.reader(file)
        first_elem= False
        for row in reader:

            if first_elem == False:
                first_elem = True
                continue
            else:
                flow_size.append(int(row[0]))

    # ******** Reordeno la matriz y meto mas elementos de la misma CDF (1000) *********

    flow_mtrx = []

    for element in range(0,40000):
        flow_mtrx.append( flow_size[ int( random.uniform(0,len(flow_size)) ) ] ) # por conexion asignara un flujo arbitrario de la matriz

    # ********* Conexiones paralelas hasta acabar la matriz modificada *******

    LOAD = 90 # PARAMERTRO MUY IMPORTANTE, CAMBIARLO CON CADA PRUEBA DE LOAD % distinta
    connections = LOAD /10 #  numero de sesiones por host

    #print(flow_mtrx)
    executor = ThreadPoolExecutor(max_workers = connections)
    executor.map(traffic_inj, (flow for flow in flow_mtrx))
    # traffic_inj(flow_size)


if __name__ == '__main__':
    main()

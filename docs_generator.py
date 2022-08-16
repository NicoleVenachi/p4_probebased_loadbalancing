import os
import random
import time
import csv

def main():

    header = ['load (%)', 'Total time (ms)', 'Average delay (ms)', 'Average throughput (Kbits/s)', 'packet loss (%)', 'Average FCT (ms)', 'algorithm']

    loads = range(10,100,10)
    algorithms = ['ECMP', 'links_state', 'links-devices_state']

    for algorithm in algorithms:
        for load in loads:

            document = './test_results/telemetry' + '_' + algorithm + '_' + str(load) + '.csv'
            document_bu = './test_results/telemetry_bu' + '_' + algorithm + '_' + str(load) + '.csv'

            with open(document, 'w') as f:
                writer = csv.writer(f)

                writer.writerow(header)
            with open(document_bu, 'w') as f:
                writer = csv.writer(f)

                writer.writerow(header)




if __name__ == '__main__':
    '''
    Script para crear todos los documentos
    '''
    main()

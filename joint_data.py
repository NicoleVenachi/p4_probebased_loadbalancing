import os
import random
import time
import csv

def main():

    header = ['load (%)', 'Total time (ms)', 'Average delay (ms)', 'Average throughput (Kbits/s)', 'packet loss (%)', 'Average FCT (ms)', 'algorithm']

    loads = range(10,100,10)
    algorithms = ['ECMP', 'links_state', 'links-devices_state']

    data = []

    for algorithm in algorithms:
        for load in loads:



            # abro archivo y saco datos
            readed_document = './test_results//mean_results/telemetry' + '_' + algorithm + '_' + str(load) + '.csv'

            with open(readed_document, 'r') as f:
                reader = csv.reader(f)
                line_number = 1
                for row in reader:
                    if line_number == 1:
                        pass
                    else:
                        #print(row)
                        data.append(row)
                    line_number += 1


    summary_document = './test_results//mean_results/telemetry_summary.csv'

    with open(summary_document, 'w') as f:
        writer = csv.writer(f)

        writer.writerow(header)

        writer.writerows(data)



if __name__ == '__main__':
    '''
    Archivo para sacar los datos de todos los .csv y crear un csv
    global con para graficar resultados
    '''
    main()

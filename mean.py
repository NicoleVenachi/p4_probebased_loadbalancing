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

            data = []
            data_mean = []

            # abro archivo y saco datos
            readed_document = './test_results/telemetry' + '_' + algorithm + '_' + str(load) + '.csv'

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

            # saco la media de cada dato


            total_time = 0
            delay = 0
            bw = 0
            p_loss = 0
            fct = 0

            total_time_count = 0
            delay_count = 0
            bw_count = 0
            p_loss_count = 0
            fct_count = 0



            for per_data in data:

                if per_data[1] == 'None':
                    pass
                else:
                    total_time += float(per_data[1])
                    total_time_count += 1


                if per_data[2] == 'None':
                    pass
                else:
                    delay += float(per_data[2])
                    delay_count += 1


                if per_data[3] == 'None':
                    pass
                else:
                    bw += float(per_data[3])
                    bw_count += 1


                if per_data[4] == 'None':
                    pass
                else:
                    p_loss += float(per_data[4])
                    p_loss_count += 1


                if per_data[5] == 'None':
                    pass
                else:
                    fct += float(per_data[5])
                    fct_count += 1

            if len(data) == 0: # texto de primera line
                pass
            else:
                total_time /= total_time_count
                delay /= delay_count
                bw /= bw_count
                p_loss /= p_loss_count
                fct /= fct_count

            data_mean.append([str(load), str(total_time), str(delay), str(bw), str(p_loss), str(fct), algorithm ])

            # Creo archivo con la media para cada load y algorithm

            mean_document = './test_results//mean_results/telemetry' + '_' + algorithm + '_' + str(load) + '.csv'

            with open(mean_document, 'w') as f:
                writer = csv.writer(f)

                writer.writerow(header)

                writer.writerows(data_mean)



if __name__ == '__main__':
    '''
    Archivo para sacar la media de todas las semillas para cada load
    y cada algoritmo
    '''
    main()

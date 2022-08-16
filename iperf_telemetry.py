import os
import random
import time
import csv

def telemetry():

    with open('out.txt', 'r') as file:
        reader = csv.reader(file)
        first_elem= False
        current_line = 1
        for row in reader:
            if current_line < 8:
                current_line += 1
                continue
            else:
                for line in row:
                    #filtro los que tienen la telemetria de cada flujo
                    if line.endswith(')'):
                        #parto al encontrar _sec, y tomo el segundo item
                        line_elements = line.split(' sec')[1].split()
                        #este item es la info util, le saco las metricas
                        escala = line_elements[3][0] #primera letra de Bw

                        if escala == 'M':
                            bandwidth = float(line_elements[2]) * 1000000
                        elif escala == 'K':
                            bandwidth = float(line_elements[2]) *1000
                        else:
                            bandwidth = float(line_elements[2])

                        jitter = float(line_elements[4])
                        p_loss = float( line_elements[-1].replace('(','').replace('%','').replace(')','') )

                    else:
                        continue

    return (bandwidth, jitter, p_loss)

def traffic_inj():

    print('aa')

    start_t = 0
    end_t = 0
    elapsed_t = 0

    start_t = time.time()
    os.system('iperf -c 10.0.2.2 -u -n 642k')
    end_t = time.time()

    elapsed_t = end_t - start_t

    return elapsed_t #devuelve delay de la com

def particular_test():

    header = ['load (%)', 'delay (seg)', 'bw (bits/seg)', 'jitter (ms)', 'p_loss (%)', 'algorithm']
    data = []

    delay = traffic_inj()

    telemetry_info = telemetry()

    load = 10
    algorithm = 'ECMP'
    #algorithm = 'links_state'
    #algorithm = 'links-devices_state'

    document = './test_results/telemetry' + '_' + algorithm + '_' + str(load) + '.csv'

    with open(document, 'r') as f:
        reader = csv.reader(f)
        line_number = 1
        for row in reader:
            if line_number == 1:
                pass
            else:
                #print(row)
                data.append(row)
            line_number += 1

    if len(data) == 0:
        traffic_comp = (0,0,0)
    else:
        data_last_read = data[-1]
        data_last_read = data_last_read[slice(2,5)]
        traffic_comp = (float(data_last_read[0]), float(data_last_read[1]), float(data_last_read[2]) )

    data.append([str(load),str(delay), str(telemetry_info[0]), str(telemetry_info[1]), str(telemetry_info[2]), algorithm ])

    if traffic_comp == telemetry_info:
        pass
    else:
        with open(document, 'w') as f:
            writer = csv.writer(f)

            writer.writerow(header)

            writer.writerows(data)

def main():

    for test in range(0,24): # 24 seeds
        time.sleep(random.uniform(0,7))
        particular_test()

if __name__ == '__main__':
    main()

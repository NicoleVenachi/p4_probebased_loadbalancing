import os
import random
import time
import csv
from math import log

def telemetry():

    os.system('/home/p4/D-ITG-2.8.1-r1023/bin/ITGDec receiver.log >out.txt')
    with open('out.txt', 'r') as file:
        reader = csv.reader(file)
        first_elem= False
        current_line = 1
        for row in reader:
            if current_line < 25:
                current_line += 1
                continue
            elif current_line == 26:
                current_line += 1
                for line in row:
                    total_time = float(line.split(' = ')[1].strip().split(' ')[0]) * 1000
            elif current_line == 30:
                current_line += 1
                for line in row:
                    delay = float(line.split(' = ')[1].strip().split(' ')[0]) * 1000
            elif current_line == 34:
                current_line += 1
                for line in row:
                    throughput = float(line.split(' = ')[1].strip().split(' ')[0])
            elif current_line == 36:
                current_line += 1
                for line in row:
                    p_loss = float(line.split(' (')[1].strip().split(' ')[0])
            else:
                current_line += 1
                continue

    return (total_time, delay, throughput, p_loss)

def traffic_inj():

    os.system('/home/p4/D-ITG-2.8.1-r1023/bin/ITGSend -T UDP -a 10.0.2.2 -k 63 -x receiver.log')

def fct_calculation():

    packet_size = 64512
    capacity = 2500000

    os.system('ping 10.0.2.2 -c 1 -s ' + str(packet_size) + ' > fct.txt')
    try:
        with open('fct.txt', 'r') as file:
            reader = csv.reader(file)
            current_line = 1
            for row in reader:
                if current_line < 6:
                    current_line += 1
                    continue
                else:
                    current_line += 1
                    for line in row:
                        rtt = float(line.split(' = ')[1].split('/')[1])
                        rtt /= 1000
        print(rtt)

        fct = (log(packet_size,2)+(1/2)) * (rtt + (packet_size/capacity))
    except:

        fct = None
        print(fct)



    return fct

def particular_test():

    header = ['load (%)', 'Total time (ms)', 'Average delay (ms)', 'Average throughput (Kbits/s)', 'packet loss (%)', 'Average FCT (ms)', 'algorithm']
    data = []

    delay = traffic_inj()

    telemetry_info = telemetry()

    fct = fct_calculation()

    print(telemetry_info)

    load = 90
    #algorithm = 'ECMP'
    #algorithm = 'links_state'
    algorithm = 'links-devices_state'

    document = './test_results/telemetry' + '_' + algorithm + '_' + str(load) + '.csv'
    document_bu = './test_results/telemetry_bu' + '_' + algorithm + '_' + str(load) + '.csv'

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
        traffic_comp = (0,0,0,0)
    else:
        data_last_read = data[-1]
        data_last_read = data_last_read[slice(1,5)]
        traffic_comp = (float(data_last_read[0]), float(data_last_read[1]), float(data_last_read[2]), float(data_last_read[3]) )

    data.append([str(load), str(telemetry_info[0]), str(telemetry_info[1]), str(telemetry_info[2]), str(telemetry_info[3]), str(fct), algorithm ])

    data_bu =[]
    with open(document_bu, 'r') as f:
        reader = csv.reader(f)
        line_number = 1
        for row in reader:
            if line_number == 1:
                pass
            else:
                #print(row)
                data_bu.append(row)
            line_number += 1
    data_bu.append([str(load), str(telemetry_info[0]), str(telemetry_info[1]), str(telemetry_info[2]), str(telemetry_info[3]), str(fct), algorithm ])


    if traffic_comp == telemetry_info:
        pass

    elif fct == None:
        with open(document, 'w') as f:
            writer = csv.writer(f)

            writer.writerow(header)

            writer.writerows(data)
    else:
        with open(document, 'w') as f:
            writer = csv.writer(f)

            writer.writerow(header)

            writer.writerows(data)

        with open(document_bu, 'w') as f:
            writer = csv.writer(f)

            writer.writerow(header)

            writer.writerows(data_bu)

def main():

    for test in range(0,42): # 32 seeds
        time.sleep(random.uniform(0,7))
        particular_test()

if __name__ == '__main__':
    main()

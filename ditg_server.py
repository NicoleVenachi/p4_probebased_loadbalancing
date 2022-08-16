import os
import random
import time
import csv

def main():

    header = ['delay', 'flow_id']
    data = []
    #a = os.popen('pwd', 'r', 1).read()
    #print(a)
    #flow_size = []
    os.system('kill -9 $(lsof -t -i:9000)')
    os.system('/home/p4/D-ITG-2.8.1-r1023/bin/ITGRecv')
    print('\n')
    print('communication has finished')
    #a = os.popen('iperf -s -u').read()
    #print('\n')
    #print(a)
"""
    with open('delay.csv', 'w') as f:
        writer = csv.writer(f)

        writer.writerow(header)

        writer.writerows(data)
"""

if __name__ == '__main__':
    main()

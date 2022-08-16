import os
import random
import time
import csv

def main():

    flows_length = 100
    escala = 10

    flows = range(0,flows_length)

    header = ['flow_size', 'flow_id']
    data = []

    for flow in flows:

        pr_flow = random.uniform(0,100)

        start_t = 0
        end_t = 0
        delay = 0

        if pr_flow < 10:
            pr_size = int(random.uniform(0,300))

        elif pr_flow < 20:
            pr_size = int(random.uniform(300,600))

        elif pr_flow < 30:
            pr_size = int(random.uniform(600,750))

        elif pr_flow < 40:
            pr_size = int(random.uniform(750,850))

        elif pr_flow < 50:
            pr_size = int(random.uniform(850,1000))

        elif pr_flow < 60:
            pr_size = int(random.uniform(1000,2000))

        elif pr_flow < 70:
            pr_size = int(random.uniform(2000, 3500))

        elif pr_flow < 80:
            pr_size = int(random.uniform(3500,8000))

        elif pr_flow < 90:
            pr_size = int(random.uniform(8000,50000))

        elif pr_flow < 95:
            pr_size = int(random.uniform(50000,1000000))

        else:
            pr_size = int(random.uniform(1000000,10000000))


        data.append([str(int(pr_size/escala)), str(flow + 1)])

    flow_mean = 0
    for flow in data:
        flow_mean += int(flow[0])

    flow_mean /= flows_length 

    print(flow_mean)


    with open('traffic_mtrx.csv', 'w') as f:
        writer = csv.writer(f)

        writer.writerow(header)

        writer.writerows(data)


if __name__ == '__main__':
    main()

import csv
import json
import sys
import pdb


class Csv2json:
    def __init__(self, args):
        # 1st step: read csv
        self.data_dict = self.read_csv(args[1])

    def read_csv(self, input_file_name):
        input_file = open(input_file_name, "r")
        reader = csv.DictReader(input_file)
        # skip first line
        # next(reader)

        for row in reader:
            row = dict((x, y.lower()) for x, y in row.items())
            pdb.set_trace()
            header = row
            # break

        header = [x.lower() for x in header]
        header = [x.replace(" ", "_") for x in header]
        print(header)

        return csv.DictReader(input_file, header)


if __name__ == "__main__":
    Csv2json(sys.argv)

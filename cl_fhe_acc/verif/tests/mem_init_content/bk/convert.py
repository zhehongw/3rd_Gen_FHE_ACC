#!/usr/bin/python3
# this is a script to convert 54 bit hex mem file into 54 * line_size bit hex mem file
# support line_size >= 2 

import sys

def main(argv):
    infile_name = argv[0]
    print(infile_name)
    index = infile_name.find('.mem')
    line_size = argv[1]
    outfile_name = "../" + infile_name[:index] + "_x" + line_size + infile_name[index:]

    infile = open(infile_name, 'r')
    outfile = open(outfile_name, 'w')
    x = infile_name.split("_")
    line_count = 1024 if x[2][0:2] == "1k" else 2048
    loop_count = line_count // int(line_size)
    for i in range(loop_count):
        #get the binary representation
        tmp_line = ""
        for j in range(int(line_size)):
            in_line = infile.readline()
            to_int = int(in_line.strip("\n"), 16)
            to_bit = bin(to_int)
            tmp_line = to_bit[2:].zfill(54) + tmp_line
            #print(to_bit[2:].zfill(54))
        #print(tmp_line)
        #get the hex representation
        out_line = ""
        for i in range(0, 54 * int(line_size), 4):
            char = hex(int(tmp_line[i : i + 4], 2)).upper()
            out_line = out_line + char[2:]
        #print(out_line)
        outfile.write(out_line + "\n")

    infile.close()
    outfile.close()

if __name__ == "__main__":
    main(sys.argv[1:])


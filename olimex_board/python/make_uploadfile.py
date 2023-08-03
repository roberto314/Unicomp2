#!/usr/bin/env python3
import sys, os, struct
import UC_fill_RAM as fr

ver = 1.2

# this file creates an .ucb file for the Unicom Project.
# It is a simple binary with a header of three bytes for position
# in the RAM and three bytes for length-1 of file, all in Big Endian.
# Example: File starts at 0x800, length is 2048 bytes
# 00 08 00 00 07 FF ..... Rest is binary data.
# This format is used with the python script UC_configure.py or UC_fill_RAM.py.
#
# Version History:
# v1.0: Initial Version
# v1.2: It is possible to add a comment at the end.

def read_file(fn):
	try:
		with open(fn, "rb") as f:
			img = f.read()
			img.strip()
			return img
	except Exception as e:
		print(f'File {fn} not found!')
		exit()

def read_file_text(fn):
	try:
		with open(fn, "r") as f:
			img = f.readlines()
			return img
	except Exception as e:
		print(f'File {fn} not found!')
		exit()

def write_file(data, fn):
	with open(fn, "wb") as f:
		#print(f'File open')
		f.write(bytes(data))
		f.close()
		print(f'File written to {fn}.')

def make_bytes(val):
	return val.to_bytes(3, 'big')

def convert_textfile(f):
	retval = bytearray()
	dataarray = bytearray()
	# Format is: 
	# Address:        Data
	#    004A: AA BB CC DD EE FF
	#    0050: 00 11 22 33 44 55 66 77
	#    0058: 88 99 AA BB CC DD EE FF
	#    .......
	#
	startaddress = 0
	first = 0
	address = 0
	for line in f:
		if ((len(line.strip()) != 0) and (':' in line)):
			a,dat = line.split(":") # get address and data part
			#print(f' Address: {a}, data: {dat}')
			if a == '':
				startaddress = address
			else:
				startaddress = int(a,16)

			dat = dat.strip()
			if first == 0:
				print(f'First block. Start: {startaddress:04X}', end = ' ')
				retval += make_bytes(startaddress)          # add startaddress
				first = 1
			#print(f'New block. Start: {startaddress:04X} old: {address:04X}')
			elif (startaddress != address):
				print(f' Length: {(len(dataarray)-1):02X}')
				retval += make_bytes(len(dataarray)-1)      # add length
				retval += dataarray                         # add the data
				dataarray = bytearray()
				print(f'New block. Start: {startaddress:04X}', end = ' ')
				retval += make_bytes(startaddress)          # add new startaddress
			address = startaddress
			ds = dat.split(" ")
			for d in ds:            # this is the data block
				d.strip()
				address += 1
				dataarray += (int(d,16)).to_bytes(1, 'big')
				#print(f'{int(d,16):02X} count: {dcount} {address:04X}')
	print(f' Length: {(len(dataarray)-1):02X}') # no more lines
	retval += make_bytes(len(dataarray)-1)      # add length
	retval += dataarray                         # add the data

	return retval

def add_comment(bytes, comment):
	# comment is marked if startaddress = 0xFFFFFF and Size = 0
	bytes += (0xFFFFFF).to_bytes(3, 'big') # Start
	bytes += (0x000000).to_bytes(3, 'big') # Size
	for c in comment:
		bytes += (ord(c)).to_bytes(1, 'big')
		#print(f'Char: {c}')
	return bytes
#-----------------------------------------
def main(start, file):
	new_file = bytearray()
	new_file += make_bytes(start)
	new_file += make_bytes(len(file) - 1)
	new_file += file
	return new_file

if __name__ == '__main__':
	argc = len(sys.argv)
	if ((sys.argv[1] == "--help") or (sys.argv[1] == "-h")):
		print(f'Usage: {sys.argv[0]} outputfilename (without extension) inputfilename startaddress [inputfilename startaddress] [: "comment"]')
		print(f'If reading from Hardware, enter HW for the filename and start-end for startaddress')
		exit()
	print(f'Scriptversion: {ver}')
	of = bytearray()
	ofn = sys.argv[1] + '.ucb' # Output filename (always supplied)
	off = 2                    # start with arguments at index 2
	while True:
		fn = sys.argv[off]     # Input filename ( or ':')
		off += 1
		start = 0
		if fn == ':':
			comment = sys.argv[off] # Startaddress or comment
			print(f'Comment: {comment}')
			of = add_comment(of, comment)
		else:
			if fn == 'HW':                             # Read from Hardware
				addresses = (sys.argv[off]).split("-") # startaddress-endaddress
				start = int(addresses[0], 0)
				end = int(addresses[1], 0)
				print(f'Reading from Hardware @ 0x{start:04x} - 0x{end:04X}')
				#size = end - start + 1
				ret = fr.main('read', 0, start, end)
				print(f'size: {len(ret)}')
				of += main(start, ret)
			elif ((fn.split(".")[-1] == "TXT") or (fn.split(".")[-1] == "txt")):
				print(f'Textfile found.')             # Textfile aaaa: bb bb bb ...
				of += convert_textfile(read_file_text(fn))
				off -= 1                              # became no startaddress 
			else:                                     # Binary File
				start = int(sys.argv[off], 0)         # Startaddress
				print(f'Filename: {fn}, start at: 0x{start:04x}')
				of += main(start, read_file(fn))
		off += 1
		print(f'Offset: {off}, argc: {argc}')
		if off >= argc:
			break
	write_file(of, ofn)
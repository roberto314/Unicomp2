#!/usr/bin/env python3
import sys, os, struct

ver = 1.11

# this file creates an .ucb file for the Unicom Project.
# It is a simple binary with a header of three bytes for position
# in the RAM and three bytes for length-1 of file, all in Big Endian.
# Example: File starts at 0x800, length is 2048 bytes
# 00 08 00 00 07 FF ..... Rest is binary data.
# This format is used with the python script UC_configure.py or UC_fill_RAM.py.

def read_file(fn):
	try:
		with open(fn, "rb") as f:
			img = f.read()
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

#def make_bytes(val):
#	retval = bytearray()
#	if len(val) == 1:
#		hi =  (0)
#		mid = (0)
#		low = (val[0] & 0xFF)
#	elif len(val) == 2:
#		hi =  (0)
#		mid = (val[1] & 0xFF)
#		low = (val[0] & 0xFF)
#	else:
#		hi =  (val[2] & 0xFF)
#		mid = (val[1] & 0xFF)
#		low = (val[0] & 0xFF)
#	#print(f'Type mid: {type(mid)}, val: {mid:02x}')
#	retval = hi.to_bytes(1, 'little')
#	retval += mid.to_bytes(1, 'little')
#	retval += low.to_bytes(1, 'little')
#	return retval

def make_bytes(val):
	return val.to_bytes(3, 'big')
#-----------------------------------------
def main(start, fn):
#	filename_only = (fn.split("/"))[-1]
#	pathname = (fn.split("/"))[0]
#	if filename_only == pathname:
#		print('No path supplied')
#		#outputfile = (filename_only.split("."))[0] + '.ucb'
#		outputfile = ofn + '.ucb'
#	else:
#		#outputfile = pathname + '/' + (filename_only.split("."))[0] + '.ucb'
#		outputfile = pathname + '/' + ofn + '.ucb'
#
#	file = read_file(fn)

	new_file = bytearray()
	#new_file += make_bytes(list(struct.pack("<H", start)))
	#new_file += make_bytes(list(struct.pack("<H", len(file))))
	new_file += make_bytes(start)
	new_file += make_bytes(len(file) - 1)
	new_file += file

	#print(f'Filename old: {pathname} with length: 0x{filelen:04x}, new: {outputfile}')
#	write_file(new_file, outputfile)
	return new_file

if __name__ == '__main__':
	argc = len(sys.argv)
	if argc < 4:
		print(f'Usage: {sys.argv[0]} outputfilename (without extension) inputfilename startaddress [inputfilename startaddress]')
		exit()
	print(f'Scriptversion: {ver}')
	of = bytearray()
	ofn = sys.argv[1] + '.ucb'
	off = 2
	while True:
		fn = sys.argv[off]
		off += 1
		start = int(sys.argv[off], 0)
		off += 1
		file = read_file(fn)		
		print(f'Filename: {fn}, start at: 0x{start:04x}')
		of += main(start, file)
		if off >= argc:
			break
	write_file(of, ofn)
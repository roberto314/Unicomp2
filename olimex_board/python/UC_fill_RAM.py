#!/usr/bin/python3

import logging, sys, argparse, math
from serial import Serial
from serial import SerialException
import time

ver = 1.3

# this is the upload script for the Unicom Project.
# It uses the "ostrich" protocol from moates (see the file:
# Moates Hardware Protocol v19.xls in the various folder).
#
# Version History:
# v1.0: Initial Version
# v1.2: comments at the end are shown in the console
# v1.21: now it is possible to enter start and end if a read is performed.
# v1.3: Writing of Clock Register now added

#port = '/dev/ttyS3'
port = '/dev/ttyACM0'

RAMMAX = 0x7FFFF

class bcolors:
    FAIL = '\033[91m'    #red
    OKGREEN = '\033[92m' #green
    WARNING = '\033[93m' #yellow
    OKBLUE = '\033[94m'  #dblue
    HEADER = '\033[95m'  #purple
    OKCYAN = '\033[96m'  #cyan
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
#print(f'{bcolors.FAIL}{bcolors.ENDC}')
#print(f'{bcolors.OKGREEN}{bcolors.ENDC}')
#print(f'{bcolors.WARNING}{bcolors.ENDC}')
#print(f'{bcolors.OKBLUE}{bcolors.ENDC}')
#print(f'{bcolors.HEADER}{bcolors.ENDC}')
#print(f'{bcolors.OKCYAN}{bcolors.ENDC}')
##########################################
def dump_registers(result):
	if result[0] != None:
		print(f'-- Range Register: {result[0]}')
	if result[1] != None:
		print(f'-- Offset Register: {result[1]}')
	if result[2] != None:
		print(f'-- Address Register: 0x{result[2]:02X}')
	if ((result[3] != None) and (result[4] != None)):
		temp = result[4]+256*result[3]
		print(f'-- MUX Register: 0x{temp:04X}')
		print(f'-- MUX Register: {temp:016b}')
	if ((result[5] != None) and (result[6] != None)):
		temp = result[6]+256*result[5]
		print(f'-- DAC Register: {temp}')
	if ((result[7] != None) and (result[8] != None)):
		temp = result[8]+256*result[7]
		print(f'-- DIV Register: {temp}')
#----------------------------------
def dump_data(data):
	#print(len(data))
#	if len(data) == 1:
#		print(f'0x{data[0]:02X}')
#	else:
#		for i in range(0,len(data)-1, 16):
#			print(", ".join(f'0x{c:02X}' for c in data[i:i+16]))
	idx = len(data)
	for i in range(0, len(data), 16):
		#print(f'idx: {idx}')
		if idx < 16:
			stop = idx
		else:
			stop = 16
		for j in range(0,stop):
			print(f'0x{data[i+j]:02X}, ', end = '')
		idx -= 16
		#print('\r')
#----------------------------------
def read_file(fn):
	try:
		with open(fn, "rb") as f:
			#print('File open')
			img = f.read()
			f.close()
			return img
	except Exception as e:
		print(f'File {fn} not found!')
		exit()

def write_file(data, fn):
	if fn == '':
		dump_data(data)
		exit()
	else:
		with open(fn, "wb") as f:
			#print(f'File open')
			f.write(bytes(data))
			f.close()
#----------------------------------
def write(channel, data):
	if isinstance(data, int):
		data = bytes((data,))

	#dump_data(data)
	try:
		result = channel.write(data)
		#print(f'Write Result: {result}')
		if result != len(data):
			raise Exception('write timeout')
		channel.flush()
	except:
		print("Write error!")
		#print(f'Write: {data}')
		#[print(f'Write: {e:02X}, {chr(e)}') for e in data]
		pass

def read(channel, size = 1):
	# Read a sequence of bytes
	if size == 0:
		return

	try:
		result = channel.read(size)
		#print(f'Read Result length: {len(result)}')
		if len(result) != size:
			print(f'Read error, Size: 0x{result:02X}')
			raise Exception('Read error')
	except:
		print('Read Error!')
		result = (read_file('rom.bin'))[:size] #only for debug on a pc
	return result

def read_byte(ser):
	# Read a single byte
	return int(read(ser)[0])
	#data = rw_serial(ser, 'read',0,1)
	#print(f'Read1....{data}')
	#return int(data[0])

#def rw_serial(ser, func, data, size=1):
#	try:
#		com = Serial(port, 115200, timeout = 1, writeTimeout = 1)
#	except IOError:
#		print('Port not found!')
#		exit()	
#	if func == 'read':
#		#print(f'Read....')
#		return(read(com, size))
#	elif func == 'write':
#		#print(f'Write....')
#		return(write(com, data))
#	else:
#		print(f'no function')
#----------------------------------
def make_checksum(data):
	return sum(data) & 0xff

def print_header(data, cs):
	if cs != 'none':
		print(f'Checksum: 0x{cs:02x}')
	else:
		print(f'no Checksum.')

def write_with_checksum(ser, data):
	cs_file = make_checksum(data)
	#print(f'Checksum: 0x{cs_file:02x}')
	#print(f' Write with Checksum: {len(data)}')
	#if len(data) < 50:
	#print_header(data, cs_file)
	data += bytes([cs_file])
	#dump_data(data)
	write(ser, data)

def read_with_checksum(ser, size):
	data = read(ser, size)
	checksum = ord(read(ser, 1))
	cs_file = make_checksum(data)
	print(f'Checksum: 0x{checksum:02x}')
	if checksum != cs_file:
		#pass # TODO raise Exception('Read checksum does not match')
		print(f'Checksum does not match! 0x{checksum:02x} vs 0x{cs_file:02x}')
	return data

def display_version(ser):
	print(f'Header: VV, no Checksum.')
	write(ser, b'VV')
	device_type = read_byte(ser)
	print('%10s: %s' % ('Major', device_type))
	version = read_byte(ser)
	print('%10s: %s' % ('Minor', version))
	device_id = chr(read_byte(ser))
	if device_id == 'N':
		print('Product: Nucleo NVRAM Programmer')
	elif device_id == 'O':
		print('Product: Ostrich Eprom Emulator')
	elif device_id == 'A':
		print('Product: APU1')
	elif device_id == 'B':
		print('Product: BURN1')
	elif device_id == 'U':
		print('Product: UNICOMP')
	else:
		print(f'Product not recognized! Got:{(device_id)}')

def get_serial(ser):
	write_with_checksum(ser, b'NS')
	print(f'Header: NS, ', end = '')
	result = read_with_checksum(ser, 9)
	vendor_id = int(result[0])
	serial_number = ''.join(hex(b)[2:] for b in result[1:])
	print('%10s %d' % ('Vendor:', vendor_id))
	print('%10s %s' % ('Serial:', serial_number))       

def expect_ok(ser):
	if ser == '':
		response = b'O'
	else:
		response = read(ser)
	if response != b'O':
		raise Exception('Response error')

def set_io_bank(ser, bank):
	#print(f'--------------------------- Set Bank to: {bank} -------------------------')
	message = bytearray(b'BR')
	message += bytes((bank,))
	write_with_checksum(ser, message)
	expect_ok(ser)

def get_io_bank(ser):
	#print(f'----------------------------- Get Bank -----------------------------')
	write_with_checksum(ser, b'BRR')
	result = read_byte(ser)
	#print(f'Bank is set to: {result}')

def write_memory(ser, data, start_address):
	chunk_size = 0x100
	print('------------------------------- Write ------------------------------')
	print (f'Length of data: {len(data)} or 0x{len(data):04x}')
	print (f'Start Address: {start_address} or 0x{start_address:04x}')
	for address in range(start_address, start_address + len(data), chunk_size):
		offset = address - start_address
		block = data[offset:offset + chunk_size]
		if len(block) == 256:
			bytecount = 0
			bc = 256
		else:
			bytecount = bc = len(block)
		mmsb = (address >> 16) & 0x07
		msb = (address >> 8) & 0xff
		lsb = (address) & 0xff
		#print (f'bytecount: {bc} or 0x{bc:04x}')
		#print (f'mmsb: {mmsb:02X} msb: {msb:02X} lsb: {lsb:02X} offset: {offset:04X} chunk: {chunk_size:03X}')
		
		message = bytearray(b'W') # Normal Block Write
		print(f'Header: W, ', end = '')
		message += bytes((bytecount,))
		message += bytes((msb,))
		message += bytes((lsb,))
		#print_header(message, 'none')
		message += block
		if len(message) < 16:
			dump_data(block)
		cs_file = make_checksum(data)
		print(f'Checksum: 0x{cs_file:02x}')
		write_with_checksum(ser, message)
		expect_ok(ser)

def read_memory(ser, start, end): # only block < 256
	print('------------------------------- Read -------------------------------')
	# Can only read full 0x100 byte pages
	read_start = start & 0x7ffff
	read_end = end & 0x7ffff
	bytecount = read_end - read_start + 1
	print(f'start: {read_start} end: {read_end}')

	mmsb = (read_start >> 16) & 0x07
	msb = (read_start >> 8) & 0xff
	lsb = (read_start) & 0xff
	#print (f'mmsb: {mmsb:02X} msb: {msb:02X} lsb: {lsb:02X} chunk: 0x{bytecount:02X}')
	#if bytecount == 256:
	#	messagebc = 0
	#else:
	#	messagebc = bytecount
	message = bytearray(b'R')
	message += bytes((bytecount & 0xFF,))
	message += bytes((msb,))
	message += bytes((lsb,))
	write_with_checksum(ser, message)
	data = read_with_checksum(ser, bytecount)
	#print(len(data))
	return data

def bulk_write_memory(ser, data, start_address):
	chunk_size = 0x100
	print('-------------------------- Bulk Write (ZW) -------------------------')
	print (f'Length of data: {len(data)} or 0x{len(data):04x}')
	print (f'Start Address: {start_address} or 0x{start_address:04x}')
	for address in range(start_address, start_address + len(data), chunk_size):
		offset = address - start_address
		block = data[offset:offset + chunk_size]
		if len(block) == 256:
			bytecount = 0
			bc = 256
		else:
			bytecount = bc = len(block)
		mmsb = (address >> 16) & 0x07
		msb = (address >> 8) & 0xff
		lsb = (address) & 0xff
		#print('x', end = ' ')
		#print (f'bytecount: {bc} or 0x{bc:04x}')
		#print (f'mmsb: {mmsb:02X} msb: {msb:02X} lsb: {lsb:02X} offset: {offset:04X} chunk: {chunk_size:03X}')
		
		#dump_data(data) # DEBUG

		message = bytearray(b'ZW') # Bulk Write
		message += bytes((bytecount,))
		message += bytes((mmsb,))
		message += bytes((msb,))
		message += block
		write_with_checksum(ser, message)
		expect_ok(ser)

#def bulk_read_memory(ser, start, end, chunk_size = 0x100):
 #	# Can only read full 0x100 byte pages
 #	read_start = start & 0x7ff00
 #	read_end = (end & 0x7ff00) + 0x100
 #	blockcount = math.ceil((read_end - read_start) / 256)
 #	ret = []
 #	print(f'readstart: {read_start} readend: {read_end}, end: {end} blockcnt: {blockcount}')
 #	mmsb = (read_start >> 16) & 0x07
 #	msb = (read_start >> 8) & 0xff
 #	print (f'mmsb: {mmsb:02X} msb: {msb:02X}')
 #	message = bytearray(b'ZR')
 #	message += bytes((blockcount,))
 #	message += bytes((mmsb,))
 #	message += bytes((msb,))
 #	write_with_checksum(ser, message)
 #
 #	trim_start = (start - read_start) & 0xff
 #	trim_end = ((read_end - end - 1)) & 0xff
 #	for block in range(blockcount - 1, -1, -1):
 #		#trim_end = (address + 256) - end - 1
 #		#print (f'trim_start: {trim_start} end: {trim_end} block: {block}')
 #
 #		data = (read_with_checksum(ser, 256))[trim_start:]
 #		if trim_start > 0:
 #			trim_start = 0
 #
 #		if ((trim_end > 0) and (block == 0)):
 #			#print('trim')
 #			data = data[:-trim_end]
 #		else:
 #			#print('not trim')
 #			data = data
 #
 #		ret += data
 #	return ret

def bulk_read_memory(ser, start, end, chunk_size = 0x100):
	print('---------------------------- Bulk Read ----------------------------')
	# Can only read full 0x100 byte pages
	read_start = start & 0x7ff00
	read_end = (end & 0x7ff00) + 0x100
	blockcount = math.ceil((read_end - read_start) / 256)
	ret = []
	print(f'readstart: 0x{read_start:04X} readend: 0x{read_end:04X}, end: 0x{end:04X} blockcnt: {blockcount}')
	mmsb = (read_start >> 16) & 0x07
	msb = (read_start >> 8) & 0xff
	print (f'mmsb: {mmsb:02X} msb: {msb:02X}')
	message = bytearray(b'ZR')
	message += bytes((blockcount,))
	message += bytes((mmsb,))
	message += bytes((msb,))
	write_with_checksum(ser, message)

	trim_start = (start - read_start) & 0xff
	trim_end = ((read_end - end - 1)) & 0xff
	print (f'trim_start: {trim_start} end: {trim_end}')
	if trim_end == 0:
		trim_end = None
	else:
		trim_end = -trim_end
	data = bytearray()
	for block in range(blockcount - 1, -1, -1):
		#trim_end = (address + 256) - end - 1
		data += read(ser, 256)
		print(f'Got block: {blockcount-block}')

	cs = ord(read(ser,1))
	cs_file = make_checksum(data)
	if cs == cs_file:
		return data[trim_start:trim_end]
	else:
		print(f'Checksum Error. cs: 0x{cs:02X}, cs_file: 0x{cs_file:02X}')
		return ''

def write_config(ser, data):
	print('------------------------------ Config ------------------------------')
	length = len(data)
	#print (f'Length of data: {length} or 0x{length:04x}')
	if length > 256:
		print(f'Only config <= 256 Bytes supported!')
		exit()
	message = bytearray(b'C') # Config Write
	print(f'Header: C, ', end = '')
	message += bytes((length,))
	message += data
	#dump_data(message)
	cs_file = make_checksum(data)
	print(f'Checksum: 0x{cs_file:02x}')
	write_with_checksum(ser, message)
	time.sleep(0.1)
	expect_ok(ser)

def write_clock(ser, data):
	print('--------------------------- Write Clock ------------------------------')
	length = len(data)
	print (f'Length of data: {length} or 0x{length:04x}')
	if length > 256:
		print(f'Only block <= 256 Bytes supported!')
		exit()
	message = bytearray(b'DW') # Clock Write
	print(f'Header: DW, ', end = '')
	message += bytes((length,))
	message += data
	dump_data(data)
	cs_file = make_checksum(message)
	print(f'Checksum: 0x{cs_file:02x}')
	write_with_checksum(ser, message)
	expect_ok(ser)

def read_clock(ser):
	print(f'----------------------------- Read Clock ---------------------------')
	print(f'Header: DR, ', end = '')
	write_with_checksum(ser, b'DR')
	#time.sleep(0.2)
	result = read_with_checksum(ser, 9)
	dump_data(result)
	return result

def write_pins(ser, data):
	#print('------------------------------ Pins --------------------------------')
	length = len(data)
	#print (f'Length of data: {length} or 0x{length:04x}')
	if length > 256:
		print(f'Only block <= 256 Bytes supported!')
		exit()
	message = bytearray(b'P') # Pins Write
	print(f'Header: P, Data: ', end = '')
	message += bytes((length,))
	message += data
	dump_data(message)
	cs_file = make_checksum(data)
	print(f'Checksum: 0x{cs_file:02x}')
	write_with_checksum(ser, message)
	time.sleep(0.1)
	expect_ok(ser)

def check_bank(ser, start, end):
	#print('-------------------------- Check Bank ------------------------------')
	bank = get_io_bank(ser)
	banks = start // 0x10000
	banke = end // 0x10000
	if bank != banks:
		set_io_bank(ser, banks)
		bank = banks
	if banke != banks:
		if banks + 1 < banke:
			print('Data crosses multiple bank boarders! This is not implemented.')
			exit()
		#print(f'Data crosses bank border!')
		chunk_end = (banks + 1) * 0x10000 - start
		return chunk_end
	else:
		return 'OK'

def bulk_write_chunks_start_border_clean(ser, data, saddress):
	end = len(data) + saddress
	chunks = len(data) // 256
	left = len(data) - chunks * 256
	edata = len(data)-left
	#print(f'chunks: {chunks} Left: {left}')
	if left == 0:
		#print('Data fits in 256 byte chunks.')
		bulk_write_memory(ser, data, saddress)
	else:
		#print('Data does NOT fit in 256 byte chunks.')
		if (len(data) > 255):
			bulk_write_memory(ser, data[:edata], saddress)
		saddress = saddress + len(data[:edata])
		eaddress = saddress + left
		check_bank(ser, saddress, eaddress)
		write_memory(ser, data[edata:], saddress)

############################################
def main(ser, func, data = 0, start = 0, end = 0):

	#try:
	#	ser = Serial(port, 115200, timeout = 1, writeTimeout = 1)
	#except IOError:
	#	print('Port not found!')
	#ser = ''
	#	#exit()

	if func == 'version':
		display_version(ser)
	elif func == 'serial':
		get_serial(ser)
	elif func == 'setbank':
		set_io_bank(ser, data)
	elif func == 'getbank':
		get_io_bank(ser)
	elif func == 'write':
		#end = start + len(data)
		#banks = start // 0x10000
		#banke = end // 0x10000
		#print(f'Banks used: startbank: {banks} endbank {banke}')
		if ((start % 256) == 0):
			#print('Start is on 256 bytes boundary.')
			bulk_write_chunks_start_border_clean(ser, data, start)

		else:
			#print('Start is NOT on a 256 bytes boundary!')
			end = (start & 0x7FF00) + 0xFF
			dataend = end - start + 1
			#print(f'Start: 0x{start:04X}, size: 0x{dataend:04X} end: 0x{end:04X}')
			check_bank(ser, start, end)
			write_memory(ser, data[:dataend], start)
			dataleft = len(data[dataend:])
			print(f'--------------------------- Done! Left: {dataleft} --------------------------')
			if dataleft > 0:
				start = start + len(data[:dataend])
				bulk_write_chunks_start_border_clean(ser, data[dataend:], start)

	elif func == 'read':
		if (end - start) >= 256:
			return bulk_read_memory(ser, start, end)
		else:
			return read_memory(ser, start, end)
	elif func == 'config':
		write_config(ser, data)
	elif func == 'clockw':
		write_clock(ser, data)
	elif func == 'clockr':
		clocksettings = read_clock(ser)
		dump_registers(clocksettings)
	elif func == 'pins':
		write_pins(ser, data)

def extract_files(img):
	start = int.from_bytes(img[0:3], 'big', signed=False)
	imglen = int.from_bytes(img[3:6], 'big', signed=False)
	if ((start == 0xFFFFFF) and (imglen == 0)): # comment
		#comment = (img[6:]).encode('ascii',errors='ignore')
		comment = (img[6:]).decode('utf8')
		print(f'{bcolors.OKGREEN}{comment}{bcolors.ENDC}')
		return 0,0,0,''
	else:
		end = start + imglen
		ret = img[6:imglen+7]
		rest = img[imglen+7:]
		return start,end,ret,rest

############################################
if __name__ == '__main__':
	parser = argparse.ArgumentParser(description = 'Command line interface for the Unicomp RAMROM Board. Version: ' + str(ver))
	parser.add_argument(
		'-v', '--verbose',
		action = 'count',
		help = 'increase logging level')
	subparsers = parser.add_subparsers(
		dest = 'command',
		title = 'Operations',
		description = '(See "%(prog)s COMMAND -h" for more info)',
		help = '')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'write',
		help = 'write data to device')
	subparser.add_argument(
		'file',
		#nargs = '?',
		#default = sys.stdin.buffer,
		help = 'input filename or data in HEX (ex.: UC_fill.py write :aa,0b,cc,... 0xF000) with no spaces!')
	subparser.add_argument(
		'start',
		nargs = '?',
		default = 0,
		help = 'memory start address')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'read',
		help = 'read data from device')
	subparser.add_argument(
		'start',
		help = 'start address (inclusive)')
	subparser.add_argument(
		'size',
		help = 'bytecount or with a _ in front until (_0xFF means start to 0xFF)')
	subparser.add_argument(
		'file',
		nargs = '?',
		#type = _parse_output_file,
		default = '', #sys.stdout.buffer,
		help = 'output filename [default: use stdout]')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'config',
		help = 'writes configuration data')
	subparser.add_argument(
		'file',
		help = 'input filename')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'clock',
		help = 'reads/writes clock data')
	subparser.add_argument(
		'data',
		nargs = '?',
		default = '',
		help = 'input data (comma seperated in HEX)')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'pins',
		help = 'writes to digital pins (0-RST active, 1-RST inactive, 2-Clock active, 3-Clock inactive)')
	subparser.add_argument(
		'data',
		help = 'input 8-bit data')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'setbank',
		help = 'set bank for emulation and I/O')
	subparser.add_argument(
		'bank',
		type = int,
		help = 'bank number (0-8)')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'getbank',
		help = 'get bank for emulation and I/O')
	#---------------------------------------------------------------------------------    
	subparser = subparsers.add_parser(
		'serial',
		help = 'get serial Number')
	#---------------------------------------------------------------------------------        
	subparser = subparsers.add_parser(
		'version',
		help = 'display device version number and exit',
		add_help = False)

	args = parser.parse_args()
	if args.command == '':
		print("No command")
		exit()
	ser = None
	try:
		ser = Serial(port, 115200, timeout = 1, writeTimeout = 1)
	except IOError:
		print('Port not found!')
		#exit()
	#print(ser)
	if args.command == 'version':
		main(ser, 'version')

	elif args.command == 'serial':
		main(ser, 'serial')

	elif args.command == 'setbank':
		main(ser, 'setbank', args.bank)

	elif args.command == 'getbank':
		main(ser, 'getbank')

	elif args.command == 'config':
		img = read_file(args.file)
		main(ser, 'config', img)

	elif args.command == 'pins':
		mylist = []
		b = args.data[0:]
		n = int(b,0)
		mylist.append(n)
		print(f'Received: {b} interpreted as: {n:02X}')
		main(ser, 'pins', bytes(mylist))

	elif args.command == 'clock':
		mylist = []
		if args.data == '':
			#print(f'Read Registers')
			main(ser, 'clockr')
		else:
			for b in (args.data).split(','):
				if b.isalnum():
					n = int(b, 16)
					print(f'Received: {b} interpreted as: {n:02X}')
					mylist.append(n)
				else:
					print(f'couldnt interpret: {b}')

			img = bytes(mylist)
			main(ser, 'clockw', img)
	
	elif args.command == 'write':
		if args.file[0] == ':':    # Some bytes received (format :yy,xx,zz)
			#mylist = [int(e, 16) if e.isalnum() else e for e in (args.file[1:]).split(',')]
			mylist = []
			for b in (args.file[1:]).split(','):
				if b.isalnum():
					n = int(b, 16)
					print(f'Received: {b} interpreted as: {n:02X}')
					mylist.append(n)
				else:
					print(f'couldnt interpret: {b}')

			img = bytes(mylist)
			start = int(args.start, 0) & RAMMAX
			end = start + len(img) - 1
			if end > RAMMAX:
				print(f'Write goes beyond 0x7FFF! (size: 0x{len(img):04X})')
				exit()
			main(ser, 'write', img, start)
		else:                   # real file received
			print(f'real file received {args.file}')
			img = read_file(args.file)
			ext = args.file.split(".")[-1] # check extension
			if ext != 'ucb': 
				start = int(args.start, 0) & RAMMAX
				end = start + len(img) - 1
				if end > RAMMAX:
					print(f'Write goes beyond 0x7FFF! (size: 0x{len(img):04X})')
					exit()
				main(ser, 'write', img, start)	
			else:                          # .ucb file has startaddress and size within
				print(f'Extension: {ext}')

				while True:
					start,end,oimg,rest = extract_files(img) # ucb file can contain more than one image
					if len(rest) == 0:
						break
					print(f'start: 0x{start:04X} end: 0x{end:04X}')
					main(ser, 'write', oimg, start)
					img = rest

	elif args.command == 'read':
		start = int(args.start, 0) & RAMMAX

		sizetemp = args.size
		if sizetemp[0] == '_':
			endtemp = int(sizetemp[1:], 0)
			#print(f'sizetemp: {sizetemp[1:]}, endtemp: {endtemp}')
			size = endtemp - start + 1
			print(f'Using endvalue. Calculated Size is: {size:04X} or {size}') 
		else:
			size = int(sizetemp, 0)
			print(f'Using size. Size is: {size:04X} or {size}') 
		if (size < 1) or (size > 0x7FFF):
			print('Size must be between 0 and 0x7FFF!')
			exit()
		end = start + size - 1
		if end > RAMMAX:
			print('Read goes beyond 0x7FFF!')
			exit()
		data = main(ser, 'read', 0, start, end)
		write_file(data, args.file)
	try:
		ser.close()
	except:
		pass

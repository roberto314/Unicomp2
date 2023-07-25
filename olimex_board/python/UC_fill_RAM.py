#!/usr/bin/python3

import logging, sys, argparse, math
from serial import Serial
from serial import SerialException
#port = '/dev/ttyS3'
port = '/dev/ttyACM0'

RAMMAX = 0x7FFFF
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
		print('\r')
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

	try:
		result = channel.write(data)
		if result != len(data):
			raise Exception('write timeout')
		channel.flush()
	except:
		print("Write failure!")
		#print(f'Write: {data}')
		#[print(f'Write: {e:02X}, {chr(e)}') for e in data]
		pass

def read(channel, size = 1):
	# Read a sequence of bytes
	if size == 0:
		return

	try:
		result = channel.read(size)
		if len(result) != size:
			print('I/O error')
			raise Exception('I/O error')
	except:
		print('Read Error!')
		result = (read_file('rom.bin'))[:size] #only for debug on a pc
	return result

def read_byte(ser):
	# Read a single byte
	return int(read(ser)[0])

#----------------------------------
def make_checksum(data):
	return sum(data) & 0xff

def print_header(data, cs):
	if cs != 'none':
		try:
			string = data.decode("ascii")
		except:
			string = 'not ascii'
		print(f'Header: {string}, Checksum: 0x{cs:02x}')
	else:
		#try:
		#	string = data.decode("ascii")
		#except:
		#	string = 'not ascii'
		print(f'Header: {data}, no Checksum.')

def write_with_checksum(ser, data):
	cs_file = make_checksum(data)
	#print(len(data))
	if len(data) < 10:
		print_header(data, cs_file)
	data += bytes([cs_file])
	write(ser, data)

def read_with_checksum(ser, size):
	data = read(ser, size)
	checksum = ord(read(ser, 1))
	cs_file = make_checksum(data)
	print(f'Checksum of block: 0x{cs_file:02x}')
	if checksum != cs_file:
		#pass # TODO raise Exception('Read checksum does not match')
		print(f'Checksum does not match! 0x{checksum:02x} vs 0x{cs_file:02x}')
	return data

def display_version(ser):
	write(ser, b'VV')
	print(f'Header: VV, no Checksum.')
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
	else:
		print('Product not recognized!')

def get_serial(ser):
	write_with_checksum(ser, b'NS')
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
	print(f'--------------------------- Set Bank to: {bank} -------------------------')
	message = bytearray(b'BR')
	message += bytes((bank,))
	write_with_checksum(ser, message)
	expect_ok(ser)

def get_io_bank(ser):
	print(f'----------------------------- Get Bank -----------------------------')
	write_with_checksum(ser, b'BRR')
	result = read_byte(ser)
	print(f'Bank is set to: {result}')

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
		message += bytes((bytecount,))
		message += bytes((msb,))
		message += bytes((lsb,))
		#print_header(message, 'none')
		message += block
		#dump_data(block)
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
	print('---------------------------- Bulk Write ----------------------------')
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
	data = []
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
		return []

def check_bank(ser, start, end):
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
		print(f'Data crosses bank border!')
		chunk_end = (banks + 1) * 0x10000 - start
		return chunk_end
	else:
		return 'OK'

def bulk_write_chunks_start_border_clean(ser, data, saddress):
	end = len(data) + saddress
	chunks = len(data) // 256
	left = len(data) - chunks * 256
	edata = len(data)-left
	print(f'chunks: {chunks} Left: {left}')
	if left == 0:
		print('Data fits in 256 byte chunks.')
		bulk_write_memory(ser, data, saddress)
	else:
		print('Data does NOT fit in 256 byte chunks.')
		if (len(data) > 255):
			bulk_write_memory(ser, data[:edata], saddress)
		saddress = saddress + len(data[:edata])
		eaddress = saddress + left
		check_bank(ser, saddress, eaddress)
		write_memory(ser, data[edata:], saddress)

############################################
def main(func, data = 0, start = 0, end = 0):

	try:
		ser = Serial(port, 115200, timeout = 1, writeTimeout = 1)
	except IOError:
		print('Port not found!')
		ser = ''
		#exit()

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
			print('Start is on 256 bytes boundary.')
			bulk_write_chunks_start_border_clean(ser, data, start)

		else:
			print('Start is NOT on a 256 bytes boundary!')
			end = (start & 0x7FF00) + 0xFF
			dataend = end - start + 1
			print(f'Start: 0x{start:04X}, size: 0x{dataend:04X} end: 0x{end:04X}')
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

def extract_files(img):
	start = int.from_bytes(img[0:3], 'big', signed=False)
	imglen = int.from_bytes(img[3:6], 'big', signed=False)
	end = start + imglen
	ret = img[6:imglen+7]
	rest = img[imglen+7:]
	return start,end,ret,rest

############################################
if __name__ == '__main__':
	parser = argparse.ArgumentParser(description = 'Command line interface for the Unicomp RAMROM Board')
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
		help = 'input filename or data in HEX (ex.: UC_fill.py write 0xF000 :aa,0b,cc,...) with no spaces!')
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
		help = 'bytecount')
	subparser.add_argument(
		'file',
		nargs = '?',
		#type = _parse_output_file,
		default = '', #sys.stdout.buffer,
		help = 'output filename [default: use stdout]')
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

	if args.command == 'version':
		main('version')

	elif args.command == 'serial':
		main('serial')

	elif args.command == 'setbank':
		main('setbank', args.bank)

	elif args.command == 'getbank':
		main('getbank')

	elif args.command == 'write':
		if args.file[0] == ':': # Number of bytes received
			mylist = [int(e, 16) if e.isalnum() else e for e in (args.file[1:-1]).split(',')]
			img = bytes(mylist)
			start = int(args.start, 0) & RAMMAX
			end = start + len(img) - 1
			if end > RAMMAX:
				print(f'Write goes beyond 0x7FFF! (size: 0x{len(img):04X})')
				exit()
			main('write', img, start)
		else:                  # real file received
			print(f'real file received {args.file}')
			img = read_file(args.file)
			ext = args.file.split(".")[-1]
			if ext != 'ucb': 
				start = int(args.start, 0) & RAMMAX
				end = start + len(img) - 1
				if end > RAMMAX:
					print(f'Write goes beyond 0x7FFF! (size: 0x{len(img):04X})')
					exit()
				main('write', img, start)	
			else:    # .ucb file has startaddress and size within
				print(f'Extension: {ext}')

				while True:
					start,end,oimg,rest = extract_files(img) # ucb file can contain more than one image
					print(f'start: 0x{start:04X} end: 0x{end:04X}')
					main('write', oimg, start)
					img = rest
					if len(rest) == 0:
						break

	elif args.command == 'read':
		size = int(args.size, 0)
		if (size < 1) or (size > 0x7FFF):
			print('Size must be between 0 and 0x7FFF!')
			exit()
		start = int(args.start, 0) & RAMMAX
		end = start + size - 1
		if end > RAMMAX:
			print('Read goes beyond 0x7FFF!')
			exit()
		data = main('read', 0, start, end)
		write_file(data, args.file)
	try:
		ser.close()
	except:
		pass

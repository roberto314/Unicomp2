#!/usr/bin/env python3
import argparse
import time
from serial import Serial
from serial import SerialException


#port = '/dev/ttyS3'
port = '/dev/ttyACM0'

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


def set_offset(val):
	byte1 = val&0x1f
	write_i2c([DS1085_OFFSET, byte1])

def set_addr(val):
	byte1 = val&0x0f
	write_i2c([DS1085_ADDR, byte1])

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
##########################################
def expect_ok(ser):
	if ser == '':
		response = b'O'
	else:
		response = read(ser)
	if response != b'O':
		raise Exception('Response error')

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
		result = ([0] * size)
		print(f'Read Error! Size: {size}')
	return result

def make_checksum(data):
	return sum(data) & 0xff

def write_with_checksum(ser, data):
	cs_file = make_checksum(data)
	data += bytes([cs_file])
	write(ser, data)

def read_with_checksum(ser, size):
	data = read(ser, size)
	checksum = ord(read(ser, 1))
	cs_file = make_checksum(data)
	if checksum != cs_file:
		print(f'Checksum does not match! 0x{checksum:02x} vs 0x{cs_file:02x}')
	return data

def read_clock(ser):
	write_with_checksum(ser, b'DR')
	result = read_with_checksum(ser, 9)
	#dump_registers(result)
	return result

def write_clock(ser, data):
	length = len(data)
	message = bytearray(b'DW') # Clock Write
	message += bytes((length,))
	message += bytes(data)
	write_with_checksum(ser, message)
	expect_ok(ser)
##########################################
def find_registers(freq_fast, freq_slow=1000000):
	offset = 6
	prescaler = 1
	stepsize = 5000 # Datasheet 5kHz Stepsize for DS1085-5
	dacmax = 1023   # Datasheet DAC can be 0-1023
	mclk_window_max = (int)((2560000 * (offset + 18) + (dacmax*stepsize)) / prescaler) # 2560000 is offset size from datasheet
	mclk_window_min = (int)((2560000 * (offset + 18)) / prescaler)
	#print (f'1st freq window: {mclk_window_max} - {mclk_window_min}, offset: {offset}, prescaler: {prescaler}')
	while freq_fast <= mclk_window_max:
		if freq_fast >= mclk_window_min:
			break
		offset -= 1
		if offset == -7:
			offset = 6
			prescaler *= 2
		if prescaler == 16:
			print("too small, out of Range!")
			exit()
		mclk_window_max = (int)((2560000 * (offset + 18) + (dacmax*stepsize)) / prescaler) # 2560000 is offset size from datasheet
		mclk = (int)(2560000 * (offset + 18))
		if (offset == -6) and (prescaler < 8):
			mclk_window_min = int(33E6 / prescaler)
		else:
			mclk_window_min = (int)((2560000 * (offset + 18)) / prescaler)
		#print (f'freq window: {mclk_window_max} - {mclk_window_min}, offset: {offset}, prescaler: {prescaler}')
	dac_off = round((freq_fast - mclk_window_min) * prescaler / stepsize) # 5kHz step size
	real_freq = (int)((2560000 * (offset + 18) + (dac_off*stepsize)) / prescaler)
	error = 1E6 * ((real_freq - freq_fast) / freq_fast)
	main_clock = real_freq * prescaler
	print(f"found offset: {offset}, prescaler0: {prescaler}, DAC: {dac_off}, Main Clockfreq.: {main_clock}")	
	if main_clock < 33000000:
		print(f'****************************************************************')
		print(f'****************************************************************')
		print(f'***********************  ATTENTION!  ***************************')
		print(f'***********  a main clock frequency below 33MHz can  ***********')
		print(f'****************  lead to unexpected operation!  ***************')
		print(f'****************************************************************')
		print(f'****************************************************************')
	print(f"frequency fast in: {freq_fast} out: {real_freq} CPU: {real_freq/8} Hz Error: {error:.2f} ppm")
	div1 = (round(main_clock / freq_slow)) - 2
	if div1 > 1024:
		print(f'{bcolors.FAIL}ATTETION DIVIDER > 1024!{bcolors.ENDC}')
	real_freq2 = main_clock / (div1 + 2)
	error2 = 1E6 * ((real_freq2 - freq_slow) / freq_slow)
	error3 = 100 * ((real_freq2 - freq_slow) / freq_slow)
	print(f'frequency slow in: {freq_slow} out: {int(real_freq2)}, divider: {div1} Error: {error3:#.3f} %, {error2:#.3f} ppm')
	return offset,prescaler,dac_off,div1


def main(f0=None, f1=None, p0=None, p1=None, offset=None, address=None, mux=None, dac=None, div=None):

	try:
		ser = Serial(port, 115200, timeout = 1, writeTimeout = 1)
	except IOError:
		print('Port not found!')
		ser = ''
		#exit()

	clocksettings = read_clock(ser)
	def_offset = clocksettings[0]   # first byte is range register
	o_offset = clocksettings[1]
	o_address = clocksettings[2]
	o_mux = clocksettings[4]+256*clocksettings[3]
	o_dac = clocksettings[6]+256*clocksettings[5]
	o_div = clocksettings[8]+256*clocksettings[7]
	newval = [None] * 9

	#print(f'----- Old Settings ------')
	#dump_registers(clocksettings)
	#print(f'Length of clocksettings: {len(clocksettings)}')

	if f0 != None:
		#print(f'Calculating registers for f0. {f0}')
		if f0 > 66555000:
			print("f0 too big, out of Range!")
			exit()
		tf0 = f0
	else:
		tf0 = 8000000

	if f1 != None:
		#print(f'Calculating registers for f1. {f1}')
		tf1 = f1
	else: tf1 = 1000000

	if f0 != None or f1 != None:
		offset,p0,o_dac,o_div = find_registers(tf0, tf1)

	if p0 != None:
		#print(f'Calculating registers for prescaler0. {p0}')
		temp = o_mux & 0x1E7 # clr bit 3 and 4 (and 9)
		if p0 == 1:
			o_mux = temp 
		elif p0 == 2:
			o_mux = temp | 0x0008
		elif p0 == 4:
			o_mux = temp | 0x0010
		elif p0 == 8:
			o_mux = temp | 0x0018

	if p1 != None:
		#print(f'Calculating registers for prescaler1. {p1}')
		temp = o_mux & 0x1F9 # clr bit 1 and 2 (and 9)
		if p1 == 1:
			o_mux = temp 
		elif p1 == 2:
			o_mux = temp | 0x0002
		elif p1 == 4:
			o_mux = temp | 0x0004
		elif p1 == 8:
			o_mux = temp | 0x0006

	if offset != None:
		#print(f'Calculating registers for offset. {offset}')
		o_offset = offset + def_offset

	o_address = 8 # Disable automatic save (WC Bit = 1)
	if address != None:
		#print(f'Calculating registers for address. {address}')
		o_address = address

	if mux != None:
		#print(f'Calculating registers for mux. {mux}')
		o_mux = mux

	if dac != None:
		#print(f'Calculating registers for dac. {dac}')
		o_dac = dac

	if div != None:
		#print(f'Calculating registers for div. {div}')
		temp = o_mux & 0x1FE # clr bit 0 (and 9)
		if div == 1:
			o_mux = temp | 1 # set bit 0 (DIV1)
		else:
			o_mux = temp # bit 0 cleared
			o_div = div - 2

	newval[0] = def_offset # not used for writing
	newval[1] = o_offset
	newval[2] = o_address
	temp = o_mux.to_bytes(2, 'big')
	newval[3] = temp[0]  #Hi
	newval[4] = temp[1]  #Lo
	temp = o_dac.to_bytes(2, 'big')
	newval[5] = temp[0]  #Hi
	newval[6] = temp[1]  #Lo
	temp = o_div.to_bytes(2, 'big')
	newval[7] = temp[0]  #Hi
	newval[8] = temp[1]  #Lo
	#print(f'------ New settings ------')
	#dump_registers(newval)
	write_clock(ser, newval)

if __name__ == '__main__':
	parser = argparse.ArgumentParser(prog = 'ds1085.py')
	parser.add_argument(
		'-f0',
		type = float,
		help = 'Frequency for OUT0 in Hz, ds1085.py -f 1000000 for 1MHz')
	parser.add_argument(
		'-f1',
		type = float,
		help = 'Frequency for OUT1 in Hz, ds1085.py -s 1000000 for 1MHz')
	parser.add_argument(
		'-k',
		type = float,
		help = 'Frequency for OUT0 in kHz, ds1085.py -k 1000 for 1MHz')
	parser.add_argument(
		'-M',
		type = float,
		help = 'Frequency for OUT0 in MHz, ds1085.py -M 1 for 1MHz')
	parser.add_argument(
		'-m',
		help = 'Write MUX Register')
	parser.add_argument(
		'-v',
		help = 'Write DIV Register for OUT1')
	parser.add_argument(
		'-d',
		help = 'Write DAC Register')
	parser.add_argument(
		'-o',
		help = 'Write Offset Register (+/-6)')
	parser.add_argument(
		'-p0',
		help = 'Set Prescaler for OUT0')
	parser.add_argument(
		'-p1',
		help = 'Set Prescaler for OUT1')
	parser.add_argument(
		'-x',
		help = 'Save Register values to EPROM')
	subparsers = parser.add_subparsers(
		dest = 'registers',
		title = 'Read registers')	
	subparser = subparsers.add_parser(
		'READ',
		help = 'Read all Register')
	args = parser.parse_args()

	freq_fast = 0;
	freq_slow = 0;

	def_offset = 0
	
	p0 = None
	p1 = None
	offset = None
	address = None
	mux = None
	dac = None
	div = None
	f0 = None
	f1 = None
	#if args.x == None and args.f == None and args.k == None and args.M == None and args.m == None and args.q0 == None and args.q1 == None:
	#	print("No command")
	#	exit()
	
	if args.p0 != None:
		if args.p0:
			val = int(args.p0, 0)
			if val in (1,2,4,8):
				#print(f'You entered {val}')
				p0 = val
			else:
				print(f'Prescaler {val} not supported')
			#set_pre0(val)
	if args.p1 != None:
		if args.p1:
			val = int(args.p1, 0)
			if val in (1,2,4,8):
				#print(f'You entered {val}')
				p1 = val
			else:
				print(f'Prescaler {val} not supported')
	if args.o != None:
		if args.o:
			val = int(args.o, 0)
			#print(f'You entered: {val}')
			if (val >= -7 and val <= 6):
				print(f'Setting Offset at: {val+def_offset}')
				offset = (val+def_offset) # set at position 0
			else:
				print(f'Setting out of range')

	if args.x != None:
		address = int(args.x, 0)
		print(f'Setting Address to {address} (0 automatically saves state)')
	
	if args.m != None:
		if args.m:
			mux = int(args.m, 0)
			#print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
	
	if args.d != None:
		if args.d:
			dac = int(args.d, 0)
			#print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
	
	if args.v != None:
		if args.v:
			val = int(args.v, 0)
			if val < 1:
				print('N-Divider must be > 1!')
				exit()
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			div = val

	if args.registers != None:
		try:
			ser = Serial(port, 115200, timeout = 1, writeTimeout = 1)
		except IOError:
			print('Port not found!')
			exit()
		clocksettings = read_clock(ser)
		#print(f'Length of clocksettings: {len(clocksettings)}')
		dump_registers(clocksettings)
		exit()
	
	if args.f0 != None:
		f0 = (int)(args.f0)
	if args.k != None:
		f0 = (int)(args.k*1000)
	if args.M != None:
		f0 = (int)(args.M*1000000)
	if args.f1 != None:
		f1 = (int)(args.f1)
	#print (f'Got new f0: {f0:,.2f}')
	main(f0, f1, p0, p1, offset, address, mux, dac, div)
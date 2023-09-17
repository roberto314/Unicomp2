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
		print(f'-- Prescaler 0 Register: {result[1]}')
	if result[2] != None:
		print(f'-- Prescaler 1 Register: {result[2]}')
	if result[3] != None:
		print(f'-- Offset Register: {result[3]}')
	if result[4] != None:
		print(f'-- Address Register: 0x{result[4]:02X}')
	if ((result[5] != None) and (result[6] != None)):
		temp = result[6]+256*result[5]
		print(f'-- MUX Register: 0x{temp:04X}')
	if ((result[7] != None) and (result[8] != None)):
		temp = result[8]+256*result[7]
		print(f'-- DAC Register: {temp}')
	if ((result[9] != None) and (result[10] != None)):
		temp = result[10]+256*result[9]
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
		print('Read Error!')
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
	result = read_with_checksum(ser, 11)
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
def find_registers(freq_fast, freq_slow, val):
	retval = val
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
	print(f"found offset: {offset}, prescaler0: {prescaler}")
	
	retval[1] = prescaler # set prescaler 0
	retval[0] = offset
	dac_off = round((freq_fast - mclk_window_min) * prescaler / stepsize) # 5kHz step size
	print(f"found DAC: {dac_off}")
	temp = dac_off.to_bytes(2, 'big')
	retval[7] = temp[0]  #Hi
	retval[8] = temp[1]  #Lo

	real_freq = (int)((2560000 * (offset + 18) + (dac_off*stepsize)) / prescaler)
	error = 1E6 * ((real_freq - freq_fast) / freq_fast)
	main_clock = real_freq * prescaler
	print(f"Main Clockfreq.: {main_clock}")
	if main_clock < 33000000:
		print(f'****************************************************************')
		print(f'****************************************************************')
		print(f'***********************  ATTENTION!  ***************************')
		print(f'***********  a main clock frequency below 33MHz can  ***********')
		print(f'****************  lead to unexpected operation!  ***************')
		print(f'****************************************************************')
		print(f'****************************************************************')
	print(f"Real frequency fast: {real_freq} CPU: {real_freq/8} Hz Error: {error:.2f} ppm")
	div1 = (round(main_clock / freq_slow)) - 2
	if div1 > 1024:
		print(f'{bcolors.FAIL}ATTETION DIVIDER > 1024!{bcolors.ENDC}')
	temp = div1.to_bytes(2, 'big')
	retval[9] = temp[0]  #Hi
	retval[10] = temp[1] #Lo	
	print(f'Got freq. slow: {freq_slow} Hz, divider: {div1}')
	real_freq2 = main_clock / (div1 + 2)
	error2 = 1E6 * ((real_freq2 - freq_slow) / freq_slow)
	error3 = 100 * ((real_freq2 - freq_slow) / freq_slow)
	print(f'Real frequncy slow: {real_freq2/1E6:#.6f} MHz, Error: {error3:#.3f} %, {error2:#.3f} ppm')
	return retval


def main(val):

	try:
		ser = Serial(port, 115200, timeout = 1, writeTimeout = 1)
	except IOError:
		print('Port not found!')
		ser = ''
		#exit()

	#if freq_fast == 0:
	#	print('Shutting clock off.')
	clocksettings = read_clock(ser)
	def_offset = clocksettings[0]
	if val[0] != None:
		val[3] = val[0]+def_offset
		val[0] = 0

	print(f'----- Old Settings ------')
	dump_registers(clocksettings)
	for i in range(len(val)):
		if val[i] == None:
			val[i] = clocksettings[i]; # use the old values as default

	print(f'------ New settings ------')
	dump_registers(val)
	write_clock(ser, val)

if __name__ == '__main__':
	parser = argparse.ArgumentParser(prog = 'ds1085.py')
	parser.add_argument('-f',
		type = float,
		help = 'Frequency for OUT0 in Hz, ds1085.py -f 1000000 for 1MHz')
	parser.add_argument('-s',
		type = float,
		help = 'Frequency for OUT1 in Hz, ds1085.py -s 1000000 for 1MHz')
	parser.add_argument('-k',
		type = float,
		help = 'Frequency for OUT0 in kHz, ds1085.py -k 1000 for 1MHz')
	parser.add_argument('-M',
		type = float,
		help = 'Frequency for OUT0 in MHz, ds1085.py -M 1 for 1MHz')
	subparsers = parser.add_subparsers(
		dest = 'registers',
		title = 'Read or Write registers')
	subparser = subparsers.add_parser(
		'MUX',
		help = 'Write MUX Register')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'DIV',
		help = 'Write DIV Register for OUT1')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'DAC',
		help = 'Write DAC Register')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'OFF',
		help = 'Write Offset Register (+/-6)')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'PRE0',
		help = 'Set Prescaler for OUT0')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'PRE1',
		help = 'Set Prescaler for OUT1')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'SAVE',
		help = 'Save Register values to EPROM')
	args = parser.parse_args()

	freq_fast = 0;
	freq_slow = 0;

	#set_addr(0x08); # Disable automatic save (WC Bit = 1)
	def_offset = 0#get_range()
	#temp = result[6]+256*result[5]
	#print(f'-- MUX Register: 0x{temp:04X}')
	#temp = result[8]+256*result[7]
	#print(f'-- DAC Register: 0x{temp:04X}')
	#temp = result[10]+256*result[9]
	#print(f'-- DIV Register: 0x{temp:04X}')

	newval = [None] * 11
	if args.registers == None and args.f == None and args.k == None and args.M == None and args.s == None:
		print("No command")
		exit()
	
	elif args.registers == 'PRE0':
		if args.value:
			val = int(args.value, 0)
			if val in (1,2,4,8):
				print(f'You entered {val}')
				newval[1] = val
			else:
				print(f'Prescaler {val} not supported')
			#set_pre0(val)
	elif args.registers == 'PRE1':
		if args.value:
			val = int(args.value, 0)
			if val in (1,2,4,8):
				newval[2] = val
				print(f'You entered {val}')
			else:
				print(f'Prescaler {val} not supported')
	elif args.registers == 'OFF':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered: {val}')
			if (val >= -7 and val <= 6):
				print(f'Setting Offset at: {val+def_offset}')
				newval[0] = (val+def_offset) # set at position 0
	elif args.registers == 'SAVE':
		print(f'Setting Address to 0 (automatically saves state)')
		newval[4] = 0
		exit()
	elif args.registers == 'MUX':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			temp = val.to_bytes(2, 'big')
			newval[5] = temp[0]  #Hi
			newval[6] = temp[1]  #Lo
	elif args.registers == 'DAC':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			temp = val.to_bytes(2, 'big')
			newval[7] = temp[0]  #Hi
			newval[8] = temp[1]  #Lo
	elif args.registers == 'DIV':
		if args.value:
			val = int(args.value, 0)
			if val < 2:
				print('N-Divider must be > 2!')
				exit()
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			temp = val.to_bytes(2, 'big')
			newval[9] = temp[0]  #Hi
			newval[10] = temp[1] #Lo
			#set_div(val-2)
	elif args.f != None:
		freq_fast = (int)(args.f)
	elif args.k != None:
		freq_fast = (int)(args.k*1000)
	elif args.M != None:
		freq_fast = (int)(args.M*1000000)
	if args.s != None:
		freq_slow = (int)(args.s)
	print (f'Got new freq_fast: {freq_fast:,.2f}')
	if freq_fast > 66555000:
		print("too big, out of Range!")
		exit()
	if ((freq_fast > 0) or (freq_slow > 0)):
		newval = find_registers(freq_fast, freq_slow, newval)
	#dump_registers(newval)
	#print(f'-------------------------------')
	main(newval)
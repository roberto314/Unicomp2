#!/usr/bin/env python3
import argparse
import time

try:
	from pyA20.i2c import i2c
	from pyA20.gpio import gpio
	from pyA20.gpio import port
	from pyA20.gpio import connector
	ENABLE = port.PH0
except ImportError:
	print('UC_set_freq Running on PC')

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

DS1085_DEVADDR = 0x58
DS1085_DAC      = 0x08
DS1085_OFFSET   = 0x0E
DS1085_DIV      = 0x01
DS1085_MUX      = 0x02
DS1085_ADDR     = 0x0D
DS1085_RANGE    = 0x37
DS1085_WRITE_E2 = 0x3F

def write_i2c(val):
	try:
		i2c.open(DS1085_DEVADDR)
		i2c.write(val)
		i2c.close()
	except:
		for x in val:
			print(f'VAL in HEX: {x:04X}, Val in DEC {x}')

def get_i2c(register, cnt=1):
	try:
		i2c.open(DS1085_DEVADDR)
		i2c.write([register])
		val = i2c.read(cnt)
		i2c.close()
	except:
		val = [0x43, 0x55]
	return val
###########################################
def set_dac(val):
	byte1 = val >> 2
	byte2 = (0b11 & val) << 6
	write_i2c([DS1085_DAC, byte1, byte2])

def get_dac():
	val = get_i2c(DS1085_DAC,2)
	return(val[0]<<2|val[1]>>6)
##########################################
def set_offset(val):
	byte1 = val&0x1f
	write_i2c([DS1085_OFFSET, byte1])

def get_offset():
	val = get_i2c(DS1085_OFFSET,1)
	return(val[0]&0x1f)
##########################################
def set_div(val):
	byte1 = val >> 2
	byte2 = (0b11 & val) << 6
	write_i2c([DS1085_DIV, byte1, byte2])

def get_div():
	val = get_i2c(DS1085_DIV,2)
	return(val[0]<<2|val[1]>>6)
##########################################
def set_mux(val):
	byte1 = val >> 2
	byte2 = (0b11 & val) << 6
	write_i2c([DS1085_MUX, byte1, byte2])

def get_mux():
	val = get_i2c(DS1085_MUX,2)
	return(val[0]<<2|val[1]>>6)
##########################################
def set_addr(val):
	byte1 = val&0x0f
	write_i2c([DS1085_ADDR, byte1])

def get_addr():
	val = get_i2c(DS1085_ADDR,1)
	return(val[0]&0x0f)
##########################################
def set_pre0(val):
	temp = get_mux() & 0x1E7 # clr bit 3 and 4 (and 9)
	if val == 1:
		temp = temp 
	elif val == 2:
		temp = temp | 0x0008
	elif val == 4:
		temp = temp | 0x0010
	elif val == 8:
		temp = temp | 0x0018
	set_mux(temp)

def get_pre0():
	val = get_mux()
	val = (val >> 3) & 3
	if val == 0:
		return 1
	elif val == 1:
		return 2
	elif val == 2:
		return 4
	elif val == 3:
		return 8
	else:
		return 0xFF
##########################################
def set_pre1(val):
	temp = get_mux() & 0x1F9 # clr bit 1 and 2 (and 9)
	if val == 1:
		temp = temp 
	elif val == 2:
		temp = temp | 0x0002
	elif val == 4:
		temp = temp | 0x0004
	elif val == 8:
		temp = temp | 0x0006
	set_mux(temp)

def get_pre1():
	val = get_mux()
	val = (val >> 1) & 3
	if val == 0:
		return 1
	elif val == 1:
		return 2
	elif val == 2:
		return 4
	elif val == 3:
		return 8
	else:
		return 0xFF
##########################################
def get_range():
	val = get_i2c(DS1085_RANGE,2)
	return(val[0]>>3)

def main(freq_fast, freq_slow = 1000000):

	try:
		gpio.init() #Initialize module. Always called first
		gpio.setcfg(ENABLE, gpio.OUTPUT)
	except:
		pass

	if freq_fast == 0:
		print('Shutting clock off.')
		try:
			gpio.output(ENABLE, 1)
		except:
			pass
		return

	try:
		i2c.init("/dev/i2c-2") #init second i2c bus
	except:
		pass
	
	time.sleep(0.1)
	def_offset = get_range()
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
	print(f"found offset: {offset}, Default Offset: {def_offset}, prescaler0: {prescaler}")
	
	time.sleep(0.1)
	set_pre0(prescaler)
	set_pre1(0)
	time.sleep(0.1)
	set_offset(def_offset+offset)
	dac_off = round((freq_fast - mclk_window_min) * prescaler / stepsize) # 5kHz step size
	print(f"found DAC: {dac_off}")
	set_dac(dac_off)

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
		
	set_div(div1)
	print(f'Got freq. slow: {freq_slow} Hz, divider: {div1}')
	real_freq2 = main_clock / (div1 + 2)
	error2 = 1E6 * ((real_freq2 - freq_slow) / freq_slow)
	error3 = 100 * ((real_freq2 - freq_slow) / freq_slow)
	print(f'Real frequncy slow: {real_freq2/1E6:#.6f} MHz, Error: {error3:#.3f} %, {error2:#.3f} ppm')

	try:
		gpio.output(ENABLE, 0) #switch output on
		print('Switch clock on.')
	except:
		pass

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
		help = 'R/W MUX Register')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'DIV',
		help = 'R/W DIV Register for OUT1')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'DAC',
		help = 'R/W DAC Register')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'OFF',
		help = 'R/W Offset Register (+/-6)')
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
	freq_slow = 1000000;
	try:
		i2c.init("/dev/i2c-2") #init second i2c bus
	except:
		pass

	set_addr(0x08); # Disable automatic save (WC Bit = 1)
	time.sleep(0.1)
	def_offset = get_range()


	if args.registers == None and args.f == None and args.k == None and args.M == None and args.s == None:
		print("No command")
		exit()
	
	elif args.registers == 'SAVE':
		print(f'Setting Address to 0 (automatically saves state)')
		set_addr(0)
		exit()
	elif args.registers == 'MUX':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			set_mux(val)
		else:
			val = get_mux()
			print(f'Mux in HEX: {val:04x}, Val in DEC {val}')
		exit()
	elif args.registers == 'DIV':
		if args.value:
			val = int(args.value, 0)
			if val < 2:
				print('N-Divider must be > 2!')
				exit()
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			set_div(val-2)
		else:
			val = get_div() + 2
			print(f'Div in HEX: {val:04x}, Val in DEC {val}')
		exit()
	elif args.registers == 'DAC':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			set_dac(val)
		else:
			val = get_dac()
			print(f'Dac in HEX: {val:04x}, Val in DEC {val}')
		exit()
	elif args.registers == 'OFF':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered: {val}')
			if (val >= -7 and val <= 6):
				print(f'Setting Offset at: {val+def_offset}')
				set_offset(val+def_offset)
		else:
			val = get_offset()
			print(f'Offset is: {val}, Default Offset: {def_offset}')
			print(f'Relative Offset is: {val-def_offset}')
		exit()
	elif args.registers == 'PRE0':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered {val}')
			set_pre0(val)
		else:
			val = get_pre0()
			print(f'Prescaler 0 is {val}')
		exit()
	elif args.registers == 'PRE1':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered {val}')
			set_pre1(val)
		else:
			val = get_pre1()
			print(f'Prescaler 1 is {val}')
		exit()
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

	main(freq_fast, freq_slow)
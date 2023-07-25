#!/usr/bin/env python3
import argparse
import time

PC = 0
if PC==0:
	from pyA20.i2c import i2c
	from pyA20.gpio import gpio
	from pyA20.gpio import port
	from pyA20.gpio import connector

ENABLE = port.PH0
DS1085_DEVADDR = 0x58
DS1085_DAC      = 0x08
DS1085_OFFSET   = 0x0E
DS1085_DIV      = 0x01
DS1085_MUX      = 0x02
DS1085_ADDR     = 0x0D
DS1085_RANGE    = 0x37
DS1085_WRITE_E2 = 0x3F

def write_i2c(val):
	if PC==0:
		i2c.open(DS1085_DEVADDR)
		i2c.write(val)
		i2c.close()
	else:
		print(f'VAL in HEX: {val:04x}, Val in DEC {val}')

def get_i2c(register, cnt=1):
	if PC==0:
		i2c.open(DS1085_DEVADDR)
		i2c.write([register])
		val = i2c.read(cnt)
		i2c.close()
	else:
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

def main():
	parser = argparse.ArgumentParser(prog = 'ds1085.py')
	parser.add_argument('-f',
		type = float,
		help = 'Frequency in Hz, ds1085.py -f 1000000 for 1MHz')
	parser.add_argument('-k',
		type = float,
		help = 'Frequency in kHz, ds1085.py -k 1000 for 1MHz')
	parser.add_argument('-M',
		type = float,
		help = 'Frequency in MHz, ds1085.py -M 1 for 1MHz')
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
		help = 'R/W DIV Register')
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
		help = 'Set Prescaler 0')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'PRE1',
		help = 'Set Prescaler 1')
	subparser.add_argument(
		'-v', '--value',
		help = 'value for Register')
	subparser = subparsers.add_parser(
		'SAVE',
		help = 'Save Register values to EPROM')
	args = parser.parse_args()

	if PC==0:
		i2c.init("/dev/i2c-2") #init second i2c bus
		gpio.init() #Initialize module. Always called first
		gpio.setcfg(ENABLE, gpio.OUTPUT)

	set_addr(0x08); # Disable automatic save (WC Bit = 1)
	time.sleep(0.1)
	val = get_range()

	def_offset = val
	#print(f'Range in HEX: {val:04x}, Val in DEC {val}')
	#val = get_offset()
	#print(f'Offset in HEX: {val:04x}, Val in DEC {val}')
	#print(f'Relative Offset in HEX: {val-def_offset:04x}, Val in DEC {val-def_offset}')
	#print (f'args: {args}')
	frequency = 0;
	if args.registers == None and args.f == None and args.k == None and args.M == None:
		print("No command")
		exit()
	
	elif args.registers == 'SAVE':
		print(f'Setting Address to 0 (automatically saves state)')
		set_addr(0);
	elif args.registers == 'MUX':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			set_mux(val)
		else:
			val = get_mux()
			print(f'Mux in HEX: {val:04x}, Val in DEC {val}')
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
	elif args.registers == 'DAC':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			set_dac(val)
		else:
			val = get_dac()
			print(f'Dac in HEX: {val:04x}, Val in DEC {val}')
	elif args.registers == 'OFF':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered (HEX): 0x{val:04x} (DEC): {val}')
			if (val >= -7 and val <= 6):
				print(f'Setting Offset at: {val+def_offset}')
				set_offset(val+def_offset)
		else:
			val = get_offset()
			print(f'Offset in HEX: {val:04x}, Val in DEC {val}')
			print(f'Relative Offset in HEX: {val-def_offset:04x}, Val in DEC {val-def_offset}')
	elif args.registers == 'PRE0':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered {val}')
			set_pre0(val)
		else:
			val = get_pre0()
			print(f'Prescaler 0 is {val}')
	elif args.registers == 'PRE1':
		if args.value:
			val = int(args.value, 0)
			print(f'You entered {val}')
			set_pre1(val)
		else:
			val = get_pre1()
			print(f'Prescaler 1 is {val}')
	elif args.f != None:
		frequency = (int)(args.f)
	elif args.k != None:
		frequency = (int)(args.k*1000)
	elif args.M != None:
		frequency = (int)(args.M*1000000)
	if frequency == 0:
		print('Shutting off.')
		gpio.output(ENABLE, 1)
		exit()

	gpio.output(ENABLE, 0)
			
	print (f'Got new frequency: {frequency:,.2f}')
	if frequency > 66555000:
		print("too big, out of Range!")
		exit()

	offset = 6
	prescaler = 1
	freq_window_max = (int)((2560000 * (offset + 18) + (1024*5000)) / prescaler) # 2560000 is offset size from datasheet
	freq_window_min = (int)((2560000 * (offset + 18)) / prescaler)
	#print (f'1st freq window: {freq_window_max} - {freq_window_min}, offset: {offset}, prescaler: {prescaler}')
	while frequency <= freq_window_max:
		if frequency >= freq_window_min:
			break
		offset -= 1
		if offset == -8:
			offset = 6
			prescaler *= 2
		if prescaler == 16:
			print("too small, out of Range!")
			exit()
		freq_window_max = (int)((2560000 * (offset + 18) + (1024*5000)) / prescaler) # 2560000 is offset size from datasheet
		freq_window_min = (int)((2560000 * (offset + 18)) / prescaler)
		#print (f'freq window: {freq_window_max} - {freq_window_min}, offset: {offset}, prescaler: {prescaler}')
	print(f"found offset: {offset}, prescaler0: {prescaler}")
	set_pre0(prescaler)
	set_offset(offset+def_offset)
	dac_off = round((frequency - freq_window_min) * prescaler / 5000) # 5kHz step size
	print(f"found DAC: {dac_off}")
	set_dac(dac_off)
	real_freq = (int)((2560000 * (offset + 18) + (dac_off*5000)) / prescaler)
	error = 1E6 * ((real_freq - frequency) / frequency)
	print(f"Real frequency: {real_freq}Hz Error: {error:.2f}ppm")
	

if __name__ == '__main__':
	main()
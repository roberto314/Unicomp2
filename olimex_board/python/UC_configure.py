#!/usr/bin/env python3
import sys, os
from configobj import ConfigObj

ver = 2.00

import UC_set_freq as sf
import UC_fill_RAM as fr
import set_reset as s_rst

def read_file(fn):
	try:
		with open(fn, "rb") as f:
			img = f.read()
			return img
	except Exception as e:
		print(f'File {fn} not found!')
		exit()


def make_romimage(dir, cf, noram):
	romcnt  = int(cf['rom']['romcnt'], 0)
	#romcs   = int(cf['rom']['cs'] , 0)
	start   = int(cf['rom']['start'] , 0)
	end     = int(cf['rom']['stop'] , 0)
	romstart = [0] * romcnt
	romend = [0] * romcnt
	romimage = [0] * romcnt
	for i in range(int(romcnt)):
		name = 'rom'+str(i)
		romstart[i] = int(cf[name]['start'], 0)
		romend[i]   = int(cf[name]['stop'] , 0)
		romimage[i] = dir + '/' + cf[name]['file']
		size = romend[i] - romstart[i] + 1
		#rbits = len(bin(size-1)[2:])
		#rbits = 0x10000 - size
		print(f'ROM: {romstart[i]:04X} to {romend[i]:04X} (size: {size} bytes) file: {romimage[i]}')
		#print(f'bits to ignore: {rbits} size of window: 0x{size-1:04X}')
		img = read_file(romimage[i])
		if len(img) != size:
			print('Size is too big!')
			exit()
		#print(f'Loading rom: {romimage[i]} to stm32.')
		if noram == 'false':
			fr.main('write', img, romstart[i])
	# Configure
	spi_start = (start // 0x100) & 0xFF
	spi_end = (end // 0x100) & 0xFF
	return (spi_start * 0x100 + spi_end)
	#print(f'Sending {spi_start:02X} to {spi_end:02X}')
	#s_spi.main(cs, spi_start * 256 + spi_end)

def config_per(name): 
	# peripherals have usualy a small window which doesn't cross a 'border' where the upper
	# address bits change. In the CPLD we compare the 'upper' bits. How many (lower) bits 
	# we ignore is depending on the value of 'bits'.
	try:
		start = int(cf[name]['start'], 0)
		end   = int(cf[name]['stop'] , 0)
		cs    = cf[name]['cs']
		sz = end - start
		bits = len(bin(sz)[2:])
		print(f'{name}: {start:04X} to {end:04X} with chipselect: {cs}')
		print(f'bits to ignore: {bits} size of window: 0x{sz:04X}')
		# Configure
		spi_start = start & 0xFFFF
		#spi_cnt = (end // 0x1) & 0xF
		#print(f'Sending {spi_start:03X} to {spi_end:03X}')
		#print(f'Sending {(spi_start*0x1000 + spi_end):06X}')
		#s_spi.main(cs, spi_start * 0x100 + bits) # send 24bits

	except:
		print(f'{name} not in config')

def config_ram(name, rom_data):
	try:
		start = int(cf[name]['start'], 0)
		end   = int(cf[name]['stop'] , 0)
		cs    = cf[name]['cs']
		#sz = (end - start) // 0x100
		#bits = len(bin(sz)[2:])
		print(f'{name}: {start:04X} to {end:04X} with chipselect: {cs}')
		#print(f'bits to ignore: {bits} size of window: 0x{sz:02X}')
		# Configure
		spi_start = (start // 0x100) & 0xFF
		spi_end = (end // 0x100) & 0xFF
		ram_data = spi_start * 0x100 + spi_end
		#print(f'Sending {spi_start:03X} to {spi_end:03X}')
		#print(f'Sending {(spi_start*0x1000 + spi_end):06X}')
		#s_spi.main(cs, rom_data * 0x10000 + ram_data)

	except:
		print(f'{name} not in config')

def main(dir, cf, noram):
	appname = cf['app']['name']
	version = cf['app']['ver']
	computername = cf['computer']['name']
	clockfreqf = int(cf['computer']['freqf'], 0)
	clockfreqs = int(cf['computer']['freqs'], 0)
	print(f'Appname: {appname}, Version: {version}')
	print(f'Configure for:\n\t{computername} \n\t{clockfreqf/1E6:#.6f} MHz fast clock, \n\t{clockfreqs/1E6:#.6f} MHz slow clock.')
	print('-------------------------- Reset Unicomp ---------------------------')
	s_rst.main(0) # Reset active
	print('-------------------------- Turn off Clock --------------------------')
	sf.main(0, 0)
	print('------------------------- Configure Clock --------------------------')
	sf.main(clockfreqf*8, clockfreqs)  # configure Clock
	print('-------------------------- Send ROM Image --------------------------')
	spi_data = make_romimage(dir, cf, noram)
	print('-------------------------- Configure RAM ---------------------------')
	config_ram('ram', spi_data)
	print('------------------------- Configure Serial -------------------------')
	config_per('serial')
	print('------------------------ Configure Parallel ------------------------')
	config_per('parallel')
	print('-------------------------- Reset inactive --------------------------')
	s_rst.main(1)  # Reset inactive - Run
	print('-------------------------- Modifications  --------------------------')
	text1 = cf['modifications']['text']
	print(f'{text1}')

if __name__ == '__main__':
	if len(sys.argv) < 2:
		print('Please supply config directory as argument!')
		print('Supply -noram at the end for NOT updating RAM')
		exit()
	os.system('clear')
	print(f'Scriptversion: {ver}')
	arg = sys.argv[1]
	noram = 'false'
	if len(sys.argv) > 2:
		if sys.argv[2] == '-noram':
			noram = 'true'
	if arg[-1] == '/':
		arg = arg[:-1]
	configdir = (arg.split("/"))[-1];
	configpath = arg
	#configdir = config[-1]
	#print(f'Looking in: {configpath}')
	configfile = configpath + '/' + configdir + '.cfg';
	print(f'Configfile found: {configfile}')
	cf = ConfigObj(configfile)
	main(configpath, cf, noram)
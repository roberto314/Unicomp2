#!/usr/bin/env python3
import sys, os
from configobj import ConfigObj

ver = 2.00

import UC_set_freq as sf
import UC_fill_RAM as fr
import set_reset as s_rst

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

def read_file(fn):
	try:
		with open(fn, "rb") as f:
			img = f.read()
			return img
	except Exception as e:
		print(f'File {fn} not found!')
		exit()

def upload_image(dir, cf, i):
	try:
		name = 'img'+str(i)
		imgstart = int(cf[name]['start'], 0)
		imgend  = int(cf[name]['end'] , 0)
		imgnumber = dir + '/' + cf[name]['file']
		size = imgend - imgstart + 1
		print(f'{bcolors.OKGREEN}-------------------------- Upload Image {i} --------------------------{bcolors.ENDC}')
		print(f'Image {i}: {imgstart:04X} to {imgend:04X} (size: {size} bytes) file: {imgnumber}')
		img = read_file(imgnumber)
		if len(img) != size:
			print(f'{bcolors.FAIL}          ###### Size is too big! ######{bcolors.ENDC}')
			exit()
		fr.main('write', img, imgstart)
		return 0
	except:
		return 1

def config_rom(dir, cf, norom, cfdat):
	start   = int(cf['rom']['start'] , 0)
	end     = int(cf['rom']['end'] , 0)
	name = 'rom'
	print(f'{name} is from {start:04X} to {end:04X}')

	# Configure
	cfdat['rom'] = [start, end]
	return cfdat
	#print(f'Sending {spi_start:02X} to {spi_end:02X}')
	#s_spi.main(cs, spi_start * 256 + spi_end)

def config_per(name): 
	try:
		start0 = int(cf[name]['start0'], 0)
		end0   = int(cf[name]['end0'] , 0)
		start1 = int(cf[name]['start1'], 0)
		end1   = int(cf[name]['end1'] , 0)
		cs    = cf[name]['cs']
		print(f'{name}0: {start0:04X} to {end0:04X} with chipselect: {cs}')
		print(f'{name}1: {start1:04X} to {end1:04X}')
		# Configure

	except:
		print(f'{name} not in config')

def config_ram(name, cfdat):
	try:
		start = int(cf[name]['start'], 0)
		end   = int(cf[name]['end'] , 0)
		cfdat['ram'] = [start, end]
		#sz = (end - start) // 0x100
		#bits = len(bin(sz)[2:])
		print(f'{name} is from {start:04X} to {end:04X}')
		#print(f'bits to ignore: {bits} size of window: 0x{sz:02X}')
		# Configure

	except:
		print(f'{name} not in config')
	return cfdat

def main(dir, cf, norom):
	appname = cf['app']['name']
	version = cf['app']['ver']
	computername = cf['computer']['name']
	clockfreqf = int(cf['computer']['freqf'], 0)
	clockfreqs = int(cf['computer']['freqs'], 0)
	configdata = {}
	print(f'Appname: {appname}, Version: {version}')
	print(f'Configure for:\n\t{computername} \n\t{clockfreqf/1E6:#.6f} MHz fast clock, \n\t{clockfreqs/1E6:#.6f} MHz slow clock.')
	print(f'{bcolors.OKGREEN}-------------------------- Reset Unicomp ---------------------------{bcolors.ENDC}')
	s_rst.main(0) # Reset active
	print(f'{bcolors.OKGREEN}-------------------------- Turn off Clock --------------------------{bcolors.ENDC}')
	sf.main(0, 0)
	print(f'{bcolors.OKGREEN}------------------------- Configure Clock --------------------------{bcolors.ENDC}')
	sf.main(clockfreqf*8, clockfreqs)  # configure Clock
	print(f'{bcolors.OKGREEN}-------------------------- Configure ROM ---------------------------{bcolors.ENDC}')
	configdata = config_rom(dir, cf, norom, configdata)
	print(f'{bcolors.OKGREEN}-------------------------- Configure RAM ---------------------------{bcolors.ENDC}')
	configdata = config_ram('ram', configdata)
	print(f'{bcolors.OKGREEN}------------------------- Configure Serial -------------------------{bcolors.ENDC}')
	config_per('serial')
	print(f'{bcolors.OKGREEN}------------------------ Configure Parallel ------------------------{bcolors.ENDC}')
	config_per('parallel')
	i=0
	while 1:
		if norom == 'false':
			if (upload_image(dir, cf, i)):
				break
			
		else:
			print(f'{bcolors.FAIL}        ###### actually NOT uploading rom image! ######{bcolors.ENDC}')
			break
		i += 1
	
	print(f'{bcolors.OKGREEN}-------------------------- Reset inactive --------------------------{bcolors.ENDC}')
	s_rst.main(1)  # Reset inactive - Run
	print(f'{bcolors.OKGREEN}-------------------------- Modifications  --------------------------{bcolors.ENDC}')
	text1 = cf['modifications']['text']
	print(f'{text1}')
	print(configdata)

if __name__ == '__main__':
	if len(sys.argv) < 2:
		print(f'{bcolors.FAIL}Please supply config directory as argument!{bcolors.ENDC}')
		print(f'{bcolors.FAIL}Supply -norom at the end for NOT updating ROM{bcolors.ENDC}')
		exit()
	os.system('clear')
	print(f'Scriptversion: {ver}')
	arg = sys.argv[1]
	norom = 'false'
	if len(sys.argv) > 2:
		if sys.argv[2] == '-norom':
			norom = 'true'
	if arg[-1] == '/':
		arg = arg[:-1]
	configdir = (arg.split("/"))[-1];
	configpath = arg
	#configdir = config[-1]
	#print(f'Looking in: {configpath}')
	configfile = configpath + '/' + configdir + '.cfg';
	print(f'{bcolors.OKCYAN}Configfile found: {configfile}{bcolors.ENDC}')
	cf = ConfigObj(configfile)
	main(configpath, cf, norom)
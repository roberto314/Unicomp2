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
#print(f'{bcolors.FAIL}{bcolors.ENDC}')
#print(f'{bcolors.OKGREEN}{bcolors.ENDC}')
#print(f'{bcolors.WARNING}{bcolors.ENDC}')
#print(f'{bcolors.OKBLUE}{bcolors.ENDC}')
#print(f'{bcolors.HEADER}{bcolors.ENDC}')
#print(f'{bcolors.OKCYAN}{bcolors.ENDC}')

def dump_events(data):
	print(f'{bcolors.WARNING} START -- CHIP -- MASK --{bcolors.ENDC}')
	width = 3
	idx = len(data)
	for i in range(0, len(data), width):
		if idx < width:
			stop = idx
		else:
			stop = width
		for j in range(0,stop):
			print(f'{bcolors.WARNING}0x{data[i+j]:04X}, ', end = '')
		idx -= width
		print(f'\r{bcolors.ENDC}')

def dump_data(data):
	width = 5
	idx = len(data)
	for i in range(0, len(data), width):
		#print(f'idx: {idx}')
		if idx < width:
			stop = idx
		else:
			stop = width
		for j in range(0,stop):
			print(f'{bcolors.OKCYAN}0x{data[i+j]:02X}, ', end = '')
		idx -= width
		print(f'\r{bcolors.ENDC}')
#----------------------------------
def write_file(data, fn):
	if fn == '':
		dump_data(data)
		#exit()
	else:
		with open(fn, "wb") as f:
			#print(f'File open')
			f.write(bytes(data))
			f.close()

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

def make_bytes(val):
	val = (val & 0x00FFFFF8)
	return val.to_bytes(3, 'big')

def find_key(d, val): # finds the key of one value in dictionary
	keys = []
	for i in d:
		keys.append(i)
		#print(f'key {i}')

	for i in range(len(d)):
		#print(f'index {i}')
		if val in d[keys[i]]: # if we get an empty list
			return keys[i]

	return ''

def find_border_key(peripheral, val):
	for i in (peripheral):
		#print(f'Key: {i}')
		if i != '0xFFN':
			for j in peripheral[i]:
				if j%2 == 0:
					start = j
				else:
					end = j
					bs = (start&0xFFFF8)
					be = ((end&0xFFFF8)+7)
					#print(f'Window: {start:04X} - {end:04X} masked: {bs:04X} - {be:04X}')
					if ((val >= start) and (val <= end)):
						#print(f'found key: {i} for {val:04X}')
						return i
	return ''

def check_before_adding_to_hole(per, value):
	vlist = per['0xFFN']
	for p in per:
		if p != '0xFFN':
			#print(f'p: {p}')
			for a in per[p]:
				start = (a & 0x000FFFF8)
				end = (a & 0x000FFFF8)+7
				#print(f'a: {a:04X}, {start:04X} - {end:04X}')
				if ((value >= start) and (value <= end)):					
					#print(f'Found value, not appending.')
					return
	#print(f'appending.')
	vlist.append(value)
	per['0xFFN'] = vlist
	return

def add_key(peripheral, address, addr):

	key = find_key(peripheral, address)
	#print(f'2key {key}')

	#print(f'{bcolors.OKGREEN}Coming in with: {address:04X} {bcolors.ENDC}')
	lower_inner = (address & 0x000FFFF8)
	upper_inner = lower_inner + 7
	upper_outer = lower_inner + 8
	lower_outer = lower_inner - 1
	#print(f'{bcolors.OKGREEN}checking borders: {lower_outer:04X}, {lower_inner:04X}, {upper_inner:04X}, {upper_outer:04X} {bcolors.ENDC}')
	
	val = ''
	if key != '':
		val = peripheral[key]
	if val == '':
		print(f'Shit happened.')

	if ((lower_outer not in addr) and (lower_outer > 0)):
		addr.append(lower_outer)
		key = find_border_key(peripheral, lower_outer)
		if key != '':
			#print(f'1Appending to {key}')
			val = peripheral[key]
			val.append(lower_outer)
			peripheral[key]=val
		else:
			#print(f'1Appending {lower_outer:04X} to hole?')
			check_before_adding_to_hole(peripheral, lower_outer)
			

	if (lower_inner not in addr):
		addr.append(lower_inner)
		key = find_border_key(peripheral, lower_inner)
		if key != '':
			#print(f'2Appending to {key}')
			val = peripheral[key]
			val.append(lower_inner)
			peripheral[key]=val
		else:
			#print(f'2Appending {lower_inner:04X} to hole?')
			check_before_adding_to_hole(peripheral, lower_inner)
	

	if (upper_inner not in addr):
		addr.append(upper_inner)
		key = find_border_key(peripheral, upper_inner)
		if key != '':
			#print(f'3Appending to {key}')
			val = peripheral[key]
			val.append(upper_inner)
			peripheral[key]=val
		else:
			#print(f'3Appending {upper_inner:04X} to hole?')
			check_before_adding_to_hole(peripheral, upper_inner)

	if (upper_outer not in addr):
		addr.append(upper_outer)
		key = find_border_key(peripheral, upper_outer)
		if key != '':
			#print(f'4Appending to {key}')
			val = peripheral[key]
			val.append(upper_outer)
			peripheral[key]=val
		else:
			#print(f'4Appending {upper_outer:04X} to hole?')
			check_before_adding_to_hole(peripheral, upper_outer)


	#exit()
	return peripheral, addr

def fix_hole(peripheral, addr):
	print(f'----- fixing Holes...')
	idx = 0
	if not peripheral['0xFFN']: # check if list is empty
		return
	for v in peripheral['0xFFN']:
		
		if ((idx%2 == 0) and (v%2 == 0)):
			print(f'Start - ok {v:04X}')
		elif ((idx%2 == 1) and (v%2 == 1)):
			print(f'End - ok {v:04X}')
		else:
			print(f'problem : {v:04X}')
		idx += 1
	v = peripheral['0xFFN'][-1]
	if idx%2 == 1:
		print(f'problem 2: {v:04X}')
		for address in addr:
			if address > v:
				print(f'found: {address:04X}')
				check_before_adding_to_hole(peripheral, address-1)
				return


def make_dict_per(cf):
	try:
		peripheral = {}
		peripheral['0xFFN'] = []
		keys = len(cf['peripherals'].keys())
		print(f'{bcolors.OKGREEN}--------------------- Configure Peripherals ------------------------{bcolors.ENDC}')
		#print(f'found {keys} keys.')
		for i in range(keys):
			name = cf['peripherals'].keys()[i]
			print(f'Found: {name}')
			sublen = len(cf['peripherals'][name])
			#print(f'found {sublen} values in {name}')
			cs_number = ''
			valtemp = ''
			valH = []
			valL = []
			for j in range(sublen):
				valname = cf['peripherals'][name].keys()[j]
				value = int(cf['peripherals'][name][valname], 0)
				if (('start' in valname) and ((value % 2) == 1)):
					print(f'{bcolors.FAIL} Startvalue must be even! ({valname} = 0x{value:04X}){bcolors.ENDC}')
					exit()
				if (('end' in valname) and ((value % 2) == 0)):
					print(f'{bcolors.FAIL} Endvalue must be odd! ({valname} = 0x{value:04X}){bcolors.ENDC}')
					exit()

				if ('cs' in valname): # Use the cs value as name for all peripherals
					peripheral[str(value)+'H'] = valH
					peripheral[str(value)+'L'] = valL
				else:
					if name != 'ram' and name != 'rom': # here we are in any other per. than ram or rom
						if (('hstart' in valname) or ('hend' in valname)):
							valH.append((value))
							#print(f'Got HI {valname} in {name} with ')
						else:
							valL.append((value))
							#print(f'Got LO {valname} in {name} with ')

				if 'ram' in name:
					valL.append((value))
					peripheral['14A'] = valL
				elif 'rom' in name:
					valH.append((value))
					peripheral['14O'] = valH
		keys = []
		addr = []
		for i in (peripheral):
			#print(f'Key: {i}')
			keys.append(i)
			for j in peripheral[i]:
				#print(f'Value: {j:04X}')
				addr.append(j)

		addr.sort()
		dup = {x for x in addr if addr.count(x) > 1}
		if len(dup):
			for y in dup:
				print(f'{bcolors.FAIL}Found duplicates. Please fix! (0x{y:04X}) {bcolors.ENDC}')
			exit()

		for k in range(len(addr)):
			val = addr[k] # the indices should be start,end,start,end,....
			oe = 'start'   # so start are at even index and end at odd index.
			if k%2 == 1:
				oe = 'end'
			#print(f'Address: {val} index: {oe}')
			for i in range(len(peripheral)):
				if val in peripheral[keys[i]]: # if we get an empty list
					idx2 = peripheral[keys[i]].index(val)
					oe2 = 'start'
					if idx2%2 == 1:
						oe2 = 'end'
					if oe != oe2:   # if the indices are not equal (as in odd or even) there is an overlap!
						print(f'{bcolors.FAIL}Found overlap at index: {idx2} in {keys[i]} Value: 0x{peripheral[keys[i]][idx2]:04X}{bcolors.ENDC}')
		for address in addr:
			#print(f'1Value: {address:04X}')
			if address % 2: # Endaddresses
				if (address & 7) != 7:
					#print(f'End NOT on 8 byte border {address:06X}')
					peripheral, addr = add_key(peripheral, address, addr)

			else:        # Startaddress
				if (address & 7) != 0:
					#print(f'Start NOT on 8 byte border {address:06X}')
					peripheral, addr = add_key(peripheral, address, addr)

		fix_hole(peripheral, addr)
		
		addr = []  # make new addr array with all the addresses
		print(f'---------------- DUMP ------------------')
		cnt = 0
		for i in (peripheral):
#			print(f'Key: {i}')
			for j in peripheral[i]:
#				print(f'Value: {j:04X}')
				addr.append(j)
				cnt += 1
#		print(f'Total number of events: {cnt}')
		addr.sort()             # sort it again

		for i in addr:
			if i % 2 == 0:
				key = find_key(peripheral, i)
				print(f'{bcolors.OKGREEN}{key} ', end = '\t')
				print(f'Start addr: {i:04X}', end = '')
			else:		
				print(f'  End addr: {i:04X}{bcolors.ENDC}')

		return peripheral, addr
	except Exception as e:
		print(f'Error: {e}')
		#raise



def get_bitmask(start, finish, tp):
	sz = finish - start
	beg = (start & 0x00000007) # mask out all addresses over 8
	end = 7 - (finish & 0x00000007)
	next_address = (finish & 0xFFFF8) + 8
	#next_address = (finish & 0xFFFF0)+(finish & 0x000008)
	print(f'Size: {sz+1}, Begin: {start:06X} from border: {beg:02X}, End: {finish:06X} to border: {end:02X} next event: {next_address:06X} func: {tp} ')

	if beg == 0:     # on 8 byte border (0,8)
		soff = 0xF0
	elif beg == 2:   # on 2 or A
		soff = 0xFD
	elif beg == 4:   # on 4 or C
		soff = 0xFB
	elif beg == 6:   # on 6 or E
		soff = 0xF7

	if end == 0:     # on 8 byte border (7,F)
		eoff = 0xF0
	elif end == 2:   # two before 8 byte border (5,D)
		eoff = 0xF8
	elif end == 4:   # four before 8 byte border (3,B)
		eoff = 0xFC
	elif end == 6:   # six before 8 byte border (7,F)
		eoff = 0xFE

	temp = (soff | eoff)%(2**8)
	
	if tp == 'A': # RAM - low nibble (WP) 0, Low and high nibble same
		retval = ((temp * 16) + (temp)%(2**4))%(2**8)
	elif tp == 'O': # ROM - low nibble (WP) F, low nibble is NOT high nibble
		retval = (((temp * 16) + (~temp))%(2**4))%(2**8)
	elif tp == 'L': # second output - low nibble 0-F
		retval = (temp)%(2**8)
	elif tp == 'H': # first output - high nibble 0-F
		retval = (temp * 16 + 0x0F)%(2**8)
	elif tp == 'N': # nothing selected
		retval = ((~temp * 16))%(2**8) + (~temp)%(2**4)
	
	print(f'eoff: {eoff:02X} soff: {soff:02X} temp:{temp:02X} retval: {retval:02X}')
	return retval, next_address

def find_indices(list_to_check, item_to_find):
    indices = []
    for idx, value in enumerate(list_to_check):
        if value == item_to_find:
            indices.append(idx)
    return indices

def make_bytearray(clist):
	retval = bytearray()
	for i in range(0, len(clist), 3):
		addr = (clist[i])
		retval += addr.to_bytes(3, 'big')
		chip = (clist[i+1])
		retval += chip.to_bytes(1,'big')
		mask = (clist[i+2])
		retval += mask.to_bytes(1,'big')
		#print(f'Address: {addr:04x}, cs: {chip:02X}, mask: {mask:02X}')
	return retval

def config_per(cf): 
	try:
		peripheral = {}
		addr = []
		oldkeyn = 0xFF
		oldaddress = 0xFFFFFFFF
		oldstart = old_next_address = next_address = oldend = 0xFFFFFFFF
		new_file = bytearray()
		configfile = bytearray()
		peripheral, addr = make_dict_per(cf)
		#print(f'{peripheral}, {addr}')
#		for i in addr:
#			print(f'addr: {i:04X}')
		print(f'----------------- Begin ----------------')
		events_done = []
		for address in addr:
			if address % 2: # Endaddresses
				#print(f'End @ {address:04X} Oldstart: {oldstart:06X}')
				key = find_key(peripheral, oldstart)  # Whats the chipselect of that value
				if (address > (oldstart + 7)):
					print(f'{bcolors.HEADER}big block {oldstart:04X} - {address:04X} with key: {key}{bcolors.ENDC}')
					mask,next_address = get_bitmask(oldstart, address, key[-1:])# get the bitmask for the next 8 addresses
					events_done.append(oldstart)
					events_done.append(int(key[:-1] , 0))
					events_done.append(mask)
					old_next_address = next_address
				else:
					print(f'{bcolors.HEADER}small block {oldstart:04X} - {address:04X} with key: {key}{bcolors.ENDC}')
					if (oldstart-1) in addr:
						print(f'{bcolors.OKBLUE}no hole @ {oldstart:04X}{bcolors.ENDC}')
					else:
						print(f'{bcolors.OKBLUE}hole @ {(oldend+1):04X} - {(oldstart-1):04X} old next Adress: {old_next_address:04X}{bcolors.ENDC}')

					if (oldstart & 0xFFFFF8) in events_done:
						#idx = events_done.index((oldstart & 0xFFFFF8))
						lidx = find_indices(events_done, (oldstart & 0xFFFFF8))

						print(f'{bcolors.OKGREEN}already done! @ {lidx} {bcolors.ENDC}')
						mask,next_address = get_bitmask(oldstart, address, key[-1:])# get the bitmask for the next 8 addresses
						if (len(lidx) == 1):
							idx = lidx[0] # only one event
						else:
							idx = 0
							for i in lidx:
								if int(key[:-1]) == events_done[i+1]:
									print(f'{bcolors.OKGREEN} Found Key {i} {bcolors.ENDC}')
									idx = i

						if int(key[:-1]) == events_done[idx+1]:
							print(f'{bcolors.OKGREEN} Keys are the same {bcolors.ENDC}')
							val = events_done[idx+2]
							newval = val & mask
							events_done[idx+2] = newval
							old_next_address = next_address
						else:
							print(f'{bcolors.FAIL} Keys are different!{bcolors.ENDC}')
							events_done.append((oldstart & 0xFFFFF8))
							events_done.append(int(key[:-1] , 0))
							events_done.append(mask)
							old_next_address = next_address
					else:
						print(f'{bcolors.OKGREEN}new event!{bcolors.ENDC}')
						mask,next_address = get_bitmask(oldstart, address, key[-1:])# get the bitmask for the next 8 addresses
						events_done.append((oldstart & 0xFFFFF8))
						events_done.append(int(key[:-1] , 0))
						events_done.append(mask)
						old_next_address = next_address

				oldend = address
				#write_file(configfile, '')
				dump_events(events_done)

			else:           # Startaddresses
				print(f'Start @ {address:06X} Oldnext: {old_next_address:06X}')
				#if (address) > (next_address+7):
				#	print(f'gap found @ {next_address:04X} - {old_next_address:04X}')
				#	configfile += make_bytes(next_address)   # Convert address to three bytes
				#	configfile += keyn.to_bytes(1,'big')  # send cs
				#	mask,next_address = get_bitmask(next_address, old_next_address, key[-1:])# get the bitmask for the next 8 addresses
				#	configfile += mask.to_bytes(1,'big')  # and send mask


				#if oldstart > address:
				#	print(f'Begin....')
				oldstart = address



#		for i in range(0, len(addr)-1, 2):
#			if (addr[i] != 0):
#				#print(f'---here: {addr[i-1]:04X} - {addr[i]:04X}')
#				if (addr[i-1]+1 != addr[i]): # Compare last end to this start
#					print(f'Hole here: {addr[i-1]+1:04X} - {addr[i]-1:04X}')
#
#				if ((addr[i-1] & 0x07) != 7):
#					new_file += make_bytes(addr[i-1]&0xFFFF8)     # Convert address to three bytes
#					print(f'End not on a 8byte border!')
#					mask,next_address = get_bitmask((addr[i-1]&0xFFFF8), addr[i-1], key[-1:])# get the bitmask for the next 8 addresses
#					print(f'Index: {i} Key: {key} old adr.: {oldaddress:04X} addr.: {addr[i]:04X} next addr.:  {addr[i+1]:04x} Mask: {mask:02X}')
#					new_file += keyn.to_bytes(1,'big')  # send cs
#					new_file += mask.to_bytes(1,'big') # and send mask
#
#				else:
#					print(f'End -is- on a 8byte border!')
#					new_file += b'\xFF\xFF'                 # no select there
#			key = find_key(peripheral, addr[i]) # Whats the chipselect of that value
#			keyn = int(key[:-1])                # convert to number only
#			mask,next_address = get_bitmask(addr[i], addr[i+1], key[-1:])# get the bitmask for the next 8 addresses
#			print(f'Index: {i} Key: {key} old adr.: {oldaddress:04X} addr.: {addr[i]:04X} next addr.:  {addr[i+1]:04x} Mask: {mask:02X}')
#			if ((oldkeyn == keyn) and ((oldaddress+8) > addr[i])):
#				print(f'Sepcial case, same address different mask!') # Address and cs are already in bytearray, only the mask needs to be adjusted
#				new_file[-1] = (oldmask & mask) # overwrite last byte
#			else:
#				new_file += make_bytes(addr[i])     # Convert address to three bytes
#				new_file += keyn.to_bytes(1,'big')  # send cs
#				new_file += mask.to_bytes(1,'big') # and send mask
#			oldkeyn = keyn
#			oldmask = mask
#			oldaddress = addr[i]


		#new_file = bytearray()
		new_file = make_bytearray(events_done)
		new_file += make_bytes(addr[-1]+1)  # Convert last end address + 1 to three bytes
		new_file += b'\xFF\xFF'             # no select there
		new_file += b'\x00\x00\x00\x00\x00' # this marks is the end (Address = 0)
		write_file(new_file, 'configdata.uc')
		dump_data(new_file)
		fr.main('config', new_file)
	except Exception as e:
		print(f'Error: {e}')


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

	config_per(cf) # configure peripherals
	
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
	#print(configdata)

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
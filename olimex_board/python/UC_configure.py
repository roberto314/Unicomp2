#!/usr/bin/env python3
import sys, os
from configobj import ConfigObj
import time
from serial import Serial

ver = 2.20
port = '/dev/ttyACM0'

import UC_set_freq_stm32 as sf
import UC_fill_RAM as fr
#import set_reset as s_rst

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

def dump_list(data):
    idx = len(data)
    width = idx
    if width == 0:
        return
    for w in range(width):
        print (f'  {w:02} ', end = '')
    print(f'')
    for i in range(0, len(data), width):
        #print(f'idx: {idx}')
        if idx < width:
            stop = idx
        else:
            stop = width
        for j in range(0,stop):
            v = data[i+j]
            if v == 0xFF:
                print(f'{bcolors.WARNING}0x{v:02X} ', end = '')
            elif v == 0xF0:
                print(f'{bcolors.OKBLUE}0x{v:02X} ', end = '')
            elif v == 0x0F:
                print(f'{bcolors.OKGREEN}0x{v:02X} ', end = '')
            else:
                print(f'{bcolors.OKCYAN}0x{v:02X} ', end = '')
        idx -= width
        #print(f'{bcolors.ENDC} - {(i+7):>2} ({(i+7):02X})\r')
        print(f'{bcolors.ENDC}\r')
#----------------------------------
def dump_data(data, width):
    idx = len(data)
    for w in range(width):
        print (f'  {w}  ', end = '')
    print(f'')
    for i in range(0, len(data), width):
        #print(f'idx: {idx}')
        if idx < width:
            stop = idx
        else:
            stop = width
        for j in range(0,stop):
            print(f'{bcolors.OKCYAN}0x{data[i+j]:02X} ', end = '')
        idx -= width
        print(f'{bcolors.ENDC} - {(i+width):>2} ({(i+width):02X})\r')
        #print(f'{bcolors.ENDC}\r')
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
            #print(f'File {fn} read.')
            return img
    except Exception as e:
        print(f'{bcolors.FAIL}---- File {fn} not found!{bcolors.ENDC}')
        exit()

def upload_image(ser, fpath, cf, key):
    try:
        name = key
        imgstart = int(cf[name]['start'], 0)
        imgend  = int(cf[name]['end'] , 0)
        imgnumber = fpath + '/' + cf[name]['file']
        size = imgend - imgstart + 1
        #print(f'Image {i}: {imgstart:04X} to {imgend:04X} (size: {size} bytes) file: {imgnumber}')
        print(f'{bcolors.OKGREEN}trying to upload {imgnumber} from: {imgstart:04X} to {imgend:04X} {bcolors.ENDC}')
        img = read_file(imgnumber)
        if len(img) != size:
            print(f'{bcolors.FAIL}      ###### Size is wrong! (Image: 0x{len(img):04X} Space: 0x{size:04X}) ######{bcolors.ENDC}')
            exit()
        fr.main(ser, 'write', img, imgstart)
        return 0
    except Exception as e:
        print(f'Error in upload_image: {e}!')
        return 1

def upload_patch(ser, cf, key):
    try:
        name = key
        imgstart = int(cf[name]['address'], 0)
        datalist = cf[name]['data']
        print(f'Datalist: {datalist}, Length: {len(datalist)}')
        if (len(datalist) > 2):
            datastr = ','.join(datalist)
            mylist = []
            #print(f'read {key}: Address: 0x{imgstart:04X} Data: {datastr}')
            for b in datastr.split(','):
                if b.isalnum():
                    n = int(b, 16)
                    #print(f'Received: {b} interpreted as: {n:02X}')
                    mylist.append(n)
                else:
                    print(f'couldnt interpret: {b}')
            img = bytes(mylist)
        else:
            val = int(datalist,16)
            #print(f'Value: 0x{val:02X}')
            img = bytes([val])
            #print(f'Img: {img}')
        print(f'{bcolors.OKGREEN}trying to apply patch at: {imgstart:04X}, {datalist} {bcolors.ENDC}')
        fr.main(ser, 'write', img, imgstart)
        return 0
    except Exception as e:
        print(f'Error in upload_image: {e}!')
        return 1

def make_bytes(val):
    val = (val & 0x00FFFFF8)
    return val.to_bytes(3, 'big')

def my_append(addr, val, hl): # adds a new peripheral and makes the lists same size
    if len(addr) <= val:
        #print(f'Size is smaller or equal than position. Val: {val} Length: {len(addr)}')
        if (val%2) == 1: # endaddress
            #print(f'Got End @ {val}, remove last item (end marker)')
            del addr[-1]    # remove the last 'end' marker
            while len(addr) <= val:

                addr.append(hl)
        else:            # startaddress
            #print(f'New start @ {val}')
            while len(addr) < val:
                addr.append(0xFF)
            addr.append(hl)
        addr.append(0xFF) # append an 'end' marker
    else:
        #print(f'Size is bigger. ')
        if (val%2) == 1: # endaddress
            #print(f'Got End @ {val}')
            i = val
            while ((addr[i] != hl) and (i > 0)):
                addr[i] = hl
                i -= 1
            #while len(addr) <= val:
            #   addr.append(0)
        else:            # startaddress
            #print(f'New start2 @ {val}')
            addr[val] = hl
    #print(f'Size now: {len(addr)}')
    return addr

def merge_ram_rom(ba, v):
    errval = 0
    cs14 = ba[14]
    bl = len(cs14)
    vl = len(v)

    #print(f'Got length: {bl}, {vl}')
    if bl == 0:
        #print(f'adding new values {v}')
        ba[14] = v
    else:
        #print(f'Merging values.')
        while len(cs14) < vl:
            cs14.append(0xFF)
        for x in range(len(v)):
            listval = cs14[x]
            newval = v[x]
            #print(f'Val: {newval} list: {listval}')
            if ((listval != 0xFF) and (newval != 0xFF)):
                print(f'{bcolors.FAIL}Overlap in RAM/ROM detected at address: {x:05x}{bcolors.ENDC}')
                errval += 1
            cs14[x] = (listval & newval)%(2**8)
        ba[14] = cs14
    return ba, errval

def collapse_lists(ba): # collapses all 15 lists into one eventlist and does errorcheck
    errval = 0 
    new_list = []
    ll = len(ba)
    if ll != 15:
        print(f'{bcolors.FAIL}Did you forget RAM or ROM?{bcolors.ENDC}')
        exit()
    #print(f'Lists: {ll}')
    biggestlen = 0
    actual_lists = 0
    for l in ba:
        tl = len(l)
        if tl > 0:
            actual_lists += 1
        if tl > biggestlen:
            biggestlen = tl
    #print(f'max len: {biggestlen}, Lists: {actual_lists}')
    count = 0
    for idx in range(biggestlen):   # Errorcheck (overlaps)
        chip = 0xFF
        for l in range(15):
            if ba[l] == []:
                continue
            #print(f'chip {l}, Address: {idx}')
            if len(ba[l]) <= idx:
                #print(f'List too small {l}')
                (ba[l]).append(0xFF)
            val = ba[l][idx]
            if val == 0xF0:
                chip = l         # chipselect 0..14 for low 
            elif val == 0x0F:
                chip = (16 + l)  # and 16..30 for high

            if val != 0xFF:
                count += 1

 #      print(f'Address: {idx}, count {count}')
        if (count > 1):
            print(f'{bcolors.FAIL}More than one event @ address: {idx:06x} {bcolors.ENDC}')
            errval += 1
        count = 0

        #print(f'chip: {chip}')
        if chip >= 32:
            chip = 0xFF
        new_list.append(chip)

 #  print(f'length new_list: {len(new_list)}')
    if ((new_list[-1] != 0xFF) or (len(new_list)%8 != 0)):
        while len(new_list)%8 != 0:
            new_list.append(0xFF)  #get to full 8 bytes

    new_list.append(0xFF)  #make endmarker
    while len(new_list)%8 != 0:
        new_list.append(0xFF) 
    
 #  print(f'length padded to: {len(new_list)}')
    return new_list, errval

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

def remove_unnecessary_events(el):
    retlist = []
    ll = len(el)
 #  print(f' Length before: {ll}')
    old_address = 0xFFFFFF
    old_chip = 0xFF
    old_mask = 0xFF
    for i in range(0, len(el), 3):
        address = el[i]
        chip = el[i+1]
        mask = el[i+2]
        if ((chip == old_chip) and (address == old_address + 8) and (mask == old_mask)):
            #print(f'Duplicate found at:  {address:06X}')
            pass
        else:
            retlist.append(address)
            retlist.append(chip)
            retlist.append(mask)

        old_address = address
        old_chip = chip
        old_mask = mask
 #      print(f'Address: {address:06X} chip: {chip:02X}, mask {mask:02X}')
    
 #  print(f' Length after: {len(retlist)}')
    return retlist

def distill_list(ad): # looks at 8 addresses in a row and maps it to bits
    el = []
    ll = len(ad)
    last_byteval = 0
    last_chip = 0
    for i in range(0, ll, 8): # here we go through all the addresses in 8 step
        chips = []
        temp = 0
        for b in range(0, 7, 2): # here we go through the 8 addresses in 2 step
            #print(f'pos: {b}')
            if (i+b) >= ll:
                print(f'{bcolors.FAIL}List ends not on 8 byte border!{bcolors.ENDC}')
                ad.append(0xFF)
            val = ad[i+b]
            if val != temp:
                if val not in chips:
                    chips.append(val)
 #              if val == 0x1E: # this is RAM
 #                  print(f'RAM from: {(i+b):06X}')
 #              elif val == 0xFF: # this is nothing
 #                  print(f'hole from: {(i+b):06X}')
 #              elif val == 0x0E: # this is ROM
 #                  print(f'ROM from: {(i+b):06X}')
 #              elif val < 16:
 #                  print(f'Peripheral with chipselect {val} on low output from: {(i+b):06X}')
 #              else:
 #                  print(f'Peripheral with chipselect {val-16} on high output from: {(i+b):06X}')
            temp = val
        #print(f'Found {len(chips)} chips in the 8 byte range {i} - {i+7}.')
        chips.sort()
        last_i = 0xFFFFFFF
 #      print(f'--------------- working on address: {i:06x} ------------------------')
        for c in range(len(chips)): # here we go through all the chips which have an event in the 8 block
            chip = chips[c]
            byteval = 0xFF
            #print(f'chip: {chip}')
            for b in range(0, 7, 2): # here we go through the 8 addresses in 2 step again
                val = ad[i+b]
                power = (2**int(b/2))%(2**8)
                if val == chip:
                    byteval -= power
                    #print(f'found it. power: {power}, byteval: {byteval:02X} chip: {val}')
                else:
                    #print(f'nothing pos: {power}, val: {val}')
                    pass

            if chip < 0x0E:              # Peripheral on low output
                chiptw = chip
                bytevaltw = byteval
            elif chip == 0x0E:           # RAM
                chiptw = chip
                bytevaltw = ((byteval*16)+(byteval%16))%(2**8) # for ram we don't set the low nibble (Writeprotect)
            elif ((chip > 0x0F) and (chip <  0x1E)): # Per. on high output
                chiptw = chip - 16
                bytevaltw = (byteval*16)%(2**8)+0x0F
            elif (chip == 0x1E):          # ROM
                chiptw = chip - 16
                bytevaltw = (byteval*16)%(2**8)+0x0F
            else:                         # Hole
                chiptw = 0xFF
                bytevaltw = 0xFF

 #          print(f'--------------- adding: address: {i:06x} - {last_i:06x} chip: {chip} - {last_chip}, byteval {byteval:02X} - {last_byteval:02X}')
            if chip%16 == 0x0E:
 #              print(f'RAM or ROM found        {i:06x} - {last_i:06x} chip: {chip} - {last_chip}, byteval {byteval:02X} - {bytevaltw:02X}')
                if (i == last_i):           # same address,
                    if (chip != last_chip): # different RAM/ROM chip
 #                      print(f'switched from ROM -> RAM')
                        el.append(i) # address
                        el.append(chiptw)
                        el.append(bytevaltw)
                    else:                   #  same address, same chip: logical AND
 #                      print(f'same address, same chip')
                        bv = (el[-1]) & bytevaltw
                        el[-1] = bv
                else: 
 #                  print(f'different address')
                    el.append(i) # address
                    el.append(chiptw)
                    el.append(bytevaltw)

            else:
 #              print(f'normal peripheral found {i:06x} - {last_i:06x} chip: {chip} - {last_chip}, byteval {byteval:02X} - {last_byteval:02X}')
                if (i == last_i):           # same address,
                    if (chip%16 != last_chip%16): # different per. chip
 #                      print(f'same address, different chip')
                        el.append(i) # address
                        el.append(chiptw)
                        el.append(bytevaltw)
                    else:                   # same address, same chip: logical AND
 #                      print(f'same address, smae chip')
                        bv = (el[-1]) & bytevaltw
                        el[-1] = bv

                else:
 #                  print(f'different address {i:06x} - {last_i:06x} chip: {chip} - {last_chip}, byteval {byteval:02X} - {last_byteval:02X}')
                    el.append(i) # address
                    el.append(chiptw)
                    el.append(bytevaltw)
                    #pass

            last_i = i
            last_chip = chip
            last_byteval = byteval

        chips = []
    el = remove_unnecessary_events(el)
    return el

def config_per(cf): 
    err = 0
    errval = 0
    try:
        ba = [] # ba is a list of lists. 15 lists for 15 chipselect lines
        keys = len(cf['peripherals'].keys())
        print(f'{bcolors.OKGREEN}--------------------- Configure Peripherals ------------------------{bcolors.ENDC}')
        #print(f'found {keys} keys.')
        for i in range(keys):           # go through keys (like [[ram]])
            name = cf['peripherals'].keys()[i]
            print(f'Found peripheral: {name}')
            addr = []
            if ((name in 'ram') or (name in 'rom')):
                #print(f'ram or rom found, adding cs at 14')
                cs = 14
            for sk in cf['peripherals'][name]:
                if sk[0] == 'l':
                    hl = 0xF0
                elif sk[0] == 'h':
                    hl = 0x0F
                elif 'cs' == sk:
                    pass
                else:
                    if 'ram' in name:
                        hl = 0xF0
                    elif 'rom' in name:
                        hl = 0x0F
                    else:
                        print(f'{bcolors.FAIL}Keynames don\'t start with \'h\' or \'l\' at key: {sk}{bcolors.ENDC}')
                val = int(cf['peripherals'][name][sk],0)
 #              print(f'Key: {sk} with value: {val:04X} found', end = '')
                
                if (('end' in sk) and ((val % 2) == 1)):        # test value (must be odd)
 #                  print(f' - OK.')
                    addr = my_append(addr, val, hl)
 #                  dump_list(addr)
                elif (('start' in sk) and ((val % 2) == 0)):    # test value (must be even) 
 #                  print(f' - OK.')
                    addr = my_append(addr, val, hl)
 #                  dump_list(addr)
                elif ('cs' in sk):
 #                  print(f' - OK.')
                    cs = val
                else:
                    print(f'{bcolors.FAIL}found wrong address (odd/even) at: {val:05X}{bcolors.ENDC}')
                    exit()
 #          print(f'-------------------cs: {cs} len: {len(ba)}')

            while len(ba) <= cs: # make a new list in the right place
                ba.append([])

            if cs == 14:
                ba, err = merge_ram_rom(ba, addr) # the ram and rom list are merged int one, format like the others
 #              print(f'Err: {err}')
                errval += err
            else:
                ba[cs] = addr       
 #          print(f'List: {ba} len: {len(ba)}')

 #      l = []
 #      for li in range(len(ba)):
 #          l = ba[li]
 #          if len(l) > 0:
 #              print(f'Chipselect: {li}')
 #          dump_list(l)

        addresdata , err= collapse_lists(ba) # collapses all 15 lists into one eventlist
        errval += err
 #      dump_list(addresdata)
        el = distill_list(addresdata) # maps it into bits
 #      dump_data(el, 3)

 #      print(f'Errval: {errval}')
        new_file = make_bytearray(el)
        new_file += b'\x00\x00\x00\x00\x00' # this marks is the end (Address = 0)
        write_file(new_file, 'configdata.uc')
        dump_data(new_file, 5)
        #if errval == 0:
        #   fr.main(ser, 'config', new_file)
        #   pass
        return (errval, new_file)
    except Exception as e:
        print(f'Error: {e}')
        #raise

def main(ser, fpath, cf, norom):
    appname = cf['app']['name']
    version = cf['app']['ver']
    computername = cf['computer']['name']
    clockfreqf = int(cf['computer']['freqf'], 0)
    clockfreqs = int(cf['computer']['freqs'], 0)
    #configdata = {}
    print(f'Appname: {appname}, Version: {version}')
    print(f'Configure for:\n\t{computername} \n\t{clockfreqf/1E6:#.6f} MHz fast clock, \n\t{clockfreqs/1E6:#.6f} MHz slow clock.')
    print(f'{bcolors.OKGREEN}-------------------------- Reset Unicomp ---------------------------{bcolors.ENDC}')
    fr.main(ser, 'pins',bytes([0])) # Reset active
    #time.sleep(0.5)
    errval, retval = config_per(cf)
    if errval > 0:
        print(f'Error in config_per!')
        exit()
    print(f'{bcolors.OKGREEN}-------------------------- Upload Config ---------------------------{bcolors.ENDC}')
    fr.main(ser, 'config', retval)
    #time.sleep(1.5)

    print(f'{bcolors.OKGREEN}-------------------------- Turn off Clock --------------------------{bcolors.ENDC}')
    fr.main(ser, 'pins',bytes([3])) # Clock Off

    for k in cf.keys():
        if 'img' in k:
            if norom == 'false':
                if (upload_image(ser, fpath, cf, k)):
                    print(f'{bcolors.FAIL}Problem uploading Image!{bcolors.ENDC}')
            else:
                print(f'{bcolors.FAIL}        ###### actually NOT uploading Image! ######{bcolors.ENDC}')

    for k in cf.keys():
        if 'patch' in k:
            if norom == 'false':
                if (upload_patch(ser, cf, k)):
                    print(f'{bcolors.FAIL}Problem uploading Patch!{bcolors.ENDC}')
                    break
            else:
                print(f'{bcolors.FAIL}        ###### actually NOT applying patch! ######{bcolors.ENDC}')
            

    
    print(f'{bcolors.OKGREEN}------------------------- Configure Clock --------------------------{bcolors.ENDC}')
    clocksettings = fr.read_clock(ser)
    fr.dump_registers(clocksettings)
    newval = [None] * 9
    def_offset = clocksettings[0]
    offset,p0,o_dac,o_div = sf.find_registers(clockfreqf*8, clockfreqs)  # configure Clock
    o_offset = offset + def_offset
    o_mux = clocksettings[4]+256*clocksettings[3]
    o_mux = o_mux & 0x1F9 # Set Prescaler 1 to 1
    temp = o_mux & 0x1E7 # clr bit 3 and 4 (and 9)
    if p0 == 1:
        o_mux = temp 
    elif p0 == 2:
        o_mux = temp | 0x0008
    elif p0 == 4:
        o_mux = temp | 0x0010
    elif p0 == 8:
        o_mux = temp | 0x0018
    o_address = 8
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
    fr.write_clock(ser, bytes(newval))  

    print(f'{bcolors.OKGREEN}----------------------------- Clock on -----------------------------{bcolors.ENDC}')
    fr.main(ser, 'pins',bytes([2])) # Clock On
    print(f'{bcolors.OKGREEN}-------------------------- Reset inactive --------------------------{bcolors.ENDC}')
    fr.main(ser, 'pins',bytes([1]))  # Reset inactive - Run
    print(f'{bcolors.OKGREEN}-------------------------- Modifications  --------------------------{bcolors.ENDC}')
    text1 = cf['modifications']['text']
    print(f'{bcolors.WARNING}{text1}{bcolors.ENDC}')
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
    try:
        ser = Serial(port, 115200, timeout = 1, writeTimeout = 1)
    except IOError:
        print('Port not found!')
        exit()

    ser.flush()
    main(ser, configpath, cf, norom)
    #print('Port flush')
    ser.flush()
    #print('Port close')
    ser.close()
    #try:
    #   ser.close()
    #except:
    #   pass

#!/usr/bin/python3
import sys, os, stat, subprocess, re, binascii, time


ver = 1.20

CPU = "6303" # can also be "hc11"
LABLSPC = 8  # Lable ends at pos 8 (mnemonic starts there)
MNEMSPC = 6  # mnemonic ends at LABLSPC + 8 (argument starts there)
ARGSPC  = 15 # Argument ends at LABLSPC + MNEMSPC + 35 (comment starts there)

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

# Line Format:
# Label (not always) Mnemonic Argument (zero or one field) (;) comment
# ZFFD9              STAB     M00E7                            with or w/o ;
#
NOARGMN = {'ABA','CLRA','CLRB','CBA','COMA','COMB','NEGA','NEGB','DAA',
           'DECA','DECB','INCA','INCB','PSHA','PSHB','PULA','PULB','ROLA',
           'ROLB','RORA','RORB','ASLA','ASLB','ASRA','ASRB','LSRA','LSRB',
           'SBA','TAB','TBA','TSTA','TSTB','SEI','DEX','CLI','RTS','INX',
           'INS','DES','TSX','TXS','CLC','SWI','NOP','RTI','SEC'}

def remove_empty(line):
	retline = ''
	argument = ''
	for i in range(len(line)):
		if line[i] != '':
			argument = line[i]
			retline = line[i+1:]
			return retline, argument.strip()
	return retline, argument

def assemble_comment(tl):
	line = ''
	#print(f'COMMENTLINE:---------> {tl}')
	for p in tl:
		ch = p.strip()
		#print(f'COMMENTBLOCK:---------> {ch}')
		if ch != '' and ch != ';':
			line = line + ch + ' '
	line = line.strip()
	if line.startswith(';'):
		return line[1:]
	else:
		return line

def get_character_string(line):
	al = ''
	for p in line:
		if p != '':
			al = al + p.strip() + ' '
	return al

def modifiy_argument(line):
	al = ''
	al = line
	#print(f'AL: {al}')
	if al.startswith('#'):
		#print(f'####################################### AL # ')
		if al[1] == '\'':
			#print(f'####################################### AL \'')
			al = al + '\''	
	return al

def bt_cmt(line):
	ret = ''
	l = line.split(' ')
	for c in l:
		p = c.strip()
		if p != '':
			#print(f'{p} ')
			ret = ret + p + ' '
	return ret

def parse_line(line):
	label = ''
	mnemonic = ''
	argument = ''
	cmt = ''
	lcmt = ''
	line = line.replace('\t', ' ')
	tl = line.split(' ')
	temp = tl[0]
	#print(f'In Parse_line.. {line} Chunk: {temp}')
	if temp.startswith(";") or temp.startswith("*"):
		cmt = bt_cmt(line)
		return cmt, label, mnemonic, argument, lcmt
	if tl[0] != '':
		label = tl[0]
	tl = tl[1:]
	tl, mnemonic = remove_empty(tl)
	if mnemonic.upper() in NOARGMN:  # no argument
		#argument = '-----'
		#print(f'----------------Mn: {mnemonic.upper()}')
		lcmt = assemble_comment(tl)
	elif mnemonic == 'FCC' or mnemonic == 'fcc': # special case for character strings
		argument = get_character_string(tl)
		#print(f'------- {tl}')
	else:                     # argument
		tl, temp = remove_empty(tl)
		argument = modifiy_argument(temp)
		#tl, temp = remove_empty(tl)
		lcmt = assemble_comment(tl)
	#if tl != '': # comment
	#	lcmt = ''
	#lcmt = tl
	if label == '' and mnemonic == '':
		return ';','','','',''
	else:
		return cmt,label, mnemonic, argument, lcmt

def put_line(filename, line):
	with open(filename, 'a') as fp:
		fp.write(line)

def main(asmfile):
	filename = 'beautified.asm'
	with open(filename, 'w') as fp:
		fp.write('')
	for line in asmfile:
		cmt,label,mnemonic, argument, lcmt = parse_line(line)
		if cmt == '':
			print(f'{label:{LABLSPC}}{mnemonic:{MNEMSPC}}{argument:{ARGSPC}}; {lcmt}')
			put_line(filename, f'{label:{LABLSPC}}{mnemonic:{MNEMSPC}}{argument:{ARGSPC}}; {lcmt}\n')
		else:
			print(f'{cmt}')
			put_line(filename, f'{cmt}\n')

	exit()


if __name__ == '__main__':
	# Here we create the infofile with the usual entries and also
	# check for the disassembler f9dasm or dasmfw
	if len(sys.argv) < 2:
		print(f'{bcolors.FAIL}Please supply sourcefile as argument!{bcolors.ENDC}')
		exit()
	os.system('clear')
	print(f'Scriptversion: {ver}')
	filename = sys.argv[1]
	if os.path.isfile(filename) == False:
		print(f'{bcolors.FAIL}File {filename} does not exist!{bcolors.ENDC}')
		exit()
	#ext = sourcefile.split('.')[-1]
	#filename = sourcefile.split('.')[0]
	#if os.path.isfile(filename+".asm") == False:
	#	print(f'Disassembly not here. Run once...')
	#	exit()
	with open(filename, 'r') as fp:
		asmfile = fp.read().split("\n")
		fp.close()	
	main(asmfile)
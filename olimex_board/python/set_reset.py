#!/usr/bin/env python3

try:
    from pyA20.gpio import gpio
    from pyA20.gpio import port
    from pyA20.gpio import connector
    RST = port.PE11
except ImportError:
    print('set_reset Running on PC')    

import sys
import time

# working: PH0, PH2, PE0..11, PI0..3
def main(val):
    try:
        gpio.init() #Initialize module. Always called first
        gpio.setcfg(RST, gpio.OUTPUT)
        gpio.output(RST, 0)
    except:
        pass

    if val == 1:
        print('Set Reset High')
        try:
            gpio.output(RST, 1)
        except:
            pass
    elif val == 0:
        print('Set Reset Low')
        try:
            gpio.output(RST, 0)
        except:
            pass
    else:
        print('Set Reset Low for 100m')
        try:
            gpio.output(RST, 0)
        except:
            pass

        time.sleep(0.100)
        print('Set Reset High')
        try:
            gpio.output(RST, 1)
        except:
            pass

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Please supply Reset (high = 1 or Low = 0) as argument!')
        exit()
    val = int(sys.argv[1], 0)
    main(val)

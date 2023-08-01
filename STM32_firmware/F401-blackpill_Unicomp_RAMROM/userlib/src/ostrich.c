/*
 * ostrich.c
 *
 *  Created on: Dec 1, 2022
 *      Author: rob
 */

#include <stdio.h>
#include <string.h>
#include "portab.h"
#include "ch.h"
#include "hal.h"
#include "portab.h"
#include "ostrich.h"
#include "chprintf.h"
#include "usbcfg.h"
#include "SPI.h"

extern BaseSequentialStream *const ost;
extern BaseSequentialStream *const dbg;

void debug_print_state(char * text, uint8_t val){
  if (DEBUGLEVEL >= 3){
    switch (val){
    case IDLE:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "IDLE\r\n");
      break;
    case VERSION:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "VERSION\r\n");
      break;
    case BANK:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK\r\n");
      break;
    case BANK_BR:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BR\r\n");
      break;
    case BANK_BRR:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BRR\r\n");
      break;
    case BANK_BES:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BES\r\n");
      break;
    case BANK_BS:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BS\r\n");
      break;
    case BANK_BE:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BE");
      break;
    case BANK_BEE:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BEE\r\n");
      break;
    case BANK_BRn:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BRn\r\n");
      break;
    case BANK_BSn:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BSn\r\n");
      break;
    case BANK_BEn:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BANK_BEn\r\n");
      break;
    case BAUD:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BAUD\r\n");
      break;
    case BAUD_Sn:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BAUD_Sn\r\n");
      break;
    case SERIAL:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "SERIAL\r\n");
      break;
    case SERIAL_NS:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "SERIAL_NS\r\n");
      break;
    case WRITE:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "WRITE\r\n");
      break;
    case WRITE_nM:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "WRITE_nM\r\n");
      break;
    case WRITE_nML:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "WRITE_nML\r\n");
      break;
    case WRITE_nMLB:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "WRITE_nMLB\r\n");
      break;
    case WRITE_nMLCs:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "WRITE_nMLCs\r\n");
      break;
    case READ:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "READ\r\n");
      break;
    case READ_nM:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "READ_nM\r\n");
      break;
    case READ_nML:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "READ_nML\r\n");
      break;
    case READ_nMLCs:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "READ_nMLCs\r\n");
      break;
    case BULK:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK\r\n");
      break;
    case BULK_ZRn:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZRn\r\n");
      break;
    case BULK_ZRnB:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZRnB\r\n");
      break;
    case BULK_ZRnBM:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZRnBM\r\n");
      break;
    case BULK_ZRnBMCs:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZRnBMCs\r\n");
      break;
    case BULK_ZWn:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZWn\r\n");
      break;
    case BULK_ZWnB:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZWnB\r\n");
      break;
    case BULK_ZWnBM:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZWnBM\r\n");
      break;
    case BULK_ZWnBMB:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZWnBMB\r\n");
      break;
    case BULK_ZWnBMBCs:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "BULK_ZWnBMBCs\r\n");
      break;
    case CONFIG_C:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "CONFIG_C\r\n");
      break;
    case CONFIG_Cn:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "CONFIG_Cn\r\n");
      break;
    case CONFIG_CnCs:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "CONFIG_CnCs\r\n");
      break;
    default:
      chprintf(dbg, "%s", text);
      chprintf(dbg, "UNHANDLED\r\n");
      break;
    }
  }
}

void debug_print_val1(char * text, uint16_t val){
  if (DEBUGLEVEL >= 2){
    chprintf(dbg, "%s %04x\r\n", text, val);
  }
}

//extern uint8_t buffer[256];
static THD_WORKING_AREA(waCharacterInputThread, 512);
static THD_FUNCTION(CharacterInputThread, arg) {
  uint8_t c;
  uint8_t tbuf[256];
  uint8_t serial[]={10,1,2,3,4,5,6,7,8};
  uint16_t cntdwn;
  int32_t address;
  static uint8_t bankemv=0, bankemp=0, bankrw=0, bank;
  static uint8_t btemp;
  char_state_t state = IDLE;
  uint8_t checksum;
  systime_t start, end;
  static uint8_t cs, temp;
  static uint16_t i, count;
  static uint16_t zoff;
  (void)arg;
  while (true){
#ifdef OSTRICHUSB
    if (OSTRICHPORT.config->usbp->state == USB_ACTIVE) {
#else
    if (1){
#endif
      c=streamGet(&OSTRICHPORT);
      start = chVTGetSystemTime();

      if (start > end){
        state = IDLE;
      }
      end = chTimeAddX(start, TIME_MS2I(500));
      //sdAsynchronousRead(&OSTRICHPORT, (uint8_t *)&c, 1);
      if (state == IDLE){
        debug_print_state("------------ State0: ------------ ", state);
      }

      switch (state){
      case IDLE:
        cs = c;
        //end = chTimeAddX(chVTGetSystemTimeX(), TIME_MS2I(5));
        //chprintf(dbg, "Checksum 0 is %x\r\n", cs);
        switch (c){
        case 'V':
          state = VERSION;
          debug_print_state("Header Start: ", state);
          break;
        case 'B':
          state = BANK;
          debug_print_state("Header Start: ", state);
          break;
        case 'S':
          state = BAUD;
          debug_print_state("Header Start: ", state);
          break;
        case 'N':
          state = SERIAL;
          debug_print_state("Header Start: ", state);
          break;
        case 'W':
          state = WRITE;
          debug_print_state("Header Start: ", state);
          break;
        case 'R':
          state = READ;
          debug_print_state("Header Start: ", state);
          break;
        case 'Z':
          state = BULK;
          debug_print_state("Header Start: ", state);
          break;
        case 'C':
          state = CONFIG_C;
          debug_print_state("Header Start: ", state);
          break;
        default:
          state = IDLE;
          break;
        }
          break;
        //####################### WRITE ##########################
        case WRITE:
          cs += c;
          state = WRITE_nM;
          debug_print_state("State2: ", state);
          cntdwn = 0;
          if (c == 0){
            count = 256;
          }
          else{
            count = (uint16_t)c;
          }
          //chprintf(dbg, "Count: %u\r\n", count);
          break;
        case WRITE_nM:  //17
          cs += c;
          state = WRITE_nML;
          debug_print_state("State2: ", state);
          //chprintf(dbg, "Addr Hi: %i\r\n", c);
          address =(uint16_t)c;
          address *= 256;
          break;
        case WRITE_nML:  //18
          cs += c;
          state = WRITE_nMLB;
          debug_print_state("State2: ", state);
          address += c;
          //chprintf(dbg, "Address: %i\r\n", address);
          break;
        case WRITE_nMLB:  //19 Here are the Bytes coming
          cs += c;
          //chprintf(dbg, "Countdown1: %i\r\n", cntdwn);
          tbuf[cntdwn++] = c;
          //chprintf(dbg, "Countdown2: %u\r\n", cntdwn);

          //chprintf(dbg, "Char: %x\r\n", c);
          if (cntdwn == count){
            state = WRITE_nMLCs;
            debug_print_state("State2: ", state);
          }
          break;
        case WRITE_nMLCs:  //20
          state = IDLE;
          //chprintf(dbg, "Cs 20: %x Cs got: %x\r\n", cs, c);
          debug_print_state("Got Checksum: ", state);
          debug_print_val1("Checksum: ", cs);
          if (c == cs){
            checksum = 0;
            address += 0x10000*bankrw;
            if (DEBUGLEVEL >= 1){
              chprintf(dbg, "Bulk Write (ML): 0x%6X, cnt: %03d, data: 0x%02X\r\n", address, count, tbuf[0]);
            }
            write_block(address, count, tbuf, 0);
            //streamWrite(ost, (const unsigned char *)buffer, count);
            //cntdwn = count-1;
            //for (i=0; i<count; i++){
            //  buffer[address + i] = tbuf[cntdwn--];
            //}

            chprintf(ost, "O");
          }
          else{
            chprintf(dbg, "Checksum ERROR\r\n");
          }
          break;
        //####################### READ ##########################
        case READ:  //21
          cs += c;
          state = READ_nM;
          debug_print_state("State2: ", state);
          if (c == 0){
            count = 256;
          }
          else{
            count = (uint16_t)c;
          }
          //chprintf(dbg, "Count: %u\r\n", count);
          break;
        case READ_nM:  //22
          cs += c;
          state = READ_nML;
          debug_print_state("State2: ", state);
          address =(uint16_t)c;
          address *= 256;
          break;
        case READ_nML:  //23
          cs += c;
          state = READ_nMLCs;
          debug_print_state("State2: ", state);
          address += c;
          //chprintf(dbg, "Address: %i\r\n", address);
          break;
        case READ_nMLCs:  //24
          state = IDLE;
          debug_print_state("Got Checksum: ", state);
          debug_print_val1("Checksum: ", cs);
          if (c == cs){
            //streamWrite(ost, (const unsigned char *)buffer, count);
            checksum = 0;
            read_block(address+0x10000*bankrw, count, tbuf, 0);
            for (i=0; i<count; i++){
              checksum += tbuf[i];
              streamPut(ost, tbuf[i]);
            }
            streamPut(ost, checksum);
          }
          else{
            chprintf(dbg, "Checksum ERROR\r\n");
          }
            break;
          //####################### BULK  #########################
          case BULK:  //25
            cs += c;
            switch (c){
            case 'R':
              state = BULK_ZRn;
              debug_print_state("State2: ", state);
              break;
            case 'W':
              state = BULK_ZWn;
              debug_print_state("State2: ", state);
              break;
            default:
              state = IDLE;
              debug_print_state("State3: ", state);
              break;
            }
            //chprintf(dbg, "State: %u\r\n", state);
            break;
          //####################### BULK WRITE #####################
          case BULK_ZWn:  //30
            cs += c;
            state = BULK_ZWnB;
            debug_print_state("State2: ", state);
            count = 0;
            if (c == 0){
              count = 256;
            }
            else{
              count = (uint16_t)c;
            }
            //chprintf(dbg, "Count: %u\r\n", count);
            break;
          case BULK_ZWnB:  //31
            cs += c;
            state = BULK_ZWnBM;
            debug_print_state("State2: ", state);
            bank = c;
            //chprintf(dbg, "Bank: %u\r\n", c);
          break;
          case BULK_ZWnBM:  //32
            cs += c;
            state = BULK_ZWnBMB;
            debug_print_state("State2: ", state);
            address = 0;
            address += (uint16_t)c;
            address *= 256;
            address += 0x10000*bank;
            zoff = 0;
            //chprintf(dbg, "Address: %08x\r\n", address);
          break;
          case BULK_ZWnBMB: //33  Here are the Bytes coming
            cs += c;
            tbuf[zoff++] = c;
            //chprintf(dbg, "%02x, %d\r\n", c, zoff);
            if (zoff == count){
              state = BULK_ZWnBMBCs;
              debug_print_state("State2: ", state);
            }
            break;
          case BULK_ZWnBMBCs:  //34
            state = IDLE;
            debug_print_state("Got Checksum: ", state);
            debug_print_val1("Checksum: ", cs);
            if (c == cs){
              if (DEBUGLEVEL >= 1){
                chprintf(dbg, "Bulk Write (ZW): %6X, cnt: %03d, data: %02X %02X %02X %02X\r\n", address, count, tbuf[0], tbuf[1], tbuf[2], tbuf[3]);
              }
              write_block(address, count, tbuf, 0);
              chprintf(ost, "O");            }
            else{
              chprintf(dbg, "Checksum ERROR\r\n");
            }
            break;
          //####################### BULK READ #####################
          case BULK_ZRn:  //26
            cs += c;
            state = BULK_ZRnB;
            debug_print_state("State2: ", state);
            if (c == 0){
              count = 256;
            }
            else{
              count = (uint16_t)c;
            }
            //chprintf(dbg, "Count: %u\r\n", count);
            break;
          case BULK_ZRnB:  //27
            cs += c;
            state = BULK_ZRnBM;
            debug_print_state("State2: ", state);
            bank = c;
            address = (int32_t)c * 65536;
            //chprintf(dbg, "Bank: %u\r\n", c);
          break;
          case BULK_ZRnBM:  //28
            cs += c;
            state = BULK_ZRnBMCs;
            debug_print_state("State2: ", state);
            //address = 0;
            address += (int32_t)c * 256;
            //address *= 256;
            //chprintf(dbg, "Address: %d, %d\r\n", address, c);
          break;
          case BULK_ZRnBMCs:  //29
            state = IDLE;
            debug_print_state("Got Checksum: ", state);
            debug_print_val1("Checksum: ", cs);
            if (c == cs){
              if (DEBUGLEVEL >= 1){
                chprintf(dbg, "Bulk Read (ZR): Addr.: %6X, blocks: 0x%04x\r\n", address, count);
              }
              //streamWrite(ost, (const unsigned char *)buffer, count);
              checksum = read_single_byte(address++, 0);
              streamPut(ost, checksum);
              count *= 256;
              count --;

              while (count){ //Blocks of 256 Bytes
                //chprintf(dbg, "Count: %u\r\n", i);
                //read_block(address+256*i, 256, tbuf);
                //tbuf[0] = read_single_byte(address++, 0);
                tbuf[0] = read_next_byte();
                address++;
                checksum += tbuf[0];
                streamPut(ost, tbuf[0]);
                count--;
              }
              streamPut(ost, checksum);
              //chprintf(dbg, "Bulk Read: Checksum: %u\r\n", checksum);
            }
            else{
              chprintf(dbg, "Checksum ERROR\r\n");
            }
            break;
      //####################### BANK ##########################
      case BANK:
        cs += c;
        switch (c){
        case 'R':
          state = BANK_BR;
          debug_print_state("Header not finished: ", state);
          break;
        case 'S':
          state = BANK_BS;
          debug_print_state("Got Header: ", state);
          break;
        case 'E':
          state = BANK_BE;
          debug_print_state("Got Header: ", state);
          break;
        default:
          state = UNHANDLED;
          break;
        }
        break;
        //---------------------------------------------------------
      case BANK_BR:
        cs += c;
        //chprintf(dbg, "Checksum 2 is %x\r\n", cs);
        if (c == 'R'){                   // B R R
          state = BANK_BRR;
          debug_print_state("Got Header: ", state);
        }
        else{                             // B R + n
          state = BANK_BRn;
          debug_print_state("Got Number: ", state);
          btemp = c;                     // Bank Number
        }
        break;
      case BANK_BRR:
        state = IDLE;
        debug_print_state("Got Checksum: ", state);
        debug_print_val1("Checksum: ", cs);
        if (c == cs){                   // B R R + CS
          //chprintf(ost, "%i", bankrw);
          streamPut(ost, bankrw);
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
      case BANK_BRn:
        state = IDLE;
        debug_print_state("Got Checksum: ", state);
        //chprintf(dbg, "in BRn: %u, %02x, %d\r\n", state, c, btemp);
        if (c == cs){                   // B R + n + CS
          if (btemp <= 8){
            bankrw = btemp;
            chprintf(ost, "O");
            if (DEBUGLEVEL >= 1){
              chprintf(dbg, "Changed RW Bank to %i\r\n", bankrw);
            }
          }
          else{
            chprintf(dbg, "Bank > 8 ERROR\r\n");
          }
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
        //---------------------------------------------------------
      case BANK_BS:                 // B S + n
        cs += c;
        state = BANK_BSn;
        debug_print_state("State2: ", state);
        temp = c;                     // Bank Number
        break;
      case BANK_BSn:
        state = IDLE;
        debug_print_state("State2: ", state);
        debug_print_val1("Checksum: ", cs);
        if (c == cs){                   // B S + n + CS
          if (temp <= 8){
            bankemp = temp;
            chprintf(ost, "O");
            //chprintf(dbg, "Changed Persistent Bank to %i\r\n", bankemp);
          }
          else{
            chprintf(dbg, "Bank > 8 ERROR\r\n");
          }
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
        //---------------------------------------------------------
      case BANK_BE:
        cs += c;
        if ((c == 'E') || (c == 'R')){                   // B E E or B E R
          state = BANK_BEE;
          debug_print_state("State2: ", state);
        }
        else if (c == 'S'){                                       // B E S
          state = BANK_BES;
          debug_print_state("State2: ", state);
        }
        else{                             // B E + n
          state = BANK_BEn;
          debug_print_state("State2: ", state);
          temp = c;                     // Bank Number
        }
        break;
      case BANK_BEE:
        state = IDLE;
        debug_print_state("State3: ", state);
        debug_print_val1("Checksum: ", cs);
        if (c == cs){                   // B E E + CS
          //chprintf(ost, "%i", bankemv);
          streamPut(ost, bankemv);
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
      case BANK_BES:
        state = IDLE;
        debug_print_state("State2: ", state);
        debug_print_val1("Checksum: ", cs);
        if (c == cs){                   // B E S + CS
          //chprintf(ost, bankemp);
          streamPut(ost, bankemp);
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
      case BANK_BEn:
        state = IDLE;
        debug_print_state("State2: ", state);
        if (c == cs){                   // B E + n + CS
          if (temp <= 8){
            bankemv = temp;
            chprintf(ost, "O");
            //chprintf(dbg, "Changed Volatile Bank to %i\r\n", bankemv);
          }
          else{
            chprintf(dbg, "Bank > 8 ERROR\r\n");
          }
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
      //####################### VERSION ##########################
      case VERSION:                   // V V
        state = IDLE;
        debug_print_state("Got Header: ", state);
        if (c == 'V'){
          //chnWrite(&OSTRICHPORT, (const uint8_t *)"\12\5O", 3); // in octal! \12 == 10
          chprintf(ost, "%c%cN", VMAJOR, VMINOR);
        }
        break;
      //####################### SERIAL ##########################
      case SERIAL:
        cs += c;
        if (c == 'S'){                   // N S
          state = SERIAL_NS;
          debug_print_state("Got Header: ", state);
        }
        break;
      case SERIAL_NS:
        state = IDLE;
        debug_print_state("Got Checksum: ", state);
        debug_print_val1("Checksum: ", cs);
        if (c == cs){                   // N S + CS
          // Get Checksum of Serial Number
          temp=0;
          for (i=0;i<sizeof(serial);i++){
            streamPut(ost, serial[i]);
            temp += serial[i];
          }
          //streamWrite(ost, (const unsigned char *)serial, 9);
          streamPut(ost, temp);
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
        //####################### BAUD ##########################
      case BAUD:                   // S + n
        cs += c;
        state = BAUD_Sn;
        debug_print_state("Got Header: ", state);
        break;
      case BAUD_Sn:             // S + n + CS
        state = IDLE;
        debug_print_state("Got Checksum: ", state);
        debug_print_val1("Checksum: ", cs);
        if (cs == c){
          chprintf(ost, "O");
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;
      //####################### CONFIG ##########################
      case CONFIG_C:
        cs += c;
        state = CONFIG_Cn;
        count = (uint16_t)c;
        cntdwn = 0;
        debug_print_val1("Count: ", count);
        break;
      case CONFIG_Cn: //  Here are the Bytes coming
        cs += c;
        tbuf[cntdwn++] = c;
        if (cntdwn == count){
          debug_print_state("State2: ", state);
          state = CONFIG_CnCs;
        }
        break;
      case CONFIG_CnCs:
        debug_print_state("State3: ", state);
        state = IDLE;
        if (c == cs){
          if (DEBUGLEVEL >= 1){
            chprintf(dbg, "Config (C): cnt: %03d, data: %02X, %02X, %02X, %02X\r\n", count, tbuf[0], tbuf[1], tbuf[2], tbuf[3]);
          }
          write_config2(tbuf);
          chprintf(ost, "O");
        }
        else{
          chprintf(dbg, "Checksum ERROR\r\n");
        }
        break;

      case UNHANDLED:
        state = IDLE;
        break;
      }
    }
    else{
      chThdSleepMilliseconds(100);
    }
  }
}
void start_ostrich_thread(void){
  chThdCreateStatic(waCharacterInputThread, sizeof(waCharacterInputThread), NORMALPRIO, CharacterInputThread, NULL);
}


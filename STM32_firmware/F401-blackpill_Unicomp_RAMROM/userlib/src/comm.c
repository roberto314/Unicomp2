/*
 * comm.c
 *
 *  Created on: 04.02.2018
 *      Author: Anwender
 */



#include "ch.h"
#include "hal.h"
#include "comm.h"

#include "chprintf.h"
#include "chscanf.h"
#include "stdlib.h"
#include "string.h" /* for memset */
#include "shell.h"
#include "SPI.h"
#include "ostrich.h"
#include "portab.h"

extern BaseSequentialStream *const ost; //OSTRICHPORT
st_configdata_t cfdat[20];

uint16_t one = 60000;
int16_t two = -22;
uint32_t three = 0xffffffff;
int32_t four = -645599;

/*===========================================================================*/
/* Command line related.                                                     */
/*===========================================================================*/
void cmd_spi(BaseSequentialStream *chp, int argc, char *argv[]){
  (void)* argv;
  (void)argc;
  int32_t val;
  const char * const usage = "Usage: spi2 8bit\r\n";

  if (argc != 1) {
    chprintf(chp, usage);
    return;
  }
  val = (int32_t)strtol(argv[0], NULL, 0);
  chprintf(chp, "You entered: %08x \r\n", val);
//  WriteSPI(val);
}

void cmd_fill(BaseSequentialStream *chp, int argc, char *argv[]){
  (void)* argv;
  (void)argc;
  int32_t address, acnt, lcnt;
  uint8_t d;
  uint8_t data[256];
  const char * const usage = "Usage: fill count address byte\r\n";
  chprintf(chp, "Fills block with bytes from address\r\n");
  if (argc != 3) {
    chprintf(chp, usage);
    return;
  }
  lcnt = (int32_t)strtol(argv[0], NULL, 0);
  address = (int32_t)strtol(argv[1], NULL, 0);
  d  = (uint8_t)strtol(argv[2], NULL, 0);
  if (lcnt > 256){
    chprintf(chp, "Only 256 bytes for now\r\n");
    return;
  }
  chprintf(chp, "Starting at: %8x blocksize: %8x \r\n", address, lcnt);


  for (acnt = 0; acnt < lcnt; acnt ++){
    data[acnt] = d;
  }
  write_block(address, lcnt, data, 0);
  chprintf(chp, "OK.\r\n");
}

void cmd_br(BaseSequentialStream *chp, int argc, char *argv[]){
  (void)* argv;
  (void)argc;
  int32_t address, acnt, lcnt;
  uint8_t d, line=0;
  uint8_t data[256];
  const char * const usage = "Usage: br count address \r\n";
  chprintf(chp, "Prints block of bytes from address\r\n");
  if (argc != 2) {
    chprintf(chp, usage);
    return;
  }
  memset(data,0,256);
  address = (int32_t)strtol(argv[1], NULL, 0);
  lcnt = (int32_t)strtol(argv[0], NULL, 0);
  if (lcnt > 256){
    chprintf(chp, "Only 256 bytes for now\r\n");
    return;
  }
  chprintf(chp, "Starting at: %08x\r\n", address);
  read_block(address, lcnt, data, 0);

  for (acnt = 0; acnt < lcnt; acnt ++){
    d=data[acnt];
    chprintf(chp, "%02x, ", d);
    line++;
    if (line % 8 == 0){
      chprintf(chp, "\r\n");
    }
    if (line % 32 == 0){
      chprintf(chp, "Address now: %08x\r\n", address+acnt+1);
      line = 0;
    }
  }
}

void cmd_rb(BaseSequentialStream *chp, int argc, char *argv[]){
  (void)* argv;
  (void)argc;
  int32_t address;
  uint8_t data;
  const char * const usage = "Usage: rb address \r\n";
  chprintf(chp, "Reads byte from address\r\n");
  if (argc != 1) {
    chprintf(chp, usage);
    return;
  }
  address = (int32_t)strtol(argv[0], NULL, 0);
  data=read_single_byte(address, 0);
  chprintf(chp, "Data on %08x is %02x\r\n", address, data);

}

void cmd_wb(BaseSequentialStream *chp, int argc, char *argv[]){
  (void)* argv;
  (void)argc;
  uint8_t data;
  int32_t address;
  const char * const usage = "Usage: wb address data \r\n";
  chprintf(chp, "Writes byte to address\r\n");
  if (argc != 2) {
    chprintf(chp, usage);
    return;
  }
  address = (int32_t)strtol(argv[0], NULL, 0);
  data = (uint8_t)strtol(argv[1], NULL, 0);

  write_single_byte(data, address, 0);
  chprintf(chp, "Data: %02x @ address %08x\r\n", data, address);
}

void cmd_wc(BaseSequentialStream *chp, int argc, char *argv[]){
  (void)* argv;
  (void)argc;
  //uint8_t data;
  //int32_t address;
  const char * const usage = "Usage: wc\r\n";
  chprintf(chp, "Writes config data\r\n");
  if (argc < 2) {
    chprintf(chp, usage);
//    return;
  }
//  cfdat[0] = (st_configdata_t){
//    .address = 0,
//    .data[0]  = 0xFF,
//    .data[1]  = 0xFF,
//    .data[2]  = 0xFF,
//    .data[3]  = 0xFF,
//    .data[4]  = 0xFF,
//    .data[5]  = 0xFF,
//    .data[6]  = 0xFF,
//    .data[7]  = 0xFF,
//    .data[8]  = 0xFF,
//    .data[9]  = 0xFF,
//    .data[10]  = 0xFF,
//    .data[11]  = 0xFF,
//    .data[12]  = 0xFF,
//    .data[13]  = 0xFF,
//    .data[14]  = 0x00 //00 for RAM, 0F for ROM
//  };
//  cfdat[1] = (st_configdata_t){
//    .address = 0x8000,
//    .data[0]  = 0xFF,
//    .data[1]  = 0xFF,
//    .data[2]  = 0xFF,
//    .data[3]  = 0xFF,
//    .data[4]  = 0xFF,
//    .data[5]  = 0xFF,
//    .data[6]  = 0xFF,
//    .data[7]  = 0xFF,
//    .data[8]  = 0xFF,
//    .data[9]  = 0xFF,
//    .data[10]  = 0xFF,
//    .data[11]  = 0xFF,
//    .data[12]  = 0xFF,
//    .data[13]  = 0xFF,
//    .data[14]  = 0xFF
//  };
//  cfdat[2] = (st_configdata_t){
//    .address = 0xA000,
//    .data[0]  = 0x00, // High nibble is ACIA1, Low nibble ACIA2
//    .data[1]  = 0xFF,
//    .data[2]  = 0xFF,
//    .data[3]  = 0xFF,
//    .data[4]  = 0xFF,
//    .data[5]  = 0xFF,
//    .data[6]  = 0xFF,
//    .data[7]  = 0xFF,
//    .data[8]  = 0xFF,
//    .data[9]  = 0xFF,
//    .data[10]  = 0xFF,
//    .data[11]  = 0xFF,
//    .data[12]  = 0xFF,
//    .data[13]  = 0xFF,
//    .data[14]  = 0xFF
//  };
//  cfdat[3] = (st_configdata_t){
//    .address = 0xB000,
//    .data[0]  = 0xFF,
//    .data[1]  = 0xFF,
//    .data[2]  = 0xFF,
//    .data[3]  = 0xFF,
//    .data[4]  = 0xFF,
//    .data[5]  = 0xFF,
//    .data[6]  = 0xFF,
//    .data[7]  = 0xFF,
//    .data[8]  = 0xFF,
//    .data[9]  = 0xFF,
//    .data[10]  = 0xFF,
//    .data[11]  = 0xFF,
//    .data[12]  = 0xFF,
//    .data[13]  = 0xFF,
//    .data[14]  = 0xFF
//  };
//  cfdat[4] = (st_configdata_t){
//    .address = 0xC000,
//    .data[0]  = 0xFF,
//    .data[1]  = 0xFF,
//    .data[2]  = 0xFF,
//    .data[3]  = 0xFF,
//    .data[4]  = 0xFF,
//    .data[5]  = 0xFF,
//    .data[6]  = 0xFF,
//    .data[7]  = 0xFF,
//    .data[8]  = 0xFF,
//    .data[9]  = 0xFF,
//    .data[10]  = 0xFF,
//    .data[11]  = 0xFF,
//    .data[12]  = 0xFF,
//    .data[13]  = 0xFF,
//    .data[14]  = 0x0F
//  };
//  cfdat[5] = (st_configdata_t){
//    .address = 0x10000,
//    .data[0]  = 0xFF,
//    .data[1]  = 0xFF,
//    .data[2]  = 0xFF,
//    .data[3]  = 0xFF,
//    .data[4]  = 0xFF,
//    .data[5]  = 0xFF,
//    .data[6]  = 0xFF,
//    .data[7]  = 0xFF,
//    .data[8]  = 0xFF,
//    .data[9]  = 0xFF,
//    .data[10]  = 0xFF,
//    .data[11]  = 0xFF,
//    .data[12]  = 0xFF,
//    .data[13]  = 0xFF,
//    .data[14]  = 0xFF
//  };
//  cfdat[6] = (st_configdata_t){
//    .address = 0x0000,
//    .data[0]  = 0xFF,
//    .data[1]  = 0xFF,
//    .data[2]  = 0xFF,
//    .data[3]  = 0xFF,
//    .data[4]  = 0xFF,
//    .data[5]  = 0xFF,
//    .data[6]  = 0xFF,
//    .data[7]  = 0xFF,
//    .data[8]  = 0xFF,
//    .data[9]  = 0xFF,
//    .data[10]  = 0xFF,
//    .data[11]  = 0xFF,
//    .data[12]  = 0xFF,
//    .data[13]  = 0xFF,
//    .data[14]  = 0xFF
//  };
  write_config(&cfdat[0]);
  chprintf(chp, "Done.\r\n");
}

void cmd_test(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)* argv;
  (void)argc;
  char text[10];
  uint16_t val;

  chprintf(chp, "Enter Number (<256) \r\n");
//  ret = chscanf(chp, "%7s", &text);
  if (chscanf((BaseBufferedStream *)chp, "%10s", &text) != 1){
    chprintf(chp, "Something went wrong\r\n");
    return;
  }
  val = (uint16_t)strtol(text, NULL, 0);

  chprintf(chp, "You entered text: %s Val: %04x got: %02x\r\n",
                      text, val);
  chprintf(ost, "OK\r\n");

}


#if DEBUGFUNCTIONS > 0
void cmd_reg32(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)argv;
  if (argc != 1) {
    chprintf(chp, "Changes 32bit Register Value\r\n");
    chprintf(chp, "Usage: reg VALUE\r\n");
    chprintf(chp, "Base is: 0x%08X\r\n", bas);
    chprintf(chp, "Offset is: 0x%02X\r\n", off);
    chprintf(chp, "Value at Offset 0x%02X is 0x%08X\r\n", off, *(uint32_t *)(bas+off));
    return;
  }
  uint32_t val = strtol(argv[0], NULL, 16);
  *(uint32_t *)(bas+off) = val;
  chprintf(chp, "Value at Offset 0x%02X is 0x%08X\r\n", off, *(uint32_t *)(bas+off));
}
void cmd_reg16(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)argv;
  if (argc != 1) {
    chprintf(chp, "Changes 16bit Register Value\r\n");
    chprintf(chp, "Usage: reg VALUE\r\n");
    chprintf(chp, "Base is: 0x%08X\r\n", bas);
    chprintf(chp, "Offset is: 0x%02X\r\n", off);
    chprintf(chp, "Value at Offset 0x%02X is 0x%04X\r\n", off, *(uint16_t *)(bas+off));
    return;
  }
  uint16_t val = (uint16_t )strtol(argv[0], NULL, 16);
  *(uint16_t *)(bas+off) = val;
  chprintf(chp, "Value at Offset 0x%02X is 0x%04X\r\n", off, *(uint16_t *)(bas+off));
}
void cmd_bas(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)argv;
  if (argc != 1) {
    chprintf(chp, "Changes Base Adress\r\n");
    chprintf(chp, "Usage: bas VALUE\r\n");
    chprintf(chp, "Base is: 0x%08X\r\n", bas);
    return;
  }
  bas = strtol(argv[0], NULL, 16);
  chprintf(chp, "Changed value to: 0x%08X\r\n", bas);
}
void cmd_off(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)argv;
  if (argc != 1) {
    chprintf(chp, "Changes Offset Adress\r\n");
    chprintf(chp, "Usage: off VALUE\r\n");
    chprintf(chp, "Offset is: 0x%02X\r\n", off);
    return;
  }
  off = strtol(argv[0], NULL, 16);
  chprintf(chp, "Changed value to: 0x%02X\r\n", off);
}
void shellModifyu16(BaseSequentialStream *chp, uint16_t * modify_p) {
  chprintf(chp, "Welcome to modify u16\r\n");
  chprintf(chp, "press '+' to increase one, '-' to decrease one \r\n");
  chprintf(chp, "'D' to increase 10, 'd' to decrease 10 \r\n");
  chprintf(chp, "'C' to increase 100, 'c' to decrease 100 \r\n");
  chprintf(chp, "'M' to increase 1000, 'm' to decrease 1000 \r\n");
  chprintf(chp, "'*' to multiply with 10, '/' to divide by 10 \r\n");
  chprintf(chp, "press 'x' to exit \r\n");

  chprintf(chp, "Status of var is: %u\r\n", *modify_p);
  while (true) {
    char c;

    if (streamRead(chp, (uint8_t *)&c, 1) == 0)
      chThdSleepMilliseconds(250);

    if (c == '+') {
      (*modify_p)++;
    }
    if (c == '-') {
      (*modify_p)--;
    }
    if (c == 'D') {
      *modify_p += 10;
    }
    if (c == 'd') {
      *modify_p -= 10;
    }
    if (c == 'C') {
      *modify_p += 100;
    }
    if (c == 'c') {
      *modify_p -= 100;
    }
    if (c == 'M') {
       *modify_p += 1000;
     }
     if (c == 'm') {
       *modify_p -= 1000;
     }
    if (c == '*') {
      *modify_p *= 10;
    }
    if (c == '/') {
      *modify_p /= 10;
    }
    if (c == 'x') {
      chprintf(chp, "EXIT\r\n");
      return;
    }
    if (c < 0x20)
      continue;
    chprintf(chp, "%u\r\n", *modify_p);
    //update_values(modify_p);
  }
}
void shellModifys16(BaseSequentialStream *chp, int16_t * modify_p) {
  chprintf(chp, "Welcome to modify s16\r\n");
  chprintf(chp, "press '+' to increase one, '-' to decrease one \r\n");
  chprintf(chp, "'u' to increase 10, 'd' to decrease 10 \r\n");
  chprintf(chp, "'U' to increase 100, 'D' to decrease 100 \r\n");
  chprintf(chp, "'*' to multiply with 10, '/' to divide by 10 \r\n");
  chprintf(chp, "press 'x' to exit \r\n");

  chprintf(chp, "Status of var is: %d\r\n", *modify_p);
  while (true) {
    char c;

    if (streamRead(chp, (uint8_t *)&c, 1) == 0)
      chThdSleepMilliseconds(250);

    if (c == '+') {
      (*modify_p)++;
    }
    if (c == '-') {
      (*modify_p)--;
    }
    if (c == 'u') {
      *modify_p += 10;
    }
    if (c == 'd') {
      *modify_p -= 10;
    }
    if (c == 'U') {
      *modify_p += 100;
    }
    if (c == 'D') {
      *modify_p -= 100;
    }
    if (c == '*') {
      *modify_p *= 10;
    }
    if (c == '/') {
      *modify_p /= 10;
    }
    if (c == 'x') {
      chprintf(chp, "EXIT\r\n");
      return;
    }
    if (c < 0x20)
      continue;
    chprintf(chp, "%d\r\n", *modify_p);
  }
}
void shellModifyu32(BaseSequentialStream *chp, uint32_t * modify_p) {
  chprintf(chp, "Welcome to modify u32\r\n");
  chprintf(chp, "press '+' to increase one, '-' to decrease one \r\n");
  chprintf(chp, "'u' to increase 10, 'd' to decrease 10 \r\n");
  chprintf(chp, "'U' to increase 100, 'D' to decrease 100 \r\n");
  chprintf(chp, "'*' to multiply with 10, '/' to divide by 10 \r\n");
  chprintf(chp, "press 'x' to exit \r\n");

  chprintf(chp, "Status of var is: %u\r\n", *modify_p);
  while (true) {
    char c;

    if (streamRead(chp, (uint8_t *)&c, 1) == 0)
      chThdSleepMilliseconds(250);

    if (c == '+') {
      (*modify_p)++;
    }
    if (c == '-') {
      (*modify_p)--;
    }
    if (c == 'u') {
      *modify_p += 10;
    }
    if (c == 'd') {
      *modify_p -= 10;
    }
    if (c == 'U') {
      *modify_p += 100;
    }
    if (c == 'D') {
      *modify_p -= 100;
    }
    if (c == '*') {
      *modify_p *= 10;
    }
    if (c == '/') {
      *modify_p /= 10;
    }
    if (c == 'x') {
      chprintf(chp, "EXIT\r\n");
      return;
    }
    if (c < 0x20)
      continue;
    chprintf(chp, "%u\r\n", *modify_p);
  }
}
void shellModifys32(BaseSequentialStream *chp, int32_t * modify_p) {
  chprintf(chp, "Welcome to modify s32\r\n");
  chprintf(chp, "press '+' to increase one, '-' to decrease one \r\n");
  chprintf(chp, "'u' to increase 10, 'd' to decrease 10 \r\n");
  chprintf(chp, "'U' to increase 100, 'D' to decrease 100 \r\n");
  chprintf(chp, "'*' to multiply with 10, '/' to divide by 10 \r\n");
  chprintf(chp, "press 'x' to exit \r\n");

  chprintf(chp, "Status of var is: %d\r\n", *modify_p);
  while (true) {
    char c;

    if (streamRead(chp, (uint8_t *)&c, 1) == 0)
      chThdSleepMilliseconds(250);

    if (c == '+') {
      (*modify_p)++;
    }
    if (c == '-') {
      (*modify_p)--;
    }
    if (c == 'u') {
      *modify_p += 10;
    }
    if (c == 'd') {
      *modify_p -= 10;
    }
    if (c == 'U') {
      *modify_p += 100;
    }
    if (c == 'D') {
      *modify_p -= 100;
    }
    if (c == '*') {
      *modify_p *= 10;
    }
    if (c == '/') {
      *modify_p /= 10;
    }
    if (c == 'x') {
      chprintf(chp, "EXIT\r\n");
      return;
    }
    if (c < 0x20)
      continue;
    chprintf(chp, "%d\r\n", *modify_p);
  }
}
void cmd_status(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)argc;
  (void)* argv;
  chprintf(chp, "Status of Variables is: %u %d %u %d\r\n", one, two, three, four);
}
void cmd_modify(BaseSequentialStream *chp, int argc, char *argv[]) {
  const char * const usage = "Usage: mod NUMBER\r\n";

  if (argc != 1) {
    chprintf(chp, usage);
    return;
  }
  //uint16_t nr = (uint16_t)atoi(argv[0]);

  switch (atoi(argv[0])){
  case 0:
    shellModifyu16(chp, &one);
    break;
  case 1:
    shellModifys16(chp, &two);
    break;
  case 2:
    shellModifyu32(chp, &three);
   break;
  case 3:
    shellModifys32(chp, &four);
    break;
  default:
    chprintf(chp, "something went wrong\r\n");
    break;
  }
}
#endif

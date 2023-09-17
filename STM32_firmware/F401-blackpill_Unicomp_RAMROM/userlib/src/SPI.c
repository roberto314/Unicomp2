/*
 * SPI.c
 *
 *  Created on: Nov 19, 2022
 *      Author: rob
 */

#include "ch.h"
#include "hal.h"
#include "chprintf.h"
#include "SPI.h"
#include "ostrich.h"
#include "portab.h"
#include "i2c.h"

extern BaseSequentialStream *const chout;
extern st_configdata_t cfdat[20];
extern BaseSequentialStream *const dbg;
volatile uint8_t BUS_in_use;

// SPI setup ajust " SPI_BaudRatePrescaler_X" to set SPI speed.
// Peripherial Clock 42MHz SPI2 SPI3
// Peripherial Clock 84MHz SPI1                                SPI1        SPI2/3
#define SPI_BaudRatePrescaler_2         ((uint16_t)0x0000) //  42 MHz      21 MHZ
#define SPI_BaudRatePrescaler_4         ((uint16_t)0x0008) //  21 MHz      10.5 MHz
#define SPI_BaudRatePrescaler_8         ((uint16_t)0x0010) //  10.5 MHz    5.25 MHz
#define SPI_BaudRatePrescaler_16        ((uint16_t)0x0018) //  5.25 MHz    2.626 MHz
#define SPI_BaudRatePrescaler_32        ((uint16_t)0x0020) //  2.626 MHz   1.3125 MHz
#define SPI_BaudRatePrescaler_64        ((uint16_t)0x0028) //  1.3125 MHz  656.25 KHz
#define SPI_BaudRatePrescaler_128       ((uint16_t)0x0030) //  656.25 KHz  328.125 KHz
#define SPI_BaudRatePrescaler_256       ((uint16_t)0x0038) //  328.125 KHz 164.06 KHz
static SPIConfig spi_cfg_8 = { //Config for 8bits
  FALSE,
  NULL,
  NULL,
  0,
  SPI_BaudRatePrescaler_4 ,// CPOL = 0| SPI_CR1_CPOL, // CPOL = 1
  0
};

static void gptcb(GPTDriver *drv){
  (void)drv;
  BUS_in_use = 0;
  DEBUG_HI;
  //palToggleLine(DEBUG);
  //gptStopTimerI(drv);
}
/*
 * GPT6 configuration.
 */
static const GPTConfig gpt5cfg1 = {
  .frequency    = 1000000U, //1MHz Timer Freq.
  .callback     = gptcb,
  .cr2          = 0U,
  .dier         = 0U
};

static void write_byte(uint8_t data);
static uint8_t read_byte(void);

void select_chip(uint8_t chip){
  switch(chip&0x0f){
  case 0:
      palClearLine(SEL0);
      palClearLine(SEL1);
      palClearLine(SEL2);
      palClearLine(SEL4);
      break;
  case 1:
      palSetLine(SEL0);
      palClearLine(SEL1);
      palClearLine(SEL2);
      palClearLine(SEL4);
      break;
  case 2:
      palClearLine(SEL0);
      palSetLine(SEL1);
      palClearLine(SEL2);
      palClearLine(SEL4);
      break;
  case 3:
      palSetLine(SEL0);
      palSetLine(SEL1);
      palClearLine(SEL2);
      palClearLine(SEL4);
      break;
  case 4:
      palClearLine(SEL0);
      palClearLine(SEL1);
      palSetLine(SEL2);
      palClearLine(SEL4);
      break;
  case 5:
      palSetLine(SEL0);
      palClearLine(SEL1);
      palSetLine(SEL2);
      palClearLine(SEL4);
      break;
  case 6:
      palClearLine(SEL0);
      palSetLine(SEL1);
      palSetLine(SEL2);
      palClearLine(SEL4);
      break;
  case 7:
      palSetLine(SEL0);
      palSetLine(SEL1);
      palSetLine(SEL2);
      palClearLine(SEL4);
      break;
  case 8:
      palClearLine(SEL0);
      palClearLine(SEL1);
      palClearLine(SEL2);
      palSetLine(SEL4);
      break;
  case 9:
      palSetLine(SEL0);
      palClearLine(SEL1);
      palClearLine(SEL2);
      palSetLine(SEL4);
      break;
  case 10:
      palClearLine(SEL0);
      palSetLine(SEL1);
      palClearLine(SEL2);
      palSetLine(SEL4);
      break;
  case 11:
      palSetLine(SEL0);
      palSetLine(SEL1);
      palClearLine(SEL2);
      palSetLine(SEL4);
      break;
  case 12:
      palClearLine(SEL0);
      palClearLine(SEL1);
      palSetLine(SEL2);
      palSetLine(SEL4);
      break;
  case 13:
      palSetLine(SEL0);
      palClearLine(SEL1);
      palSetLine(SEL2);
      palSetLine(SEL4);
      break;
  case 14:
      palClearLine(SEL0);
      palSetLine(SEL1);
      palSetLine(SEL2);
      palSetLine(SEL4);
      break;
  case 15:
      palSetLine(SEL0);
      palSetLine(SEL1);
      palSetLine(SEL2);
      palSetLine(SEL4);
      break;
  }
}

//void wait_nops(void){
//    __NOP();
//    __NOP();
//    __NOP();
//    __NOP();
//}

static void latch_address(void){
  CPR_ACTIVE;
  __NOP();
  CPR_INACTIVE;
}

static void increment_address(void){
  CNT_ACTIVE;
  __NOP();
  CNT_INACTIVE;
  __NOP();
}

void increment_address8(void){
  uint8_t i;
  for (i=0; i<8; i++){
    increment_address();
  }
}

void setup_address(int32_t address){
  int32_t i;
  MRC_ACTIVE;  // Reset '590
  __NOP();
  MRC_INACTIVE;
  for (i=0; i<address; i++){
    increment_address();
  }
//  __NOP();
  return;
}

static void latch_data_in(void){
  WE_ACTIVE;
  __NOP();
//  __NOP();
  WE_INACTIVE;
}

static void check_BUS(void){
  /* Check if BUS is used at all. If not there is a timer callback after 1ms
      which sets the variable BUS_in_use to 0 . */
  DEBUG_LOW;
  BUS_in_use = 1;
  gptStartContinuous(&GPTD5, 1000U);
  while ((palReadLine(BUSFREE) == PAL_LOW) && BUS_in_use == 1);
  if (DEBUGLEVEL >= 1){
      if (BUS_in_use == 0){
        chprintf(dbg, "BUSFREE is staying Low.\r\n");
      }
      else {
        chprintf(dbg, "BUSFREE is changing.\r\n");
      }
  }
  gptStopTimer(&GPTD5);
}

static inline void wait_for_busfree(void){
  if (BUS_in_use == 0){
    return;
  }
  while (palReadLine(BUSFREE) == PAL_LOW);
  while (palReadLine(BUSFREE) == PAL_HIGH);
}

static void write_byte(uint8_t data){
  uint8_t buf[1];
  buf[0] = data;
  spiSend(SPI_DRIVER, 1, buf);
  latch_address();
  chSysLock();
  wait_for_busfree(); // this adds about 130ns after falling edge of BUSFREE
  CNTOE_ACTIVE;
  __NOP();
  latch_data_in();
  CNTOE_INACTIVE;
  chSysUnlock();
}

static uint8_t read_byte(void){
  uint8_t ret;
  latch_address();
//  DEBUG_LOW;
  chSysLock();
  wait_for_busfree(); // this adds about 130ns after falling edge of BUSFREE
//  DEBUG_HI;
  CNTOE_ACTIVE;
  __NOP();
  __NOP();
  RAMOE_ACTIVE;
//  __NOP();
  __NOP();
  __NOP();
//  __NOP();
  PLD_LOAD;
//  __NOP();
  __NOP();
  PLD_IDLE;
  RAMOE_INACTIVE;
  CNTOE_INACTIVE;
  chSysUnlock();
  spiReceive(SPI_DRIVER, 1, &ret);
  return ret;
}

void write_single_byte(uint8_t data, int32_t address, uint8_t reset){
  setup_address(address);
  select_chip(15); // RAM is Chip 15
  check_BUS();
  if (reset){
    TRESET_ACTIVE;
    BUS_in_use = 0;
  }
  write_byte(data);
  if (reset){
    TRESET_INACTIVE;
    BUS_in_use = 1;
  }
}

uint8_t read_single_byte(int32_t address, uint8_t reset){
  uint8_t data = 0;
  setup_address(address);
  check_BUS();
  if (reset){
    TRESET_ACTIVE;
    BUS_in_use = 0;
  }
  data = read_byte();
  if (reset){
    TRESET_INACTIVE;
    BUS_in_use = 1;
  }
  return data;
}

uint8_t read_next_byte(void){
  uint8_t data = 0;
  increment_address();
  __NOP();
  data = read_byte();
  return data;
}

void write_next_byte(uint8_t data){
  increment_address();
  __NOP();
  write_byte(data);
}

void read_block(int32_t address, int32_t len, uint8_t * data, uint8_t reset){
  int32_t l = len;
  setup_address(address);
  check_BUS();
  if (reset){
    TRESET_ACTIVE;
    BUS_in_use = 0;
  }
  while(l--){
    *data++ = read_byte();
    increment_address();
  }
  if (reset){
    TRESET_INACTIVE;
    BUS_in_use = 1;
  }
}

void write_block(int32_t address, int32_t len, uint8_t * data, uint8_t reset){
  int32_t l = len;
  select_chip(15);
  setup_address(address);
  check_BUS();
  if (reset){
    TRESET_ACTIVE;
    BUS_in_use = 0;
  }
  write_byte(*data++);
  l--;
  while(l--){
    increment_address();
    write_byte(*data++);
  }
  if (reset){
    TRESET_INACTIVE;
    BUS_in_use = 1;
  }
}

void fill_struct(uint8_t* in, st_configdata_t* out){
  out->_8h  = 0;
  out->_8hm = *in++;
  out->_8lm = *in++;
  out->_8l  = *in++;
  out->cs   = *in++;
  out->mask = *in++;
}

#define ADDRESS (cfdat._32)
#define NEXTADDRESS (nextcf._32)
#define CHIP (cfdat.cs)
#define MASK (cfdat.mask)

void write_config(uint8_t* buf){
  uint8_t chip, data = 0, no_update = 0;
  uint32_t address = 0;
  st_configdata_t cfdat, nextcf;
  fill_struct(buf, &cfdat);

  TRESET_ACTIVE;
  BUS_in_use = 0;
  setup_address(address);
  latch_address();
  CNTOE_ACTIVE;
  if (DEBUGLEVEL >= 2){
    uint8_t* dbgptr = buf;
    do{
      chprintf(dbg, "Address: %08X cs: %02X mask: %02X\r\n", ADDRESS, CHIP, MASK);
      dbgptr += 5; // go to next set of values (5 byte forward)
      fill_struct(dbgptr, &cfdat);
    } while(ADDRESS != 0);
    fill_struct(buf, &cfdat);
    buf += 5;
    fill_struct(buf, &nextcf);
  }
  if (DEBUGLEVEL >= 2){
    chprintf(dbg, "first event reached @: %06X Poking: %02X into %02X\r\n", ADDRESS, MASK, CHIP);
  }
    do {
      do { // here we go through all addresses
        for (chip = 0; chip < 15; chip++){ // write 15 RAMs chips, each one byte
          select_chip(chip);
          if (chip == CHIP){ // check if we have to change the value
            data = MASK;
//            select_chip(chip);
            spiSend(SPI_DRIVER, 1, &data);
            latch_data_in();
            if ((address >= 0x9FF0) && (DEBUGLEVEL >= 2) && (address <= 0xA008)){
              chprintf(dbg, "1address: %06X chip: %02X data: %02X nupd: %d\r\n", address, chip, data, no_update);
            }
          }
          else{
            if (data != 0xFF){
              data = 0xFF; //always assume NOT selected
              spiSend(SPI_DRIVER, 1, &data);
            }
            if (no_update == 0){
//              select_chip(chip);
              latch_data_in();
//              if ((address >= 0x9FF0) && (DEBUGLEVEL >= 2) && (address <= 0xA008)){
//                chprintf(dbg, "4address: %06X chip: %02X data: %02X nupd: %d\r\n", address, chip, data, no_update);
//              }
            }
          }
        } //--------------------------- Write chips
        if ((address + 8) <= NEXTADDRESS){
          increment_address8();
          latch_address();
          address += 8; // CPU address is mapping ram address / 8!
          no_update = 0;
        }
        else{// we have a small window of less than 8 addresses
          no_update = 1;
        }
//        if ((address >= 0xA000) && (DEBUGLEVEL >= 2) && (address <= 0xA010)){
//          chprintf(dbg, "3address: %06X chip: %02X data: %02X nupd: %d\r\n", address, CHIP, data, no_update);
//        }
      } while (address < NEXTADDRESS); // go until next event is reached
      fill_struct(buf, &cfdat);
      buf += 5;
      fill_struct(buf, &nextcf);
      if (DEBUGLEVEL >= 2){
        chprintf(dbg, "Next event reached @: %06X Poking: %02X into %02X\r\n", address, MASK, CHIP);
      }
    } while (NEXTADDRESS); // a zero at an address (other than position 0) means stop.
  CNTOE_INACTIVE;
  TRESET_INACTIVE;
  BUS_in_use = 1;
}

void write_pins(uint8_t data){
  switch (data){
  case 0:
    TRESET_ACTIVE;
    break;
  case 1:
    TRESET_INACTIVE;
    break;
  case 2:
    OUTPUT_ON;
    break;
  case 3:
    OUTPUT_OFF;
    break;
  }
}

void SPI_init(void){
  palSetPadMode(SPI_PORT, SCK_PAD, PAL_MODE_ALTERNATE(5) | PAL_STM32_OSPEED_HIGHEST);
  palSetPadMode(SPI_PORT, MOSI_PAD, PAL_MODE_ALTERNATE(5) | PAL_STM32_OSPEED_HIGHEST);
  palSetPadMode(SPI_PORT, MISO_PAD, PAL_MODE_ALTERNATE(5) | PAL_STM32_OSPEED_HIGHEST);

  palClearLine(SEL0);
  palClearLine(SEL1);
  palClearLine(SEL2);
  palClearLine(SEL4);

  PLD_IDLE;
  WE_INACTIVE;
  CNT_INACTIVE;
  MRC_INACTIVE;
  CPR_INACTIVE;
  CNTOE_INACTIVE;
  RAMOE_INACTIVE;
  TRESET_INACTIVE;
  DEBUG_HI;
  palSetLineMode(BUSFREE, PAL_MODE_INPUT);
  palSetLineMode(PLD, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(ON_OFF, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(CNT, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(MRC, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(CPR, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(CNTOE, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(RAMOE, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(TRESET, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(SEL0, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(SEL1, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(SEL2, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(SEL4, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  palSetLineMode(DEBUG, PAL_MODE_OUTPUT_PUSHPULL | PAL_STM32_OSPEED_HIGHEST);
  
  spiStart(SPI_DRIVER, &spi_cfg_8);
  spiAcquireBus(SPI_DRIVER);
  /*
   * Starting GPT5 driver, it is used for checking the BUSFREE Signal
   */
  gptStart(&GPTD5, &gpt5cfg1);

  BUS_in_use = 1; //assume bus is in use
}

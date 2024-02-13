/*
 * SPI.h
 *
 *  Created on: Nov 19, 2022
 *      Author: rob
 */

#ifndef USERLIB_INCLUDE_SPI_H_
#define USERLIB_INCLUDE_SPI_H_

#include "ch.h"
#include "hal.h"
#include "ostrich.h"

//typedef union {
//  uint32_t _32;
//  struct _8{
//    uint8_t _8l;
//    uint8_t _8lm;
//    uint8_t _8hm;
//    uint8_t _8h;
//  };
//}u_cv_t;

typedef struct {
    union {
      uint32_t _32;
      struct {
        uint8_t _8l;
        uint8_t _8lm;
        uint8_t _8hm;
        uint8_t _8h;
      };
    };
  uint8_t cs;
  uint8_t mask;
} st_configdata_t;

#define SPI_DRIVER   (&SPID1)
#define SPI_PORT     GPIOA
#define SCK_PAD      5  //PA5
#define MISO_PAD     6  //PA6
#define MOSI_PAD     7  //PA7
//#define CS_PORT      GPIOC
//#define CS_PAD       4

#define PLD           PAL_LINE(GPIOB, 12U) // Low: Load into Shift register
#define SEL0          PAL_LINE(GPIOC, 13U) // Select RAMWE
#define SEL1          PAL_LINE(GPIOC, 14U) // Select RAMWE
#define SEL2          PAL_LINE(GPIOC, 15U) // Select RAMWE
#define SEL4          PAL_LINE(GPIOA, 1U)  // Select RAMWE
#define ON_OFF        PAL_LINE(GPIOA, 0U)  // '138 Output On / Off = Write Enable
#define RAMOE         PAL_LINE(GPIOB, 2U)  // Ram Output Enable - Low Active
#define BUSFREE       PAL_LINE(GPIOB, 9U)  // Low if Bus is High-Z - Input
#define MRD           PAL_LINE(GPIOA, 15U) // Memory Read - Low Active
#define MWR           PAL_LINE(GPIOA, 9U)  // Memory Write - Low Active
#define CNT           PAL_LINE(GPIOA, 8U)  // Counter Tic
#define MRC           PAL_LINE(GPIOB, 15U) // Counter Reset - Low Active
#define CPR           PAL_LINE(GPIOB, 14U) // Counter Latch - Low Active
#define CNTOE         PAL_LINE(GPIOB, 13U) // Counter Output Enable - Low Active
#define TRESET        PAL_LINE(GPIOB, 10U) // Target Reset - High active
#define DEBUG         PAL_LINE(GPIOB, 0U)
#define RAM_CSOVR     PAL_LINE(GPIOA, 10U) // Override for RAM Chipselect

#define PLD_IDLE palSetLine(PLD)
#define PLD_LOAD palClearLine(PLD)
#define WE_INACTIVE palSetLine(ON_OFF)
#define WE_ACTIVE palClearLine(ON_OFF)
#define CNT_ACTIVE palSetLine(CNT)
#define CNT_INACTIVE palClearLine(CNT)
#define MRC_INACTIVE palSetLine(MRC)
#define MRC_ACTIVE palClearLine(MRC)
#define CPR_INACTIVE palSetLine(CPR)
#define CPR_ACTIVE palClearLine(CPR)
#define CNTOE_INACTIVE palSetLine(CNTOE)
#define CNTOE_ACTIVE palClearLine(CNTOE)
#define RAMOE_ACTIVE palClearLine(RAMOE)
#define RAMOE_INACTIVE palSetLine(RAMOE)
#define TRESET_INACTIVE palClearLine(TRESET)
#define TRESET_ACTIVE palSetLine(TRESET)
#define DEBUG_HI  palSetLine(DEBUG)
#define DEBUG_LOW palClearLine(DEBUG)
#define RCSOR_INACTIVE palSetLine(RAM_CSOVR)
#define RCSOR_ACTIVE   palClearLine(RAM_CSOVR)

void SPI_init(void);
//void WriteSPI(int32_t val);
void write_single_byte(uint8_t data, int32_t address, uint8_t reset);
uint8_t read_single_byte(int32_t address, uint8_t reset);
uint8_t read_next_byte(void);
void write_next_byte(uint8_t data);
void read_block(int32_t address, int32_t len, uint8_t * data, uint8_t reset);
void write_block(int32_t address, int32_t len, uint8_t * data, uint8_t reset);
void write_config(uint8_t* buf);
void write_pins(uint8_t data);

#endif /* USERLIB_INCLUDE_SPI_H_ */

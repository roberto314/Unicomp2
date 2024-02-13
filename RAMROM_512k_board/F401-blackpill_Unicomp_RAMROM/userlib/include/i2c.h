/*
 * i2c.h
 *
 *  Created on: Sep 15, 2023
 *      Author: rob
 */

#ifndef USERLIB_INCLUDE_I2C_H_
#define USERLIB_INCLUDE_I2C_H_

#define I2C_BUS          I2CD1
#define DS1085_DEVADDR   0x58
#define DS1085_DAC       0x08
#define DS1085_OFFSET    0x0E
#define DS1085_DIV       0x01
#define DS1085_MUX       0x02
#define DS1085_ADDR      0x0D
#define DS1085_RANGE     0x37
#define DS1085_WRITE_E2  0x3F

#define CTRL1           PAL_LINE(GPIOB, 8U) //Input of DS1085

#define OUTPUT_OFF palSetLine(CTRL1)   // CTRL1 of DS1085
#define OUTPUT_ON  palClearLine(CTRL1) // CTRL1 of DS1085

void i2c_init(void);
void write_clock(uint8_t* buf);
uint8_t read_clock(uint8_t* buf);

#endif /* USERLIB_INCLUDE_I2C_H_ */

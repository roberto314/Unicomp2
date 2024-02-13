/*
 * comm.h
 *
 *  Created on: 04.02.2018
 *      Author: Anwender
 */

#ifndef USERLIB_INCLUDE_COMM_H_
#define USERLIB_INCLUDE_COMM_H_

#include "main.h"
//#include "myStringfunctions.h"
#define cli_println(a); chprintf((BaseSequentialStream *)&DEBUGPORT, a"\r\n");
#define OK(); do{cli_println(" ... OK"); chThdSleepMilliseconds(20);}while(0)

void cmd_spi(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_fill(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_br(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_rb(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_wb(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_test(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_reg32(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_reg16(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_bas(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_off(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_status(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_modify(BaseSequentialStream *chp, int argc, char *argv[]);
void cmd_wc(BaseSequentialStream *chp, int argc, char *argv[]);

#endif /* USERLIB_INCLUDE_COMM_H_ */

/*
 * pwm.c
 *
 *  Created on: Sep 23, 2020
 *      Author: rob
 */


#include "ch.h"
#include "hal.h"

//#include "comm.h"
#include "chprintf.h"
#include "stdlib.h"
#include "string.h" /* for memset */
#include "shell.h"
#include "mypwm.h"

#define FREQ 168

uint16_t pw4=FREQ/2;
uint16_t freq=FREQ;



static void pwmpcb(PWMDriver *pwmp) {

  (void)pwmp;
  //palClearPad(GPIOD, GPIOD_LED5);
}

static void pwmc1cb(PWMDriver *pwmp) {

  (void)pwmp;
  //palTogglePad(GPIOD, GPIOD_LED5);
}

static PWMConfig pwmcfg = {
  168000000U,                                    /* 10kHz PWM clock frequency.   */
  FREQ,                                    /* Initial PWM period 1S.       */
  NULL,
  {
   {PWM_OUTPUT_ACTIVE_HIGH, NULL},
   {PWM_OUTPUT_DISABLED, NULL},
   {PWM_OUTPUT_DISABLED, NULL},
   {PWM_OUTPUT_DISABLED, NULL}
  },
  0,
  0
};


void cmd_change_freq(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)argv;
  uint32_t temp;
  if (argc != 1) {
    temp = freq;
    temp *= 1000;

    chprintf(chp, "changes timer 1 PWM Frequency\r\n");
    chprintf(chp, "PWM Frequency is: %u kHz\r\n", (uint16_t)(temp/168));
    return;
  }
  freq = atoi(argv[0]);
  pwmChangePeriod(&PWMD3, freq);
  pwmEnableChannel(&PWMD3, 0, (freq));
}
void cmd_change_pw4(BaseSequentialStream *chp, int argc, char *argv[]) {
  (void)argv;
  if (argc != 1) {
    chprintf(chp, "writes new pulse width to timer 1\r\n");
    chprintf(chp, "Duty Cycle is: %u\r\n", pw4);
    return;
  }
  pw4 = atoi(argv[0]);
  pwmEnableChannel(&PWMD3, 0, pw4);
}

void mypwmInit(void){
  pwmStart(&PWMD3, &pwmcfg);
  //pwmEnablePeriodicNotification(&PWMD1);
  palSetPadMode(GPIOB, 4, PAL_MODE_ALTERNATE(2));
  pwmEnableChannel(&PWMD3, 0, pw4);
  //pwmEnableChannelNotification(&PWMD1, 0);
}

/*
    ChibiOS - Copyright (C) 2006..2018 Giovanni Di Sirio

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
#include "main.h"
#include "ch.h"
#include "hal.h"
#include <string.h>
#include <stdlib.h>
#include "portab.h"
#include "shell.h"
#include "chprintf.h"

#include "SPI.h"
#include "i2c.h"
#include "usbcfg.h"
#include "ostrich.h"
#include "comm.h"
#include "mypwm.h"

//#define usb_lld_connect_bus(usbp)
//#define usb_lld_disconnect_bus(usbp)

extern THD_WORKING_AREA(waCharacterInputThread, 128);
extern THD_FUNCTION(CharacterInputThread, arg);
//uint8_t buffer[256];

/*===========================================================================*/
/* Command line related.                                                     */
/*===========================================================================*/
BaseSequentialStream *const shell = (BaseSequentialStream *)&SHELLPORT;
BaseSequentialStream *const ost = (BaseSequentialStream *)&OSTRICHPORT;
BaseSequentialStream *const dbg = (BaseSequentialStream *)&DEBUGPORT;

#define SHELL_WA_SIZE   THD_WORKING_AREA_SIZE(2048)

char history_buffer[8*64];
char *completion_buffer[SHELL_MAX_COMPLETIONS];

static const ShellCommand commands[] = {
  {"wb", cmd_wb},
  {"fill", cmd_fill},
  {"rb", cmd_rb},
  {"br", cmd_br},
  {"spi",cmd_spi},
  {"wc", cmd_wc},
  {"test",cmd_test},
  {"freq", cmd_change_freq},
  {"dc", cmd_change_pw4},
  {NULL, NULL}
};
static const ShellConfig shell_cfg1 = {
  (BaseSequentialStream *)&SHELLPORT,
  commands,
  history_buffer,
  sizeof(history_buffer),
  completion_buffer
};

//static const ShellCommand commands[] = {
//  {"test", cmd_test},
//  {NULL, NULL}
//};
//
//static const ShellConfig shell_cfg1 = {
//  (BaseSequentialStream *)&SHELLPORT,
//  commands
//};

/*
 * Green LED blinker thread, times are in milliseconds.
 */
//static THD_WORKING_AREA(waThread1, 128);
//static THD_FUNCTION(Thread1, arg) {
//
//  (void)arg;
//  chRegSetThreadName("blinker");
//  while (true) {
//    //palClearPad(GPIOA, 6);
//    chThdSleepMilliseconds(500);
//    //palSetPad(GPIOA, 6);
//    chThdSleepMilliseconds(500);
//  }
//}

/*
 * Application entry point.
 */
int main(void) {
  thread_t *shelltp = NULL;
  event_listener_t shell_el;

  /*
   * System initializations.
   * - HAL initialization, this also initializes the configured device drivers
   *   and performs the board-specific initializations.
   * - Kernel initialization, the main() function becomes a thread and the
   *   RTOS is active.
   */
  halInit();
  chSysInit();

  //PA2(TX) and PA3(RX) are routed to USART2
  SerialConfig serial_config6 = {
      //115200,
      115200,
      0,
      0,
      0
  };

  sdStart(&SHELLPORT, &serial_config6);
  palSetPadMode(GPIOA, 2, PAL_MODE_ALTERNATE(7));
  palSetPadMode(GPIOA, 3, PAL_MODE_ALTERNATE(7));

  chprintf(dbg, "\r\nNVRAM Programmer: %i.%i \r\nSystem started. (Shell)\r\n", VMAJOR, VMINOR);
  //chprintf(ost, "\r\nNVRAM Programmer: %i.%i \r\nSystem started. (Ostrich)\r\nTest with 'VV' - should return 'N'", VMAJOR, VMINOR);

//  #ifdef OSTRICHUSB
  sduObjectInit(&OSTRICHPORT);
  sduStart(&OSTRICHPORT, &serusbcfg1);
//  palSetPadMode(GPIOA, 11, PAL_MODE_ALTERNATE(10));
//  palSetPadMode(GPIOA, 12, PAL_MODE_ALTERNATE(10));

  usbDisconnectBus(serusbcfg1.usbp);
  chThdSleepMilliseconds(1500);
  usbStart(serusbcfg1.usbp, &usbcfg);
  usbConnectBus(serusbcfg1.usbp);

//  #else
//  SerialConfig serial_config2 = {
//      115200,
//      0,
//      0,
//      0
//  };
//  sdStart(&SD2, &serial_config2);
//  palSetPadMode(GPIOA, 2, PAL_MODE_ALTERNATE(7));
//  palSetPadMode(GPIOA, 3, PAL_MODE_ALTERNATE(7));
//  #endif
  mypwmInit();
  SPI_init();
  i2c_init();
  start_ostrich_thread();
  /*
   * Shell manager initialization.
   * Event zero is shell exit.
   */
  shellInit();
  chEvtRegister(&shell_terminated, &shell_el, 0);

  /*
   * Normal main() thread activity, in this demo it does nothing except
   * sleeping in a loop and check the button state.
   */
  while (true) {
#if USB_SHELL == 1
    if (SHELLPORT.config->usbp->state == USB_ACTIVE) {
      /* Starting shells.*/
      if (shelltp == NULL) {
        shelltp = chThdCreateFromHeap(NULL, SHELL_WA_SIZE,
                                       "shell1", NORMALPRIO + 1,
                                       shellThread, (void *)&shell_cfg1);
      }
#else
    if (!shelltp)
      shelltp = chThdCreateFromHeap(NULL, SHELL_WA_SIZE,
                                    "shell", NORMALPRIO + 1,
                                    shellThread, (void *)&shell_cfg1);
    else if (chThdTerminatedX(shelltp)) {
      chThdRelease(shelltp);    /* Recovers memory of the previous shell.   */
      shelltp = NULL;           /* Triggers spawning of a new shell.        */
    }
#endif
    /* Waiting for an exit event then freeing terminated shells.*/
    chEvtWaitAny(EVENT_MASK(0));
    if (chThdTerminatedX(shelltp)) {
      chThdRelease(shelltp);
      shelltp = NULL;
    }
  }
  chThdSleepMilliseconds(1000);
//  palTogglePad(GPIOA, 5);
}


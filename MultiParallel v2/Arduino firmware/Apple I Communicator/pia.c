/*
    PIA Communicator from RC6502
    https://github.com/tebl/RC6502-Apple-1-Replica
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
#include <avr/interrupt.h>
#include <stdio.h>
#include <stdlib.h>
#include <avr/io.h>
#include <util/delay.h>
#include <avr/sfr_defs.h>
#include "uart.h"

#define BAUD 115200

// VT100 codes (used for cursor and text color implementation)
#define VT100_OFF           "\033[0m"     // Disable formatting
#define VT100_DEFAULT       "\033[32m"    // Color green
#define VT100_BLINK         "\033[5;32m"  // Blink color green
#define VT100_BOLD          "\033[1;32m"  // Bold color green
#define VT100_CLS           "\033[2J"     // Clear screen
#define VT100_RESET_CURSOR  "\033[H"      // Position cursor in top left corner
#define VT100_CURSOR_LEFT   "\033[1D"     // Move cursor one column to the left
#define VT100_ERASE_EOL     "\033[K"      // Erase from cursor until end of line
#define CURSOR_CHAR   "@"

// Port definitions (Arduino pins connected to the PIA)
// PIN_PA3 8     // PB0 - out
// PIN_PA4 9     // PB1 - out
// PIN_PA5 10    // PB2 - out
// PIN_PA6 11    // PB3 - out
// PIN_STROBE 12 // PB4 - out
// PIN_RST 13    // PB5 - out
// or KBD_RDY    // PB5
// PIN_DA  A0    // PC0
// PIN_RDA A1    // PC1 - out
// PIN_PB6 A2    // PC2
// PIN_PB5 A3    // PC3
// PIN_PB4 A4    // PC4
// PIN_PB3 A5    // PC5
// TX            // PD0 - out
// RX            // PD1
// PIN_PB0 2     // PD2
// PIN_PB1 3     // PD3
// PIN_PB2 4     // PD4
// PIN_PA0 5     // PD5 - out
// PIN_PA1 6     // PD6 - out
// PIN_PA2 7     // PD7 - out

#define SET_PA0  (PORTD |= (1 << 5))
#define CLR_PA0 (PORTD &= ~(1 << 5))
#define SET_PA1  (PORTD |= (1 << 6))
#define CLR_PA1 (PORTD &= ~(1 << 6))
#define SET_PA2  (PORTD |= (1 << 7))
#define CLR_PA2 (PORTD &= ~(1 << 7))
#define SET_PA3  (PORTB |= (1 << 0))
#define CLR_PA3 (PORTB &= ~(1 << 0))
#define SET_PA4  (PORTB |= (1 << 1))
#define CLR_PA4 (PORTB &= ~(1 << 1))
#define SET_PA5  (PORTB |= (1 << 2))
#define CLR_PA5 (PORTB &= ~(1 << 2))
#define SET_PA6  (PORTB |= (1 << 3))
#define CLR_PA6 (PORTB &= ~(1 << 3))

#define GET_PB0 (PIND & ( 1 << 2))
#define GET_PB1 (PIND & ( 1 << 3))
#define GET_PB2 (PIND & ( 1 << 4))
#define GET_PB3 (PINC & ( 1 << 5))
#define GET_PB4 (PINC & ( 1 << 4))
#define GET_PB5 (PINC & ( 1 << 3))
#define GET_PB6 (PINC & ( 1 << 2))

#define RST_HI PORTB |= (1 << 5)
#define RST_LO PORTB &= ~(1 << 5)
#define KBD_STROBE_LO PORTB &= ~(1 << 4)
#define KBD_STROBE_HI PORTB |= (1 << 4)
#define VIDEO_RDA_LO PORTC &= ~(1 << 1)
#define VIDEO_RDA_HI PORTC |= (1 << 1)
#define GET_KBD_READY (PINB & (1 << 5))
#define GET_VIDEO_DA (PINC & (1 << 0))

#define KBD_INTERRUPT_ENABLE 0
#define KBD_SEND_TIMEOUT 23

uint8_t cursor_visible = 0;

void show_cursor();
void hide_cursor();
void process_video_data();

void pia_init(void){
#if KBD_INTERRUPT_ENABLE == 1 
  DDRB = 0x1F;   // PB0..5 Output for KBD_RDY on PB5
#else
  DDRB = 0x3F;   // PB0..5 Output for Reset on PB5
#endif
  DDRC = 2;      // PC1 Output
  DDRD = 0xE1;   // PD0,5..7 Output
  uart_init(BAUD);
  //uart_putc('!');
  //uart_puts("\r\nThis is the Second uart\r\n");
  uart_puts_p(PSTR(VT100_CLS));
  uart_puts_p(PSTR(VT100_RESET_CURSOR));
  uart_puts_p(PSTR(VT100_OFF));
  uart_puts_p(PSTR(VT100_DEFAULT));
  uart_puts_p(PSTR("+------------------------+\r\n"));
  uart_puts_p(PSTR("|      "));
  uart_puts_p(PSTR(VT100_OFF));
  uart_puts_p(PSTR(VT100_BOLD));
  uart_puts_p(PSTR("APPLE 1 MINI"));
  uart_puts_p(PSTR(VT100_OFF));
  uart_puts_p(PSTR(VT100_DEFAULT));
  uart_puts_p(PSTR("      |\r\n"));
  uart_puts_p(PSTR(VT100_OFF));
  uart_puts_p(PSTR(VT100_DEFAULT));
  uart_puts_p(PSTR("|------------------------|\r\n"));
  uart_puts_p(PSTR("| FIRMWARE VERSION 2.0   |\r\n"));
  uart_puts_p(PSTR("| RUUD VAN FALIER, 2017  |\r\n"));
  uart_puts_p(PSTR("| ROBERT OFFNER, 2022    |\r\n"));
  uart_puts_p(PSTR("+------------------------+\r\n"));
  uart_puts_p(PSTR("\r\n"));
  uart_puts_p(PSTR("READY...\r\n"));
  uart_puts_p(PSTR("\r\n"));
  uart_puts_p(PSTR(VT100_OFF));  
  show_cursor();  
#if KBD_INTERRUPT_ENABLE == 0
  RST_LO;
#endif
}

char map_to_ascii(int c){
  /* Convert ESC key */
  if (c == 203) c = 27;
  /* Ctrl A-Z */
  if (c > 576 && c < 603) c -= 576;
  /* Convert lowercase keys to UPPERCASE */
  if (c > 96 && c < 123) c -= 32;
  return c;
}

void pia_send(uint8_t c){
  /* Make sure STROBE signal is off */
  KBD_STROBE_LO;
  c = map_to_ascii(c);
  /* Output the actual keys as long as it's supported */
  if (c < 96){
    (c & 1)?SET_PA0:CLR_PA0;
    (c & 2)?SET_PA1:CLR_PA1;
    (c & 4)?SET_PA2:CLR_PA2;
    (c & 8)?SET_PA3:CLR_PA3;
    (c & 0x10)?SET_PA4:CLR_PA4;
    (c & 0x20)?SET_PA5:CLR_PA5;
    (c & 0x40)?SET_PA6:CLR_PA6;

    KBD_STROBE_HI;
    _delay_us(1);
    if (KBD_INTERRUPT_ENABLE){
      uint8_t timeout;

      /* Wait for KBD_READY (CA2) to go HIGH */
      timeout = KBD_SEND_TIMEOUT;
      while(GET_KBD_READY == 0){
        if (timeout == 0) break;
        else timeout--;
      }
      KBD_STROBE_LO;

      /* Wait for KBD_READY (CA2) to go LOW */
      timeout = KBD_SEND_TIMEOUT;
      while(GET_KBD_READY != 0){
        if (timeout == 0) break;
        else timeout--;
      }
    } else {
      KBD_STROBE_LO;
    }
  }
  process_video_data();
}

void process_serial_data(){
  if (uart_test() > 0) {
    uint8_t c = uart_getc();
    pia_send(c);
  }
  //process_video_data();
}

char send_ascii(char c){
  switch (c) {
    case '\r': uart_putc('\n'); /* Replace CR with LF */
    default:
      uart_putc(c);
  }
}
uint8_t read_video_data(void){
  uint8_t ret;
  ret = ((PIND & 0x1C) >> 2);
//  ret |= GET_PB0?1:0;
//  ret |= GET_PB1?2:0;
//  ret |= GET_PB2?4:0;
  ret |= GET_PB3?8:0;
  ret |= GET_PB4?0x10:0;
  ret |= GET_PB5?0x20:0;
  ret |= GET_PB6?0x40:0;
  //(PINC & 0x3C)
  return ret;
}

void process_video_data(){
  if (GET_VIDEO_DA){
    char c = read_video_data();
    VIDEO_RDA_LO;
    _delay_us(1);
    VIDEO_RDA_HI;
    
    if (c == 13){
      hide_cursor();
      uart_puts_p(PSTR("\r\n"));
    } 
    else if (c > 31){
      hide_cursor();
      uart_puts_p(PSTR(VT100_DEFAULT));
      //send_ascii(c);
      uart_putc(c);
      uart_puts_p(PSTR(VT100_OFF));
    }
    show_cursor();
  }
}

/*
 * Remove the cursor character from the screen by sending a backspace.
 */
void hide_cursor(){
  if (cursor_visible)  {
    uart_puts_p(PSTR(VT100_CURSOR_LEFT));
    uart_puts_p(PSTR(VT100_ERASE_EOL));
    cursor_visible = 0;
  }
}

/*
 * Display blinking cursor character.
 */
void show_cursor(){
  if (!cursor_visible)  {
    uart_puts_p(PSTR(VT100_BLINK));
    uart_puts_p(PSTR(CURSOR_CHAR));
    uart_puts_p(PSTR(VT100_OFF));
    cursor_visible = 1;
  }
}

int main(void){
    pia_init();
   // _delay_ms(20);
#if KBD_INTERRUPT_ENABLE == 0
  RST_HI;
#endif    
    while(1){
        process_video_data();
        process_serial_data();
    }
}
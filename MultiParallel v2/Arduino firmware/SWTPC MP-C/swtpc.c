#include <avr/interrupt.h>
#include <stdio.h>
#include <stdlib.h>
#include <avr/io.h>
#include <util/delay.h>
#include <avr/sfr_defs.h>


// Port definitions 
// 6821Pin - Arduino - Atmel Pins
// PIN_PA3     8    // PB0 - 
// PIN_PA4     9    // PB1 - 
// PIN_PA5    10    // PB2 - 
// PIN_PA6    11    // PB3 - 
// PIN_CA1    12    // PB4 - 
// FREE       13    // PB5 - 
// PIN_PB7    A0    // PC0 - out timer in
// PIN_RDA    A1    // PC1 - 
// PIN_PB6    A2    // PC2
// PIN_PB5    A3    // PC3
// PIN_PB4    A4    // PC4
// PIN_PB3    A5    // PC5
// FREE       A6    // 
// FREE       A7    // 
// TX               // PD0 - out
// RX               // PD1
// PIN_PB0     2    // PD2 - in reset timer (high active)
// PIN_PB1     3    // PD3
// PIN_PB2     4    // PD4 - in switch rx/tx (high for send)
// PIN_PA0     5    // PD5 - in 6821 tx
// PIN_PA1     6    // PD6 - 
// PIN_PA2     7    // PD7 - 

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
#define SET_PB7  (PORTC |= (1 << 0))
#define CLR_PB7 (PORTC &= ~(1 << 0))

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

//#define DLY_SEND (65535 - 53332) // 300Bd
//#define DLY_REC (65535 - 26666)  // 300Bd

//#define DLY_SEND (65535 - 26666) // 600Bd
//#define DLY_REC (65535 - 13333)  // 600Bd

#define DLY_SEND (65535 - 13333) // 1200Bd
#define DLY_REC (65535 - 6666)  // 1200Bd

uint8_t flag;
void init(void){
  DDRC = 1;      // PC0 Output (=PB7 on 6821)
  DDRD = 1; // All input except TX
  DDRB = (1<<5); // PB5 debug
  CLR_PB7;
  //CLR_PB7;
  PORTB = (1<<5); // Set PB5 (Debug)
  // we need 1.33ms for Send and 0.666ms for Receive
  // Atmel runs at 16MHz, 16bit overflow is after 4.096ms so we can run at full blast
  TCCR1A = 0; // Normal Mode
  TCCR1B = (1<<CS10);  //set the pre-scalar as 1 and start timer
  TIMSK1 = ((1<<TOIE1)); // Overflow Interrupt of Timer1 enable
  EICRA = ((1<<ISC00) | (1<<ISC01)); //Rising Edge generates Interrupt
  EIMSK = (1<<INT0);               // Enable External Interrupt 0
  flag = 0;
  sei();                           // Global Interrupts enable
}

int main(void){
    init();
   // _delay_ms(20);
    while(1){

    }
}

ISR (TIMER1_OVF_vect){
  //PORTB ^= (1<<5); // Toggle PB5 (Debug)
  // We do this because the 6821 changes the PB2 Line AFTER the counter has started!
  if (flag){ // PB2 was high at reset
    SET_PB7;
    TCCR1B = 0; // Stop Timer
  }
  else{
    if (GET_PB2){ // Send
      TCNT1 = DLY_REC; // go again
      flag = 1;
    }
    else{
      SET_PB7;
      TCCR1B = 0; // Stop Timer
    }
  }
}

ISR (INT0_vect){
  if (GET_PB2){ // Send
    TCNT1 = DLY_SEND;
    flag = 1;
  }
  else{              // Receive
    TCNT1 = DLY_REC;
    flag = 0;
  }
  CLR_PB7;
  TCCR1B = (1<<CS10);  //set the pre-scalar as 1 and start timer
}

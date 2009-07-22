#ifndef PINS_H
#define PINS_H

#define LEDPIN 13


//LOGGER UNIT
//INPUTS
#define LU_IN_RXi 0                         //RXi (inter-TC and LU comms)
#define LU_IN_GDLOX_RX 10                   //uDrive RX
#define LU_IN_COM1_RX 2                     //COM1 RX (thermostats)
#define LU_ANALOG_REDUN_TAKEOVER_CHECK 0    //Connected to ~takeover.
//OUTPUTS
#define LU_OUT_TXi 1                        //TXi (inter-TC and LU comms)
#define LU_OUT_GDLOX_TX 11                  //uDrive TX
#define LU_OUT_GDLOX_RST 12                 //uDrive reset pin
#define LU_OUT_COM1_TX 3                    //COM1 TX (thermostats)
#define LU_OUT_SADDR_D 4                    //Serial selector SR data.
#define LU_OUT_SADDR_C 5                    //Serial selector SR clock.
#define LU_OUT_REDUN_SR_D 8                 //Redundancy takeover code SR data.
#define LU_OUT_REDUN_SR_C 9                 //Redundancy takeover code SR clock.
#define LU_OUT_RST_REQ 7                    //Request to reset primary
//BIDI
#define LU_INOUT_REDUNDANCY 6               //Heartbeat

//TIME CONTROLLER
//INPUTS
#define TC_IN_RXi 0                         //RXi (inter-TC and LU comms)
#define TC_IN_REDUN_TAKEOVER_CHECK 9        //Connected to ~takeover.
#define TC_IN_RSTPIN 12                     //Experiment reset switch. Active low.
//OUTPUTS
#define TC_OUT_TXi 1                        //TXi (inter-TC and LU comms)
#define TC_OUT_POWER_SR_D 2                 //Power status SR data.
#define TC_OUT_POWER_SR_C 3                 //Power status SR clock.
#define TC_OUT_POWER_SR_L 4                 //Power status SR latch.
#define TC_OUT_EXP_TRIGGER_RELAY_ON 5       //'ON' coil for experiment power relay. Active high.
#define TC_OUT_EXP_TRIGGER_RELAY_OFF 6      //'OFF' coil for experiment power relay. Active high.
#define TC_OUT_RST_REQ 8                    //Request to reset primary
#define TC_OUT_REDUN_SR_D 10                //Redundancy takeover code SR data.
#define TC_OUT_REDUN_SR_C 11                //Redundancy takeover code SR clock.
//BIDI
#define TC_INOUT_REDUNDANCY 7               //Heartbeat

#endif

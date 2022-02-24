`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Dawei Sun
// 
// Create Date: 24.02.2022 20:45:09
// Design Name: MouseDriver
// Module Name: MouseMasterSM
// Project Name: DSL
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module MouseMasterSM(
    input CLK,
    input RESET,
    // Transmitter Control
    output SEND_BYTE,
    output [7:0] BYTE_TO_SEND,
    input BYTE_SENT,
    // Receiver Control
    output READ_ENABLE,
    input [7:0] BYTE_READ,
    input [1:0] BYTE_ERROR_CODE,
    input BYTE_READY,
    // Data Registers
    output [7:0] MOUSE_DX,
    output [7:0] MOUSE_DY,
    output [7:0] MOUSE_STATUS,
    output SEND_INTERRUPT
);

    
    //////////////////////////////////////////////////////////////////////////////////
    //
    // Main state machine
    //
    // Setup sequence
    // 1) Send FF -- Reset
    // 2) Read FA -- Mouse acknowledge
    // 3) Read AA -- Self-test pass
    // 4) Read 00 -- Mouse ID
    // 5) Send F4 -- Start transmitting 
    // 6) Read FA -- Mouse acknowledge (F4 in this case, parity check skipped)
    //
    // Setup sequence finished, flag read enable
    // Host read mouse information 3 bytes at a time
    // S1) Wait for first read. Save to Status upon arrival. Goto S2.
    // S2) Wait for second read. Save to DX upon arrival. Goto S3.
    // S3) Wait for third read. Save to DY upon arrival. Goto S1.
    // Send interrupt
    //
    //////////////////////////////////////////////////////////////////////////////////


    // State control
    reg [3:0] curr_state;
    reg [3:0] next_state;
    reg [23:0] curr_ctr;
    reg [23:0] next_ctr;

    // Transmitter control
    reg curr_sendByte;
    reg next_sendByte;
    reg [7:0] curr_byteToSend;
    reg [7:0] next_byteToSend;

    // Receiver control
    reg curr_readEnable;
    reg next_readEnable;

    // Data registers
    reg [7:0] curr_status;
    reg [7:0] next_status;
    reg [7:0] curr_DX;
    reg [7:0] next_DX;
    reg [7:0] curr_DY;
    reg [7:0] next_DY;
    reg [7:0] curr_sendInterrupt;
    reg [7:0] next_sendInterrupt;

endmodule
